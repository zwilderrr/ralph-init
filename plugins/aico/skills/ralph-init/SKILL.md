---
name: ralph-init
description: Scaffold a project directory for Ralph — the AFK AI-coding loop (run same prompt repeatedly, agent picks next PRD task, commits, updates progress). Use when the user says "set up ralph", "ralph init", "scaffold ralph", or wants an autonomous coding loop for a project. AFK mode only — we never use ralph-once.
---

# ralph-init

Scaffolds a target directory with everything Ralph needs to run in AFK (away-from-keyboard) mode: a PRD with completion tracking, a progress file, the loop script, and quality guardrails. Based on aihero.dev's "Getting started with Ralph" and "Tips for AI coding with Ralph Wiggum".

## What Ralph is (context for you, the scaffolding agent)

Ralph runs the SAME prompt in a loop. Each iteration the agent:

1. Reads `PRD.md` + `progress.txt`
2. Simplify pre-check: every ~8 commits (tracked via a `.last-simplify` SHA marker, self-initializing) the iteration is a batch simplify pass instead of a PRD task — `/simplify` on the delta, then a per-hunk equivalence review by Codex (cross-model, never self); any not-equivalent or UNSURE hunk is dropped, never patched with new tests (burden of proof on the simplification — doubt costs a revert, not a regression test)
3. Otherwise picks the highest-priority incomplete task (ONE task only)
4. Implements it, runs ALL feedback loops (typecheck, tests, lint)
5. Adversarial review: a DIFFERENT model — Codex (GPT) via `codex review --uncommitted` — reviews the iteration's diff against the task's acceptance (cross-model independence is the point — a same-model reviewer shares the blind spot that wrote the bug); findings must be fixed or journaled before the task is marked done
6. Updates PRD status + appends to `progress.txt` (incl. the review verdict)
7. Commits
8. Outputs `<promise>COMPLETE</promise>` when every PRD item passes — this exits the loop early.

We always use `afk-ralph.sh` (capped-iteration autonomous loop). Never scaffold a `ralph-once.sh`. Docker is OPTIONAL: `./afk-ralph.sh 20` runs locally; `./afk-ralph.sh --docker 20` runs each iteration inside `docker sandbox` (strongest isolation; needs Docker Desktop 4.50+; the script auto-syncs global `~/.claude/skills/` and `~/.claude/CLAUDE.md` into project-level `.claude/skills/` and `CLAUDE.local.md` (gitignored) so global context survives in the sandbox — the container still has network access, so web search/fetch work, but local-browser tools like Claude-in-Chrome don't). In both modes safety also comes from: (a) hard rules in the loop prompt (no deletes, never leave the project dir, no rm/sudo/force-push — trash goes to `./.ralph-trash/`), and (b) permission deny rules in the project's `.claude/settings.json` blocking destructive commands and file access outside the project.

## Steps

1. **Determine target directory.** Use the argument if given; otherwise the current working directory. Confirm with user only if ambiguous.

2. **Gitignore synced context.** Ensure the target's `.gitignore` contains `CLAUDE.local.md`, `.claude/skills/` (synced-in global copies shouldn't be committed — if the project has its OWN skills it wants committed, only ignore the synced ones by name), and `.ralph-trash/`.

3. **Copy templates.** Copy every file from this skill's `templates/` directory into the target, then `chmod +x afk-ralph.sh`. `settings.json` goes to `.claude/settings.json` in the target — if one already exists, MERGE the deny rules into it instead of overwriting. Do NOT overwrite an existing `PRD.md` or `progress.txt` — if present, leave them and tell the user.

4. **Fill placeholders.** Each template contains `{{PLACEHOLDER}}` markers. Fill what you can from context:
   - `{{PROJECT_NAME}}` — directory name or repo name
   - `{{QUALITY_BAR}}` — ask user or infer: prototype ("speed over perfection"), production ("must be maintainable"), or library ("backward compatibility matters")
   - `{{FEEDBACK_LOOPS}}` — detect from the repo: `tsc`, test runner, linter commands. If the repo has none, warn the user: Ralph without feedback loops takes shortcuts. Leave the placeholder with a TODO if undetectable.
   - Leave `{{...}}` markers the user must fill (PRD tasks) intact, with the instructions already in the template.

5. **CLAUDE.md pointer — sessions follow the loop's discipline.** Ensure the target's `CLAUDE.md` (create it if absent) tells interactive sessions that dev tasks follow the ralph discipline, not just the AFK loop. Without this, a regular `claude` session in the repo edits/commits per its own defaults and silently bypasses the PRD, port/review gates, and journal. Add (adapted to the project's actual file names):

   ```markdown
   - **Dev tasks follow the ralph discipline** (see AGENTS.md), in-session or
     in the loop: the task must exist in the PRD first (PRD-first — never
     implement then record), codex (cross-model) adversarial review before
     marking it done, entry appended to progress.txt, commits reference the
     task id.
   ```

6. **Seed the PRD (optional).** If the user described what to build, draft PRD tasks following the template's structure. Otherwise leave the instructional placeholders — the user writes tasks via plan mode later.

7. **Check prerequisites.** Verify and report (don't install without asking):
   - `git` repo initialized in target (Ralph commits every iteration — required; also the recovery mechanism since deletes are banned)
   - `claude` CLI on PATH
   - `codex` CLI on PATH **and logged in** (`codex login`) — the cross-model adversarial reviewer (step 4). If absent, warn the user: the loop leaves a task incomplete rather than skip the review, so an unauthed codex stalls it. They can disable review for a speed-prototype (edit AGENTS.md) or install/login codex.
   - `.claude/settings.json` deny rules in place (the guard-rails — required for local mode)
   - Docker Desktop 4.50+ with `docker sandbox` (optional — only if user wants `--docker` mode; report availability, don't require)

8. **Report.** Summarize what was created, what placeholders remain, and how to run:
   ```bash
   ./afk-ralph.sh 20           # local, guard-railed
   ./afk-ralph.sh --docker 20  # sandboxed (strongest isolation)
   ```

## Guidance to relay to the user (put in the report, briefly)

- **Small tasks win.** Break PRD items small — context rot degrades big iterations. Prefer many small loops.
- **Risky first.** Order PRD: architecture/core abstractions → integration points → unknowns → standard features → polish.
- **Guardrails are non-negotiable.** Commits must be blocked until typecheck/tests/lint pass. Ralph trusts the codebase's example more than instructions — a clean repo produces clean output.
- **Adversarial review is on by default** (AGENTS.md), and it uses a **different model — Codex (GPT) via `codex review --uncommitted`**, not a Claude subagent: a same-model reviewer shares the tendencies that wrote the bug (a real example: an under-constrained schema slipped past a same-model review because the reviewer shared the blind spot that wrote it). Feedback loops prove "typechecks + passes tests," never "does what the task intended / doesn't silently fail." It roughly doubles per-iteration cost and needs the `codex` CLI; for a pure speed-over-perfection prototype the user can scope it to core/architecture tasks (edit AGENTS.md), but default to keeping it — the failures it catches (silent drops, unbacked claims, degenerate-schema outputs) are exactly the ones the gates and same-model review miss.
- **Simplify pass is drop-biased by design.** Every ~8 commits an iteration runs `/simplify` over the accumulated delta instead of a PRD task (AGENTS.md "Simplify pass"). Codex — never a Claude reviewer — must tag each hunk equivalent, or it's reverted; UNSURE also reverts. No new tests are ever written to rescue a simplification, so the pass can't lose functionality or grow the test suite — worst case it's a no-op marker bump. Guard-rail code is out of scope entirely.
- **Cap iterations** to control cost (5–50 depending on scope).
- **progress.txt is session-scoped** — clean it up between sessions.
- PRD is adjustable mid-flight: edit tasks/`passes` status while the loop runs.
