# Gerber — Product Roadmap and Work Register

> Reconstructed 2026-10-10. This roadmap preserves both the original product-phase names and the more granular G-1A implementation IDs. **Statuses distinguish user-reported progress from verified completion.** Do not rename historical phases to make a new plan.

## TL;DR
- G-4A7R Core distribution and ordering are implemented. PMU 0.2.0 is published and satisfies the current dependency minimum; dependency delivery is no longer blocked.
- A live Core update was user-confirmed on 2026-10-27. Current-revision hosted tests pass, but the native credential matrix does not qualify live updates on Windows/Linux.
- Next step: review and separately commit the validated PMU cleanup, then implement the provider `PackageNotFound` correction and verify Gerber's existing no-package integration contract. Functional implementation is paused at that user-owned commit boundary; G-4A7R remains open.
- Plugin updates remain the separate G-4A9 task; do not start them as part of this closure.

## Vision
Free, proprietary, cross-platform, agent-first PowerShell DevOps product. Standalone Core; independent plugins; private source and eventual PowerShell Gallery distribution; documentation planned for Gerber.ps. Pre-1.0 breaking changes allowed, without legacy migrations.

## Original product phases (high-level)
| Phase | Original scope | Status |
|---|---|---|
| G-1 | Generic config, PAT, lazy ADO | In progress / parts delivered; inspect |
| G-2 | GitHub Actions, release, PowerShell Gallery | Not verified |
| G-3 | `/update` and self-update | Core implemented in G-4A7; plugins planned; quality readiness below |
| G-4 | `/plugins create` and working scaffolding | G-3D1 + G-3D1-FIX1 implemented; see detailed validation evidence |
| G-5 | Agent-first plugin development (AGENTS.md, skills) | G-3E1 implemented with generated-project validation |
| G-6 | Plugin installation, discovery, private distribution | Partly foundational; management incomplete |
| G-7 | Documentation, Gerber.ps, public launch | Planned |

The original plan explicitly allowed reordering and prioritized plugin creation and agent-first experience.

## Detailed G-1A implementation plan (historical IDs retained)
| ID | Original objective | Current evidence / status |
|---|---|---|
| G-1A | Read-only three-repository architecture analysis | Complete; `G-1A.md`, `G-1A_response.md` |
| G-1B | Runtime dependencies and manifest metadata | Both NovaModuleTools and PSModuleUpdate remain `RequiredModules` (D-002 amendment, D-017). Disposable build/import qualification passed on macOS/PowerShell 7.4.21 and 7.6.6 ([G-4A6](docs/architecture/G-4A6-runtime-dependency-qualification.md)); authorized G-4A7 Nova builds refresh the ignored local manifest |
| G-1C | Local analyzer/quality tooling | Analyzer zero findings reported; task status verify |
| G-1D | Test/publish workflows | Verify |
| G-2A | Persistent user configuration | Worked on; verify exact acceptance criteria |
| G-2B | Generic ADO profile resolution / remove organization defaults | Worked on; verify exact acceptance criteria |
| G-2C | Pure ADO URL parser | Verify |
| G-2D | Credential resolver | Original vault/env design **superseded** by Devlooped abstraction; verify current implementation |
| G-2E | Lazy ADO setup and safe command resume | Verify |
| G-2F | Named connections in Plugin API | Verify |
| G-3A | Plugin GUID identity and isolation | G-3A1 persistent approval implemented; G-3A2 persistent association and enabled/disabled lifecycle implemented; management commands remain planned |
| G-3B | Namespace aliases and conflict resolution | Planned |
| G-3C | `/plugins` overview plus `list/info/enable/disable` | Overview/list/info and enable/disable implemented; separate approve is unnecessary because enable handles declined plugins; remove/decline/revoke are not Core 1 scope |
| G-3D | Transactional `/plugins create` | G-3D1 + FIX1: explained/spaced fields, visible cwd/child defaults, completion metadata; cached pre-install name/version, canonical manifest GUID and complete Unreleased changelog; staged validation/autoapproval preserved |
| G-3E | Generated agent resources | G-3E1: canonical self-contained AGENTS.md, thin Claude/Copilot bridges, three scoped instruction files, plugin developer role and three actionable skills; generated project builds/tests/publishes locally in isolation |
| G-3F | Plugin boundary guardrails | G-3F1 implemented: standalone installed-source AST validation, transactional generation gate and generated development workflow; CodeScene review/safeguard availability remains a separate verification gate. Gerber.ExampleOrg unchanged. |
| G-4A | `/update` and update architecture | Architecture decided ([G-4A5](docs/architecture/G-4A5-update-architecture.md), D-017). Core integration implemented in G-4A7; plugins planned; see sub-rows |
| G-4A0–G-4A2 | Update analysis, PMU design, PSResourceGet qualification | Complete as historical analysis; conflicting recommendations superseded by G-4A5 |
| G-4A3 | PSModuleUpdate engine (sibling repository) | Closed 2026-10-23 within its qualified scope (PMU repository evidence) |
| G-4A4 | PMU cross-platform CI | Passed for PMU only (the historical CI run (private evidence)); not Gerber integration |
| G-4A5 | Runtime dependency contract and Gerber Core update integration | Architecture corrected 2026-10-24: both NovaModuleTools and PMU required, with distinct creation/build/publication versus update roles. Core implementation follows in G-4A7; remaining policy questions in G-4A5 section 14 |
| G-4A6 | Runtime dependency and generated manifest qualification | [Historical report](docs/architecture/G-4A6-runtime-dependency-qualification.md): exact Nova 3.4.2 builds both requirements; PMU 0.1.0-preview imports offline under numeric 0.1.0 on macOS/PowerShell 7.4.21 and 7.6.6. Missing/old dependencies rejected. G-4A7 refreshes the original ignored artifact; wider qualification remains |
| G-4A7 | Gerber Core update integration | Core startup notification and fresh `/update` discovery/confirmed PMU installation implemented; [configuration/limits](docs/core-updates.md). Full unit run: 1,674 passed, two unchanged baseline failures (analyzer/`project.json` EOF), 96.25% coverage; integration: 11 passed, two existing opt-in skips; final full PTY run: all 75 scenarios passed. Earlier transient process-start timeouts passed unchanged on isolated reruns. CodeScene: 43 scorable files at 10.0, safeguard passed. Quality readiness was blocked at the G-4A7 handoff by the analyzer/EOF baseline; G-4A8 resolves that baseline below. Live-provider and Gerber Windows/Linux qualification remain unverified |
| G-4A8 | Resolve remaining quality gate failures | Complete: sole owner-approved `PSAvoidUsingWriteHost` exclusion, two named-parameter CI path fixes and newline-only `project.json` correction. Unit: 1,679 passed, zero failed; integration: 11 passed, two existing opt-in skips; full PTY: 75 passed with zero coverage issues. Analyzer: zero findings across 518 files. `run.ps1` passed the complete pipeline with 95.92% coverage against 90%; standalone unit coverage was 96.25%. All four changed PowerShell files remain Code Health 10.0; safeguard passed. Core update behavior and required dependencies unchanged |
| G-4A7R | Correct Core update distribution and ordering | Implemented, closure incomplete; status reviewed 2026-10-30. Permanent application-owned PSGallery binding, CurrentUser scope, Stable default with persisted prerelease opt-in, obsolete Core binding ignored and `/update` fourth after `/exit`, `/help`, `/plugins`. Equal installed/available versions retain PMU's target and UpToDate without an install offer. Published PMU 0.2.0 satisfies the current numeric 0.2.0 minimum; the old unpublished-dependency blocker is resolved. Live happy-path installation is user-confirmed. Remaining: upstream PackageNotFound classification, broader live-update/recovery qualification and stale documentation; see closure evidence below. No automatic local migration/cleanup |
| G-4A9 | Plugin update integration in `/update`: overview, per-plugin selection, repository association, activation qualification | Planned after corrected Core integration. Gerber owns independently configurable per-plugin repositories; the fixed Core resolver must not inherit those settings. Both paths use PMU. Previously assigned provisional G-4A6; separate from the owner's current G-4A6 qualification |
| G-4B | Versioned documentation | Planned |
| G-4C | 1.0.0 readiness | Planned |

## G-4A7R closure evidence and remaining work

Status reviewed 2026-10-30 against revision `d599443`. Earlier G-4A7/G-4A8 rows preserve their historical handoff evidence; the following supersedes their outstanding dependency/live-update claims only within the stated scope.

| Area | Status and evidence |
|---|---|
| Dependency delivery | Passed: PSGallery lists PMU 0.2.0, its package was inspected read-only, and current-revision CI installed it from PSGallery. `project.json` requires numeric 0.2.0. No new bootstrap/publication is needed to resolve the historical missing-artifact blocker |
| Hosted unit/integration checks | Passed: [Run Tests, attempt 1](https://github.com/stiwicourage/GerberCore/actions/runs/40851789440), 2026-10-29, revision `d599443`: 1,858 unit passes, 17 integration passes, two native-credential opt-in skips and 96.54% coverage against 95%. This is not a fresh local full-quality/PTY run |
| Native credential platforms | Passed for credentials only: [platform matrix, attempt 1](https://github.com/stiwicourage/GerberCore/actions/runs/40847421840), 2026-10-29, revision `d599443`: Windows/X64, Linux/X64 and macOS/ARM64 each passed both selected credential scenarios using Gallery PMU 0.2.0. These jobs do not exercise live Core installation or recovery |
| Live Core happy path | User-reported verification, 2026-10-27: `/update list` installed `0.2.0` to `0.2.1-preview` with `Verification: Verified` and `Recovery: NotRequired`; a subsequent check returned `RestartRequired`. This is not a newly executed qualification of revision `d599443` or every platform/channel/recovery path |
| No-package classification | Unresolved: published PMU 0.2.0 `Find-ProviderResource` still routes provider exceptions through `Write-ProviderError` with `PMU.DiscoveryFailed`; the latter does not preserve structured `PackageNotFound`. Gerber correctly maps explicit `PMU.PackageNotFound` to `NoMatchingPackage`, but cannot classify the wrapped provider error. Fix and test the provider boundary in PMU; do not add another Gallery query or text-based version/error inference in Gerber |
| Classification prerequisite cleanup | Validated locally on 2026-10-30, uncommitted at PMU HEAD `e6dfe68`: behavior-preserving request-parameter extraction reduces `Find-ProviderResource` from 19 to 12 whole-declaration lines; new helper has 15. Characterization passed before/after. PMU `run.ps1` passed on macOS ARM64/PowerShell 7.6.9: 854 unit passes, one Windows-only skip; six integration passes, three opt-in live-feed skips; 98.09% coverage; zero analyzer findings. Four supported files measured 10.0 and the cleanup safeguard passed. A newline-only changelog repair is included. Await the user's separate cleanup commit before adding the functional regression or classification fix; PowerShell 7.4 and hosted lanes remain unverified |
| Remaining qualification | Unverified: live Core update on Windows/Linux and complete failure/recovery flows through Gerber. Define the bounded acceptance scope and retain platform/channel evidence before claiming broader completion. A passing credential matrix or PMU-only qualification is not a substitute |
| Documentation follow-up | Current dependency availability and dated qualification evidence reconciled in `README.md`, `CONTRIBUTING.md`, `docs/core-updates.md` and applicable unreleased release text. Historical release entries are preserved. Document the upstream classification fix only after its implementation and qualification; a local build is not publication or deployment |

Closure work does not authorize upstream edits, publication, installed-module repair, live installation, commits or pushes. Scope and authorize each subsequent task separately.

## Completed separate quality stream
- G-PTY1: permanent terminal regression framework — reported complete.
- G-PTY2: interactive CLI fixes, command inventory and coverage — reported complete.
- G-PTY3: Core-only terminal coverage and removal of Gerber.ExampleOrg-specific tests — stopped and accepted with known `/repository create` full-provisioning PTY gap; user manually verified actual repository creation.
- G-UX1: double Escape to root — implemented centrally across the shared Gerber terminal prompt/menu infrastructure with focused Pester and PTY coverage.
- G-UX1-FIX1: shared plugin menu navigation regression — `/plugins` now uses the same shared submenu navigation contract as other Core command groups, so single `Esc` returns to the immediate parent menu while the existing double-Escape-to-root behavior remains intact.
- **Do not reopen PTY work solely to eliminate this accepted gap.**

## Bounded task status (G-3D1-FIX1 + G-3E1)
1. **G-PLAN:** save and review these documents; verify existing code vs decisions. Read-only review first; no builds/tests needed.
2. **G-3C4:** no separate approve command; `/plugins enable` already explicitly approves declined plugins.
3. **G-3D1:** implementation delivered; Gerber owns the plugin-specific templates and Nova owns lifecycle. Generated examples and tests belong here, not G-3E1.
4. **G-3D1-FIX1 + G-3E1:** implemented together; focused behavior, generated-project local publication/fresh-host hello and PTY trace validation precede the final full quality loop. Evidence and runtime limitations belong in the task handoff, not inferred from roadmap status.
5. **G-3F1:** development-time Plugin API v1 boundary checks are implemented, not a PowerShell sandbox. `Test-GerberPluginBoundary` works on an uninstalled project using installed Core; generator checks before executing Nova or plugin code. Generated script/agent guidance uses this command, then standard Nova validation. Runtime approval, discovery, inventory, registration and execution semantics remain unchanged. See the task verification artifact/handoff for executed gates and unavailable CodeScene review evidence.

## Agent work constraints
- One bounded objective per Copilot task; avoid multi-hour autonomous iterations and repeated full-suite runs.
- No automatic work on Gerber.ExampleOrg or NovaModuleTools unless explicitly authorized.
- No commits, pushes, publishing, live destructive ADO operations, or actual Keychain changes without explicit authorization.
- New problems: document and stop rather than expand scope.
- Report files changed, tests actually run, limits, unresolved issues and exact stop reason.

## Next review checklist
- Close the G-4A7R upstream no-package issue and document the remaining live-update qualification scope before treating Core integration as fully qualified; then proceed to G-4A9 as a separate task.
- Compare `PLAN.md`, `ARCHITECTURE.md`, `DECISIONS.md` to source and existing project documentation.
- Confirm G-2A/G-2B and credential abstraction current state.
- Verify G-3A1/G-3A2 against the current loader and persistent configuration tests before adding `/plugins` management commands.
- Agree the **revoked-but-still-usable** warning and user override semantics before coding.
