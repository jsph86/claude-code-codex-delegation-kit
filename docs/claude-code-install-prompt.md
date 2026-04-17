# Installing the kit by asking Claude Code to do it

If you prefer to have Claude Code handle the install for you (instead of running `install.sh` directly), paste the prompt below into a fresh Claude Code session from inside the cloned repo.

The prompt is conservative: it verifies prerequisites first, backs up anything it touches, and reports back with a manifest of exactly what it did.

---

```
Install the claude-code-codex-delegation-kit from this repository. Do NOT touch
any of my repo files or my Codex auth / config. Steps:

1. Verify Codex CLI is installed and current:
   - `which codex` returns a path
   - `codex --version` prints a version
   - `codex exec --help` lists BOTH `--output-last-message` and `--sandbox`
   If any of these fail, STOP and tell me how to install / upgrade Codex.
   Do not attempt to install Codex yourself.

2. Install the wrapper:
   - Create `~/.claude/scripts/` if missing
   - Copy `bin/ask-codex.sh` from this repo to `~/.claude/scripts/ask-codex.sh`
   - `chmod +x ~/.claude/scripts/ask-codex.sh`
   - If a previous wrapper exists, back it up with a timestamped suffix first

3. Install / upgrade the rule block:
   - Ensure `~/.claude/CLAUDE.md` exists (create if missing)
   - Detect whether an existing block marked with
     `<!-- CLAUDE-CODEX-KIT:BEGIN vX.Y.Z -->` ... `<!-- CLAUDE-CODEX-KIT:END -->`
     is already present.
     - If not present: append the full contents of `templates/claude-md.md`
       (preserve a blank line before the appended block).
     - If present at the same version as this repo's `VERSION` file: skip.
     - If present at a DIFFERENT version: back up the file with a timestamped
       suffix, then replace everything between the BEGIN and END markers with
       the new block from `templates/claude-md.md`. Do NOT touch any content
       outside the markers.

4. Offline configuration check:
   - Run `bash ~/.claude/scripts/ask-codex.sh --check-model`
   - Confirm it prints the effective model and reasoning

5. Report back:
   - Files you created / overwrote / backed up / skipped
   - The resolved Codex model the wrapper will use
   - The version marker now in `~/.claude/CLAUDE.md`
   - Next step for me: open a NEW Claude Code session in any repo and ask
     "how can I design a better <feature>?" to verify the rule fires

If any step fails, stop and report the failure. Do not proceed past a failure.
Do not modify any files outside `~/.claude/`. Do not invoke Codex except for
the `--check-model` offline step.
```

---

## What this guarantees

- Claude will **check prerequisites first** (no blind installs on missing dependencies).
- Claude will **back up** anything it overwrites (your CLAUDE.md, any prior wrapper).
- Claude is **explicitly blocked** from modifying your repo or touching Codex auth.
- The install is **idempotent** — re-running skips already-installed pieces at the same version, upgrades old versions in place.
- Claude **reports back** with a manifest so you can audit what happened.
