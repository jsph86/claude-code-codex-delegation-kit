# Security & Privacy

This kit asks Claude Code to delegate read-only work to Codex CLI on your behalf. Before installing, understand the trust boundary.

## Data boundary

**Codex sends repo contents to OpenAI.** Every invocation of `ask-codex.sh` runs `codex exec` inside your repository, which sends the files Codex reads (plus the prompt you provide) to OpenAI's API. This kit does not change that behavior — it wraps the existing Codex CLI. OpenAI's data handling and retention policies apply.

**Do not use this kit on repositories containing:**

- Secrets, credentials, tokens, or keys (in code, config, env files, fixtures, or tests)
- Proprietary / confidential source code you are not permitted to share with OpenAI
- Customer data, PII, PHI, or any regulated information
- Anything under an NDA that restricts cloud LLM processing

When in doubt, use a scrubbed fork or synthetic test repo for delegated work.

## What the wrapper does NOT do

- Does not write, delete, or modify any file in your repo (`codex exec --sandbox read-only` is passed on every call)
- Does not upload credentials, config, or home-directory contents to anywhere
- Does not add telemetry, analytics, or phone-home behavior
- Does not touch your Codex auth (`~/.codex/auth.json`) or config (`~/.codex/config.toml`)

## What the wrapper DOES persist locally

- A markdown report per delegated call at `<repo-root>/.codex-reports/<file-id>.md`. **The report includes the prompt you sent Codex and Codex's response.** Treat reports as potentially sensitive — they may contain file/line references, snippets from Codex's reasoning, and the literal prompt text.
- A raw transcript at `<repo-root>/.codex-reports/.<file-id>.log` containing Codex's stdout/stderr for the call.

Both files are written to the repo root by default, **not** your home directory. They are **not** auto-gitignored — the kit assumes reports are valuable audit history. If you prefer to exclude them, add this to your repo's `.gitignore`:

```
.codex-reports/
```

## Reporting a vulnerability

If you find a security issue in this kit (not in Codex or Claude Code themselves), please open a private security advisory via GitHub:

> `Security` tab → `Report a vulnerability`

Do not open a public issue for exploitable bugs. For non-exploitable concerns (hardening suggestions, documentation gaps), a regular issue is fine.

## What the kit cannot guarantee

- The behavior of Codex CLI itself. The kit depends on stable `codex exec` flags (`--sandbox`, `--output-last-message`, `--cd`, `--skip-git-repo-check`). If OpenAI changes these, the wrapper may break until updated.
- That Claude Code will always follow the rule block. The rule is a strong instruction, not a hard enforcement mechanism. Users should still observe Claude's behavior and confirm the announcement fires on design/exploration prompts.
- The content of Codex responses. Reports may occasionally contain hallucinated file paths or line numbers. Claude is expected to validate Codex's findings against the actual repo before acting on them.

## Supply-chain

This kit has no runtime dependencies beyond `bash`, `awk`, `sed`, `grep`, `git`, and `codex`. It installs two plaintext files (`ask-codex.sh` and a documented block in `~/.claude/CLAUDE.md`). Inspect both before running `install.sh`.
