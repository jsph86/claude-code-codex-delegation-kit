## Summary

<!-- What does this PR change and why? One short paragraph. -->

## Type of change

- [ ] Bug fix (wrapper, installer, or rule block)
- [ ] New mode or trigger phrases
- [ ] Docs / README / CONTRIBUTING / SECURITY
- [ ] CI / tests
- [ ] Refactor (no behavioral change)

## Checklist

- [ ] `shellcheck install.sh bin/ask-codex.sh tests/fixtures/bin/codex` is clean
- [ ] `bats tests/` passes locally
- [ ] If I changed the rule block in `templates/claude-md.md`, I bumped the version in the BEGIN marker AND in `VERSION`
- [ ] I updated `CHANGELOG.md` under `## [Unreleased]` (or under the version I'm releasing)
- [ ] No new npm / pip / go runtime dependencies
- [ ] No telemetry / phone-home / external service calls added
- [ ] If I added a flag or mode, I updated the `--help` output and the README usage section

## Testing notes

<!-- How did you verify this works? If you ran it against a real repo, describe the prompt you tested. -->

## Screenshots (optional)

<!-- Console output showing the new behavior, redacted. -->
