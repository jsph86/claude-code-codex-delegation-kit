# Contributing

Thanks for your interest. This project stays small and focused — a bash wrapper plus a Claude rule block. Contributions that keep it that way are welcome.

## Ground rules

- **No runtime dependencies beyond bash, awk, sed, grep, git, and codex.** No npm, no pip, no go. The value is the tiny footprint.
- **Bash 3.2-compatible** (macOS default). Avoid `mapfile`, associative arrays, `${var@U}`, etc.
- **shellcheck-clean.** Run `shellcheck bin/ask-codex.sh install.sh` locally; CI will enforce.
- **No new scope.** This kit delegates read-only work. It doesn't orchestrate, doesn't write, doesn't integrate with CI/CD, doesn't send telemetry. Enhancements that grow the surface area are likely to be declined.

## How to make changes

### Tweaking the rule (trigger phrases, workflow, guardrails)

Edit `templates/claude-md.md`. Bump the version in both the `<!-- CLAUDE-CODEX-KIT:BEGIN vX.Y.Z -->` marker and the `VERSION` file at the repo root. Describe the change in `CHANGELOG.md`. The installer's upgrade path will replace old blocks in place on re-install.

### Adding a new mode

Four pieces need to change:

1. `bin/ask-codex.sh` — add a `case` branch in the mode switch that sets `PREAMBLE` for the new mode. Add the mode to the validation error message and to the flag-docs header.
2. `templates/claude-md.md` — add a row to the pre-flight trigger table mapping phrases to the new mode.
3. `tests/test_ask-codex.bats` — add a test that dispatches the new mode and checks the report header + preamble handling.
4. `CHANGELOG.md` — note the new mode under the next unreleased section.

Modes should be mutually exclusive semantics: search = find, analyze = understand, second-opinion = critique existing, consult = propose independently. If your idea doesn't fit one of those four axes, open an issue first to discuss.

### Adding trigger phrases

Edit `templates/claude-md.md`. Bias toward phrases that appear in real Claude Code interactions — open a GitHub issue with the prompt that should have triggered but didn't, and we'll evolve the table.

### Fixing a bug

Write a failing test first (`tests/*.bats`), then fix. Tests run against a fake `codex` binary in `tests/fixtures/bin/` so they don't need OpenAI credentials.

## Running tests locally

```bash
# Install bats if you don't have it
brew install bats-core   # macOS
# or: apt-get install bats   # Debian/Ubuntu

# Run everything
bats tests/

# Run one file
bats tests/test_ask-codex.bats

# Lint
shellcheck install.sh bin/ask-codex.sh
```

CI runs the same matrix on macOS and Ubuntu.

## Commit & PR conventions

- Conventional-commit-ish style is appreciated but not enforced: `feat: add --scope-dir flag`, `fix: escape slug in filename`, `docs: tighten README quickstart`.
- One logical change per PR. Keep diffs small and reviewable.
- Update `CHANGELOG.md` under `## [Unreleased]` in the same PR.
- Bump `VERSION` and the snippet marker only in release PRs, not per-feature PRs.

## Releases

Maintainers: tag from `main`:
```
git tag -a vX.Y.Z -m "Release vX.Y.Z"
git push origin vX.Y.Z
```
GitHub Actions publishes the release notes from `CHANGELOG.md`.

## Code of conduct

Be respectful. Critique ideas, not people. If there's a dispute, the project owner arbitrates.
