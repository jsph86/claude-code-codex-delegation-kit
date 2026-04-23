# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_No unreleased changes yet. Proposals land here first; bumped into a versioned section at release time._

## [1.1.0] - 2026-04-23

### Fixed

- **Empty Codex reports** — 23% of reports (15/65 in production) returned empty Response sections. Root cause: script killed by SIGHUP/SIGTERM before post-exec code could append content, or `--output-last-message` producing an empty file when Codex exhausted context on tool calls.

### Added

- **Signal trap** (SIGHUP/SIGINT/SIGTERM) — intercepts process kill and salvages partial content from the log or last-message temp file before dying. Previously the script died silently with only the report header written.
- **Completion sentinel** — writes `<!-- STATUS:RUNNING -->` into the report header, replaced with `STATUS:COMPLETE`, `STATUS:FAILED exit=N`, or `STATUS:KILLED sig=X` on each exit path. Readers can now distinguish "still running" from "died without trace" from "finished normally."
- **Three-tier response extraction** — when `--output-last-message` is empty, falls back to: (1) awk extraction of the last Codex text block from the raw log, then (2) jq extraction from the session JSONL at `~/.codex/sessions/`. Applied to both success and failure exit paths.

### Changed

- `sed -i` operations replaced with portable `sed + mv` pattern for Linux compatibility.
- `<owner>` placeholder in script header replaced with actual GitHub username.

## [1.0.0] - 2026-04-17

Initial public release.

### Added

- `bin/ask-codex.sh` wrapper with four modes (`search`, `analyze`, `second-opinion`, `consult`) that delegate read-only work to Codex CLI.
- Pre-flight trigger table in `templates/claude-md.md` that makes delegation mandatory for exploration, analysis, design, and review prompts, including both question-phrased and imperative-phrased forms.
- Dual-plan consultation workflow (`--mode=consult`) for genuinely independent design proposals: Claude drafts its own plan, Codex drafts another, Claude presents both with a comparison and recommendation.
- Compound-prompt handling — prompts matching multiple trigger rows dispatch multiple Codex modes in parallel.
- `install.sh` with managed start/end markers in CLAUDE.md for version-aware upgrades (safe replacement of old block in place, preserving everything else).
- `--check-model` audit flag prints the effective Codex model and reasoning level without calling Codex.
- Parallel-dispatch-safe report filenames: `<ts>-<slug>-<mode>-<rand6hex>.md`.
- `--timeout` support with a loud failure if `gtimeout` / `timeout` isn't available (instead of silent noop).
- TTY-aware colors in the installer so ANSI escape codes don't leak into piped or CI output.
- `--dry-run`, `--force`, and `--live-test` flags on `install.sh` for safer operations.
- SECURITY.md with an explicit data-boundary section.
- MIT LICENSE.
- `tests/` harness with a fake `codex` binary for offline CI.
- GitHub Actions workflow running shellcheck + bats on macOS and Ubuntu.
- Issue templates (bug, feature, new-mode-proposal) and a PR template.

### Known limitations

- Reasoning effort is pinned to `xhigh` by the wrapper regardless of `model_reasoning_effort` in `~/.codex/config.toml`. Override per-call with `--reasoning`.
- Reports and raw logs are persisted by default (un-gitignored). Add `.codex-reports/` to your project `.gitignore` if you prefer ephemeral trails.
- Rule block placement is at end-of-file of `~/.claude/CLAUDE.md`. If you edit the block manually between upgrades, changes inside the managed markers will be overwritten.
