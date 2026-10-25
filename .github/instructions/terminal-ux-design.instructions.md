---
applyTo: "**"
---

# Terminal UX design

Use the `terminal-ux-design` skill when a change touches any user-facing command, terminal output, prompt, help surface, progress indicator, warning, error message, or scaffold guidance for those surfaces. If a change touches both terminal-facing and non-terminal surfaces, apply the skill only to the terminal-facing portions of that change; leave non-terminal surfaces out of scope.

This applies to:

- PowerShell cmdlets
- CLI routes
- internal functions or modules whose return values or side-effects are directly rendered as terminal output by a public command or route
- contributor docs, command help, and scaffold content that teach those workflows

Keep PowerShell cmdlet UX and CLI UX distinct, but apply both Atlassian's 10 CLI design principles and Nielsen's 10 usability heuristics equally to PowerShell cmdlet UX and `% nova` CLI UX; when the two frameworks conflict, prefer the Atlassian CLI principle as the more domain-specific guidance.

The skill is authoritative for:

- Atlassian's 10 design principles for delightful CLIs
- Jakob Nielsen's 10 usability heuristics for user interface design

When invoked, review the change against each of Atlassian's 10 CLI design principles and each of Nielsen's 10 usability heuristics. For every principle or heuristic that is violated or at risk, cite it by name, explain the specific violation in the change, and propose a concrete corrective rewrite.

For Gerber interactive slash menus, preserve the shared menu contract instead of inventing parallel prompt models:

- all new or changed slash-menu flows must build on the shared menu helpers instead of custom prompt wiring or bespoke key handling
- nested slash menus must reuse the shared submenu prompt helper flow and keep the same root-menu interaction model unless a deliberate repo-wide design change is being made
- submenu prompts must open inline with a preloaded `/<command> ` buffer and the existing hint-and-suggestion behavior
- transitions from one slash-menu scope to another must redraw the normal Gerber home screen before showing the next prompt; do not leave the parent prompt rendered above the child submenu
- `Tab`, `Up`, `Down`, `Enter`, and `Esc` must keep the same meanings across root prompts, submenu prompts, and future menu features
- partial submenu input must prefer prefix matches before broader contains-style matches so narrowing behaves predictably as menus grow
- repeated interactive actions that stay inside the same tool or submenu should return to the selected action after `Press Enter to continue` instead of forcing the user back through a chooser
- recoverable menu failures must stay inside the Gerber loop with Gerber-owned messaging, while `Ctrl+C`, pipeline-stop behavior, and explicit `Esc` return-to-menu flows must remain clean and leak no raw PowerShell exception text
- when a flow asks the user to act on an existing item, show the available items before prompting for the item name instead of forcing recall from memory
- only preload placeholder templates when they actively help the task; creation flows such as `set` may benefit, but selection flows such as `get` or `remove` should usually start with an empty prompt when the relevant items are already visible
- bare `Enter` at a chooser must follow the visible default action instead of closing the submenu or bouncing to a broader menu
- `Press Enter to continue` must return the user to the menu level that best supports the next likely step:
  - result-only views should usually return to the chooser
  - repetitive input-driven flows may reopen the selected action
- `Esc` must behave as local back-navigation, moving up one Gerber menu level at a time instead of unexpectedly jumping to the root unless the user is already there
- confirmation prompts must confirm one thing at a time; do not bundle unrelated side effects into the same yes/no question when the side effect can happen earlier or be expressed separately
- privacy-sensitive flows must perform the safest useful step first; for example, copy-to-clipboard can happen before terminal reveal when showing the value is the higher-risk act
- new slash-menu behavior is not done until mirrored tests cover the interaction contract that users feel: default `Enter`, `Esc` / back behavior, continue routing, list-first selection when relevant, and recoverable-error handling when relevant
- new slash-menu behavior is not done until a tracer validation has been run: set `$env:GERBER_PROMPT_TRACE = "1"`, exercise the full flow (happy path, cancel/Esc path, and any recoverable-error path), read `.gerber/prompt-debug.log`, and confirm the key `Write-GerberPromptTrace` events fire in the expected order; use the trace log as the primary acceptance signal for interactive behavior that Pester alone cannot prove
