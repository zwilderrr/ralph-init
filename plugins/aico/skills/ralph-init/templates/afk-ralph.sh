#!/bin/bash
set -e

usage() { echo "Usage: $0 [--docker] <iterations>"; exit 1; }

USE_DOCKER=false
if [ "$1" = "--docker" ]; then USE_DOCKER=true; shift; fi
[ -z "$1" ] && usage

if $USE_DOCKER; then
  RUN=(docker sandbox run claude)
  # Global ~/.claude doesn't load inside the sandbox, but project-level context does.
  # Sync global skills + memory into the project (gitignored) so Ralph keeps them.
  # Overwrites on each run so copies stay fresh. Caveat: a project skill sharing a
  # name with a global skill gets clobbered — keep project-owned skill names distinct.
  if [ -d "$HOME/.claude/skills" ]; then
    mkdir -p .claude/skills
    rsync -a "$HOME/.claude/skills/" .claude/skills/
  fi
  if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    cp "$HOME/.claude/CLAUDE.md" CLAUDE.local.md
  fi
else
  RUN=(claude)
fi

for ((i=1; i<=$1; i++)); do
  echo "=== Ralph iteration $i of $1 $($USE_DOCKER && echo '[docker]' || echo '[local]') ==="

  result=$("${RUN[@]}" --permission-mode acceptEdits -p \
  "@PRD.md @progress.txt @AGENTS.md \
  0. SIMPLIFY PRE-CHECK: if .last-simplify is missing, initialize it to the current HEAD SHA, commit it, and continue to step 1. Otherwise, if \`git rev-list --count \$(cat .last-simplify)..HEAD\` >= 8, this iteration is a SIMPLIFY PASS instead of a PRD task — follow the 'Simplify pass' section of AGENTS.md exactly: /simplify on the delta since the marker (guard-rail code out of scope), feedback loops, per-hunk equivalence review by CODEX (cross-model — never yourself, never a Claude subagent; codex unavailable = revert everything, journal, fall through to step 1), drop every not-equivalent or unsure hunk (never add tests to save one), re-run loops, bump the marker, commit chore(simplify), journal, and STOP — that is this iteration's single task. \
  1. Find the highest-priority incomplete task in the PRD and implement it. \
  2. Run ALL feedback loops (typecheck, tests, lint). Do NOT commit if any fails. \
  3. ADVERSARIAL REVIEW — a DIFFERENT MODEL, not you (skip only for docs/trivial changes): run \`codex review --uncommitted \"<instructions>\"\` so Codex (GPT) reviews THIS iteration's uncommitted diff. Cross-model is the point — a same-model subagent shares the blind spot that made the bug. Feed it the TARGET not your aim: the task's acceptance (as OUTCOMES) + AGENTS.md quality bar/guard-rails; WITHHOLD your progress.txt notes and reasoning (they lead it). Tell it: PHASE 1, from acceptance+guard-rails alone list how this kind of change fails; PHASE 2, audit the diff against its own list + open-ended, treating comments/tests as claims to verify — hunt correctness bugs, silent-failure/dropped-data paths, unbackable claims, AND under-constrained LLM-facing schemas (fields permitting a degenerate/empty value — flag even if not offline-provable). For EACH finding output tags [severity: blocker|major|minor] [confidence: high|med|low] [fence/safety-touching: yes|no] + a breaking scenario; then explicit non-findings; then a verdict. If codex is absent/unauthed do NOT skip silently — leave the task incomplete, journal 'codex reviewer unavailable', stop. ROUTE by TWO axes — severity = consequence (fix-now vs defer); the fix-risk tags (confidence x fence x mechanical) = auto vs human. Auto-fix is FOR consequential clear defects, NOT trivia: blocker/major + high-confidence + safety-free + mechanical (one obvious fix, test-verifiable) -> AUTO-FIX then RE-RUN feedback loops + re-review, and continue; blocker/major that is safety-touching OR low-confidence OR needs judgment -> stop for a human (never auto-fix); nit -> backlog to the PRD and move on (inconsequential — do NOT spend an auto-fix + re-gate cycle on it; fix only if already on that line); a finding you DISPUTE (incl. blocker/major — you MAY disagree when it is wrong) -> write the reason in progress.txt (never silent) AND raise a disputed critical/high as LATE as responsible: raise it RIGHT AWAY if any remaining fix would build on top of the disputed code (never stack work on a contested foundation), otherwise fix+re-review everything else first and raise it at the end so the human makes ONE decision on fully-baked work; the task stays incomplete until the human resolves a disputed blocker/major (never self-clear it). Re-review after fixes: while a blocker/major (critical/high) is being fixed allow UP TO 4 rounds; for minor/nit-only iterations the cap is 2; a finding surviving its cap -> leave incomplete, journal the standoff, stop (never loop past the cap, never lower the bar). No findings AND no non-findings = rubber-stamp; reject and re-run. Do NOT mark done or commit while a blocker/major is unresolved. \
  4. Update the PRD: mark the task's passes/status as done (only when feedback loops pass AND the review is clean or dispositioned). \
  5. Append a summary to progress.txt (task ref, decisions, the review verdict + any finding dispositions, files touched, blockers). \
  6. Commit your changes with a descriptive message. \
  ONLY WORK ON A SINGLE TASK. \
  HARD RULES: Never read, write, or run commands outside this project directory. \
  Never delete files or directories — if something must go, move it into ./.ralph-trash/ instead. \
  Never use rm, sudo, git clean, git reset --hard, or force-push. \
  If every PRD task is complete and passing, output <promise>COMPLETE</promise>.")

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "PRD complete after $i iterations."
    exit 0
  fi
done

echo "Iteration cap ($1) reached. PRD not yet complete — review progress.txt and re-run."
