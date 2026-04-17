# claude-code-codex-delegation-kit

> Make Claude Code ask Codex before it burns tokens or commits to a plan.

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](./CHANGELOG.md)
[![CI](https://github.com/jsph86/claude-code-codex-delegation-kit/actions/workflows/ci.yml/badge.svg)](https://github.com/jsph86/claude-code-codex-delegation-kit/actions/workflows/ci.yml)

<!-- Demo: insert asciinema or GIF here after recording -->
<!-- [![asciicast](https://asciinema.org/a/XXXX.svg)](https://asciinema.org/a/XXXX) -->

**What you get.** Claude Code delegates heavy repo search to Codex CLI, so your context window survives. For any design / planning prompt you get *two* independent plans side-by-side — Claude's and Codex's — with Claude's comparison and recommendation on top.

- 🔒 **Read-only.** Every Codex call runs with `--sandbox read-only`. No file writes, ever.
- 📦 **No runtime deps.** Pure bash / awk / sed / grep / git / codex. Two short files.
- 🔍 **Inspectable.** No framework, no plugins, no telemetry. Read the source before you run it.

## Install

**Option A — run it yourself:**

```bash
git clone https://github.com/jsph86/claude-code-codex-delegation-kit.git
cd claude-code-codex-delegation-kit
bash install.sh
```

**Option B — have Claude Code install it:**

Paste [the install prompt](./docs/claude-code-install-prompt.md) into a Claude Code session. Claude verifies prerequisites, backs up your existing `~/.claude/CLAUDE.md`, installs the kit, and reports a full manifest.

*(Yes, you can install the tool by asking your AI assistant to install it. Feature, not bug.)*

You'll need Claude Code + Codex CLI already installed and authenticated. Full prerequisites [below](#prerequisites).

## Try it

Open a new Claude Code session in any repo and ask:

> *"how can I design a better login page?"*

Claude will announce, **before** its first tool call:

> *"This matches [design] triggers — dispatching Codex `--mode=consult` in parallel with my own planning."*

You'll see two plans — Claude's and Codex's — followed by a comparison and a recommendation.

---

## Table of contents

- [Why this exists](#why-this-exists)
- [What you get](#what-you-get-1)
- [Prerequisites](#prerequisites)
- [How it triggers](#how-it-triggers)
- [Manual usage](#manual-usage)
- [Upgrading](#upgrading)
- [Uninstalling](#uninstalling)
- [Safety & privacy](#safety--privacy)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

When Claude Code tackles a big task, it often burns through its context window iterating with `Grep` / `Glob` / sub-agents to find or understand something. That's expensive and slow.

Meanwhile, [Codex CLI](https://github.com/openai/codex) is a perfectly good read-only engine sitting right there on your machine.

This kit wires them together:

- **Heavy search, exploration, and analysis** get handed off to Codex. Claude reads the report.
- **Design and planning** prompts trigger a *dual-plan consultation* — Claude drafts its own approach, Codex drafts another independently, and Claude presents both with a comparison and a recommendation.
- **A pre-flight trigger table in `~/.claude/CLAUDE.md`** makes delegation automatic for matching prompts, so you don't have to remember to ask.

All Codex calls run with `--sandbox read-only`. The wrapper writes nothing to your repo except markdown reports in `.codex-reports/`.

---

## What you get

### Four Codex modes

| Mode | Purpose | When Claude uses it |
|---|---|---|
| `search` | Find files / patterns / call sites | Broad exploration, "find all", catalog, inventory |
| `analyze` | Understand a module end-to-end | "Explain how X works", "walk me through Y" |
| `second-opinion` | Critique an existing analysis or plan | "Review my plan", "what would you change" |
| `consult` | Propose an independent design from scratch | Any design/planning prompt — triggers dual-plan |

### The dual-plan workflow (consult mode)

When a design/planning prompt fires `--mode=consult`:

```
┌─────────────────┐     problem statement       ┌──────────────────┐
│                 │─────── + constraints ──────▶│                  │
│  Claude drafts  │  (NEVER shares own plan)    │  Codex drafts    │
│   own plan      │                             │ independent plan │
│                 │◀──── markdown report ───────│                  │
└────────┬────────┘                             └──────────────────┘
         │
         ▼
 ┌────────────────────────────────────────┐
 │ Claude presents BOTH plans to the user │
 │  - Claude's plan (written by Claude)   │
 │  - Codex's plan (attributed)           │
 │  - Where they agree / differ / missed  │
 │  - Claude's recommendation             │
 └────────────────────────────────────────┘
```

You always get two genuinely independent perspectives and Claude's synthesis on top.

### Persistent, auditable reports

Every delegated call writes a markdown report with:
- the mode, timestamp, repo, file-id
- the resolved Codex model + reasoning effort
- the prompt Claude sent
- Codex's final response

Reports land in `<repo-root>/.codex-reports/<ts>-<slug>-<mode>-<rand>.md`. Filenames are collision-safe under parallel dispatch.

---

## Prerequisites

1. **[Claude Code](https://www.anthropic.com/claude-code)** installed (CLI, desktop, or IDE extension).
2. **[Codex CLI](https://github.com/openai/codex)** installed and authenticated:
   ```bash
   npm install -g @openai/codex    # or: brew install openai/codex/codex
   codex login                     # follow the prompt
   ```
3. A top-level `model = "..."` set in `~/.codex/config.toml`, e.g.:
   ```toml
   model = "gpt-5.4"
   ```
   The installer warns if missing; the wrapper will fall back to Codex's built-in default.

---

## How it triggers

The rule block in `~/.claude/CLAUDE.md` uses a pre-flight trigger table. On every user prompt, Claude scans against this table and dispatches Codex in parallel with any other skill or tool it invokes.

| Trigger class | Matches phrases like… | Dispatches |
|---|---|---|
| Exploration / discovery | explore, investigate, map out, catalog, inventory, dig into, learn about, find all, list all, trace, scan, audit | `search` |
| Analysis | explain how X works, walk me through X, break down X, analyze X | `analyze` |
| Design (question form) | how can / should / would I/we/you design / improve / architect / structure, what's the best way to X, make X better | `consult` |
| Design (imperative form) | let's design / plan / reorganize / restructure / refactor / separate / split / merge / consolidate X, find proper name for X | `consult` |
| Review | review my plan, critique this approach, is this right, what would you change | `second-opinion` |
| Fallback | any task that realistically needs 3+ Grep/Glob iterations | `search` |

Compound prompts (e.g. *"explore the X module and reorganize the Y config"*) match multiple rows and dispatch multiple modes. The rule runs *alongside* any other skills Claude might invoke — it never substitutes for them.

---

## Manual usage

You can call the wrapper directly from your shell, outside Claude Code:

```bash
# Heavy search
bash ~/.claude/scripts/ask-codex.sh --mode=search api-endpoints \
  "List every Express route handler in src/api/. Include method, path, and auth middleware."

# Deep analysis
bash ~/.claude/scripts/ask-codex.sh --mode=analyze auth-flow \
  "Explain the end-to-end auth flow starting from the /login POST handler."

# Second opinion on your own analysis
bash ~/.claude/scripts/ask-codex.sh --mode=second-opinion my-migration-plan \
  "$(cat my-migration-plan.md)"

# Independent design proposal
bash ~/.claude/scripts/ask-codex.sh --mode=consult rate-limiter-design \
  "Design a rate limiter for the public API. Constraints: Redis-backed, per-user + per-IP, 1000 RPS ceiling."

# Audit the effective configuration (no Codex call)
bash ~/.claude/scripts/ask-codex.sh --check-model
```

### Flags

| Flag | Default | Purpose |
|---|---|---|
| `--mode=search\|analyze\|second-opinion\|consult` | `search` | Selects the system preamble |
| `--model=<id>` | `model` from `~/.codex/config.toml` | Pin a specific model for this call |
| `--reasoning=low\|medium\|high\|xhigh` | `xhigh` (wrapper-pinned) | Override reasoning effort |
| `--timeout=<seconds>` | none | Requires `gtimeout` or `timeout` on PATH |
| `--check-model` | — | Print effective config and exit (no Codex call) |
| `--version` | — | Print kit version |
| `--help` | — | Print usage |

---

## Upgrading

The installer uses a managed, versioned block in `~/.claude/CLAUDE.md`:

```markdown
<!-- CLAUDE-CODEX-KIT:BEGIN v1.0.0 -->
... rule content ...
<!-- CLAUDE-CODEX-KIT:END -->
```

To upgrade:

```bash
cd claude-code-codex-delegation-kit
git pull
bash install.sh
```

The installer detects the old version marker and replaces only the block content in place — your surrounding CLAUDE.md stays untouched. A timestamped backup is written alongside before any change.

Force a reinstall at the same version with `bash install.sh --force`.

---

## Uninstalling

```bash
# 1. Remove the wrapper
rm ~/.claude/scripts/ask-codex.sh

# 2. Open ~/.claude/CLAUDE.md in an editor and delete everything
#    from "<!-- CLAUDE-CODEX-KIT:BEGIN" through "<!-- CLAUDE-CODEX-KIT:END -->".
```

---

## Safety & privacy

See [SECURITY.md](./SECURITY.md) for the full trust boundary. Short version:

- **Codex sends your repo contents to OpenAI.** This kit does not change that — it wraps the existing Codex CLI. Don't point it at repos with secrets, customer data, or anything under NDA.
- **The wrapper writes nothing except markdown reports** in `<repo>/.codex-reports/`. No file modifications, no telemetry, no phone-home.
- **Reports contain the prompts you send** and Codex's responses. Treat them as potentially sensitive; add `.codex-reports/` to your `.gitignore` if you don't want them tracked.

---

## FAQ

<details>
<summary>Does this replace Claude Code's native search?</summary>

No. Native `Grep` / `Glob` / `Read` / `Agent(Explore)` are still available and are often the right choice for targeted lookups. The kit biases Claude toward delegation only when the task is plainly heavy (3+ search iterations, cross-repo understanding) or plainly design (where independent perspectives help).

</details>

<details>
<summary>How do I know Claude actually fired Codex?</summary>

Every delegation emits a one-sentence announcement before any tool call:

> *"This matches [exploration + design] triggers — dispatching Codex `--mode=search` + `--mode=consult`."*

If you don't see that announcement on a prompt that should have matched, the rule didn't fire. Start a fresh session (the global CLAUDE.md is cached per session) and try again.

</details>

<details>
<summary>Which Codex model runs?</summary>

The one in `~/.codex/config.toml` → `model = "..."`. The wrapper reads that file and passes the value through on every call. Change that one line when OpenAI ships a new top-tier model; every future run picks it up. Override per-call with `--model=<id>`. Audit with `ask-codex.sh --check-model`.

The wrapper pins reasoning effort to `xhigh` for delegated work regardless of your config. Override with `--reasoning=<level>`.

</details>

<details>
<summary>Can I use this with my team?</summary>

Yes. Clone the repo, have each teammate run `bash install.sh` on their own machine. The rule goes into *their* `~/.claude/CLAUDE.md`, so each person's Claude Code sessions pick it up. Everyone gets the same trigger behavior.

</details>

<details>
<summary>Will the rule ever get ignored by Claude?</summary>

The rule is a strong instruction, not a hard enforcement mechanism. LLMs exercise judgment. In practice, the pre-flight table catches most design / exploration prompts. If you see Claude skip it on a prompt that clearly matched, open an issue with the prompt — we'll evolve the trigger phrases.

</details>

---

## Contributing

PRs welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md) for ground rules, test harness, and the process for proposing new modes or trigger phrases.

The kit stays small and focused: no runtime deps beyond bash, awk, sed, grep, git, and codex. No framework creep.

---

## License

[MIT](./LICENSE) — copyright 2026 Joe Gholivand.
