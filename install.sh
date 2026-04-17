#!/usr/bin/env bash
# install.sh — claude-code-codex-delegation-kit installer.
#
# Installs the Codex delegation pattern for Claude Code on this machine:
#   1. Verifies Codex CLI is installed (configuration check only by default)
#   2. Copies bin/ask-codex.sh to ~/.claude/scripts/ask-codex.sh (+x)
#   3. Installs / upgrades the rule block in ~/.claude/CLAUDE.md between
#      managed markers (safe, reversible, version-aware)
#   4. Runs ask-codex.sh --check-model as an offline configuration summary
#
# Flags:
#   --live-test     additionally run a tiny live `codex exec` to verify auth
#   --dry-run       print planned actions without writing anything
#   --force         replace the block even if the version marker matches
#   --help          show this message
#
# Safe to re-run: already-installed pieces are detected and skipped. The
# managed-block approach means upgrading the kit version will replace the
# old block in place while preserving everything else in your CLAUDE.md.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="$KIT_DIR/bin/ask-codex.sh"
SNIPPET_SRC="$KIT_DIR/templates/claude-md.md"
VERSION_FILE="$KIT_DIR/VERSION"

SCRIPT_DST_DIR="$HOME/.claude/scripts"
SCRIPT_DST="$SCRIPT_DST_DIR/ask-codex.sh"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

BEGIN_MARK="<!-- CLAUDE-CODEX-KIT:BEGIN"
END_MARK="<!-- CLAUDE-CODEX-KIT:END -->"

DRY_RUN=0
FORCE=0
LIVE_TEST=0

while [[ "${1:-}" == --* ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=1; shift ;;
    --force)     FORCE=1; shift ;;
    --live-test) LIVE_TEST=1; shift ;;
    --help|-h)
      sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *)
      echo "install.sh: unknown flag: $1" >&2
      exit 2 ;;
  esac
done

# TTY-aware colors (avoid ANSI escape garbage in pipes/CI logs)
if [[ -t 1 ]]; then
  C_CYAN=$'\033[1;36m'
  C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'
  C_RESET=$'\033[0m'
else
  C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_RESET=""
fi

step() { printf "\n%s▸ %s%s\n" "$C_CYAN" "$1" "$C_RESET"; }
ok()   { printf "  %s✓%s %s\n" "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf "  %s!%s %s\n" "$C_YELLOW" "$C_RESET" "$1"; }
err()  { printf "  %s✗%s %s\n" "$C_RED" "$C_RESET" "$1" >&2; }
note() { printf "    %s\n" "$1"; }
plan() { printf "  %s[dry-run]%s would: %s\n" "$C_YELLOW" "$C_RESET" "$1"; }

if [[ ! -f "$VERSION_FILE" ]]; then
  err "VERSION file not found at $VERSION_FILE"
  exit 1
fi
KIT_VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"

# Extract version from snippet BEGIN marker, e.g. "BEGIN v1.0.0"
SNIPPET_VERSION="$(grep -oE "$BEGIN_MARK v[0-9]+\.[0-9]+\.[0-9]+" "$SNIPPET_SRC" | awk '{print $NF}' || true)"
if [[ -z "$SNIPPET_VERSION" ]]; then
  err "Snippet file missing version marker: $SNIPPET_SRC"
  exit 1
fi
if [[ "$SNIPPET_VERSION" != "v$KIT_VERSION" ]]; then
  warn "Snippet version ($SNIPPET_VERSION) does not match VERSION file ($KIT_VERSION) -- proceeding with $SNIPPET_VERSION"
fi

step "1. Prerequisites"

if ! command -v codex >/dev/null 2>&1; then
  err "Codex CLI not found on PATH."
  cat <<EOF

    Install it first. Options:
      - npm:  npm install -g @openai/codex
      - brew: brew install openai/codex/codex
      - Or see https://github.com/openai/codex for current install guidance.

    Then authenticate (usually \`codex login\`) and re-run this installer.

EOF
  exit 1
fi
ok "Codex CLI found: $(command -v codex) ($(codex --version 2>/dev/null | head -1))"

if ! codex exec --help 2>&1 | grep -q -- '--output-last-message'; then
  err "Your Codex CLI is too old -- \`--output-last-message\` is required. Upgrade Codex and re-run."
  exit 1
fi
ok "Codex CLI supports --output-last-message and --sandbox flags"

CODEX_CONFIG="${CODEX_HOME:-$HOME/.codex}/config.toml"
if [[ ! -f "$CODEX_CONFIG" ]]; then
  warn "No Codex config at $CODEX_CONFIG. The wrapper will fall back to Codex's built-in default model."
  note "Recommended: create $CODEX_CONFIG with \`model = \"<current-top-model-id>\"\`."
else
  MODEL_LINE="$(grep -E '^[[:space:]]*model[[:space:]]*=' "$CODEX_CONFIG" | head -1 || true)"
  if [[ -n "$MODEL_LINE" ]]; then
    ok "Codex config model line: $MODEL_LINE"
  else
    warn "Codex config exists but no top-level \`model = \"...\"\` set. Consider adding one."
  fi
fi

step "2. Install wrapper"

if [[ "$DRY_RUN" -eq 1 ]]; then
  plan "mkdir -p $SCRIPT_DST_DIR"
  plan "cp $SCRIPT_SRC $SCRIPT_DST"
  plan "chmod +x $SCRIPT_DST"
else
  mkdir -p "$SCRIPT_DST_DIR"
  if [[ -f "$SCRIPT_DST" ]] && cmp -s "$SCRIPT_SRC" "$SCRIPT_DST"; then
    ok "Wrapper already up-to-date at $SCRIPT_DST"
  else
    if [[ -f "$SCRIPT_DST" ]]; then
      BACKUP="$SCRIPT_DST.bak.$(date +%Y%m%d-%H%M%S)"
      cp "$SCRIPT_DST" "$BACKUP"
      warn "Existing wrapper backed up to $BACKUP"
    fi
    cp "$SCRIPT_SRC" "$SCRIPT_DST"
    chmod +x "$SCRIPT_DST"
    ok "Wrapper installed at $SCRIPT_DST (kit version $KIT_VERSION)"
  fi
fi

step "3. CLAUDE.md rule block (managed)"

mkdir -p "$(dirname "$CLAUDE_MD")"

detect_installed_version() {
  [[ -f "$CLAUDE_MD" ]] || { echo ""; return; }
  grep -oE "$BEGIN_MARK v[0-9]+\.[0-9]+\.[0-9]+" "$CLAUDE_MD" 2>/dev/null | awk '{print $NF}' | head -1 || true
}

INSTALLED_VERSION="$(detect_installed_version)"

if [[ -z "$INSTALLED_VERSION" ]]; then
  # Not installed yet — append
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "append snippet block (version $SNIPPET_VERSION) to $CLAUDE_MD"
  else
    if [[ ! -f "$CLAUDE_MD" ]]; then
      note "Creating new $CLAUDE_MD"
      : > "$CLAUDE_MD"
    fi
    [[ -s "$CLAUDE_MD" ]] && printf "\n" >> "$CLAUDE_MD"
    cat "$SNIPPET_SRC" >> "$CLAUDE_MD"
    ok "Rule block appended to $CLAUDE_MD (version $SNIPPET_VERSION)"
  fi
elif [[ "$INSTALLED_VERSION" == "$SNIPPET_VERSION" ]] && [[ "$FORCE" -eq 0 ]]; then
  ok "Rule block already at $INSTALLED_VERSION in $CLAUDE_MD (no change). Use --force to reinstall."
else
  # Upgrade or force-replace
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "back up $CLAUDE_MD and replace the $INSTALLED_VERSION block with $SNIPPET_VERSION"
  else
    BACKUP="$CLAUDE_MD.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$CLAUDE_MD" "$BACKUP"
    warn "Existing CLAUDE.md backed up to $BACKUP"

    # Replace the block between markers using awk (POSIX-safe)
    TMP="$(mktemp)"
    awk -v snippet="$SNIPPET_SRC" '
      BEGIN {
        # Load replacement into an array
        n = 0
        while ((getline line < snippet) > 0) {
          rep[n++] = line
        }
        close(snippet)
      }
      /<!-- CLAUDE-CODEX-KIT:BEGIN/ {
        inblock = 1
        for (i = 0; i < n; i++) print rep[i]
        next
      }
      /<!-- CLAUDE-CODEX-KIT:END -->/ {
        inblock = 0
        next
      }
      !inblock { print }
    ' "$CLAUDE_MD" > "$TMP"
    mv "$TMP" "$CLAUDE_MD"
    ok "Rule block upgraded $INSTALLED_VERSION -> $SNIPPET_VERSION in $CLAUDE_MD"
  fi
fi

step "4. Configuration check (offline)"

if [[ "$DRY_RUN" -eq 1 ]]; then
  plan "run $SCRIPT_DST --check-model"
else
  if bash "$SCRIPT_DST" --check-model; then
    ok "Configuration check succeeded"
  else
    err "Configuration check failed — review output above"
    exit 1
  fi
fi

if [[ "$LIVE_TEST" -eq 1 ]]; then
  step "5. Live test (calls Codex)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    plan "bash $SCRIPT_DST --mode=search install-smoke-test '<tiny prompt>'"
  else
    TMP_REPO="$(mktemp -d)"
    (cd "$TMP_REPO" && git init -q && echo "hello" > README.md && git add README.md && git commit -q -m "seed")
    if REPORT=$(cd "$TMP_REPO" && bash "$SCRIPT_DST" --mode=search install-smoke-test "Reply with exactly: OK. Nothing else." 2>&1); then
      ok "Live test passed. Report at: $REPORT"
      rm -rf "$TMP_REPO"
    else
      err "Live test failed. Check Codex auth (\`codex login\`) and try again. Temp repo preserved at: $TMP_REPO"
      exit 1
    fi
  fi
fi

step "Done."
cat <<EOF

Next steps:
  - Open a new Claude Code session in any repo.
  - Ask a design question like: "how can I design a better <feature> page?"
  - Claude should announce: "This matches [design] triggers -- dispatching Codex --mode=consult..."
    and you will see a bash call to: $SCRIPT_DST --mode=consult ...
  - Reports land in: <repo-root>/.codex-reports/
  - Change the Codex model anytime by editing:  ${CODEX_CONFIG:-$HOME/.codex/config.toml}

Troubleshooting:
  - Claude didn't announce -> its context cache may be stale; start a fresh session.
  - Codex invocation fails -> check the raw log at <repo>/.codex-reports/.<file-id>.log
  - Audit current config: bash $SCRIPT_DST --check-model

EOF
