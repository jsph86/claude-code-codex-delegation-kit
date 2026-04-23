#!/usr/bin/env bash
# ask-codex.sh — Delegate read-only search / analysis / design consultation to Codex.
#
# Claude Code uses this wrapper to offload heavy read-only work to Codex CLI so
# Codex's iterations don't pollute Claude's context window, and to obtain
# independent second engines for critical review (second-opinion) or independent
# design proposals (consult) that Claude can compare against its own thinking.
#
# Usage:
#   ask-codex.sh [FLAGS] <slug> "<prompt>"
#   cat prompt.md | ask-codex.sh [FLAGS] <slug>
#   ask-codex.sh --check-model
#
# Flags:
#   --mode=search|analyze|second-opinion|consult   (default: search)
#   --model=<id>                                   (default: from ~/.codex/config.toml)
#   --reasoning=low|medium|high|xhigh              (default: xhigh, pinned by wrapper)
#   --timeout=<seconds>                            (requires gtimeout or timeout on PATH)
#   --check-model                                  prints effective model/reasoning, exits
#
# Output:
#   Writes a markdown report to:  <git-repo-root>/.codex-reports/<file-id>.md
#   Prints the absolute path of that file on stdout (nothing else).
#   Raw Codex stdout/stderr goes to: <git-repo-root>/.codex-reports/.<file-id>.log
#   file-id = <YYYY-MM-DD-HHMMSS>-<slug>-<mode>-<rand6hex>
#
# Exit codes:
#   0  success
#   2  usage error
#   3  codex invocation failed (report file still written with error marker)
#
# Guarantees:
#   - Codex runs with --sandbox read-only (cannot modify any file)
#   - Final message persisted via --output-last-message (no stdout scraping)
#   - Reasoning effort pinned to xhigh unless overridden via --reasoning
#   - Parallel invocations with the same slug do not collide (unique file-id)
#   - Resolved model + reasoning stamped into the report header
#
# Part of the claude-code-codex-delegation-kit. https://github.com/jsph86/claude-code-codex-delegation-kit

set -euo pipefail

KIT_VERSION="1.1.0"

CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"

resolve_from_config() {
  # Extract a top-level string value from codex config.toml. POSIX-safe.
  local key="$1" file="$2"
  [[ -f "$file" ]] || { echo ""; return; }
  awk -v k="$key" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*\[/ { exit }
    $0 ~ "^[[:space:]]*"k"[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*"/, "")
      sub(/".*$/, "")
      print
      exit
    }
  ' "$file"
}

CFG_MODEL="$(resolve_from_config model "$CODEX_CONFIG")"
CFG_REASONING="$(resolve_from_config model_reasoning_effort "$CODEX_CONFIG")"

MODE="search"
TIMEOUT=""
OVERRIDE_MODEL=""
OVERRIDE_REASONING=""
CHECK_MODEL=0

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --mode=*)       MODE="${1#--mode=}"; shift ;;
    --mode)         MODE="$2"; shift 2 ;;
    --model=*)      OVERRIDE_MODEL="${1#--model=}"; shift ;;
    --model)        OVERRIDE_MODEL="$2"; shift 2 ;;
    --reasoning=*)  OVERRIDE_REASONING="${1#--reasoning=}"; shift ;;
    --reasoning)    OVERRIDE_REASONING="$2"; shift 2 ;;
    --timeout=*)    TIMEOUT="${1#--timeout=}"; shift ;;
    --timeout)      TIMEOUT="$2"; shift 2 ;;
    --check-model)  CHECK_MODEL=1; shift ;;
    --version)      echo "ask-codex $KIT_VERSION"; exit 0 ;;
    --help|-h)
      sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "ask-codex: unknown flag: $1" >&2
      exit 2 ;;
  esac
done

EFFECTIVE_MODEL="${OVERRIDE_MODEL:-${CFG_MODEL:-<codex-default>}}"
EFFECTIVE_REASONING="${OVERRIDE_REASONING:-xhigh}"

if [[ "$CHECK_MODEL" -eq 1 ]]; then
  cat <<EOF
ask-codex $KIT_VERSION -- effective configuration
-------------------------------------------------
Codex version:     $(codex --version 2>/dev/null | head -1 || echo '<codex not on PATH>')
Config file:       $CODEX_CONFIG
Config model:      ${CFG_MODEL:-<unset -- codex built-in default applies>}
Config reasoning:  ${CFG_REASONING:-<unset>}  (wrapper overrides this for delegated calls)
Wrapper will use:
  model:           $EFFECTIVE_MODEL
  reasoning:       $EFFECTIVE_REASONING   (pinned by wrapper unless overridden via --reasoning)

Note: the wrapper pins reasoning to \`xhigh\` for delegated work regardless of
your config's \`model_reasoning_effort\`. Override per-call with \`--reasoning\`.

To change the default model for every run, edit \`model = "..."\` in:
  $CODEX_CONFIG
EOF
  exit 0
fi

SLUG="${1:-}"
PROMPT="${2:-}"

if [[ -z "$SLUG" ]]; then
  echo "ask-codex: missing <slug>. Run with --help for usage." >&2
  exit 2
fi

if ! [[ "$SLUG" =~ ^[a-z0-9][a-z0-9-]{0,79}$ ]]; then
  echo "ask-codex: slug must be lowercase-alphanumeric-with-hyphens, <=80 chars (got: $SLUG)" >&2
  exit 2
fi

if [[ -z "$PROMPT" ]] && [[ ! -t 0 ]]; then
  PROMPT="$(cat)"
fi

if [[ -z "$PROMPT" ]]; then
  echo "ask-codex: no prompt provided (pass as 2nd arg or pipe via stdin)" >&2
  exit 2
fi

case "$MODE" in
  search)
    PREAMBLE="You are assisting a Claude Code agent by performing a READ-ONLY repository exploration. Your job is to find and summarize — not to edit, create, or delete any files.

Return a concise markdown report structured as:

1. **Summary** — 2-4 sentences answering the ask.
2. **Findings** — bulleted list, each with \`file:line\` reference and a short note.
3. **Files examined** — flat list of absolute or repo-relative paths you inspected.
4. **Gaps / open questions** — anything you could not determine.

Do not speculate beyond what the code shows. Do not run destructive commands. Do not modify any files."
    ;;
  analyze)
    PREAMBLE="You are assisting a Claude Code agent by analyzing code or design READ-ONLY.

Structure your response as:

1. **Summary** — what the thing is / does.
2. **Key findings** — with \`file:line\` references.
3. **Risks / rough edges** — concrete, cited.
4. **Suggestions** — ranked by impact; note tradeoffs.

Do not modify any files. Cite evidence; avoid vague claims."
    ;;
  second-opinion)
    PREAMBLE="You are providing an independent SECOND-OPINION review for a Claude Code agent. Be critical and constructive.

Structure your response as:

1. **Agreement** — what the prior analysis got right.
2. **Gaps** — what it missed or underweighted (cite \`file:line\`).
3. **Alternative approaches** — viable options the prior analysis didn't cover.
4. **Risk reassessment** — which risks are higher/lower than stated and why.

READ-ONLY. Do not modify any files. Ground every claim in the repo."
    ;;
  consult)
    PREAMBLE="You are a senior software architect providing an INDEPENDENT design / planning proposal for a Claude Code agent. Claude is forming its own plan in parallel. You are NOT reviewing Claude's plan — you do not know what it is. Propose the approach YOU think is best based on the repo and the problem statement.

Do not try to guess Claude's plan or adapt to it. Stay independent.

Structure your response as:

1. **Restated problem** — in your own words, so misalignment with the user's ask surfaces.
2. **Proposed approach** — concrete ordered steps. Be specific, not hand-wavy.
3. **Key design decisions** — the forks in the road; for each, the branch you picked and why.
4. **Tradeoffs** — what this approach optimizes for; what it sacrifices.
5. **Risks and unknowns** — what could go wrong; what needs validation before / during / after.
6. **Alternative approaches** — 1–2 other paths briefly, with why you did not pick them.
7. **Things not to overlook** — constraints, edge cases, invariants, non-functional requirements (performance, security, migration, rollout, backward compat, testing).

Ground claims in the actual repo. Cite \`file:line\` when referencing existing code. READ-ONLY — do not modify any files."
    ;;
  *)
    echo "ask-codex: unknown mode: $MODE (want: search | analyze | second-opinion | consult)" >&2
    exit 2 ;;
esac

REPO_ROOT="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || pwd)"
OUT_DIR="$REPO_ROOT/.codex-reports"
mkdir -p "$OUT_DIR"

TS="$(date +%Y-%m-%d-%H%M%S)"
# 6 hex chars = 16M possibilities; collision-safe under parallel dispatch
RAND="$(printf '%02x%02x%02x' $((RANDOM & 0xFF)) $((RANDOM & 0xFF)) $((RANDOM & 0xFF)))"
FILE_ID="${TS}-${SLUG}-${MODE}-${RAND}"
OUT_FILE="$OUT_DIR/${FILE_ID}.md"
LAST_MSG="$OUT_DIR/.${FILE_ID}.last.tmp"
LOG_FILE="$OUT_DIR/.${FILE_ID}.log"

# ---------------------------------------------------------------------------
# Signal trap — salvage partial Codex output before dying
# ---------------------------------------------------------------------------
# When the script is killed (session cleanup, terminal close, manual kill),
# the code AFTER the `codex exec` call never runs.  This trap extracts
# whatever Codex produced from the log file and writes it to the report
# so the caller gets something instead of an empty Response section.
_extract_last_codex_turn() {
  awk '
    /^codex$/ { in_block=1; buf=""; next }
    in_block && /^(exec$|user$)/ { in_block=0 }
    in_block && /^web search:/ { in_block=0 }
    in_block { buf = buf $0 "\n" }
    END { printf "%s", buf }
  ' "$1"
}

_on_signal() {
  local sig="$1"
  local exit_code=1
  case "$sig" in
    HUP)  exit_code=129 ;;
    INT)  exit_code=130 ;;
    TERM) exit_code=143 ;;
  esac

  {
    echo
    echo "---"
    echo
    echo "_**Script received SIG${sig}** — Codex did not complete normally._"
    echo

    # Tier 1: try the --output-last-message temp file
    if [[ -s "${LAST_MSG:-}" ]]; then
      echo "_Partial response recovered from last-message file:_"
      echo
      cat "$LAST_MSG"
    # Tier 2: extract last codex text turn from the raw log
    elif [[ -s "${LOG_FILE:-}" ]]; then
      local partial
      partial="$(_extract_last_codex_turn "$LOG_FILE")"
      if [[ -n "$partial" ]]; then
        echo "_Partial response recovered from log (last Codex text turn):_"
        echo
        printf '%s\n' "$partial"
      else
        local log_lines
        log_lines="$(wc -l < "$LOG_FILE" | tr -d ' ')"
        echo "_No text response found in log (${log_lines} lines captured)._"
        echo "_Raw log preserved at \`${LOG_FILE}\`._"
      fi
    else
      echo "_No log output captured — Codex may not have started._"
    fi
  } >> "${OUT_FILE:-/dev/null}" 2>/dev/null

  # Stamp the sentinel so readers know the script was killed (portable sed -i)
  local _target="${OUT_FILE:-/dev/null}"
  if [[ -f "$_target" ]]; then
    sed 's/<!-- STATUS:RUNNING -->/<!-- STATUS:KILLED sig='"$sig"' -->/' "$_target" > "$_target.tmp" \
      && mv "$_target.tmp" "$_target"
  fi

  rm -f "${LAST_MSG:-}"
  echo "${OUT_FILE:-}"
  exit "$exit_code"
}

trap '_on_signal HUP'  SIGHUP
trap '_on_signal INT'  SIGINT
trap '_on_signal TERM' SIGTERM

FULL_PROMPT="$PREAMBLE

---

$PROMPT"

if [[ -n "$OVERRIDE_MODEL" ]]; then
  MODEL_LABEL="(overridden via --model)"
elif [[ -n "$CFG_MODEL" ]]; then
  MODEL_LABEL="(from $CODEX_CONFIG)"
else
  MODEL_LABEL="(codex built-in default — no config setting found)"
fi

if [[ -n "$OVERRIDE_REASONING" ]]; then
  REASONING_LABEL="(overridden via --reasoning)"
else
  REASONING_LABEL="(pinned to xhigh by wrapper)"
fi

{
  echo "# Codex Report — $SLUG"
  echo
  echo "| Field | Value |"
  echo "|-------|-------|"
  echo "| **Mode** | \`$MODE\` |"
  echo "| **Timestamp** | $TS |"
  echo "| **Repo root** | \`$REPO_ROOT\` |"
  echo "| **Slug** | \`$SLUG\` |"
  echo "| **File id** | \`$FILE_ID\` |"
  echo "| **Kit version** | \`$KIT_VERSION\` |"
  echo "| **Codex version** | $(codex --version 2>/dev/null | head -1 || echo '<unknown>') |"
  echo "| **Model** | \`$EFFECTIVE_MODEL\` $MODEL_LABEL |"
  echo "| **Reasoning effort** | \`$EFFECTIVE_REASONING\` $REASONING_LABEL |"
  echo
  echo "## Prompt"
  echo
  echo '```'
  printf '%s\n' "$PROMPT"
  echo '```'
  echo
  echo "## Response"
  echo
  echo "<!-- STATUS:RUNNING -->"
  echo
} > "$OUT_FILE"

CODEX_CMD=(
  codex exec
  --sandbox read-only
  --cd "$REPO_ROOT"
  --skip-git-repo-check
  --color never
  --output-last-message "$LAST_MSG"
  -c "model_reasoning_effort=\"$EFFECTIVE_REASONING\""
)

if [[ -n "$OVERRIDE_MODEL" ]]; then
  CODEX_CMD+=(-m "$OVERRIDE_MODEL")
fi

CODEX_CMD+=("$FULL_PROMPT")

if [[ -n "$TIMEOUT" ]]; then
  if command -v gtimeout >/dev/null 2>&1; then
    TIMEOUT_BIN="gtimeout"
  elif command -v timeout >/dev/null 2>&1; then
    TIMEOUT_BIN="timeout"
  else
    echo "ask-codex: --timeout=$TIMEOUT requires \`gtimeout\` or \`timeout\` on PATH." >&2
    echo "              On macOS: \`brew install coreutils\` provides \`gtimeout\`." >&2
    exit 2
  fi
  RUN=("$TIMEOUT_BIN" "${TIMEOUT}s" "${CODEX_CMD[@]}")
else
  RUN=("${CODEX_CMD[@]}")
fi

# ---------------------------------------------------------------------------
# Three-tier response extraction
# ---------------------------------------------------------------------------
# Tier 1: --output-last-message file (best — clean final text from Codex)
# Tier 2: awk extraction of last "codex" text block from the raw log
# Tier 3: jq extraction from session JSONL (~/.codex/sessions/)
_try_log_extraction() {
  [[ -s "$LOG_FILE" ]] || return 1
  local text
  text="$(_extract_last_codex_turn "$LOG_FILE")"
  [[ -n "$text" ]] || return 1
  printf '%s\n' "$text"
}

_try_session_jsonl() {
  command -v jq >/dev/null 2>&1 || return 1
  [[ -s "$LOG_FILE" ]] || return 1
  local sid
  sid="$(awk '/^session id: /{print $3; exit}' "$LOG_FILE")"
  [[ -n "$sid" ]] || return 1
  local sessions_dir="${CODEX_HOME:-$HOME/.codex}/sessions"
  local jsonl
  jsonl="$(find "$sessions_dir" -name "*${sid}*.jsonl" -type f 2>/dev/null | head -1)"
  [[ -s "$jsonl" ]] || return 1
  local text
  text="$(jq -r '
    select(.type == "response_item")
    | .payload
    | select(.type == "message" and .role == "assistant")
    | .content[].text
  ' "$jsonl" 2>/dev/null | tail -1)"
  [[ -n "$text" ]] || return 1
  printf '%s\n' "$text"
}

if "${RUN[@]}" > "$LOG_FILE" 2>&1; then
  if [[ -s "$LAST_MSG" ]]; then
    cat "$LAST_MSG" >> "$OUT_FILE"
    rm -f "$LAST_MSG"
  else
    rm -f "$LAST_MSG"
    RECOVERED=""
    RECOVERY_SOURCE=""
    RECOVERED="$(_try_log_extraction)" && RECOVERY_SOURCE="log"
    if [[ -z "$RECOVERED" ]]; then
      RECOVERED="$(_try_session_jsonl)" && RECOVERY_SOURCE="session JSONL"
    fi
    if [[ -n "$RECOVERED" ]]; then
      {
        echo "_Response recovered from ${RECOVERY_SOURCE} (--output-last-message was empty):_"
        echo
        printf '%s\n' "$RECOVERED"
      } >> "$OUT_FILE"
    else
      {
        echo
        echo "_Codex returned an empty last-message and fallback extraction failed._"
        echo "_Raw log preserved at \`$LOG_FILE\`._"
      } >> "$OUT_FILE"
    fi
  fi
  sed 's/<!-- STATUS:RUNNING -->/<!-- STATUS:COMPLETE -->/' "$OUT_FILE" > "$OUT_FILE.tmp" \
    && mv "$OUT_FILE.tmp" "$OUT_FILE"
  echo "$OUT_FILE"
  exit 0
else
  STATUS=$?
  RECOVERED=""
  RECOVERY_SOURCE=""
  RECOVERED="$(_try_log_extraction)" && RECOVERY_SOURCE="log"
  if [[ -z "$RECOVERED" ]]; then
    RECOVERED="$(_try_session_jsonl)" && RECOVERY_SOURCE="session JSONL"
  fi
  {
    echo
    if [[ -n "$RECOVERED" ]]; then
      echo "_**Codex invocation failed** (exit $STATUS) — response recovered from ${RECOVERY_SOURCE}:_"
      echo
      printf '%s\n' "$RECOVERED"
    else
      echo "_**Codex invocation failed** (exit $STATUS). Raw stderr/stdout preserved at \`$LOG_FILE\`._"
    fi
  } >> "$OUT_FILE"
  sed 's/<!-- STATUS:RUNNING -->/<!-- STATUS:FAILED exit='"$STATUS"' -->/' "$OUT_FILE" > "$OUT_FILE.tmp" \
    && mv "$OUT_FILE.tmp" "$OUT_FILE"
  rm -f "$LAST_MSG"
  echo "$OUT_FILE"
  exit 3
fi
