# Agent skills for Powerbar users

`skills/powerbar/` teaches your coding agent (Claude Code, Codex, …) to
operate Powerbar for you: settings, widgets, groups, shortcuts and Omarchy's
bar commands, through `omarchy-shell powerbar`. It is about using Powerbar,
not developing it (that is `AGENTS.md` at the top of the repo).

To use it, link it where your agent looks for skills, for example:

```sh
ln -s ~/.config/omarchy/plugins/p0werj0int.powerbar/agents/skills/powerbar ~/.agents/skills/powerbar
ln -s ~/.config/omarchy/plugins/p0werj0int.powerbar/agents/skills/powerbar ~/.claude/skills/powerbar
```

The link follows plugin updates.
