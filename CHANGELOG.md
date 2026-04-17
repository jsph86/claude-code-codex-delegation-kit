# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_No unreleased changes yet. Proposals land here first; bumped into a versioned section at release time._

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
