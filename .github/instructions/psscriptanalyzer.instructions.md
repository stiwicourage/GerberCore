---
applyTo: "src/**/*.ps1,tests/**/*.ps1,scripts/**/*.ps1,reload.ps1"
---

# PSScriptAnalyzer workflow rules

## Scope

Use this file when changing PowerShell code, tests, build helpers, or analyzer wrappers.

## Why this matters

- PSScriptAnalyzer is the supported static analyzer for PowerShell scripts and modules in this repository.
- The repository quality loop already expects ScriptAnalyzer to run before build and test, so agents should follow that workflow instead of inventing their own lint steps.

## Required workflow

1. Use the repository wrappers as the authoritative entrypoints:
    - analyzer only: `./scripts/build/Invoke-ScriptAnalyzerCI.ps1`
    - full local loop: `pwsh -NoLogo -NoProfile -File ./run.ps1`
2. If the repository wrapper is missing or non-functional, do not silently fall back to a direct invocation. Instead, flag the broken wrapper as a blocking issue before proceeding.
3. Use raw `Invoke-ScriptAnalyzer` only for focused local investigation, including one focused run on changed files while iterating, or when you are deliberately changing analyzer tooling.
4. If invoking `Invoke-ScriptAnalyzer` directly, all of the following must hold:
    - the run is justified as focused local investigation or analyzer-tooling work
    - the target is a real `.ps1`, `.psm1`, or `.psd1` path
    - use `-Recurse` when analyzing a directory
    - if using `-Fix`, run `-WhatIf` first and inspect the diff afterwards
    - do not use `-EnableExit` when the repository wrapper already defines failure semantics
5. Treat `Error`, `Warning`, `Information`, and `ParseError` diagnostics as findings to fix before opening a pull request or passing the change to a reviewer. Parser errors are analyzer diagnostics too and are not something to suppress away.
6. The project owner explicitly approves `PSAvoidUsingWriteHost` as the sole excluded rule: intentional terminal and CI host output is supported. The repository wrapper owns this exception, including its transient retry; focused direct runs must reuse it. Do not add other ad hoc `ExcludeRule`, `ExcludeRules`, `SuppressMessageAttribute`, baselines, or custom settings changes just to make the analyzer pass.
7. `Invoke-ScriptAnalyzer -Fix` is optional and only applies to selected rules. Review every change it would make, prefer `-WhatIf` first, and inspect the diff afterwards.
8. `Invoke-ScriptAnalyzer -EnableExit` is useful for CI shells, but if the repository already has a wrapper with established failure semantics, do not replace that wrapper with an ad hoc direct invocation.

## Authoring guidance

- Prefer one focused analyzer run on the changed files while iterating, then rerun `./scripts/build/Invoke-ScriptAnalyzerCI.ps1`, then `./run.ps1` before opening a pull request or passing the change to a reviewer. During iterative focused runs, apply the same severity threshold as the full CI run: fix all `Error`, `Warning`, `Information`, and `ParseError` diagnostics.
- Keep analyzer wrappers focused on authored repository PowerShell under `src/`, `scripts/`, `tests/`, and `run.ps1` when present, not generated output such as `dist/` or `artifacts/`.
- Built-in presets such as `PSGallery` or `CodeFormatting` exist, but do not switch to them unless the repository explicitly adopts them.

## Review expectations

- Reviewers should flag direct `Invoke-ScriptAnalyzer` usage that bypasses the repository wrapper or repository-approved settings without a clear reason.
- Reviewers should flag new rule suppressions, exclusions, or analyzer-setting changes that are broader than the specific justified need.
- Reviewers should flag PowerShell changes handed off with unresolved analyzer findings.
