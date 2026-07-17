# {{PROJECT_NAME}} — agent guidelines

<!-- Ralph follows what the codebase shows more than what this file says. Keep the repo clean; keep this file honest. -->

## Quality bar

{{QUALITY_BAR}}

## Feedback loops (run ALL before every commit — never commit on failure)

{{FEEDBACK_LOOPS}}
<!-- e.g.:
- `npm run typecheck`
- `npm test`
- `npm run lint`
-->

## Working rules

- One task per iteration, one logical change per commit.
- Update PRD.md status and append to progress.txt every iteration.
- If blocked, write the blocker to progress.txt and stop — do not improvise around it.

## Adversarial review (before marking any non-trivial task done)

The agent that writes the code should not be the only one that decides it passes — that is self-grading, and it shares the blind spot that produced any bug. Independence is strongest **across models**: a same-model reviewer (another Claude subagent) shares the tendencies that wrote the bug, so the reviewer is a **different model — Codex (GPT)**. Every iteration that changes real code, after the feedback loops pass and before committing:

- Run `codex review --uncommitted "<instructions>"` — Codex reviews the working-tree diff. Do NOT feed it your reasoning; its entire value is independence.
- The instructions hand it only: the task's acceptance criteria, and this file's quality bar + guard-rails.
- Have it review **adversarially** — correctness bugs, silent-failure / dropped-data paths, claims the code can't back, guard-rail violations, AND under-constrained model-facing schemas (a field that permits a degenerate/empty value — flag as a risk even if not provable offline) — and return **severity-ranked findings**, **explicit non-findings** (what it checked and found sound), and a **go/no-go verdict**. Scope is this iteration's diff only, never the whole repo.
- If `codex` is not installed or not authenticated, the review cannot run — do NOT skip silently (that quietly removes the check): leave the task incomplete, journal "codex reviewer unavailable", and stop.
- **Non-leading context**: give it the acceptance as OUTCOMES ("the value must be X") not methods ("call Y"), plus the guard-rails; WITHHOLD your progress notes, rationale, and "I verified" claims — those aim it where you already looked and pre-answer its doubts. Ask it to build its own failure-mode list from the acceptance FIRST (phase 1), then audit the diff against that + open-ended (phase 2), treating every comment and test as a claim to verify.
- Have each finding **tagged** `[severity: blocker|major|minor] [confidence: high|med|low] [safety-touching: yes|no]`, plus explicit non-findings and a verdict.

**Route by TWO axes — severity is consequence (fix-now vs defer); the fix-risk tags (confidence × fence × mechanical) decide auto vs human. Auto-fix is FOR consequential clear defects, not trivia:**

| Finding                                                                                                                | Action                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **blocker/major + high confidence + safety-free + mechanical** (one obvious fix, no design change, a test can confirm) | **auto-fix**, then RE-RUN feedback loops + re-review, and continue — this is what auto-fix is for   |
| **blocker/major + safety-touching** (guard-rail / security / irreversible path)                                        | escalate to a human — NEVER auto-fix, any severity                                                  |
| **blocker/major + low confidence, OR needing judgment/tradeoff**                                                       | escalate to a human (auto-fixing an uncertain or judgment-laden critical damages correct code)      |
| **minor / nit**                                                                                                        | **backlog to the PRD** and move on — inconsequential, never blocks, NOT worth an auto-fix + re-gate |
| a finding you **dispute** (incl. blocker/major)                                                                        | you MAY disagree — see "Disputing a finding" below for WHEN to raise it                             |

- Re-review after any fix. The cap depends on the severity still in play: while a **blocker or major (critical/high)** finding is being fixed, allow **up to 4 rounds** — consequential defects are worth several fix→re-gate→re-review cycles before giving up. For **minor/nit-only** iterations the cap stays **2 rounds**. A finding at the governing severity surviving its cap → leave the task incomplete, journal the standoff, stop (never loop past the cap, never lower the bar).
- A review returning no findings AND no non-findings is a **rubber-stamp** — reject and re-run. A rubber-stamp is worse than no review: it launders.
- Skip only for docs-only or trivial-polish changes, and note the skip.

**Disputing a finding.** You may DISAGREE with a finding — including a blocker/major — when you judge it wrong (a false positive, a non-applicable edge case, an acceptable documented residual). Disagreement is not license to ignore: you must (a) write the reason in progress.txt, visibly, and (b) decide WHEN to surface it to the human, on this rule — **raise a disputed critical/high as LATE as you responsibly can:**

- **Raise immediately** if any remaining fix would build ON TOP of the disputed code — i.e., resolving the dispute could change what those later fixes look like. Never stack work on a contested foundation; get the human's call first.
- **Otherwise fix and re-review everything else first**, then raise the dispute at the end, so the human makes ONE decision on fully-baked, otherwise-green work instead of being interrupted mid-stream. Batch to the latest responsible moment.

Either way the task stays incomplete (not `passes: true`) until the human resolves a disputed blocker/major — you never self-clear your own dispute of a critical finding.

This roughly doubles per-iteration cost (and needs the `codex` CLI installed + logged in); it is worth it for correctness-critical work. If your quality bar is "speed over perfection," you may limit it to core/architecture tasks — say so here.

## Simplify pass (recurring pre-check — every ~8 commits)

Simplification value compounds ACROSS tasks (duplication between iterations'
code that no single-task diff can see), so it runs as a periodic batch pass,
never per-iteration. Before picking a PRD task, check:

```sh
git rev-list --count "$(cat .last-simplify)"..HEAD
```

(If `.last-simplify` is missing, initialize it to the current HEAD SHA, commit
it, and proceed to normal task selection.)

If ≥ 8, this iteration's work is a **simplify pass** instead of a PRD task:

1. Run the `/simplify` skill scoped to the delta since the marker.
   **Guard-rail / safety-critical code is OUT OF SCOPE** — a "redundant"
   check there is load-bearing; skip and journal any candidate touching it.
2. Run all feedback loops — existing tests only. **A simplify pass never adds
   tests**: the safety mechanism is the equivalence review below, where the
   remedy for doubt is dropping the hunk, not writing a test.
3. **Equivalence review — CODEX (GPT, cross-model), NEVER yourself and NEVER
   a Claude subagent** (same independence rule as the adversarial review — a
   Claude reviewing Claude's simplification shares the blind spot that
   produced it). With the changes uncommitted:

   ```sh
   codex review --uncommitted "$(cat <<'EOF'
   Review ONLY the uncommitted diff. It claims to be a pure simplification —
   zero behavior change. Your job: REFUTE that claim, per hunk.
   For EACH hunk output a verdict tag: [equivalent | not-equivalent | unsure]
   — for not-equivalent, include a concrete input where old and new code
   diverge. Hunt especially: dropped error/edge branches "simplified" away,
   short-circuit order changes, removed awaits, widened/narrowed
   conditionals, dedup that merged two ALMOST-identical code paths.
   Do NOT propose new tests — the remedy for any doubt is rejecting the hunk.
   No verdict-free output: every hunk gets a tag.
   EOF
   )"
   ```

   Routing (differs from the adversarial-review table above — dropping a hunk
   is free, so there are no fix→re-review rounds here):

   - **equivalent** → keep.
   - **not-equivalent** → drop the hunk (revert that change). Journal what
     simplify almost broke — that is a save, not a failure.
   - **unsure** → drop the hunk. Burden of proof is on the simplification;
     only reviewer-proven-equivalent changes land.
   - A review with no per-hunk verdicts is a rubber-stamp — reject and re-run.

   If `codex` is not installed or not authenticated, the pass CANNOT run — do
   NOT fall back to self-review or a Claude subagent: revert everything, leave
   the marker untouched, journal "simplify pass skipped — codex unavailable",
   and fall through to normal task selection. NEVER commit a simplification
   that was not cross-model reviewed.

4. Re-run the feedback loops on the surviving hunks.
5. Update `.last-simplify` to the new HEAD SHA (in the same commit), journal
   hunks kept/dropped and why, commit `chore(simplify): ...`. If every hunk
   dropped, commit only the marker bump — a no-op pass is a valid outcome.

No PRD entry for this — the threshold check IS the scheduler, and a
permanently-recurring PRD task would block `<promise>COMPLETE</promise>`.

## Guard-rails (hard rules — no exceptions)

- Stay inside this project directory. Never read, write, or run commands against paths outside it (no `..`, no `~`, no absolute paths outside the repo).
- Never delete anything. Move unwanted files to `./.ralph-trash/` instead; git history is the recovery mechanism.
- Forbidden commands: `rm`, `rmdir`, `sudo`, `git clean`, `git reset --hard`, force-push.
