# PRD — {{PROJECT_NAME}}

<!--
HOW TO FILL THIS FILE
- List tasks small: one logical change each. Small tasks = tighter feedback, better output, one commit per task.
- Order by risk: architecture & core abstractions first, then integration points, then unknowns/spikes, then standard features, then polish.
- Every task needs verifiable acceptance criteria — vague criteria cause infinite loops.
- You can edit this file WHILE the loop runs: add clarifications, flip statuses.
- Tip: use `claude` plan mode (shift-tab) to draft tasks, then save here.
-->

## Scope

{{ONE_PARAGRAPH_SCOPE — what this project/feature is and is NOT}}

## Quality bar

{{QUALITY_BAR}}

## Tasks

<!-- Copy this block per task. Keep `passes: false` until acceptance criteria verifiably pass. -->

### 1. {{TASK_TITLE}}

- category: {{functional|architecture|integration|polish}}
- passes: false
- description: {{WHAT_TO_BUILD}}
- acceptance:
  - {{VERIFIABLE_CRITERION_1}}
  - {{VERIFIABLE_CRITERION_2}}

## Completion

When ALL tasks have `passes: true`, output `<promise>COMPLETE</promise>`.
