# G-4A0 - Shared PowerShell Self-Update Architecture

**Status:** Architecture recommendation; implementation and product decisions are not approved by this report.
**Date:** 2026-10-22.
**Audience:** Gerber and NovaModuleTools maintainers.
**Scope:** Updating the consuming module itself, not managing arbitrary installed modules or plugins.

> **Historical analysis - partly superseded (2026-10-23).** The current authoritative update architecture is [G-4A5](G-4A5-update-architecture.md). The recommendation of Option B (build-time shared source) was never approved and was superseded by the independent PSModuleUpdate module. The Core-only `/update` scope, "no startup checks" and the framing of a mandatory `RequiredModules` dependency as undesirable are superseded: PSModuleUpdate is a required Gerber Core dependency, Gerber notifies about Core updates at startup, and `/update` covers Core and plugins. The text below is preserved unchanged.

> **Runtime dependency clarification (2026-10-24):** both NovaModuleTools and PSModuleUpdate are required Gerber runtime dependencies. Sections 1 and 3's no-Nova restriction relied on the former D-002/Core baseline and is superseded by the owner's decision: Gerber exposes plugin development through `/plugins create`, using Nova build/test/package/local publication functionality. Nova operations remain on demand; PMU, not Nova, owns generic update installation. See [D-002 / D-017](../../DECISIONS.md) and [G-4A5 historical reconciliation](G-4A5-update-architecture.md#11-historical-reconciliation). Historical findings such as empty `RequiredModules` describe the inspected revision, not the current declarations.

## 1. Executive summary

**Recommend Option B: a small, centrally maintained, version-pinned source component incorporated into each consumer's build. Do not create a separately installed shared runtime module for Gerber 1.0.0.** Start with a deterministic planning contract, prove package-engine behavior in isolation, and share the common discovery/install adapter only once that behavior is established. Product configuration, consent, terminal UI, notification triggers and activation remain consumer-owned.

NovaModuleTools contains a real self-update subsystem, not just a wrapper around an installation command. However, wholesale extraction would export Nova-specific settings, UI, project-resource resolution and unverified package-engine assumptions. Its current plan identifies a target, but execution calls `Update-Module` without that exact version or a source binding, then marks the operation updated without inspecting the installed result. It neither reloads the module nor provides rollback. These are architecture constraints, not guarantees to preserve.

Gerber already has an independently usable Core, no declared PowerShell module dependencies, durable user configuration and a registry-based interactive CLI. Making Core or its startup depend on Nova would contradict its existing boundary. A new runtime updater would not itself violate the no-Nova rule, but would introduce another installable component, compatibility contract and recovery dependency without demonstrated benefit over packaging the same source privately.

The recommendation centralizes policy and, after verification, the standard package-engine adapter; it does not centralize user state or invent a package manager. Security fixes require new consumer releases, an explicit cost of build-time reuse. If that cost becomes unacceptable with more consumers or urgent out-of-band fixes, reconsider Option A using the same stateless plan/apply contract.

**Before coding:** approve source-component ownership/distribution, package engine and minimum version, channel defaults, scope, supported installation provenance, same-directory prerelease replacement handling, and recovery guarantees. The report does not implement `/update`, extract code, introduce dependencies or authorize another phase.

## 2. Current NovaModuleTools implementation

### Evidence boundary

NovaModuleTools was inspected at commit `8164967da1cd1f14d4f5e24e24d5392bac8b1a32`, with a clean worktree. Gerber's base commit was `435c649a566599200ed458a8ae19f9d66cfd0b4d`; its current working tree already contained unrelated plugin-boundary work and documentation edits. Gerber findings describe those inspected working-tree files, not a claim that all of them exist in the base commit.

Findings are based on implementation, callers, tests, manifests and documentation, supplemented by Microsoft package-engine documentation. No self-update, package installation, real repository lookup, runtime compatibility test or rollback experiment was executed. Existing tests described below were read, not run.

The requested names exist as **`Invoke-NovaModuleSelfUpdate`** and **`Get-NovaModuleSelfUpdatePlan`**, in files without the function-name hyphens under `src/private/update/`. The public command is **`Update-NovaModuleTool`**, singular, with compatibility alias **`Update-NovaModuleTools`**, despite its source file being `src/public/UpdateNovaModuleTools.ps1`. [N1-N4]

### Implemented lifecycle

| Step | Actual behavior | Evidence |
| --- | --- | --- |
| 1. Initiate | Explicit `Update-NovaModuleTool`, its alias, or `nova update`. Build completion and scaffold initialization also invoke availability notifications; these do not install updates. No import-time check was found. | N1, N5 |
| 2. Load preferences | Read per-user `PrereleaseNotificationsEnabled`, defaulting to `true`. Stable notifications remain enabled. The same preference controls prerelease eligibility for an explicit update, despite its notification-oriented name. | N6 |
| 3. Identify current version | Use the currently executing module, defaulting to `$ExecutionContext.SessionState.Module`: name, manifest base version and `PrivateData.PSData.Prerelease`, combined into `[semver]`. This is the active version, not the highest installed version or a package-manager inventory. No installation path/scope is captured. | N7 |
| 4. Discover versions | Run a resource script in a separate in-process PowerShell instance. It calls `Find-Module` against hardcoded `PSGallery`, once for stable and optionally once with `-AllowPrerelease`. Explicit updates allow 10 seconds; notifications normally allow 3 seconds. | N3, N8 |
| 5. Select candidate | Stable must be semantically newer than current. Prerelease must be enabled, newer than current and textually different from the stable lookup result. The planner chooses an eligible prerelease before stable. | N4 |
| 6. Approve | Prerelease gets a custom Yes/No confirmation, default No, followed by public cmdlet `ShouldProcess`. `-WhatIf` skips the custom prerelease prompt and installation, but still performs discovery. Stable has no equivalent custom product prompt; native/package-engine confirmation may apply. | N1, N9 |
| 7. Install | `Invoke-NovaModuleSelfUpdate` delegates to an adapter calling `Update-Module -Name <name>`, adding `-AllowPrerelease` when selected and `-ErrorAction Stop`. It does not pass `RequiredVersion`, `Scope`, `Force`, `AcceptLicense` or an execution source binding. | N2 |
| 8. Report | When the adapter returns without throwing, set `Updated = true`, obtain a release-notes URI and render the result. There is no installed-version/path verification. | N10 |
| 9. Activate | No `Remove-Module`, reimport or PowerShell restart occurs. The old module remains active. Restart/reload requirements are not communicated reliably. | N7, N10-N11 |
| 10. Recover | Wrap installation exceptions as a Nova error with retry guidance. There is no transaction coordinator, partial-install reconciliation, automatic rollback or updater lock. | N8, N10 |

### Channels, version ordering and sources

The lookup resource returns `SourceRepository`, `Stable` and `Prerelease`; candidate records carry `ModuleName`, `Version`, `Channel` and `Repository`. The prerelease-enabled lookup is not a separate preview feed: it asks PSGallery for a result including prereleases, which may itself be stable. The planner rejects an identical stable/prerelease version string. There is no named release-train registry, branch selection, beta-versus-preview subscription, version range or public target-version selection.

Normal repository ordering makes the prerelease-first rule workable, but the planner does not independently choose the maximum of stable and prerelease: supplied data containing an eligible preview below a newer stable would still select preview. Equal semantic versions with different text, unusual labels and build metadata need explicit characterization. A stable release can supersede the same-base prerelease; stable-only selection must not downgrade a newer preview to an older stable. [N4]

Both lookup calls use terminating errors. A stable lookup failure prevents trying prerelease; a subsequent prerelease lookup failure prevents returning the already found stable candidate. Timeout and `EndInvoke` failures become `$null`, losing their distinctions. An explicit command turns this into `Nova.Dependency.ModuleSelfUpdateCandidateUnavailable`; notifications return silently, and their safe wrapper also suppresses exceptions. There is no discovery cache or check-throttling layer in the inspected update path. [N3, N5, N8]

Discovery is explicitly PSGallery, but execution delegates source selection to `Update-Module` and its installation metadata. That command requires installation through `Install-Module` according to Microsoft documentation. Nova does not establish this provenance, although it also supports development builds and local installation. Discovery and installation can therefore disagree about source or fail for a manually installed copy. [N2, N7, M1]

Nova passes no scope. Modern PowerShellGet documents `CurrentUser` as the default, but Nova pins neither its presence nor its version. **CurrentUser behavior is a documented modern-provider expectation, not verified scope preservation across all supported installations.** An AllUsers-loaded copy may receive a separate CurrentUser installation rather than replacement in its original scope. [N2, N12, M1]

### Approval and return contract

The workflow context contains `Preference`, `InstalledModule`, `LookupResult`, `WorkflowParams`, `Plan` and `Action`. The plan/result contains:

```text
ModuleName, CurrentVersion, TargetVersion,
LookupCandidateVersion, LookupCandidateChannel, LookupRepository,
PrereleaseNotificationsEnabled, UpdateAvailable, Updated, Cancelled,
IsPrereleaseTarget, UsedAllowPrerelease
```

Completion adds `ReleaseNotesUri`. These fields are compatibility considerations for Nova migration, not the proposed shared schema. [N3-N4, N10]

The public update has no `-Force` switch. PowerShell `-Confirm` can combine native confirmation with the prerelease prompt. CLI `nova update --confirm` has its own earlier mutation confirmation and strips `Confirm` before forwarding, potentially followed by the prerelease prompt. Combined confirmation behavior is not covered by the focused tests. No persistent authorization to install updates is stored. [N1, N5, N9]

### Imported modules, errors and recovery

Installation success is not activation success. The release-notes helper defaults to the still-loaded module, and suggested `Get-NovaProjectInfo -InstalledNovaVersion` also resolves the loaded Nova version. Consequently, the displayed notes and verification can describe the old version. Documentation wording about reading notes from the updated module exceeds what the implementation proves. A release-notes failure after installation can also prevent a complete result even though disk state changed. A no-op installer return is still marked `Updated = true`. [N7, N10-N11]

There is no automatic rollback. Standard module-version coexistence can enable manual recovery, but is not an application transaction guarantee. In particular, PowerShellGet installs prereleases sharing one numeric `ModuleVersion` into the same version directory; preview-to-preview or preview-to-stable can overwrite that directory. Do not assume the old preview remains recoverable side by side. Exact PSResourceGet behavior must be tested separately. [M4]

### Persisted preferences

The public `Get-NovaUpdateNotificationPreference` reads status; `Set-NovaUpdateNotificationPreference -EnablePrereleaseNotifications` or `-DisablePrereleaseNotifications` writes it with `ShouldProcess`. CLI equivalents are `nova notification`, `nova notification --enable` and `nova notification --disable`. Update confirmation itself does not save a channel choice. [N6, N13]

Paths are `%APPDATA%/NovaModuleTools/settings.json` on Windows, `$XDG_CONFIG_HOME/NovaModuleTools/settings.json` on Unix when configured, otherwise `$HOME/.config/NovaModuleTools/settings.json`. The writer saves an object containing the one Boolean with direct `Set-Content`; it is not an atomic merged settings transaction. Missing/unreadable/malformed settings default to prerelease enabled. A string `"false"` casts to true, a behavior explicitly recorded in an existing reader test. A shared engine must not adopt that persistence policy implicitly. [N6]

### Packaging, tests and gaps

Nova's inspected project version is `3.4.2-preview`, targeting PowerShell 7.4. Required modules are Pester, Microsoft.PowerShell.PlatyPS and PSScriptAnalyzer, not a declared PowerShellGet minimum. Publishing uses PSResourceGet and PSGallery, whereas self-update uses legacy PowerShellGet. Repository registrations and version metadata are not interchangeable merely because both engines reach the Gallery. [N12, N14]

Focused tests cover version shaping, stable/prerelease comparisons, planner branches, result fields, default-No prerelease confirmation, timeouts/disposal, adapter flags, wrapped errors, `-WhatIf`, cancellation and alias export. The public integration smoke test accepts either a result or the generic lookup-unavailable error: it does not prove a real installation. Architecture tests restrict raw `Update-Module` to its adapter. [N15]

Absent demonstrated guarantees include exact approved-version installation, source parity, scope, post-install verification, imported-file behavior, provider availability, offline classification, concurrent attempts, interrupted-install recovery, rollback, trust/license prompts and cross-platform package operations. **Test source inspected is not test execution evidence.**

## 3. Current Gerber requirements

Gerber's roadmap lists G-4A `/update` as planned/verify; the earlier high-level G-3 self-update label is historical. No Core `/update` command is present in the inspected registry. Do not confuse pipeline tag updates or plugin activation with module self-update. [G1-G3]

The manifest source declares `Gerber`, GUID `ec5ae6fe-540b-48c2-a6d1-cb39aac6c444`, version `0.1.0-preview`, PowerShell 7.4 and `RequiredModules: []`. Nova generates the delivered manifest/module under `dist/`; source `project.json` is not an installed-version oracle. Gallery distribution is product intent, not a verified published release/pipeline prerequisite. G-4A must verify the actual Gerber package is available before claiming an installable target. [G1-G2]

`Invoke-Gerber` clears and initializes the command registry, shows the menu, and clears registry state on exit. Core definitions, plugin discovery/approval and handler dispatch are separate. A Core handler returns a Boolean controlling loop exit; emitting an update-result object from that handler would violate the dispatch contract. Render/consume it in a Core wrapper and return the normal Boolean. [G3-G4]

`Get-GerberCurrentVersion` first reads the module behind `Invoke-Gerber`, but currently uses only its numeric version; its source-mode fallback reads cwd `project.json`. Neither is sufficient unchanged for self-update provenance and prerelease identity. Build an update request from the active module's manifest metadata and path, including `PSData.Prerelease`, not a project in the caller's directory. This report does not change that helper. [G5]

Persistent configuration already provides schema version 1, absent-file defaults, explicit malformed-file errors, preservation of unknown properties and a temporary-file/flush/replace writer. It lives outside installed modules. There is no implemented update section or update-policy validator. Atomic file replacement does not prevent two read-modify-write callers losing each other's changes; it is not a global configuration lock. [G6-G7]

Core must work without Nova, plugins, ADO or PATs. Only `/plugins create` lazily offers Nova installation, with explicit consent. This is precedent for lazy optional tooling, not permission to require Nova for `/update`. Plugin API v1 has UI, ADO, Secrets and Clipboard capabilities, not a module-installation service. Plugin approval is GUID-based user intent, not package authenticity. `/update` belongs in Core and must not enumerate plugins for installation, change their approvals or add a plugin package-manager API. [G1, G8-G9]

## 4. Reusable versus module-specific functionality

| Responsibility | Shared source component | Consuming module |
| --- | --- | --- |
| Version semantics | Normalize base/prerelease metadata; eligibility; stable/prerelease precedence; no implicit downgrade | Supply active self identity and selected policy |
| Installed state | Inspect the named module's installed manifests/provider metadata without importing candidate code | Identify the active module/path and whether source/development use should be supported |
| Discovery | One bounded provider adapter; exact module and explicit source; normalized releases and classified errors | Approve allowed source and channel; decide when checks happen |
| Planning | Deterministic target, source, scope, safety classification and reasons | Apply product defaults and supported version constraints |
| Installation | After the provider spike: execute exact plan through a standard package engine, coordinate this updater's lock and verify resulting state | Own user consent and any supported special deployment mode |
| Settings | No settings file, user registry or global registration | Read, validate and persist product preferences in the existing store |
| UI | Structured objects, standard diagnostic/progress boundaries, no branded prompts | Gerber screens/navigation; Nova cmdlet/CLI prompts, formatting and errors |
| Activation/recovery | Report installed versus active state and standard recovery information | Decide when to exit/restart; document product-specific recovery |
| Notifications | No startup hooks or persistent background scheduler | Nova build/scaffold checks; any future Gerber notification policy |

Reusable code is a starting point, not a copy list: the current planner's prerelease priority and updater's success flag need contractual decisions. Time-bounded execution is reusable as an approach, but suppressing all errors is not the desired explicit-command contract.

An important coupling must be removed before reuse: `Get-NovaModuleUpdateLookupScript` uses `Get-ResourceFilePath`, which searches the current Nova project's resources before module-owned resources. A project resource at `update/ModuleUpdateLookup.ps1.txt` can therefore replace executable discovery text. This is a statically identified trust-boundary concern, not a tested exploit. Self-update code must come from the packaged consumer/component, never cwd project overrides. [N8, N16]

## 5. Architectural alternatives

### Option A - Shared runtime PowerShell module

A separately published engine would expose a small stateless API and be imported only when updating. A mandatory `RequiredModules` dependency would make import/startup dependent on it; a lazy dependency preserves startup but requires missing/corrupt/incompatible dependency handling at `/update`.

Advantages are independently distributed fixes, one engine release and a clear provider-contract test suite. Consumers still need explicit supported version ranges, controlled module selection and independent UI/configuration. Two products in one process can require incompatible engine versions; PowerShell command/module resolution and any shared type definitions must not silently bind to whichever version loaded first.

Costs include package ownership, publishing, bootstrapping, additional supply-chain exposure and another component whose own update can fail. A newest engine is not necessarily compatible. A runtime engine cannot guarantee its own recovery, and installing a consumer through an outdated/corrupt engine must not be the only repair route.

**Reject for the initial delivery:** no evidence of a requirement for updater-only releases outweighs these costs. Reconsider if several independent consumers require centrally deployable fixes and accept a tested dependency lifecycle.

### Option B - Shared source/build-time component

Maintain a small source component centrally. Consumers vendor a reviewed release/commit and its license/provenance into their own private source tree; Nova's normal builder incorporates it. Installed products contain their own engine code and require no shared updater module. Normal consumers do not need access to the source repository.

Distribution must be deliberate, not floating downloads or manual untracked copy/paste: record upstream revision, component version, content checksums and local namespace mapping; reject local edits/drift in a future development check. Refresh via reviewed consumer changes. Pin source before building, including for offline builds. Do not modify Nova's build system or fetch source during module import.

Nova's inspected `Build-Module` assembles project source files under classes/public/private. No external component-fetch mechanism was established by this investigation. Vendoring into that existing input tree avoids assuming one exists; a future synchronization check is new work requiring approval. Generated private function names must be consumer-prefixed, deterministic and tested so both products can be imported together without collisions. Do not expose shared classes or global commands just for source reuse. [N17]

Advantages are independent deployment, failure isolation, no updater bootstrap cycle and common tested behavior. Costs are per-consumer releases for fixes, provenance/license work, potential drift and consumer validation of each refresh. Security advisories must identify component versions and affected consumer releases.

**Recommend**, with bounded phases: share the planner first; use an isolated spike to establish one provider adapter, then share that adapter rather than maintaining permanent Nova/Gerber copies of the install workflow.

### Option C - Independent implementations

Each product wraps standard PowerShell mechanisms and owns all planning, installation and tests. There is no shared package or source lifecycle; this is the simplest initial packaging model and may be sufficient for genuinely different deployment policies.

The existing Nova behavior shows that meaningful logic extends beyond calling an installer: prerelease semantics, source parity, active/installed state, scope, timeouts, confirmation and recovery all need maintenance. Two independent implementations duplicate those decisions and their failure tests. A fix in one product does not protect the other.

**Reject as the target architecture**, not because duplication is always wrong, but because both products need the same self-update lifecycle. It remains the fallback if approved sharing ownership/distribution cannot be established; do not block Gerber 1.0 indefinitely or disguise copied implementations as a shared component.

### Additional alternative - Only document manual package installation

Keep standard installation instructions and omit automated `/update`. This is the smallest recovery surface and should always remain available, but alone does not meet the roadmap's interactive update objective. Retain it as the out-of-band repair path, not the primary architecture.

## 6. Comparison matrix

Ratings are qualitative judgments for these two consumers, not measured implementation costs.

| Criterion | A: Runtime module | B: Pinned shared source | C: Independent |
| --- | --- | --- | --- |
| Normal startup dependency | None if lazy; mandatory if manifest-required | None added | None added |
| Bootstrap and version compatibility | Separate runtime compatibility/install lifecycle | Build-time compatibility; no separately loaded engine | Product-local only |
| Central maintenance | One runtime implementation | One authoritative source; deliberate consumer refresh | Repeated fixes and policy decisions |
| Security-fix delivery | Potential updater-only release; consumers must actually adopt it | Each affected consumer must release | Each product fixes/releases independently |
| Failure isolation | Engine failure shared by loaded consumers | Broken component contained to the consumer release | Product-local failures |
| Release independence | Consumer/API compatibility constrains engine adoption | Consumer pins component and releases independently | Fully independent |
| Test strategy | Engine plus dependency/bootstrap matrix | Component contracts plus both packaged consumers | Repeated product behavior suites |
| Offline install/build | Dependency must already exist or be installed separately | Vendored source builds offline; installed update still needs a source | No sharing prerequisite |
| Source distribution | Public module contract and package lifecycle | Revision/checksum/license and namespace discipline | No shared artifact |
| Other consumers | Easiest plug-in API adoption after engine installation | Explicit source integration; less convenient | Must reimplement |
| Fit for Gerber 1.0 | More lifecycle than demonstrated need | Best reuse/startup trade-off | Simpler packaging, greater long-term duplication |

## 7. Recommended architecture

Adopt **B, subject to approval**, with one data contract and one supported standard package engine initially. Prefer **Microsoft.PowerShell.PSResourceGet** for the provider spike: it offers explicit repository/scope/version installation, matches Nova's publishing engine and does not depend on a prior `Install-Module` receipt in the same manner as `Update-Module`. Do not declare a minimum provider version or fallback order until tests establish them. PowerShell 7.4 is a runtime requirement, not proof that a compatible package-engine command is discoverable in every environment. [M1-M3]

Keep the pure planner separate from I/O and package-engine capability detection. The approved plan is authoritative: installation must not silently recompute "latest", switch provider/repository, widen a version constraint or downgrade. Prefer side-by-side installation for a different numeric version; never delete the working old version as part of routine update.

Suggested central **source-component** repository name: `PowerShellSelfUpdate.Source` (proposal only; name availability not checked).

```text
PowerShellSelfUpdate.Source/
  src/                     # pure policy and, after proof, standard provider adapter
  tests/                   # deterministic component and isolated provider contracts
  integration/             # minimal consumer fixtures, no Gerber/Nova private calls
  docs/                    # contract, support matrix, recovery and adoption
  component.json           # proposed version/provenance/distribution metadata
  LICENSE
```

These paths and the metadata file are proposals, not an existing framework or files created by this task. Preserve Nova's MIT copyright/permission notices for reused substantial source; consumer packaging must carry the required notice. Source extraction permissions and final component ownership/license should be confirmed rather than inferred solely from Gerber's proprietary product model. [N18]

A separate shared **module** is not recommended now. If Option A is approved later, `PSModuleSelfUpdate` is a possible module name, with `project.json`, `src/public/`, `src/private/`, mirrored `tests/` and command help following the discovered project toolchain. Name availability is unverified; do not reserve, publish or scaffold it during G-4A0.

## 8. Proposed API and behavior contract

### Public versus internal surface

**Option B adds no shared exported PowerShell commands.** There is no `Register-ModuleSelfUpdate`, persistent registration database, globally selected consumer or automatic discovery of all modules. Consumer wrappers construct a self descriptor on each invocation and call privately incorporated operations.

Use two logical operations, with actual private names mapped to each consumer's namespace. The following signatures are design notation, not implemented commands or executable instructions:

```text
Get-ModuleSelfUpdatePlan -Request <SelfUpdateRequest> -> SelfUpdatePlan
Invoke-ModuleSelfUpdate -Plan <SelfUpdatePlan>       -> SelfUpdateResult
```

The query operation does capability/installed-state/source discovery and invokes an internal pure planner. The invoke operation revalidates the exact target and preconditions, supports `ShouldProcess` at the mutation boundary, coordinates this updater's lock, delegates installation and verifies disk state. It does not prompt through a custom callback, reload the product or save configuration.

If a runtime module is later selected, these two operations can become its public API, with a specific noun/prefix chosen then. A registration operation would add mutable global state without solving a demonstrated requirement.

### Declarative consumer input

| Input | Ownership and purpose |
| --- | --- |
| `ContractVersion` | Small schema version, reject unsupported values rather than guess |
| `ModuleName`, `ModuleGuid` | Exact self identity from consumer-owned metadata; reject wildcard/empty/multiple targets; GUID helps reject wrong packages but is not proof of publisher authenticity |
| `ActiveVersion`, `ActiveModulePath` | Active manifest base version plus prerelease label and actual path; never infer these from cwd |
| `RepositoryName`, expected source URI | Explicit allowlisted package source; compare registered endpoint as well as display name |
| `Channel` | `Stable` or `IncludePrerelease`; the latter permits stable too, not preview-only |
| Optional supported version constraint | Only if the consumer needs a real compatibility limit; default newest eligible version greater than current, never an implicit downgrade |
| `Scope` | Explicit supported scope; proposed ordinary self-update policy is CurrentUser, with AllUsers/ambiguous/development cases requiring a clear decision |
| Lookup timeout | Bounded discovery policy; distinct from installation timeout/cancellation |

Supply effective values, not full Gerber/Nova configuration objects. The engine inspects installed candidates independently; caller-supplied active version is not sufficient proof that a target is installed. Notification frequency and persistence remain outside this input.

Confirmation behavior is consumer-owned: the request's channel records prerelease eligibility, not consent to install. Gerber's interactive wrapper asks once about the exact proposed action; a later public scripting wrapper uses native `ShouldProcess` and explicit automation inputs. Neither stores an `Approved = true` flag as a reusable authorization token.

Do not add callbacks for name, version, source, channel, prompting or preferences. Both known consumers can supply those as data. The one standard provider adapter is implementation detail, not a plugin/provider SDK. If a third consumer proves a materially different installation strategy necessary, define an explicit strategy identifier and separately tested contract then; unsupported manual/custom deployments currently return actionable guidance instead of invoking arbitrary install scriptblocks.

### Plan, result, errors and idempotency

Plans identify `ContractVersion`, component/provider version, exact module identity, active and observed installed versions/paths, exact target including prerelease, source name/URI, destination scope, channel, reason and disposition. Dispositions distinguish `UpdateAvailable`, `UpToDate`, `AlreadyInstalledRestartRequired` and `ActionRequired`. Network or provider failure is not `UpToDate`.

Results distinguish `Installed`, `AlreadyInstalled`, `Cancelled`, `WhatIf` and `ActionRequired`, with `VerifiedInstalledVersion`, `InstalledPath`, unchanged `ActiveVersion`, `RestartRequired` and safe recovery guidance. Do not set success solely because an installer returned. Plans/results contain no credentials.

An explicitly requested failure uses a terminating structured `ErrorRecord` with stable component error identifiers, relevant category/target, preserved safe inner diagnostics and observed partial-state data when available. Separate invalid request, unsupported provider, source mismatch/untrusted repository, lookup timeout/offline, permission, conflict, package identity mismatch and verification failure. Product wrappers translate these into Gerber/Nova messages. Optional background notifications may suppress visible warnings, but should retain diagnostic status; they must not convert failed discovery into "no update".

Reapplying a plan inspects the target again under the lock. If the exact healthy target exists in the intended scope, do not reinstall: return `AlreadyInstalled`, possibly with restart required. If active state, source endpoint, identity, destination or policy changed, require a fresh plan/confirmation. A newer release appearing does not authorize changing the target. Do not silently repair an existing suspect directory with reinstall/force; use the documented explicit repair path.

`-WhatIf` permits read-only discovery/validation but no install, repository trust changes, dependency bootstrap, configuration writes or repair. Discovery can fail offline and must say so. Product-specific cancellation and native confirmation remain distinct from repository trust or license authorization.

## 9. Consumer integration model

```text
Consumer entry point
  -> read/validate consumer configuration and active module metadata
  -> private component: capability check, installed/source discovery, plan
  -> consumer: show exact action, ask for consent or apply scripting semantics
  -> private component: revalidate, lock, exact standard install, verify
  -> consumer: render installed/active distinction and restart/recovery guidance
```

Gerber owns `updates` preferences in its existing user configuration; Nova keeps its existing settings path and notification commands. A proposed Gerber section is `updates.channel: "stable"`; optional notification settings should only be added when notification behavior is approved. Repository identity should come from consumer-approved deployment configuration, not an arbitrary terminal argument or project resource.

Reading or checking must not create settings. A one-time preview selection must not silently change the persistent channel. Validate actual Booleans/enums, preserve unrelated ADO/plugin settings and reject corrupt input with recovery guidance. Gerber's existing atomic writer can be reused; do not replace it with Nova's settings helper or pretend it prevents concurrent read-modify-write conflicts.

The same source-component revision and contract tests are used in both products, but defaults need not match: preserving Nova's existing prerelease preference does not require Gerber to default to prerelease.

## 10. Update-engine bootstrap and self-update strategy

### Recommended build-time lifecycle

There is **no separately installed update engine to update**. Its version is recorded in the consumer artifact; installing a newer Gerber/Nova version also installs that consumer's newer component. Existing installed consumers keep their packaged component until deliberately updated. No engine calls back into Nova to update itself, and no circular runtime dependency exists.

If the embedded component is outdated, unavailable because the product installation is damaged, or incompatible with the available package engine, ordinary package commands in a clean PowerShell session remain the independent repair path. Document exact consumer name/version/source/scope and install a known-good package through a supported provider. Do not require the broken `/update` path or a working private source checkout for recovery.

Check provider command/module version and required parameters when `/update` is invoked, not at Core startup. If missing/incompatible, explain the requirement and provide ordinary manual provider installation/update guidance. Do not auto-install/update/trust a provider during a normal availability check. An explicit opt-in dependency setup flow would be a later product decision, separate from installing Gerber.

### If a runtime engine is chosen later

Load only a compatible, explicitly selected engine version lazily. Missing, corrupt or incompatible engine state disables self-update with actionable repair guidance, not Gerber's other commands. Default to ordinary administrator/user-initiated engine installation; **no automatic engine self-update** and no implicit "upgrade engine, retry consumer" chain.

The engine could be updated as an ordinary module in a fresh session. It must never be its own mandatory recovery tool. Consumer-to-engine dependencies must not be mirrored by engine-to-consumer dependencies, and incompatible major engine versions cannot be resolved by silently choosing latest.

## 11. Security and failure recovery

This is a threat/reliability design assessment, not an executed vulnerability audit or proof of authentic packages.

| Concern | Required boundary or recovery policy |
| --- | --- |
| Trusted source | Bind exact module name and approved repository endpoint in discovery and install. Detect a registered repository name pointing elsewhere. Never search every registered feed or fall back to another source after failure. |
| Repository trust | Registration/trusted flags indicate package-manager consent, not cryptographic publisher identity. Do not register feeds, mark them trusted or suppress trust prompts automatically. Return an action-required state for explicit user setup when needed. |
| Integrity/authenticity | Use standard provider download/integrity handling; exact versions and HTTPS do not establish publisher authenticity or immutable content. GUID/name checks reject identity mistakes, not malicious impersonation. Do not claim cross-platform signature verification; PSResourceGet's documented Authenticode option is Windows-only. Any stronger publisher policy requires separate design. |
| Supply chain | Pin component source and review refreshes; preserve license/provenance. Preview transitive package dependencies where the provider can expose them and keep source policy explicit. No raw download-and-execute scripts or cwd-overridable updater resources. |
| Consent/license | Approval concerns one exact Core/tool update, not trust-policy changes, license acceptance, arbitrary modules or provider repair. Never equate `-Confirm:$false`, force/reinstall or channel opt-in with all these permissions. Fail rather than hang on unexpected provider prompts in noninteractive use. |
| Permissions/scope | Proposed normal flow is explicit CurrentUser with no auto-elevation. AllUsers, redirected/custom paths and mixed installations require an explicit supported policy; never silently shadow AllUsers with a user copy or change scope after denial. |
| Interrupted install | Keep existing working versions; delegate package staging to the standard provider. On failure, inspect and report observable target state; do not assert atomic rollback. Do not remove uncertain/user-owned directories automatically. |
| Partial/broken target | Verify manifest identity, full version, location and available provider provenance. A successful disk check is not proof of successful runtime import; where needed use an isolated fresh-host smoke test. If verification fails, report failure and the exact suspect target, with manual repair guidance. |
| Same-directory replacement | Detect destination collisions, especially same-base prerelease transitions. Do not assume side-by-side recovery. Initially defer unsafe in-use replacement to an explicitly requested ordinary install after exiting affected PowerShell sessions; do not add a background privileged worker. Provider behavior must be proven before allowing more. |
| Concurrency | A per-user/module/destination cross-process lock can serialize this component's attempts; recheck inside it and release on exit/crash using OS-supported ownership. It cannot lock out unrelated external package commands. Detect changed state and fail clearly; never claim a machine-wide transaction. |
| Failed new version | Preserve known-good different-version installs. Document fresh-session import by exact known-good manifest path; a base-version-only selector can be ambiguous for prereleases. Do not automatically delete the new version or roll back user configuration. |
| Network/offline | Bound lookup and distinguish timeout, unavailable feed and authentication/proxy errors. No failed check should appear as up-to-date. Offline use of the rest of Gerber remains unaffected; no stale cached plan may authorize a different install. |

Installing Gerber Core may still install its declared package dependencies through the standard provider; "Core only" means no independent plugin/module inventory upgrade, not bypassing required dependency resolution. Gerber's inspected `RequiredModules` is empty, but future dependencies must not be hidden. PSResourceGet documentation notes a NuGet v3 dependent-resource limitation; PSGallery-oriented support must not be generalized to arbitrary private feeds without testing. [M2]

**Rollback level proposed for first delivery:** retained known-good versions plus documented manual repair, not transactional automatic rollback. This limitation must be approved. Same-base previews may have no retained copy; the safest initial behavior is to defer that install, not promise recovery the package layout cannot provide.

## 12. Cross-platform considerations

Both project manifests target **PowerShell 7.4**. No Windows PowerShell 5.1 compatibility is proposed. Existing use of `[semver]` fits the stated runtime but does not prove arbitrary Gallery/NuGet version forms are accepted by both providers.

| Platform | Architectural expectation | Verification still required |
| --- | --- | --- |
| Windows | CurrentUser avoids ordinary administrative install requirements; AllUsers generally requires elevation. Imported assemblies/files can block replacement. Configuration uses APPDATA. | Actual supported provider versions, in-use file behavior, access denied, same-base previews, side-by-side install and fresh-session activation on PowerShell 7.4 |
| macOS | Standard provider scope/module path discovery; user configuration follows XDG/HOME. No Windows-only credential or elevation assumptions in updater. | Package install/recovery, path precedence, case-sensitive volume behavior, interrupted/locked operation and fresh-session activation |
| Linux | Same portable contract and XDG/HOME configuration; headless updates must not prompt. | Provider availability, filesystem permissions, custom PSModulePath, no-TTY behavior, interruption/recovery and fresh-session activation |

Never construct module installation paths from these config paths or hardcode a Windows Documents layout. Resolve actual provider destinations and module search paths, and report path precedence: installing a version does not guarantee the next import selects it if another path is earlier or a profile explicitly imports an old path.

On Unix, being able to replace a file does not make an imported module hot-swap safe. Existing functions, scriptblocks, assemblies and plugin contexts can remain old in memory; lazily read resources can become new on disk. Use an explicit fresh-session activation boundary on all platforms, not automatic `Import-Module -Force` while Gerber is executing.

**Verified here:** source/manifests express the runtime target and use cross-platform configuration branches; Microsoft documents the standard provider mechanisms. **Unverified here:** live updater behavior on every OS, including macOS. Historical manual Gerber/credential validations are not evidence for package updates.

## 13. Migration strategy for NovaModuleTools

Nova can adopt the component without losing its intended capabilities: stable/prerelease discovery, preference commands, build/scaffold notifications, cmdlet/CLI initiation, preview/confirmation, errors and result presentation all remain possible.

This is not a drop-in migration guarantee. Deferring same-directory preview replacement or rejecting ambiguous/manual/AllUsers installations would restrict currently attempted operations. Approve those restrictions explicitly or prove safe support before cutover; do not label that behavior change as extraction-only compatibility.

Keep Nova-specific entry points, alias, preference path and stored Boolean, CLI route/help, branded errors/output, release-notes presentation and notification hooks in Nova. Replace generic policy/discovery/install internals behind those boundaries. Preserve the existing observable result fields through explicit mapping where they are supported contracts; improved exact-target/result verification can add state without treating old `Updated = true` behavior as correctness.

Migration steps:

1. Run sufficient existing characterization tests against unchanged Nova before restructuring. Add missing characterization of current result/CLI/preference behavior and record deliberate defect fixes separately.
2. Introduce the shared request/plan boundary without changing public names, aliases or preference meaning. Do not make Nova settings a dependency of the component.
3. Remove updater resource resolution through cwd/project paths. Add a permanent regression proving a project-local lookup resource cannot replace packaged self-update code.
4. Adopt the proven package adapter with explicit source, scope and exact version. A PowerShellGet-to-PSResourceGet change needs tests of existing PowerShellGet-installed packages, repository-store differences, prerelease metadata and package provenance; do not silently fallback after an error.
5. Report installed versus loaded versions, restart requirements and newly installed release notes accurately. Separate metadata-display failure from a verified installation result.
6. Update Nova README, cmdlet help, CLI help and versioning/update guide. Preserve notification default/confirmation behavior unless product approval explicitly changes it.

Compatibility risks include default prerelease eligibility, notification preference semantics, double confirmation, plan fields consumed by scripts, source-built/local installs, scope changes, provider bootstrap and preview folder collisions. Fixing these can change public behavior even if the extraction itself is internal.

Required regression scenarios include current stable/preview/no-update/cancel/`-WhatIf`; enabled/disabled preference and malformed settings; loaded-old/newer-already-installed; stable greater than preview; exact target unchanged after another release appears; explicit source mismatch; provider missing; legacy installation provenance; scope permission failure; partial install; repeat/concurrent attempts; post-install notes failure; and fresh-session activation. Preserve existing assertions through green-to-green refactoring; intentional fixes need separately observed red-to-green tests.

## 14. Integration strategy for Gerber

### Interactive slash-command surface

Add `/update` later as a Core-owned registry entry using the normal definitions, discovery/help and dispatch. It fixes its target to **Gerber**, not an argument identifying any module. It does not update Gerber.ExampleOrg, other plugins or Nova. No Plugin API addition is needed.

Proposed interaction:

1. Show "Checking for Gerber updates" with current full version, chosen channel and source; bounded lookup must not freeze the UI indefinitely.
2. Report up-to-date, unavailable, action-required, or exact candidate distinctly. If already installed but old code is active, offer restart guidance without installing again.
3. Show active-to-target version, repository and destination scope plus prerelease/restart warnings in one install confirmation. Use the shared confirmation helper with **Cancel explicitly selected as default**; its generic default is currently action, so omitting this option would be unsafe. [G10]
4. Apply only that plan after confirmation. Show checking/installing/verifying phase status without invented percentages. User cancellation must not print success or claim rollback.
5. On success show "Gerber <target> installed. This session is still running <active>. Exit Gerber and start a new PowerShell session to use the update." Preserve the menu loop until the user exits; do not hot-reload Core or rebuild plugin contexts in place.
6. Recoverable errors stay within Gerber with a concise reason and actionable next step; continue/result views return to the root context rather than immediately triggering another install. Preserve local Esc, double-Esc-to-root and Ctrl+C/pipeline-stop semantics. During installation, cancellation support depends on the provider and must not promise a safe instant abort.

Use schema-version-1 user configuration, provisionally stable by default even when a preview is loaded. If no newer stable exists, say "No newer stable release" rather than silently downgrading. Prerelease eligibility requires explicit product policy/selection; a persisted preference change must be separate from consent to install. No automatic startup network lookup or update is recommended for initial G-4A.

Development `dist/`, manually copied modules and AllUsers installations need an explicit supported policy before apply; default to an actionable unsupported/deferred state rather than guessing the user's desired deployment. Core update preserves existing user config, plugin approvals and installed plugins. Plugin compatibility is re-evaluated by existing startup logic after restart; an update is not a guarantee that every plugin supports the new Core.

### PowerShell scripting surface

`Invoke-Gerber` is currently the interactive entry point, not a generic noninteractive update API. Do not overload it with invented Unix-style flags. A separate public Gerber update cmdlet is optional and requires approval; if added later, use named PowerShell parameters, native `ShouldProcess`, structured results/errors, generated command help and no hidden interactive prerelease/trust/license prompts in automation.

Nova retains its distinct existing cmdlet and `nova update` surfaces. The component's private contract is not itself a supported Gerber scripting API.

### UX design review and later acceptance

For the slash surface, this proposal addresses Atlassian's **Align with established conventions**, **Build help into the CLI**, **Show progress visually**, **Create a reaction for every action**, **Craft human-readable error messages**, **Support your skim-readers**, **Suggest the next best step**, **Consider your options**, **Provide an easy way out** and **Flags over args** through registry/help discovery, concise phases/results, explicit choices/cancel and a fixed self target rather than unlabeled positional module arguments.

For any future cmdlet surface, apply those ten principles separately: approved command/named parameters and `Get-Help`; `Write-Progress` and structured outcomes; actionable stable errors and restrained diagnostics; explicit scripting inputs, native preview/confirmation and standard cancellation. No CLI flag spellings belong in its parameter help.

Nielsen's **Visibility of system status**, **Match between the system and the real world**, **User control and freedom**, **Consistency and standards**, **Error prevention**, **Recognition rather than recall**, **Flexibility and efficiency of use**, **Aesthetic and minimalist design**, **Help users recognize, diagnose, and recover from errors**, and **Help and documentation** are addressed by the same explicit version/source/scope preview, shared Gerber UI, fixed target, separate installed/active language, concise recovery and contextual help.

Remaining UX risks are concrete: omitting default-Cancel violates **Error prevention/User control**; hot reload violates **Consistency/Visible status** by making "updated" ambiguous; silently swallowed lookup errors violate **Human-readable errors/Recovery**; duplicate install/prerelease confirmations impair **Efficiency/Minimalism**. Use the corrective flow above, while keeping unrelated trust/license decisions separate. These are design assessments, not verified rendering.

Later implementation must add mirrored Pester tests and permanent PTY scenarios for registry discovery/dispatch, plan/no-update, default Enter cancellation, Esc/double-Esc, exact confirmation, progress, restart messaging and recoverable failure. Run the tracked terminal gate and inspect current-run prompt traces for happy/cancel/error paths. No terminal behavior changed or tracer validation ran in G-4A0.

## 15. Risks and tradeoffs

| Risk/tradeoff | Consequence and mitigation |
| --- | --- |
| Component over-extraction | Sharing Nova UI/settings/resource behavior creates coupling. Start at explicit data contracts; move only proven common policy/adapter behavior. |
| Planner-only sharing becomes permanent | Most failure logic could remain duplicated. Make common adapter adoption a phase exit criterion, or explicitly decide independent implementations instead of claiming full engine reuse. |
| Source synchronization | Fixes are not live in existing consumers. Track component provenance and affected releases; publish consumer fixes deliberately. |
| New source repository overhead | Ownership, access and release/version discipline cost time. Approve them before creating infrastructure; use Option C only as an explicit fallback. |
| Provider migration | New engine can change metadata, trust, scope and dependency behavior. Verify against existing Nova installs and choose one supported initial engine. |
| Active/installed divergence | Users may think new code is already running. Always show both states and use a fresh-session boundary. |
| Same-base preview replacement | A version change may overwrite the active directory and erase the previous preview. Detect/defer until provider-specific behavior and recovery are proven. |
| Recovery limits | Retention/manual repair is not automatic rollback, and may not save same-base previews. Approve and document that limitation. |
| False authenticity confidence | Name, GUID, HTTPS, repository trust and exact version are not signatures. Keep claims bounded and revisit publisher policy separately. |
| Unverified platform assumptions | A cross-platform API is not an executed install matrix. Require isolated Windows/macOS/Linux evidence before release claims. |

README, contribution guidance, changelog and release notes were reviewed for consistency. They remain unchanged: this report introduces no supported command, configuration field or release behavior. `PLAN.md`, `ARCHITECTURE.md` and `DECISIONS.md` are evidence inputs, not silently rewritten approvals.

## 16. Proposed implementation phases

These are follow-on proposals, not permission to execute them.

| Phase | Deliverable | Exit evidence |
| --- | --- | --- |
| 0. Product approval | Choose B/ownership, provider candidate, channels, provenance/scope and recovery boundary | Decisions in section 17 resolved or explicitly deferred with consequences; no infrastructure created by assumption |
| 1. Characterize and spike | Existing Nova behavior baseline plus disposable standard-provider experiments | Green pre-refactor behavior tests; isolated exact-version/source/scope, imported-module, same-base-preview, provider-version and recovery results on PowerShell 7.4 |
| 2. Shared planning component | Pinned source, license/provenance, deterministic contract and minimal consumer fixtures | Shared contract tests and namespace/co-import/build tests; no runtime dependency or registration store |
| 3. Common provider adapter and Nova adoption | Proven common install/verification boundary; preserve Nova public wrappers/preferences | Test-first fixes, green-to-green migration evidence, explicit compatibility notes and exact-target verification; no duplicate permanent installer implementations |
| 4. Gerber G-4A | Core-only `/update`, existing configuration/UI integration and restart guidance | Focused tests, built-module integration, isolated install checks, PTY inventory/coverage, current-run happy/cancel/error traces |
| 5. Release qualification | Supported provider/platform matrix and manual repair documentation | Required consumer quality loops, zero ScriptAnalyzer findings, applicable CodeScene 10.0 evidence, validated packaging/help, and isolated recovery evidence |

Do not update a developer's real module store to supply test evidence. Use test-owned repositories/module paths and disposable hosts; controlled live publication/install experiments require separate authorization. Component unit tests use deterministic data; adapter tests model network/timeouts/trust/permissions, target races, process interruption and concurrent attempts. Package tests prove the code and provenance metadata are actually included in both delivered consumers.

## 17. Open decisions requiring product-owner approval

| Decision | Recommended default | Approval consequence |
| --- | --- | --- |
| Reuse architecture | B: pinned shared source, not a separately installed runtime module | Approves a later component project/distribution mechanism; does not approve creating it now |
| Ownership/license/distribution | One maintained source repository with versioned, reviewed consumer refreshes; preserve MIT notices | Assign maintainers and adoption/security-fix responsibility before extraction |
| Package engine/minimum | Spike PSResourceGet first; select a tested minimum, no silent fallback | Determines bootstrap guidance and Nova migration compatibility |
| Gerber default channel | Stable; preview explicitly selected; no downgrade | Decide whether preview installs should track preview by default and whether channel changes persist |
| Nova compatibility | Keep existing preference commands/path/meaning initially | Separately approve prerelease-default, corrupt-settings and confirmation changes |
| Exact target/source | Install only the approved exact release from the approved endpoint | Fixes current Nova plan/apply mismatch; affects tests and error behavior |
| Scope and provenance | Explicit CurrentUser for supported user installs; block/defer AllUsers, mixed, source/dist or manual cases until policy is defined | Decide whether to preserve scope or permit an explicitly previewed user-scope override; never silently shadow |
| In-use/same-base replacement | Do not hot-reload; defer unsafe same-directory writes to a separate ordinary install after affected sessions exit | A preview update may require an out-of-session manual step; decide whether later automation is warranted |
| Recovery guarantee | Keep different known-good versions; manual repair, no automatic rollback | Accept limits for partial updates and preview directory reuse or fund a separately scoped stronger design |
| Public scripting API | No new exported Gerber cmdlet required for initial slash workflow | Approve separately if automation is a product requirement |
| Notifications | No new Gerber startup checks or automatic installs | Any opt-in check cadence/cache is separate scope; Nova retains its existing triggers |
| Trust/license/publisher policy | No silent trust changes, broad acceptance flags or claimed cross-platform signing guarantee | Decide explicit setup UX and whether stronger authenticity verification is a release prerequisite |
| Major-version policy | No implicit downgrade; decide permitted upgrade ceiling explicitly | Determines whether future incompatible Core/plugin API major updates need extra policy |

**Stop condition:** G-4A0 delivers this evidence-backed recommendation. No implementation phase starts until the applicable decisions are approved.

## Appendix A. Source evidence

Paths are relative to the named repository. Links to Nova use the inspected sibling checkout; the revision above is the reproducibility anchor. Line ranges identify the inspected source, not permanent anchors across future edits.

### NovaModuleTools

| ID | Source and relevant location |
| --- | --- |
| N1 | [Public update command](../../../NovaModuleTools/src/public/UpdateNovaModuleTools.ps1), lines 1-23: singular function, alias, prerelease consent, `ShouldProcess`, workflow |
| N2 | [Self-update helper](../../../NovaModuleTools/src/private/update/InvokeNovaModuleSelfUpdate.ps1), lines 1-10; [package command adapter](../../../NovaModuleTools/src/private/update/InvokeNovaModuleUpdateCommand.ps1), lines 1-26 |
| N3 | [Workflow context](../../../NovaModuleTools/src/private/update/GetNovaModuleSelfUpdateWorkflowContext.ps1), lines 1-46 |
| N4 | [Planner](../../../NovaModuleTools/src/private/update/GetNovaModuleSelfUpdatePlan.ps1), lines 1-20; [plan conversion](../../../NovaModuleTools/src/private/update/ConvertToNovaModuleSelfUpdatePlan.ps1), lines 1-90; [stable eligibility](../../../NovaModuleTools/src/private/update/TestNovaStableUpdateAvailable.ps1), lines 1-9; [prerelease eligibility](../../../NovaModuleTools/src/private/update/TestNovaPrereleaseUpdateAvailable.ps1), lines 1-20 |
| N5 | [CLI routing](../../../NovaModuleTools/src/private/cli/InvokeNovaCliCommandRoute.ps1), update route/confirmation; [CLI invocation context](../../../NovaModuleTools/src/private/cli/GetNovaCliInvocationContext.ps1), lines 38-84; [build workflow](../../../NovaModuleTools/src/private/build/InvokeNovaBuildWorkflow.ps1), lines 41-43; [initialization](../../../NovaModuleTools/src/private/scaffold/GetNovaModuleInitializationWorkflowContext.ps1), lines 8-12; [notification](../../../NovaModuleTools/src/private/update/InvokeNovaModuleUpdateNotification.ps1); [safe notification wrapper](../../../NovaModuleTools/src/private/update/InvokeNovaModuleUpdateNotificationSafely.ps1) |
| N6 | [Preference reader](../../../NovaModuleTools/src/private/update/ReadNovaUpdateNotificationPreference.ps1); [writer](../../../NovaModuleTools/src/private/update/WriteNovaUpdateNotificationPreference.ps1); [status](../../../NovaModuleTools/src/private/update/GetNovaUpdateNotificationPreferenceStatus.ps1); [settings path](../../../NovaModuleTools/src/private/update/GetNovaUpdateSettingsFilePath.ps1); [shared settings directory](../../../NovaModuleTools/src/private/shared/GetNovaSettingsDirectoryPath.ps1); [JSON I/O](../../../NovaModuleTools/src/private/shared/InvokeNovaJsonFile.ps1), lines 7-38; [reader tests](../../../NovaModuleTools/tests/private/update/ReadNovaUpdateNotificationPreference.Tests.ps1), string-Boolean case at lines 30-34 |
| N7 | [Active-module version](../../../NovaModuleTools/src/private/update/GetNovaInstalledModuleVersionInfo.ps1), lines 1-15; [PSData access](../../../NovaModuleTools/src/private/shared/GetNovaModulePsDataValue.ps1); [CLI installed version](../../../NovaModuleTools/src/private/cli/GetNovaCliInstalledVersion.ps1) |
| N8 | [Lookup](../../../NovaModuleTools/src/private/update/InvokeNovaModuleUpdateLookup.ps1); [lookup resource resolution](../../../NovaModuleTools/src/private/update/GetNovaModuleUpdateLookupScript.ps1); [runspace timeout](../../../NovaModuleTools/src/private/update/InvokeNovaPowerShellScriptWithTimeout.ps1), lines 1-35; [executed resource](../../../NovaModuleTools/src/resources/update/ModuleUpdateLookup.ps1.txt), lines 1-68 |
| N9 | [Prerelease confirmation](../../../NovaModuleTools/src/private/update/ConfirmNovaPrereleaseModuleUpdate.ps1); [prompt](../../../NovaModuleTools/src/private/update/GetNovaPrereleaseModuleUpdateConfirmationPrompt.ps1); [CLI update argument parser](../../../NovaModuleTools/src/private/cli/ConvertFromNovaUpdateCliArgument.ps1) |
| N10 | [Update workflow](../../../NovaModuleTools/src/private/update/InvokeNovaModuleSelfUpdateWorkflow.ps1), lines 1-75 and result rendering/next-step functions |
| N11 | [Release-notes URI](../../../NovaModuleTools/src/private/shared/GetNovaModuleReleaseNotesUri.ps1); [project info command](../../../NovaModuleTools/src/public/GetNovaProjectInfo.ps1), lines 19-22; [cmdlet update help](../../../NovaModuleTools/docs/NovaModuleTools/en-US/Update-NovaModuleTools.md); [versioning guide](../../../NovaModuleTools/docs/versioning-and-updates.html), update section; [README](../../../NovaModuleTools/README.md), lines 112-151; [CLI update help](../../../NovaModuleTools/src/resources/cli/help/update.psd1) |
| N12 | [Project metadata](../../../NovaModuleTools/project.json), version, runtime and required modules |
| N13 | [Get preference](../../../NovaModuleTools/src/public/GetNovaUpdateNotificationPreference.ps1); [Set preference](../../../NovaModuleTools/src/public/SetNovaUpdateNotificationPreference.ps1); [preference context](../../../NovaModuleTools/src/private/update/GetNovaUpdateNotificationPreferenceChangeContext.ps1); [preference workflow](../../../NovaModuleTools/src/private/update/InvokeNovaUpdateNotificationPreferenceChange.ps1) |
| N14 | [Publish workflow](../../../NovaModuleTools/.github/workflows/Publish.yml), stable lines 64-75 and prerelease lines 144-158; [repository registration action](../../../NovaModuleTools/.github/actions/ensure-psresource-repository/action.yml); [publish adapter](../../../NovaModuleTools/src/private/release/InvokeNovaRepositoryPublishCommand.ps1); [built-module publication](../../../NovaModuleTools/src/private/release/PublishNovaBuiltModuleToRepository.ps1) |
| N15 | [Update unit tests](../../../NovaModuleTools/tests/private/update/); [public unit tests](../../../NovaModuleTools/tests/public/UpdateNovaModuleTools.Tests.ps1); [public integration tests](../../../NovaModuleTools/tests/public/UpdateNovaModuleTools.Integration.Tests.ps1); [architecture guardrails](../../../NovaModuleTools/tests/ArchitectureGuardrails.Tests.ps1), lines 75-80 |
| N16 | [Resource path selection](../../../NovaModuleTools/src/private/shared/GetResourceFilePath.ps1), lines 7-33 |
| N17 | [Module assembly](../../../NovaModuleTools/src/private/build/BuildModule.ps1), lines 7-28 |
| N18 | [MIT license](../../../NovaModuleTools/LICENSE) |

The complete inspected `src/private/update/` domain consists of these files; related public/CLI/build/resource/shared files are linked above:

| Area | File basenames, all `.ps1` |
| --- | --- |
| Planning/version | `GetNovaInstalledModuleVersionInfo`, `GetNovaAvailableSemanticVersion`, `TestNovaStableUpdateAvailable`, `TestNovaPrereleaseUpdateAvailable`, `GetNovaModuleSelfUpdatePlan`, `ConvertToNovaModuleSelfUpdatePlan` |
| Discovery | `GetNovaModuleUpdateLookupScript`, `InvokeNovaModuleUpdateLookup`, `InvokeNovaPowerShellScriptWithTimeout` |
| Apply/workflow/consent | `GetNovaModuleSelfUpdateWorkflowContext`, `InvokeNovaModuleSelfUpdate`, `InvokeNovaModuleUpdateCommand`, `InvokeNovaModuleSelfUpdateWorkflow`, `ConfirmNovaPrereleaseModuleUpdate`, `GetNovaPrereleaseModuleUpdateConfirmationPrompt` |
| Preferences | `GetNovaUpdateSettingsFilePath`, `ReadNovaUpdateNotificationPreference`, `WriteNovaUpdateNotificationPreference`, `GetNovaUpdateNotificationPreferenceStatus`, `GetNovaUpdateNotificationPreferenceChangeContext`, `InvokeNovaUpdateNotificationPreferenceChange` |
| Notifications | `InvokeNovaModuleUpdateNotification`, `InvokeNovaModuleUpdateNotificationSafely`, `WriteNovaAvailableModuleUpdateWarning` |

### Gerber

| ID | Source and relevant location |
| --- | --- |
| G1 | [Roadmap](../../PLAN.md); [architecture baseline](../../ARCHITECTURE.md); [decisions](../../DECISIONS.md), especially D-001, D-002, D-007, D-012-D-014 |
| G2 | [Project metadata](../../project.json), name/version, GUID, PowerShellHostVersion and empty RequiredModules |
| G3 | [Core command definitions](../../src/private/cli/Get-GerberCoreCommandDefinitionList.ps1); [public entry point](../../src/public/Invoke-Gerber.ps1) |
| G4 | [Registry initialization](../../src/private/cli/Initialize-GerberCommandRegistry.ps1), lines 1-46; [handler dispatch](../../src/private/cli/Invoke-GerberRegisteredCommand.ps1); [menu/error control](../../src/private/cli/Invoke-GerberMenuLoopIteration.ps1) |
| G5 | [Current-version helpers](../../src/private/cli/Initialize-GerberCommandRegistry.ps1), lines 68-116 |
| G6 | [Configuration reader](../../src/private/config/Get-GerberUserConfiguration.ps1); [validator](../../src/private/config/Test-GerberUserConfiguration.ps1); [writer](../../src/private/config/Save-GerberUserConfiguration.ps1); [path resolution](../../src/private/config/Resolve-GerberUserConfigPath.ps1) |
| G7 | [Save tests](../../tests/private/config/Save-GerberUserConfiguration.Tests.ps1); [configuration validation tests](../../tests/private/config/Test-GerberUserConfiguration.Tests.ps1) |
| G8 | [Plugin tooling consent](../../src/private/plugins/Confirm-GerberPluginDevelopmentTool.ps1); [plugin creation guide](../plugins-create.md) |
| G9 | [Plugin API reference](plugin-api-v1-capabilities.md); [safe manifest discovery](../../src/private/plugins/Get-GerberPluginManifestMetadataList.ps1); [plugin import/version check](../../src/private/cli/Add-GerberPluginToRegistryBuilder.ps1), lines 111-157 |
| G10 | [Shared confirmation prompt/options](../../src/private/cli/Read-GerberConfirmationPrompt.ps1); [README](../../README.md); [entry-point help](../Gerber/en-US/Invoke-Gerber.md) |
| G11 | [Copilot instructions](../../.github/copilot-instructions.md); [repository conventions](../../.github/instructions/repository-conventions.instructions.md); [contribution guide](../../CONTRIBUTING.md); [PR template](../../.github/pull_request_template.md); [quality wrapper](../../run.ps1); [formatting check](../../scripts/build/Test-TextFileFormatting.ps1) |

### Standard PowerShell mechanisms

Microsoft documentation consulted on 2026-10-22; documentation is not a substitute for the isolated provider matrix:

- **M1:** [Update-Module, PowerShellGet 2.x](https://learn.microsoft.com/en-us/powershell/module/powershellget/update-module?view=powershellget-2.x): installation provenance, exact version, scope and standard confirmation.
- **M2:** [Install-PSResource](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/install-psresource?view=powershellget-3.x): explicit repository/version/scope, no automatic import, reinstall, trust/license switches, Windows-only Authenticode and NuGet v3 dependency limitation. Newer preview-only options are not assumed available on the eventual minimum provider.
- **M3:** [Find-PSResource](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/find-psresource?view=powershellget-3.x): stable/prerelease discovery and repository behavior.
- **M4:** [Prerelease module versions](https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support?view=powershellget-2.x): manifest prerelease metadata and PowerShellGet same-base-version directory overwrite behavior.

## Appendix B. Validation and scope record

| Check | Status and evidence |
| --- | --- |
| Repository investigation | **Passed:** actual Nova lifecycle, tests/docs, Gerber infrastructure and all three required architecture alternatives inspected; relevant source paths recorded above |
| Report completeness | **Passed:** all 17 required decision-report topics are included, with proposed behavior separated from current implementation and approval decisions left open |
| Markdown/source references | **Passed:** document checks confirmed all 17 numbered sections, balanced language-tagged fences, no trailing whitespace and existence of all 84 local source links; this is not runtime validation |
| Repository formatting wrapper | **Passed:** `pwsh -NoLogo -NoProfile -File ./scripts/build/Test-TextFileFormatting.ps1 -ProjectRoot ./docs/architecture` confirmed exactly one trailing newline and no extra blank lines for that documentation scope |
| Existing behavior tests/platform updates | **Unverified:** not executed for this investigation; no claims of current passing tests or successful real updates |
| ScriptAnalyzer/build/Pester/PTY/tracer | **Not applicable to this prose-only change:** no executable source, command help, tested code examples or runtime behavior changed; later implementation gates are specified above |
| CodeScene | **Not applicable to prose:** no supported code file changed and no commit/PR proposed; no Code Health score or safeguard success is claimed |
| Other docs/release metadata | **Passed:** README, CONTRIBUTING, CHANGELOG and RELEASE_NOTE reviewed; unchanged because no supported API/workflow/release behavior is introduced |
| Guidance limitation | The indexed `.github/instructions/documentation.instructions.md` is absent in this checkout; available shared documentation-separation guidance and the project Markdown skill were used. No missing guidance file was created. |
| Write scope | **Passed:** content hashes for all 39 pre-existing modified/untracked Gerber files were preserved, only this report was added, and NovaModuleTools remained clean. No production code or other repository was modified. No implementation, dependency install, pipeline edit, commit, push, tag, publish or release was performed. |
