Claude skill based on Matt Pocock's article on Ralph loops + some simple adversarial code review. [article](https://www.aihero.dev/getting-started-with-ralph)

# aico claude-skills

Shared Claude Code skills for the aico team, distributed as a plugin marketplace.

## Install (once per machine)

```
/plugin marketplace add zwilderrr/ralph-init
/plugin install aico@aico-skills
```

## Skills

- `ralph-init` — scaffold a project for Ralph, the AFK AI-coding loop (PRD-driven,
  capped iterations, cross-model adversarial review). Invoke with `/ralph-init`
  (or `/aico:ralph-init` if the name is ambiguous).

## Adding a skill

Drop a skill directory (containing `SKILL.md`) under `plugins/aico/skills/`,
commit, push. Installed teammates pick it up on plugin update.
