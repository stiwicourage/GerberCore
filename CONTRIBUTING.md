# Contributing

Thank you for contributing. Keep changes small, reviewable, and easy to validate.

Before opening a pull request:

- update tests when behavior changes
- keep tests mirrored to changed source files: one focused `.Tests.ps1` file for every new or changed `src/**/*.ps1` file
- use `tests/TestHelpers/` or test-support files for shared setup instead of broad catch-all test files
- add or update PlatyPS-compatible help under `docs/Gerber/en-US/` when public commands or public classes change
- when you add a new public function, create its matching help file in the same change
- use Nova commands and `project.json` for build, test, package, and release behavior
- keep PowerShell code, tests, and examples compatible with `project.json` `Manifest.PowerShellHostVersion`; if the project targets `5.1`, do not add PowerShell 7.x-only features
- keep local quality checks ordered as ScriptAnalyzer, then `Invoke-NovaBuild`, then `Invoke-NovaTest`, then `Test-NovaBuild` when your project defines both test flows
- run `./scripts/build/Invoke-ScriptAnalyzerCI.ps1` for the analyzer-only gate and `pwsh -NoLogo -NoProfile -File ./run.ps1` for the full local quality loop, including the tracked PTY terminal regression gate
- declare every Gerber Core executable command in a passing PTY scenario or an exact, justified category exclusion; new Core interactive commands require dispatch, workflow, navigation, rendering, and relevant error/recovery coverage
- keep generic Plugin API coverage in `Gerber.TerminalFixture`; product plugin repositories own terminal coverage for their commands and must not be loaded by Gerber's default runner
- keep scenario `commands`, `workflows`, and `coverage` metadata aligned with behavior the scenario actually executes; metadata without a passing current-run scenario does not satisfy the coverage gate
- inspect `artifacts/terminal/runs/<run-id>/command-coverage.json` for Core failures and `plugin-command-coverage.json` for the generic Plugin API contract
- when you change `.github/copilot-instructions.md`, run `pwsh -NoLogo -NoProfile -File ./scripts/build/Sync-AgenticCopilotScaffold.ps1` so `AGENTS.md` stays synchronized
- use `Invoke-NovaTest` for unit validation and `Test-NovaBuild` for build-validation integration runs; do not validate with direct `Invoke-Pester`
- for generated plugins, run `./scripts/Test-PluginBoundary.ps1` before the normal Nova flow; installed Gerber's `Test-GerberPluginBoundary -Path <project>` inspects public operations and diagnoses identifiable private Core dependencies without executing plugin source. Request missing public capabilities rather than importing Core internals; see [the static detection limits](docs/architecture/plugin-api-v1-capabilities.md#development-time-boundary-validation)
- keep public command unit ownership in `tests/public/<Command>.Tests.ps1`
- keep per-command public integration ownership in `tests/public/<Command>.Integration.Tests.ps1` when built-module behavior itself needs validation
- for destructive or environment-coupled commands, prefer safe `-WhatIf` integration coverage when appropriate
- if the repository quality loop or `Invoke-ScriptAnalyzerCI.ps1` reports ScriptAnalyzer findings, fix them before you ask for review; zero findings is the only passing result
- follow `.github/instructions/psscriptanalyzer.instructions.md` as the ScriptAnalyzer workflow source of truth; use direct `Invoke-ScriptAnalyzer` only for focused local checks that reuse the repo-approved settings
- keep one externally called function per file and match the file name to that function; private files may keep extra related functions only as same-file top-level support helpers, and PowerShell functions must not declare nested functions inside their bodies
- follow `.github/instructions/code-quality-matrix.instructions.md` for source/helper-script maintainability and `.github/instructions/testing-policy.instructions.md` for test design
- keep `docs/Gerber/en-US/*.md` as valid PlatyPS command help by using `New-MarkdownCommandHelp`, `Update-MarkdownCommandHelp`, and `Test-MarkdownCommandHelp`
- make every changed or generated text file end immediately after exactly one newline terminator with no blank spacer line at the bottom; use `pwsh -NoLogo -NoProfile -File ./scripts/build/Test-TextFileFormatting.ps1` for a focused check, and keep `tests/TextFileFormatting.Tests.ps1` green when Pester is enabled
- preserve the owner's approved `PSAvoidUsingWriteHost` exclusion in the analyzer wrapper: intentional terminal/CI host output is allowed; do not exclude or suppress other PSScriptAnalyzer rules
- do not rely on a ScriptAnalyzer baseline or grandfathered findings; every `Error`, `Warning`, `Information`, and `ParseError` diagnostic must be resolved
- do not hand-create module `.psm1` or module `.psd1` files in source
- review `README.md`, `CHANGELOG.md`, and `RELEASE_NOTE.md` when the workflow or public behavior changed
- keep PowerShell cmdlet guidance, CLI guidance, and contributor guidance clearly separated
- validate the changed path before you ask for review

## Native credential platform matrix

`run-platform-matrix` (`.github/workflows/Run-Platform-Matrix.yml`) is a narrow
platform-dependent integration lane, not another full-suite or coverage run.
Initially its only triggers are pushes to `feature/mainstream` and
`workflow_dispatch`. GitHub only enables manual dispatch when the workflow exists
on the default branch, so initial feature-only qualification must use a push to
`feature/mainstream`; manual UI/CLI dispatch is not available yet. Add
`develop`/`main` triggers only after actual feature-branch
Windows, Linux and macOS runs are qualified and the owner accepts that rollout.
Neither the workflow definition nor mocked/local tooling tests qualify a platform.

The pinned lanes are Windows 2025/x64, Ubuntu 24.04/x64 and macOS 15/ARM64,
using PowerShell >= 7.4. They install the existing CI module prerequisites and
build with `Invoke-NovaBuild`. NovaModuleTools >= 3.4.2 and PSModuleUpdate >= 0.1.0
remain required. The only selected tests are the two existing
`NativeCredentialStore` scenarios in
`tests/public/CredentialService.Integration.Tests.ps1`: Core and external Plugin
API native credential create/read/update/remove round trips.

The guarded entrypoint is
`./scripts/build/ci/Invoke-NativeCredentialPlatformCI.ps1`. It refuses non-hosted
or mismatched runners; do not spoof its runner environment or run it against a
normal workstation vault. It temporarily sets
`GERBER_RUN_NATIVE_CREDENTIAL_TESTS=1`, clears inherited `GCM_CREDENTIAL_STORE`,
and restores both values around exactly:

```powershell
Test-NovaBuild -TagFilter NativeCredentialStore -OutputVerbosity Detailed -OutputRenderMode Ansi
```

Linux uses a private `XDG_DATA_HOME`, a disposable Xvfb display, a single
`dbus-run-session`, and gnome-keyring's real Secret Service provider with an
unlocked default collection. Before changing `XDG_DATA_HOME`, the step captures
and exports PowerShell's original `PSModulePath` so the already-installed CI
modules remain discoverable in the child process without reinstalling them.
The packaged credential backend requires a
graphical session even when D-Bus and the collection are already available;
Xvfb supplies that session without an interactive desktop. macOS temporarily
selects an unlocked keychain created under
`RUNNER_TEMP`, restores the original default/search list, and deletes only that
owned keychain. Windows uses the disposable hosted user's native Credential
Manager. Test targets contain fresh GUIDs; no real user credentials are used.
Provider checks fail rather than falling back to mocks or another backend.

Each lane removes old `artifacts/TestResults.xml` before testing and requires a
fresh Nova NUnit summary with exactly 2 executed / 2 passed and no failed,
erroneous, inconclusive or skipped tests. Nova's raw `total` includes discovered
`NotRun` cases (currently 13 discovered / 11 not run); the guard checks the
executed count from outcome counters, validates consistency, and preserves the
original XML. The summary is uploaded even on failure when
available; keyring files/passwords and credentials are not artifacts. This
`Test-NovaBuild` lane does not alter the normal source coverage gate.

The lane's isolated tooling tests run with
`Invoke-NovaTest -TagFilter BuildTooling`. This filtered unit selection does not
exercise all production source, so the unchanged whole-project coverage target
can fail even when every selected tooling assertion passes; use the normal full
quality flow for whole-project coverage evidence.

## Agentic Copilot workflow

Recommended flow:

1. **Design**
    - Use `/agent architect`, `.github/agents/architect.agent.md`, and `.github/prompts/design-change.prompt.md` when the scope still needs analysis.
2. **Implement**
    - Use `/agent powershell-developer`, `.github/agents/powershell-developer.agent.md`, and `.github/prompts/implement-issue.prompt.md` to implement the agreed change.
    - If the work is mainly about tests or coverage, use `/agent test-engineer`, `.github/agents/test-engineer.agent.md`, and `.github/prompts/improve-test-coverage.prompt.md`.
3. **Review**
    - Use `/agent reviewer`, `.github/agents/reviewer.agent.md`, and `.github/prompts/review-change.prompt.md` before handoff or pull request review.
4. **Prepare release**
    - Use `/agent release-manager`, `.github/agents/release-manager.agent.md`, and `.github/prompts/prepare-release.prompt.md` when release-facing files change.
