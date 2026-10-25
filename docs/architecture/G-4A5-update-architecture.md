# G-4A5 - Authoritative runtime dependency and update architecture

**Status:** Current project-owner architecture contract, amended by **G-4A7R**:
permanent PSGallery-only Core distribution; G-4A9 plugin updates remain planned.
Core channel selection is amended by the approved `/update policy` design:
Stable remains the default; IncludePrerelease is an explicit persisted opt-in.
Historical G-4A5/G-4A6/G-4A7 evidence is retained below.
**Date:** 2026-10-23; dependency clarification, source inspection and G-4A7/G-4A7R follow-up 2026-10-24.
**Authority:** This document and decision [D-017](../../DECISIONS.md) supersede the conflicting recommendations in [G-4A0](G-4A0-shared-self-update-analysis.md), [G-4A1](G-4A1-psmoduleupdate-design.md) and [G-4A2](G-4A2-psresourceget-provider-qualification.md), and explicitly amend the NovaModuleTools exclusion in D-002. Those reports and the original D-002 wording remain historical context; no other D-002 boundaries are removed.

## 1. Evidence labels

| Label | Meaning in this document |
| --- | --- |
| **Decided** | Explicit project-owner decision. |
| **Planned** | Decided direction, not implemented in Gerber. |
| **Source inspected (Gerber)** | Present or absent in the current source/artifact inspected 2026-10-24; not executed behavior qualification. |
| **Implemented (PMU)** | Present in the sibling PSModuleUpdate repository; not a statement about Gerber. |
| **Implemented (Gerber)** | Present in G-4A7 Core source; executed evidence and limits are stated separately. |
| **Verified** | Backed by executed evidence named alongside it. |
| **Unverified** | Expected or intended; no executed evidence. |

## 2. Statuses at a glance

| Item | Status |
| --- | --- |
| PSModuleUpdate (PMU) generic engine, `Get-PSModuleUpdate` / `Install-PSModuleUpdate` | Implemented (PMU); G-4A3 closed 2026-10-23 within its qualified scope (macOS, PowerShell 7.6.6, PSResourceGet 1.2.0) |
| PMU cross-platform CI (G-4A4) | Verified: the historical CI run (private evidence); six platform lanes (Windows x64, Linux x64, macOS ARM64, each on PowerShell 7.4 and stable), quality and ci-gate passed |
| Gerber `RequiredModules` | **Decided for both modules:** current PMU minimum is numeric `0.1.1` for mixed-layout installed-copy discovery; Nova remains `3.4.2`. PMU `0.1.1-preview` is not yet published; dependency bootstrap is a separate approved action. [G-4A6](G-4A6-runtime-dependency-qualification.md) remains historical `0.1.0` build/import evidence, not current deployment qualification |
| Plugin creation and Nova lifecycle integration | **Source inspected:** `/plugins create` stages Gerber templates and invokes Nova build/unit/integration validation before approval; local publication is a separate instructed step, not automatic creation behavior |
| Gerber Core startup check and `/update` | **Implemented (Gerber), G-4A7:** bounded notification-only startup probe and fresh Core discovery/confirmed installation through PMU. Mocked/disposable unit, built-module import and PTY evidence on macOS/PowerShell 7.4.21; no live-provider installation or Windows/Linux Gerber qualification |
| G-4A7R fixed Core repository | PSGallery-only binding and structured no-match presentation implemented; live PMU qualification blocked by installed-copy enumeration and provider-error classification limits documented in [Core updates](../core-updates.md#qualification-and-remaining-scope). Read-only PSResourceGet discovery found no Gerber package |
| Plugin update integration | **Planned**, after Core integration |
| Nexus | Unverified; protocol-compatibility expectation only |

**PMU CI success is evidence about PMU in isolation. It is not Gerber integration.** The G-4A4 run exercised PMU's own tests and qualification on six lanes; it did not load Gerber, run `/update`, or exercise Gerber configuration, credentials, plugins or terminal presentation.

The **historical G-4A5 inspection record** was read-only source inspection, not a runtime test: [project.json](../../project.json), [Core command definitions](../../src/private/cli/Get-GerberCoreCommandDefinitionList.ps1), [entry point](../../src/public/Invoke-Gerber.ps1), [registry initialization](../../src/private/cli/Initialize-GerberCommandRegistry.ps1) and [menu/startup rendering](../../src/private/cli/Show-GerberMenu.ps1). The then-existing `dist/Gerber/Gerber.psd1` had only `# RequiredModules = @()` and was not regenerated or imported during G-4A5; [G-4A6](G-4A6-runtime-dependency-qualification.md) subsequently used a disposable copy and preserved that artifact. G-4A7 normal Nova builds now refresh it. PMU API/CI statements above retain their previously recorded evidence, not new provider qualification.

## 3. Roles

```text
Gerber Core    owns CLI/UX, plugin creation workflows/templates, configuration,
               fixed PSGallery Core binding, per-plugin repositories/credentials,
               startup notification,
               /update, overview, confirmation, Core/plugin coordination, results,
               restart guidance, plugin approval/security
Gerber plugins own identity, version, behavior, optional approved metadata
NovaModuleTools provides module build/test/package/local publication for
               Gerber's plugin-development lifecycle
PMU            owns generic discovery, eligibility, exact install, verification,
               locking, rollback/recovery, structured outcomes
PSResourceGet  owns repository protocols, transport, provider authentication
```

| Owner | Responsibilities |
| --- | --- |
| **Gerber Core** | Both RequiredModules declarations; CLI commands/UX; plugin creation workflows/templates; startup update check; `/update`; Core and plugin update coordination and overview; fixed PSGallery Core binding and independent per-plugin repository association; application configuration; plugin credential acquisition and selection; user interaction and confirmation; result presentation; restart and activation guidance; plugin approval and security policy |
| **Gerber plugins** | Own module identity and version; functional behavior; any approved plugin-specific metadata Gerber requires; optional direct use of PMU for a legitimate standalone scenario |
| **NovaModuleTools** | Module development, build, test, packaging and local publication used by Gerber's plugin-development functionality; not the Gerber update engine |
| **PSModuleUpdate** | Repository-bound update discovery; version eligibility and selection; exact package installation; package verification; locking and concurrency; rollback and recovery; generic structured outcomes |
| **PSResourceGet** | Repository-provider operations; repository registration; package discovery and transport; provider-level authentication |

Gerber-specific responsibilities must not move into PMU, and PMU mechanics must not be duplicated inside Gerber. Nova builds/packages/publishes plugin projects; PMU discovers and installs eligible updates to installed modules. Local publication can copy a development build into a module directory, but that does not make it the update-management engine. Plugins are not required to implement discovery, version comparison, download, installation, locking or rollback. A plugin that consumes PMU directly uses the same engine; it is not a second update engine.

## 4. PSModuleUpdate: shared generic engine (Decided)

PMU stays independent of Gerber Core, Gerber plugins, NovaModuleTools, Azure DevOps or Nexus application logic, Gerber configuration, Gerber credential storage and Gerber terminal presentation. It has no per-vendor update engines and uses PSResourceGet for supported repository protocols.

Public surface (Implemented (PMU), per its help sources): `Get-PSModuleUpdate` creates a read-only exact-version plan; `Install-PSModuleUpdate` applies it. Planning takes either `-Repository <registered name>` or `-RepositoryUri <uri>` (mutually exclusive), an optional `-Policy` (`Channel`, `Scope`, `ExpectedRepositoryUri`, `VersionRange`; default Stable and CurrentUser) and an optional per-call `-Credential` (`PSCredential`, used in memory only). Plans never authorize a downgrade, never change repository silently, and carry no credentials.

## 5. Required runtime dependencies (Decided; declarations present)

- **Both NovaModuleTools and PSModuleUpdate must remain `RequiredModules`**, through `project.json` and Nova's generated manifest mechanism; no hand-written manifest.
- NovaModuleTools is required because Gerber exposes plugin development: Gerber creates the plugin project from its own templates and uses Nova for build/test validation, packaging and local publication workflows. It is not exclusively a development-time dependency of the Gerber repository.
- PMU is required because Gerber exposes integrated update management: automatic Core discovery checks at startup, manual fresh checks and confirmed Core installation through `/update`, and future plugin updates through that same command and engine.
- The G-4A1 recommendation not to add PMU to `RequiredModules`, and the G-4A0/G-4A1 goal of preserving Gerber operation when PMU is absent, are **rejected/superseded**. See section 11.
- If either required module is missing or incompatible, ordinary PowerShell dependency resolution may prevent Gerber from importing. This is accepted. Required availability does not mandate Nova build/package/publish operations during every startup.
- **Dependency availability is distinct from repository availability.** A failure to reach an update repository must never prevent an otherwise imported Gerber from starting and working normally.

Previously recorded integration constraints (not rechecked installed inventory or permanent compatibility guarantees): the PMU artifact was `0.1.0-preview` and PMU requires PSResourceGet 1.2.0.

### Current creation implementation (Source inspected; not re-executed)

The owner's `/create` terminology refers here to plugin creation, currently registered as **`/plugins create`**; no root `/create` alias exists. [The handler](../../src/private/cli/Invoke-GerberPluginsCreateCommand.ps1) checks [Nova availability](../../src/private/plugins/Confirm-GerberPluginDevelopmentTool.ps1), then invokes [transactional generation](../../src/private/plugins/New-GerberPluginProject.ps1). Gerber owns input, templates, staging, boundary checks, copied-registry validation and GUID approval. [Project validation](../../src/private/plugins/Test-GerberPluginProject.ps1) launches a child PowerShell process whose [validation script](../../src/resources/Test-GerberGeneratedProject.ps1) imports Nova and calls `Invoke-NovaBuild`, `Invoke-NovaTest` and `Test-NovaBuild`.

Creation does not invoke packaging or publication and does not leave the plugin installed/loaded. The completion screen and [creation guide](../plugins-create.md) instruct the user to run `Publish-NovaModule -Local` separately; templates also document `New-NovaModulePackage` for packaging. The existing handler's missing-tool consent fallback is not proof that a dependency-compliant Gerber import works without Nova. Installed-module dependency resolution and on-demand lifecycle execution are separate concerns.

Existing lifecycle integration test source is at [New-GerberPluginProject.Integration.Tests.ps1](../../tests/private/plugins/New-GerberPluginProject.Integration.Tests.ps1), with support under `tests/`. Earlier G-3D1/G-3E1 validation reports describe isolated publication/fresh-host hello with Nova 3.4.1; those are historical results, not qualification of the current 3.4.2 declaration or a fresh run here.

### Prerelease representation (historical finding; local G-4A6 follow-up)

The earlier 2026-10-23 record reports that a temporary manifest using `RequiredModules = @(@{ModuleName='PSModuleUpdate'; ModuleVersion='0.1.0-preview'})` failed with "Cannot convert value '0.1.0-preview' to type System.Version" on macOS PowerShell 7.x. `ModuleVersion` must be a plain `System.Version`; the then-inspected PMU reported `Version 0.1.0` with `PSData.Prerelease = 'preview'`. That historical evidence is retained; G-4A6 separately records fresh version-field experiments.

The current `project.json` declares **PMU `ModuleVersion: "0.1.1"` and NovaModuleTools `"3.4.2"`**. The 2026-10-25 dependency correction consumes upstream `0.1.1-preview`'s mixed-layout installed-copy scan fix. PMU ignores legacy resource directories without a module manifest beside numeric installations, still rejects genuine invalid candidates, and does not select or migrate a flat-only copy as a versioned installation. PMU 0.1.1 is not yet published; dependency bootstrap is a separate approved action, with no automatic local Gerber migration or cleanup.

The former invalid `-preview` declaration is historical, not a current configuration defect. [G-4A6](G-4A6-runtime-dependency-qualification.md) verified disposable generation and offline import with the then-required numeric PMU `0.1.0`, exact Nova 3.4.2 and installed PMU 0.1.0-preview on macOS/PowerShell 7.4.21 and 7.6.6. That dated evidence is preserved, not upgraded to qualification of the new dependency or a live installation. Numeric ModuleVersion is a minimum and does not constrain the prerelease channel. Nova refreshes the ignored manifest through normal builds; package-source and wider platform qualification remain. Neither required dependency is an unresolved architecture choice.

## 6. Startup update check (Decided; Core implemented in G-4A7)

Normal Gerber startup through its public entry points checks for Gerber Core updates. The check must:

1. Identify the currently executing Gerber Core version (prerelease-aware; the existing numeric-only version helper is insufficient, see G-4A1 section 12).
2. Always explicitly use the fixed official PSGallery repository; no user, environment or plugin setting can override it.
3. Determine whether a newer eligible version exists under the applicable channel policy.
4. On update available, show a short notification with the available version and refer to `/update`.

Illustrative notification only, not an observed available Gerber package:

```text
Gerber v0.1.0-preview

A new version of Gerber is available: v0.1.0
Run /update list to review the available update.
```

The check is **informational only**. It never installs, prompts for installation, changes module versions, updates plugins, modifies Gerber configuration, or triggers a release/publication. There is no automatic installation or scheduled background updating.

Outcomes must stay distinct and must never claim currency without evidence:

| Outcome | Meaning | Presentation |
| --- | --- | --- |
| No update available | Check completed; no newer eligible version | No notification required |
| Update available | Newer eligible version found | Short notification with version and `/update list` |
| Update check failed | Network or repository error occurred | Startup continues; no "up to date" claim |
| No matching package / no eligible release | Discovery completed but Core is unpublished or no target satisfies the selected PMU policy | Startup continues without an availability/currency claim; `/update list` explains the outcome |
| Update check could not be completed | Probe timed out or executing-module identity could not be resolved | Startup continues; no "up to date" claim |

Failure never blocks startup. Exact wording, timeouts and caching are implementation details to be specified without changing the above contract.

**Provisional G-4A7 implementation, not permanent policy:** `Invoke-Gerber`, not
module import, invokes a separate noninteractive PowerShell probe with a
2,000 ms wait budget and terminates slow children. Only a display summary crosses
the process boundary. The available-version notification survives home-screen
redraws but is discarded at session exit; no persistent cache exists.
Core does not consult credential configuration or initialize native storage.
Startup probes can run in noninteractive environments without requesting
credentials or installation consent. Failures, no-package and no-eligible-target
outcomes do not display a currency claim. Core never reports `Unconfigured`.

## 7. `/update` (Decided; Core implemented, plugins planned)

`/update` is Gerber's central update-management command. It is architecturally responsible for **both** Core and plugin updates and is **not** Core-only (the Core-only scope in G-4A0/G-4A1 is superseded). Both use the same PMU engine.

`/update` opens the shared inline **list**/**policy** chooser.
`/update list` performs a **fresh** update check when invoked; it never reuses
a startup notification result as current. Result continuation and policy Escape
return to the update chooser using the standard local-back navigation.

**Implementation sequencing:**

1. **Phase 1 - Core.** Required dependency, startup notification, and `/update` for Gerber Core. Implemented in G-4A7; qualification limits remain.
2. **Phase 2 - Plugins (G-4A9).** Plugin discovery of updates, overview and selection, in a separate phase. Core's fixed repository resolver must not be reused as a plugin default, and plugin configuration must not enter Core's resolution path.

### Overview presentation

Gerber owns the overview and interaction; PMU owns generic discovery and installation. The compact table shows component, installed version, available version and repository. Illustrative plugin presentation (versions and repositories are illustrative, not verified production configuration):

```text
Plugin              Installed    Available    Repository
----------------------------------------------------------
Gerber.AzureDevOps  1.2.0        1.3.0        PSGallery
Gerber.ExampleTeam     2.1.0        2.2.0        ExampleTeam
Gerber.ExamplePartner  1.4.0        1.4.0        ExamplePartner
Gerber.ExampleOrg      3.0.0        3.1.0        ExampleOrg
```

A corresponding Gerber Core overview must be supported. The user must eventually be able to choose which available updates to install. This is not approval for bulk updates, automatic plugin updates, a new terminal framework, or abstractions for hypothetical features. Slash-menu behavior must follow the shared menu contract in [terminal UX instructions](../../.github/instructions/terminal-ux-design.instructions.md).

G-4A7 currently renders one Core row with Component, Name, Installed, Available,
Repository and Status. It requests explicit consent with Cancel as the default,
retains the overview/scope during confirmation, and explains any required
operation-local trust/license acceptance. Installation receives the original
live PSGallery-bound PMU plan, not the startup summary. Gerber displays PMU
verification/recovery/restart results without hot reloading Core or assuming
rollback succeeded after a failure. Noninteractive views never confirm or install.

## 8. Plugin updates (Decided; Planned)

- Plugins are independently versioned modules and may use different repositories (illustrative: `Gerber.AzureDevOps` to PSGallery, `Gerber.ExampleTeam` to `ExampleTeam`, and so on; not verified production configuration).
- Repository identity comes from **explicit, trusted configuration or an approved plugin metadata contract**. It is never inferred from the plugin name, never assumed to be PSGallery, and never switched automatically because another repository holds a higher version.
- Gerber coordinates discovery and selection; PMU executes the generic operation.
- Existing plugin security and approval boundaries remain intact ([ARCHITECTURE.md](../../ARCHITECTURE.md) plugin lifecycle, [D-003](../../DECISIONS.md)): approval is by manifest GUID, persists across updates, and a GUID is not proof of publisher or code integrity. An update must not silently bypass plugin trust or approval requirements (for example a plugin whose GUID changes is not the same plugin).
- **Plugin update lifecycle and activation require integration qualification.** Do not assume that replacing an installed or imported plugin activates its new version in the running session; restart guidance belongs to Gerber (PMU reports `RestartRequired` from actual loaded copies and never imports the target).

## 9. Core and plugin repository policies (Decided; clarified G-4A7R)

**Gerber Core always uses PSGallery.** It is the permanent, sole official
distribution channel, not a configurable default. User configuration,
environment variables and plugin metadata/configuration cannot override it.
There is no repository-selection prompt and no alternative-repository fallback.
A read-only public PMU `0.1.1-preview` probe on 2026-10-25 returned installed/target
Gerber `0.1.0` and `UpToDate` from the actual PSGallery feed using the installed
versioned module and Stable/CurrentUser policy. No installation or global
module/repository change occurred; this is mixed-layout/feed lookup evidence,
not complete live installation qualification.
No matching package remains a legitimate discovery result, not a configuration
error or a fabricated version.
Gerber classifies only PMU's explicit `PMU.PackageNotFound` as no matching/eligible
package. The separate upstream PMU issue still collapses provider-thrown `PackageNotFound`
into `PMU.DiscoveryFailed`; that path remains a reported failure, not inferred
success. See the [observed integration limits](../core-updates.md#qualification-and-remaining-scope).

`Resolve-GerberCoreUpdateRequest` is Core-specific and does not read user or
plugin configuration. `Resolve-GerberCoreUpdatePolicy` separately reads only
the optional `coreUpdates.channel` setting from validated user configuration.
Both manual discovery and the isolated startup process use that resolver and
the same configuration path, including `GERBER_CONFIG_PATH`.
Core explicitly passes `-Repository PSGallery` and PMU
policy with `ExpectedRepositoryUri` equal to
`https://www.powershellgallery.com/api/v2`, the selected channel and
`Scope = CurrentUser`. PMU rejects a missing/repointed registration. Installation
uses the original live plan, which retains the exact repository binding.
The obsolete `updates.modules.Gerber` object is ignored, not migrated or
rewritten; unrelated plugin settings are preserved.

`/update policy` persists `Stable` or `IncludePrerelease` atomically without
discovery or installation; missing values default to Stable without writing,
while explicit invalid values/types fail validation. A changed channel clears
the session's old startup notification. Discovery retains its effective channel
separately from the original PMU plan, and installation requires both to match
the current configured channel. Repository identity, endpoint, CurrentUser
scope and explicit default-Cancel confirmation remain mandatory.

**Plugins select repositories independently per plugin** through Gerber-owned
metadata/configuration (G-4A9; schema not implemented here). Different plugins
may use PSGallery, Azure Artifacts or compatible private NuGet repositories
including Nexus. A plugin from `ExampleTeam` must not silently fall back to PSGallery
because it has a newer same-named module. Neither plugin settings nor the fixed
Core resolver supply defaults for each other. Both paths use PMU's same generic
engine; no vendor-specific providers or duplicate package mechanics are introduced.

### Core prerelease policy

The installed Core identity includes manifest `PSData.Prerelease`, for example
`0.1.0-preview`. Core defaults to PMU's **Stable** channel: newer previews
are excluded; stable `0.1.0` may supersede that preview, and newer stable versions
are eligible under PMU's normal no-downgrade/installed-copy rules. PMU also
supports `IncludePrerelease`, selected explicitly through `/update policy`
and persisted as `coreUpdates.channel` for startup and manual checks.
Gerber neither compares version strings nor changes its declared version.
PMU owns semantic ordering, candidate filtering, plan selection and installation.

Evidence boundary (from PMU G-4A3 closure and decisions D-020/D-021, not Gerber):

| Repository | Evidence |
| --- | --- |
| PSGallery | Verified in PMU's qualification: discovery and install on macOS; PMU CI covers the six lanes of G-4A4 |
| Azure Artifacts | Verified in PMU's qualification for authenticated stable discovery/installation with caller-supplied credentials; private prerelease progression not qualified |
| Nexus | **Unverified.** Expected to work through a PSResourceGet-supported NuGet v3 endpoint; no executed evidence exists |

No vendor-specific behavior is claimed beyond this table.

## 10. Authentication (Decided; Core public, plugins planned)

Core always uses public PSGallery and does not request credentials, read native
secrets or consult Core credential configuration. The following private-feed
responsibilities apply to future plugin updates, not Core repository selection.

- Gerber owns the configuration and credential selection needed to choose repositories and obtain credentials. PMU does not know how Gerber stores or obtains credentials.
- The generic API uses `PSCredential` where credentials are explicitly supplied. Discovery and installation may each need authentication, so credentials must be available to both operations; PMU requires them to be supplied again for installation.
- Distinguish: public repositories needing no credentials; private repositories with explicit `PSCredential`; repositories using already configured provider authentication.
- Credentials are selected by trusted repository configuration and applicable policy. Do not assume all private repositories use Azure DevOps PATs and do not reuse Gerber's ADO credentials for arbitrary repositories.
- Update plans must not persist passwords or PATs; PMU's own technical recovery journals must not store credentials. Never log credentials or sensitive authentication detail. No new authentication framework is introduced; the existing Gerber credential abstraction ([D-010](../../DECISIONS.md), [credential-service](credential-service.md)) is the source of Gerber-side credentials.

**Historical G-4A7 binding, superseded by G-4A7R:** user-configurable Core
repository, optional policy and credential references were provisional
implementation choices. They are not a supported configuration contract.
The complete old Core binding is ignored without rewriting it or unrelated
plugin settings. See [Core updates](../core-updates.md). The future plugin
configuration/metadata contract remains G-4A9.

## 11. Historical reconciliation

| Source | Historical statement | Disposition |
| --- | --- | --- |
| G-4A7; earlier G-4A5 sections 6, 9, 10 and 14; earlier D-017 | Core repository selected through `updates.modules.Gerber`, including policy/credential references; public default undecided | Superseded by owner G-4A7R: permanent application-owned PSGallery binding, no overrides/fallback, fixed PMU Stable/CurrentUser policy and no Core credentials. Old Core settings are ignored; plugin configuration remains independent |
| D-002 (2026-10-10 reconstruction) | "Core is fully usable without Gerber.ExampleOrg, any other plugin, ADO, PAT, or NovaModuleTools" | Owner clarification 2026-10-24 supersedes only the Nova exclusion: Nova is required for application-exposed plugin development. Independence from plugins/ADO/PAT, public-only Plugin API integration, generic Core ownership and Gerber.ExampleOrg as consumer remain |
| ARCHITECTURE.md, Product boundaries / Initialization / Development and quality | Nova "NOT mandatory"; import/use without Nova; invocation-only tooling wording | Superseded as dependency policy by D-017 and section 5. On-demand Nova operations remain; dependency availability is required |
| D-008; plugin creation guide/README/release notes | Nova checked/needed "only" for creation/development, with installation consent | Existing handler behavior retained and labeled as such, not an optional-import contract. Gerber plugin creation already calls Nova at application runtime |
| G-4A0 sec. 1 and 3 | Runtime Nova would violate the existing boundary; "Core must work without Nova"; creation cited as lazy optional tooling | Historical reliance on the old D-002/Core baseline, superseded by the owner's required-Nova decision; it does not justify using Nova as the update engine |
| G-4A1 sec. 9 | PMU may use Nova as development/build tooling without requiring it at runtime | Retained: this is about **PMU's** independence, not Gerber's runtime dependencies |
| G-4A0 sec. 5-7, 10 | Build-time shared-source component recommended (Option B) | Never approved; superseded by G-4A1 and G-4A3 independent PMU module |
| G-4A0 sec. 14 | Core-only `/update`; no startup checks | Superseded for scope; startup notification and Core + plugin architecture per this document |
| G-4A0 sec. 5, 10 | Mandatory `RequiredModules` dependency framed as undesirable | Superseded; required dependency is decided |
| G-4A1 sec. 1, 2, 9, 12 | Lazy runtime consumption; do not add PMU to `RequiredModules`; Gerber works without PMU; no startup PMU discovery | Superseded/rejected by the current owner decision, including sec. 2's historical "Confirmed" label for normal operation without PMU. Independent PMU ownership is retained |
| G-4A1 sec. 12, 16 | Core-only update presentation | Superseded; architecture covers Core and plugins |
| G-4A1 sec. 7, 12 | `updates` configuration and repository URI proposals; SecretManagement-oriented credential options | Proposals only; Gerber configuration and credential design remain open and must follow D-010 |
| G-4A2 | Provider qualification on PSResourceGet 1.2.0; prerelease collision findings | Evidence retained; same-base replacement and scope constraints superseded by PMU G-4A3 decisions |
| G-4A3 | PMU API, locking, recovery, credential contract | Implemented (PMU), closed 2026-10-23 within its qualified scope; no Gerber integration |
| G-4A4 | PMU cross-platform CI | Verified for PMU only (section 2) |
| G-4A5, previously recorded analysis | Omission from `RequiredModules` and graceful absence recommended | Rejected by owner; retained here as historical context, not current policy |
| G-4A5, earlier sec. 5 and 14 | Required Nova treated as conflicting/unresolved; dependency integration wholly planned; current PMU declaration described as `0.1.0-preview` | Owner clarified both required dependencies; declarations already existed with then-numeric PMU `0.1.0`. The 2026-10-25 correction raises the minimum to numeric `0.1.1`; delivery and live-install qualification remain separate |

D-002's original scope is evidenced by the reconstructed Core boundary and the contemporaneous on-demand creation description; it supplies no separate rationale for banning Nova at runtime. G-4A0 adds the recorded runtime-updater concerns (extra installable component, compatibility/recovery dependency and build-time reuse trade-offs), not a recovered explanation from the owner for D-002. The cited `G-1A.md` and `G-1A_response.md` are not in this checkout, so no original rationale beyond available records is asserted. Historical report bodies are preserved; current authority is explicit rather than silently rewriting past conclusions.

## 12. Boundaries not in scope

This architecture does not approve: automatic installation, scheduled background checks, bulk or automatic plugin updates, a new terminal framework, a second update engine, vendor providers, automatic repository switching, publication or release actions, or changes to plugin approval semantics.

## 13. Qualification required before claiming support

Gerber Core: generated manifest declaring **both** required modules and import compatibility with their intended installed versions (including PMU prerelease metadata); import behavior when either dependency is missing/incompatible; startup check without blocking when the repository is unreachable (all outcomes in section 6); fresh check on `/update`; terminal regression coverage for new interactive behavior; PMU and PSResourceGet version compatibility; restart guidance for the running session.
Plugins (later): repository association contract, credential selection per repository, activation of updated plugins, approval and GUID continuity, partial failure across multiple selected updates.

## 14. Remaining ambiguities (not decided here)

1. **Remaining delivery qualification** (section 5): local disposable generation/import passed in [G-4A6](G-4A6-runtime-dependency-qualification.md), and G-4A7 normal builds refresh the original ignored artifact. Package-source acquisition and Windows/Linux Gerber qualification remain.
2. The Core repository is **not ambiguous**: permanent PSGallery, with no override. Only the future plugin update configuration schema remains open.
3. The approved plugin-to-repository metadata or configuration contract.
4. Long-term startup timeout/cache policy; G-4A7 uses a 2,000 ms child-process budget and session-only presentation state.
5. Future plugin authentication policy; Core startup is always public PSGallery and never requests credentials, installation consent or installation.
6. Minimum PSResourceGet range beyond the current 1.2.0 constraint.
