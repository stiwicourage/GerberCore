# Gerber – Claude Code

Gerber is a PowerShell module (an interactive DevOps multitool). Claude is not the primary AI tool in this repository. The rules are written for GitHub Copilot and live in `.github/`. This file is only a bridge so Claude Code follows the same rules without duplicating their text.

@AGENTS.md

## How to read the Copilot guidance in Claude Code

AGENTS.md above is the index. Claude Code does not load the rest automatically, so read it yourself with the Read tool when the task requires it:

- **Instructions** (`.github/instructions/*.instructions.md`): `applyTo:` globs do not work here. Before changing files, read `repository-conventions` plus every file whose `applyTo:` matches the paths you touch (for example `powershell-coding-standards` for `src/`, `tests/`, `scripts/`; `testing-policy` for tests).
- **Skills** (`.github/skills/<name>/SKILL.md`): read the file directly. There is no `skill` tool to call.
- **Agents** (`.github/agents/*.agent.md`) and **prompts** (`.github/prompts/*.prompt.md`): treat them as workflow descriptions. Read the prompt that matches the task in the AGENTS.md task map and follow it. Agent roles are not activated automatically.
- Follow the reading order in AGENTS.md (README.md, CONTRIBUTING.md, pull request template) for changes to commands, helpers, tests, CI, or documentation.

## Tools that may not exist in Claude Code

AGENTS.md mentions the CodeScene tools (`code_health_review`, `code_health_score`, `pre_commit_code_health_safeguard`). Use them only if they are available as MCP tools in the session. Otherwise state that the CodeScene step was not run.

The ScriptAnalyzer requirement applies unchanged and needs only a shell:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-ScriptAnalyzerCI.ps1
pwsh -NoLogo -NoProfile -File ./run.ps1   # full quality loop, when in scope
```

The completion summary must report the ScriptAnalyzer result. Zero findings is the requirement.

## On conflict

If this file and `.github/` disagree, `.github/instructions/` wins. Fix the rules there, not here.
