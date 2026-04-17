<!-- CLAUDE-CODEX-KIT:BEGIN v1.0.0 -->
## Delegating to Codex -- PROACTIVE but BOUNDED

Codex (`~/.claude/scripts/ask-codex.sh`) is a second read-only engine. Use it to save Claude's context on heavy search/exploration and to obtain independent perspectives for critical review or design — **not to avoid thinking.**

### Pre-flight trigger check -- run FIRST on every user prompt

BEFORE invoking any tool or skill, scan the user's prompt against this table. If a row matches, the listed Codex mode(s) are MANDATORY -- dispatch them in parallel with whatever else you run.

| Trigger class | Matches phrases like… | Mandatory Codex mode |
|---|---|---|
| **Exploration / discovery** | explore, investigate, map out, catalog, inventory, dig into, learn about, understand how X works, where/how is X used, find all, list all, trace, scan, audit | `--mode=search` |
| **Analysis** | explain how X works end-to-end, walk me through X, break down X, analyze X | `--mode=analyze` |
| **Design / planning (question form)** | how can / should / would I/we/you design / improve / plan / architect / structure / approach / tackle, what's the best way to X, how would you approach X, make X better / cleaner / more robust | `--mode=consult` |
| **Design / planning (imperative form)** | let's design / plan / architect / reorganize / restructure / refactor / separate / split / merge / consolidate X, rework X, find proper / better / right name for X, adjust the schema / columns, organize X into Y | `--mode=consult` |
| **Review / second opinion** | review my plan, critique this approach, is this the right call, what would you change about X | `--mode=second-opinion` |
| **Fallback (no explicit trigger)** | any task that would realistically need 3+ Grep/Glob iterations or reading 10+ files | `--mode=search` |

**Compound prompts:** if the prompt matches MULTIPLE rows (e.g. *"explore the X module AND reorganize the Y config"*), dispatch ALL matching modes. Do not pick one -- the user asked for both. Run them in parallel, or sequentially when the design call depends on the search result (usually `--mode=search` first for ground truth, then `--mode=consult` for design).

**This is ADDITIVE.** Specialized skills (knowledge retrieval, domain lookup, creative-work skills, etc.) do NOT exempt you from this check. Both run in parallel.

**Announce upfront -- one sentence, BEFORE your first tool call:**
> *"This matches [trigger classes] triggers -- dispatching Codex [--mode=X, --mode=Y]."*

No announcement = the rule was violated.

### Core principles (apply to every mode)

- Claude OWNS every recommendation. Codex advises; Claude decides.
- Form your own position BEFORE or IN PARALLEL with Codex -- never *after* reading Codex first.
- Attribute Codex's contributions clearly; never pass them off as Claude's.
- Challenge Codex when it's wrong. Start from your own position; move only if Codex's reasoning is demonstrably better.
- Audit the effective model anytime: `bash ~/.claude/scripts/ask-codex.sh --check-model`.

### Command reference

```
bash ~/.claude/scripts/ask-codex.sh --mode=<search|analyze|second-opinion|consult> <slug> "<detailed prompt>"
```

- `<slug>` = lowercase-alphanumeric-with-hyphens (used in the filename).
- Brief Codex like a new colleague -- it has NO conversation context; include repo paths, what to look for, and the desired output shape.
- Prints the absolute path of a markdown report on stdout -- `Read` that file and work from it.
- Reports persist in `<repo-root>/.codex-reports/`; read-only sandbox; top model pinned in `~/.codex/config.toml`.

### Dual-Plan workflow (when `--mode=consult` fires)

When consult is triggered (alone or alongside search / analyze), the full dual-plan pattern is required:

1. Dispatch Codex `--mode=consult` immediately with problem statement + constraints ONLY. NEVER share Claude's own plan.
2. In parallel, draft Claude's own plan using whatever tools/skills are appropriate. Commit it BEFORE reading Codex's output, to prevent anchoring.
3. Compare: where you agree, where you differ, what each of you missed.
4. Present BOTH plans to the user with:
   - Claude's plan (written by Claude, not copied)
   - Codex's plan (summarized from the report, attributed)
   - Claude's critical comparison
   - Claude's recommendation -- pick, merge, or escalate, with reasoning

### Guardrails -- against over-reliance

- NEVER skip drafting your own plan when `--mode=consult` fires. Codex is a consultant, not a substitute for reasoning.
- NEVER pass Codex's output off as your own.
- NEVER defer to Codex on disagreement. State your position with reasoning.
- NEVER share Claude's own plan with Codex in `--mode=consult` -- that biases Codex and kills independence.
- DO NOT delegate trivial work: single-file lookups, obvious fixes, small refactors, one-step decisions.
- DO NOT delegate tasks that need Claude's conversation context (in-flight plan state, prior user turns).
- DO NOT delegate anything that requires writes -- the wrapper is read-only.
<!-- CLAUDE-CODEX-KIT:END -->
