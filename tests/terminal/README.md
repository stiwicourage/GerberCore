# Gerber terminal regression tests

This directory contains the permanent PTY-based regression suite for Gerber's interactive terminal UI.

## Dependencies

The suite uses pinned Python dependencies from `tests/terminal/requirements.txt`:

- `pexpect==4.9.0` for pseudo-terminal process control
- `pyte==0.8.2` for ANSI screen reconstruction

The PowerShell wrapper under `scripts/build/Invoke-TerminalRegressionCI.ps1` creates and maintains a local virtual environment under `artifacts/terminal/.venv` and runs focused Python self-tests before the PTY scenarios.

Dependency installation is bounded by `-DependencyInstallTimeoutSeconds` and the complete PTY run is
bounded by `-SuiteTimeoutSeconds`.

## Run the full suite

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-TerminalRegressionCI.ps1
```

`pwsh -NoLogo -NoProfile -File ./run.ps1` is the normal tracked full-quality entry point and
includes this PTY gate automatically. Use `Invoke-TerminalRegressionCI.ps1` directly when you need
focused terminal-only validation.

## Run one scenario

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-TerminalRegressionCI.ps1 -ScenarioId exit-editing-regression
```

## Run one category

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-TerminalRegressionCI.ps1 -Category plugin
```

## Artifacts

Failure artifacts are written under `artifacts/terminal/runs/<run-id>/failures/<scenario-id>/` and include:

- `failure.json`
- `traceback.txt`
- `screen.txt`
- `raw-output.txt`
- `module-state.json`
- `diagnostic-events.json`
- `prompt-trace.log`

The runner writes the current run summary to `artifacts/terminal/runs/<run-id>/summary.json` and
copies the latest summary to `artifacts/terminal/latest-summary.json`.

Every full run also writes:

- `command-inventory.json` — Gerber Core command paths generated from the built Core registry
- `command-coverage.json` and `.md` — Core category coverage and explicit exclusions
- `plugin-command-inventory.json` — generic fixture plugin commands only
- `plugin-command-coverage.json` and `.md` — generic Plugin API contract coverage

The coverage gate distinguishes discovery, dispatch, workflow, navigation, rendering, and
error/recovery coverage. A scenario only counts when it exists, declares the command and category,
executes in the current full run, and passes. Missing commands, stale exclusions, duplicate scenario
identifiers, and referenced scenarios that did not pass fail the full gate.

## Adding a scenario

1. Register the command through the normal Core registry. Product plugin scenarios belong in the
   plugin's own repository; only generic Plugin API contracts belong in `Gerber.TerminalFixture`.
2. Add a function under `tests/terminal/scenarios/`.
3. Decorate it with `@scenario(...)`, including `commands`, `workflows`, and the coverage categories
   the scenario actually executes.
4. Use the high-level `GerberTerminalApp` API so the scenario describes user behavior rather than
   PTY mechanics.
5. Prefer semantic assertions such as `expect_input`, `expect_selected_suggestion`,
   `expect_preview`, and `wait_for_text`.
6. Run the focused scenario, then run the complete suite so registry and coverage validation execute.

Example:

```python
from framework.scenario_registry import ScenarioMetadata, scenario


@scenario(
    "sample-selection",
    title="Sample selection",
    categories=("core", "selection"),
    metadata=ScenarioMetadata(
        commands=("sample choose",),
        workflows=("command:sample choose", "selection:sample"),
        coverage=("dispatch", "workflow", "navigation", "rendering"),
    ),
)
def sample_selection(context) -> None:
    context.app.start()
    context.app.type("/sample choose")
    context.app.press("ENTER")
    context.app.expect_selected_suggestion("1. First")
```

Use `tests/terminal/coverage-exclusions.json` for Core and
`tests/terminal/plugin-coverage-exclusions.json` for the generic fixture only when a category is
genuinely not applicable or cannot safely run unattended. Exclusions are exact command/category
records with a narrow classification and reason; broad command-family exclusions are not accepted.

## Debugging

- Enable the summary output from the runner to see exact scenario IDs.
- Re-run the single failing scenario with `-KeepSuccessArtifacts` to retain runtime state files.
- Inspect the sanitized prompt trace log and raw terminal output in the failure artifact directory.
- Inspect `command-coverage.json` when the full run reports missing, stale, or unexecuted coverage.
