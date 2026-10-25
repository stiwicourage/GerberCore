# G-4A1 - PSModuleUpdate architecture and API design

**Status:** Architecture recommendation; implementation and distribution approval pending.
**Research date:** 2026-10-22.
**Scope:** Investigation and this report only. No PMU project, runtime changes, dependency additions, pipeline changes or release actions.

> **Historical analysis - partly superseded (2026-10-23).** The current authoritative update architecture is [G-4A5](G-4A5-update-architecture.md). Independent PSModuleUpdate ownership is retained. The recommendations for lazy/optional runtime consumption, omitting PSModuleUpdate from `RequiredModules`, keeping Gerber functional without it and avoiding startup discovery are **superseded/rejected by the project owner**; PSModuleUpdate is a required Core dependency and Gerber checks for Core updates at startup (notification only). Core-only update presentation is superseded by a unified Core and plugin `/update`. Constraints later replaced by PSModuleUpdate decisions (CurrentUser-first, collision rejection, no rollback) are superseded by its G-4A3 decisions. The text below is preserved unchanged and its proposals are not current requirements.

> **Runtime dependency clarification (2026-10-24):** Gerber requires **both NovaModuleTools and PSModuleUpdate** through `RequiredModules`; see [D-002 / D-017](../../DECISIONS.md) and [G-4A5](G-4A5-update-architecture.md#5-required-runtime-dependencies-decided-declarations-present). This supersedes section 2's historical "Normal Gerber operation independent of PMU" row despite its "Confirmed" label. Section 9's Nova-as-build-tool statement concerns **PMU**, not Gerber, and remains compatible with PMU independence. Gerber uses Nova for application-exposed plugin development and PMU for generic updates; no runtime Nova operations are required on every startup. The report body remains historical.

This design builds on [G-4A0](G-4A0-shared-self-update-analysis.md), but does not treat its shared-source recommendation as approved. The subsequent product decisions in section 2 supersede its proposed adoption order. All PMU commands, types, settings, interactions and repository layouts below are **proposals**, not existing functionality.

Repository evidence comes from Gerber's inspected working tree based on commit `435c649a566599200ed458a8ae19f9d66cfd0b4d`, including pre-existing uncommitted work, and the clean NovaModuleTools checkout at `8164967da1cd1f14d4f5e24e24d5392bac8b1a32`. Local links resolve against those checkouts; the revision identifiers establish the investigation context, not a claim that Gerber's working tree equals its HEAD.

## 1. Executive summary

**Develop PSModuleUpdate (PMU) as a small, independently released self-update orchestration library over Microsoft.PowerShell.PSResourceGet. Recommend lazy runtime consumption, not build-time incorporation.** Gerber is the first consumer; NovaModuleTools retains its present updater until Gerber demonstrates reliable operation and migration is separately approved.

Standard PowerShell commands already provide discovery, repository access, authentication integration, dependency resolution and installation. PMU should not duplicate them. The reusable gap is identifying the running consumer, selecting an eligible release, presenting a source-bound exact-version plan, applying that plan, verifying installed identity and reporting the distinction between installed and active code.

An ordinary consumer needing only "install the latest release" can use PSResourceGet directly with a small wrapper. That is sufficient for that narrower requirement. It is not the complete contract requested here: sharing identity/source checks, active-versus-installed handling, verification, errors and recovery across several consumers would otherwise recreate the same orchestration in each wrapper. No maintained complete self-update library was identified in the scoped public search. PMU is justified **only for that orchestration**, not as another package manager.

Recommend two public commands, without registration or callbacks:

```text
Get-PSModuleUpdate -Module <PSModuleInfo> -Repository <string>
                  [-Policy <hashtable>] [-Credential <PSCredential>]

Install-PSModuleUpdate -Update <UpdatePlan> [-Credential <PSCredential>]
                      [-AcceptLicense] [-TrustRepository] [-WhatIf] [-Confirm]
```

Use stable PSResourceGet **1.2.0 as the initial qualification baseline and proposed minimum**. Its release notes and stable-tag tests establish NuGet v3 dependency support and Azure Artifacts Credential Provider integration. A warning in the live installation reference still says v3 dependencies are unsupported; that warning must not be repeated as an established limitation of 1.2.0. These findings update the provider uncertainty recorded in G-4A0; they do not establish that every private feed or credential-provider installation works. [M1] [M2] [M3]

The main cost of runtime consumption is an optional, separately installed dependency. Keep it off Gerber's import/startup path, provide standard-command setup and recovery guidance, and do not automatically update PMU. Approve the API, compatibility/scope policy, trust model and recovery limits before coding.

## 2. Confirmed architecture decisions

### Product decisions supplied for G-4A1

| Confirmed decision | Architectural consequence |
| --- | --- |
| Name: PSModuleUpdate; abbreviation: PMU | Independent product identity; not a Gerber or Nova private component |
| Independent development and maintenance | Own repository, versioning, releases, support policy and documentation when creation is authorized |
| Standard PowerShell package management | No custom feed client, package resolver, Azure authentication implementation or general module manager |
| Gerber first | Gerber supplies the reference integration and qualification evidence |
| Nova migration later | Preserve Nova's current implementation until PMU succeeds through Gerber |
| One explicitly identified consumer | No global update inventory, automatic plugin updates or unrelated module updates |
| Normal Gerber operation independent of PMU | Missing, incompatible or broken PMU cannot block Core import, startup or unrelated commands |
| Design task only | Only this report is created; no subsequent phase starts automatically |

### Recommendations, not previously approved decisions

Lazy runtime distribution, PSResourceGet 1.2.0 minimum, the two-command contract, CurrentUser-first support, Stable as Gerber's default and manual recovery without automatic rollback require approval. G-4A0's shared-source recommendation and Nova-first implementation sequence are not prerequisites or commitments.

Gerber's current roadmap, architecture and decisions are evidence inputs, not rewritten approvals. Its metadata currently declares version `0.1.0-preview`, PowerShell 7.4 and no required modules; the approaching 1.0 release does not mean the inspected checkout is already version 1.0. [G1] [G2] [G3] [G4]

## 3. Existing solutions assessment

### Research method and limits

Research used current Microsoft documentation, public GitHub repository/release metadata, stable-tag source/tests and PowerShell Gallery package metadata. Search terms included PowerShell module self-update/updater projects and the proposed command names. The search was finite: absence from indexed public results is not proof that no private, unindexed or future solution exists. Maintenance dates describe observed activity, not a quality guarantee.

No credentials, private feeds, installations or real update operations were used. Provider tests cited below were **read**, not executed by this task.

| Candidate | Maintenance and license evidence | Coverage and compatibility assessment | Adoption conclusion |
| --- | --- | --- | --- |
| Microsoft.PowerShell.PSResourceGet | Stable 1.2.0 released 2026-03-11; repository activity 2026-10-20; 1.3.0-rc1 released 2026-10-20; MIT | Official Windows/macOS/Linux engine; PowerShell 7.4-compatible foundation. Discovery, exact versions/ranges, prereleases, scopes, v2/v3 repositories, dependencies and private credentials. Does not own active-consumer identity, approval plans or restart reporting. [M1] [M2] [M3] [M4] [M5] [M6] | Adopt as PMU's sole initial package engine |
| PowerShellGet | Stable 2.2.5 published 2020-09-22; MIT; legacy v2 repository now archived | Standard cross-platform discovery/install/update functionality on modern PowerShell, credentials and prereleases; PackageManagement dependency. Nova already uses it. `Update-Module` normally requires prior PowerShellGet installation provenance. Azure/provider behavior and repository stores differ from PSResourceGet. [M7] [M8] | Retain in Nova until migration; do not add a second PMU backend |
| ModuleFast | GitHub stable 0.6.1 released 2026-05-12; repository activity 2026-10-20; MIT text in LICENSE, although GitHub's classifier reports NOASSERTION | Strong plan/install candidate with version constraints, prereleases and HTTPS Basic/PAT authentication for v3 sources. Custom HTTP client/resolver, default Gallery mirror and compatibility tradeoffs; v2/local feeds are non-goals. No complete active-self-update/restart contract. [T1] | Reject for this task: replaces the standard-provider foundation rather than filling its orchestration gap |
| MaintainModule | Gallery stable 0.1.5 published 2023-01-19, later beta releases; repository activity 2026-09-17; MIT | Updates selected/all installed modules, can trust PSGallery, remove old versions and import modules; extra rsServiceModule dependency. README claims all operating systems, not PMU-specific 7.4/private-feed qualification. [T2] | Reject: broader inventory/cleanup policy and no matching plan/verify/active-state contract |
| AzureArtifactsPowerShellModuleHelper | Gallery 2.4.9 published 2026-04-24; repository activity 2026-04-28; MIT | PowerShellGet-based Azure feed/PAT convenience wrappers. Its own README says the helper is unnecessary when using PSResourceGet's credential-provider integration. Cross-platform packaging is not a verified PMU authentication matrix. [T3] | Do not add: use supported PSResourceGet mechanisms |
| PSModuleUpdater | Public repository created/pushed 2025-04-25; no releases found; MIT | Script to update installed-module inventory, not a reusable active-consumer library. No sufficient 7.4/private-feed/verification evidence. [T4] | Not an adequate complete solution |
| PoSh-SelfUp-Module | Repository activity 2024-09-05; no release or detected license evidence | Work-in-progress self-updating module skeleton; import-time update/reload conflicts with Gerber's startup and activation requirements. Platform/private-feed guarantees unverified. [T5] | Reject as foundation; do not copy unlicensed source |

PSResourceGet and PowerShellGet provide the underlying package capabilities; none of the alternatives demonstrates all required orchestration with a smaller and safer consumer integration. ModuleFast's planning feature was considered rather than dismissed merely because it is an installer.

ModuleFast advertises bootstrap without external module dependencies, but that convenience comes from its own package infrastructure. MaintainModule adds rsServiceModule; the Azure helper adds wrappers around PowerShellGet rather than eliminating its provider requirements. The third-party projects' platform claims are not evidence that their current releases passed this task's PowerShell 7.4/private-feed matrix. PSResourceGet authentication extensions also have optional dependencies: SecretManagement/vault modules or a compatible Azure credential-provider installation are needed only for the chosen mechanism.

### Important version-specific findings

Stable PSResourceGet 1.2.0 resolves the earlier uncertainty about v3 dependencies: release history introduces support in preview1, fixes it in preview2 and later release candidates, and stable source test `Install module and its dependencies` asserts four installed resources. Exact stable, bracketed exact and full prerelease installation are also covered in that stable-tag suite. The inspected tag resolves to commit `9289da13a78a05b08c53756194816cf79d4584c6`. [M1] [M3]

Do not depend on 1.3 preview/RC features such as newer runtime/target-framework installation options, `$PSUserContentPath` handling or default Microsoft Artifact Registry registration. PowerShell 7.4 alone does not imply PSResourceGet 1.2.0 is installed: Microsoft's release history lists older provider versions bundled with 7.4 releases. [M1]

## 4. Build-versus-adopt recommendation

**Adopt PSResourceGet; build only the small PMU orchestration layer missing above it.**

| Approach | What consumers still implement | Fit |
| --- | --- | --- |
| Direct PSResourceGet integration | Active identity, channel policy, plan binding, confirmation adaptation, verification, active/installed distinction and recovery mapping | Good for one simple latest-install flow; duplicates the requested contract across consumers |
| Existing third-party updater | Adapt broad policies and still add missing identity/source/activation guarantees; sometimes replace the package engine | No investigated candidate is a smaller complete solution |
| Thin PMU over PSResourceGet | Consumer configuration/UI plus a small optional-dependency adapter | Recommended reusable contract; adds independent maintenance and optional bootstrap cost |
| General PMU package framework | Provider SDK, custom discovery, authentication/resolution abstractions | Rejected as unnecessary scope and operational risk |

Use this scope test during implementation: if PMU needs its own NuGet HTTP client, solver, package inventory, background scheduler, repository database or custom transaction engine, reconsider the design rather than assuming those are requirements. A future discovery that a maintained solution meets the complete contract should reopen the build decision.

Nova's current latest-discovery/latest-install workflow is ordinary PowerShell orchestration, not an attempt to implement package management. Exact target binding is a modest consistency improvement for a user-approved plan: a newly published release should not silently replace the version the user just approved.

## 5. PMU responsibilities and boundaries

| Responsibility | Owner |
| --- | --- |
| Supply its active module object, approved source and effective channel/scope policy | Consumer |
| Validate one target identity; distinguish active code from installed copies | PMU |
| Query one registered repository, choose an eligible newer release, return a plan | PMU orchestration using PSResourceGet |
| Feed protocols, repository storage, credential-provider integration, package extraction and dependency resolution | PSResourceGet and its supported dependencies |
| Apply the exact approved top-level version/source, verify observed installation, report restart/recovery | PMU |
| Gerber terminal UI, Nova cmdlet/CLI behavior, local configuration and notifications | Respective consumer |
| Repository registration/trust policy, credential/vault setup and dependency bootstrap authorization | User/administrator or separately approved deployment setup |
| Publisher authenticity policy and release provenance | Package publisher and consumer/deployment owner; not implied by repository trust |

No persistent registration command is needed. Every request supplies its consumer context. PMU keeps no global "current consumer", saved approval, preference file or inventory of modules to update. Both known consumers can describe their differences declaratively; callbacks for version lookup, prompting, configuration or installation are unnecessary.

The engine updates only its named consumer. Standard resolution may install that package's **declared dependencies**; that is not permission to scan/update unrelated modules. Gerber currently declares no required modules and must not acquire a Nova or plugin dependency through this feature. Dependency changes must be reported where the provider exposes them; PMU must not imply that a top-level exact-version plan is a complete transitive dependency lock.

Custom deployment layouts and arbitrary install-script hooks are excluded initially. Unsupported installations produce guidance rather than a default installer callback.

### Existing Nova lifecycle and reusable material

| Actual stage | Existing behavior and evidence | PMU versus Nova ownership |
| --- | --- | --- |
| Initiation | Public `Update-NovaModuleTool`, alias `Update-NovaModuleTools`, and `nova update`. Build/scaffold notifications are separate checks, not automatic installation. [N1] [N2] | Public names, routes and trigger schedules remain Nova-owned |
| Active version | `Get-NovaInstalledModuleVersionInfo` reads the running module, combines manifest version/prerelease through its helper and parses semantic version. It does not select the highest installed copy. [N3] | PMU needs this distinction, without Nova naming/configuration |
| Discovery | Packaged lookup text calls `Find-Module` against PSGallery, stable then optional prerelease. Explicit workflow requests a 10-second lookup; notification checks use a shorter timeout. Lookup failure becomes a specific explicit-command error; notifications can remain silent. [N2] [N4] | Standard discovery belongs to provider; timeout/error orchestration is reusable |
| Selection | `Get-NovaModuleSelfUpdatePlan` chooses eligible prerelease first when preference permits, otherwise newer stable, otherwise no update. The prerelease-enabled provider query may return stable. [N5] [N6] | Pure planning concepts/tests reusable; proposed PMU ordering is separately specified |
| Approval | Additional default-No prerelease confirmation, then native `ShouldProcess`; `-WhatIf` still performs discovery but skips installation and prerelease prompt. [N1] [N10] | Nova retains its wrapper UX; PMU exposes native mutation semantics |
| Installation | `Invoke-NovaModuleSelfUpdate` reaches a narrow adapter calling standard `Update-Module -Name`, optionally `-AllowPrerelease`, with stop-on-error. No exact version or explicit scope is passed. [N7] [N8] | Replace orchestration/adapter later; do not describe Nova as a custom installer |
| Completion | `Updated=true` follows a nonthrowing install, without installed-version verification. Active code is not reloaded. Release-note lookup uses the current session and can fail after installation. [N9] | PMU supplies verified disk/active results; Nova renders notes separately |
| Preferences | Nova persists `PrereleaseNotificationsEnabled`, default true, in its own settings JSON. It controls both notifications and update eligibility. [N11] [N12] | Remains Nova-owned, including compatibility decisions |
| Recovery | Error wrapping exists; no demonstrated application rollback, cross-process update lock or post-install reconciliation. [N9] | PMU can improve detection/reporting, not promise transactional rollback |

Nova's lookup resource resolution can prefer project-local resources; package provenance, source isolation and direct provider integration should replace that implicit coupling, not export it as a PMU extension mechanism. Nova's release-note/UI helpers, settings paths, CLI routes and build hooks are not extraction candidates. [N13]

## 6. Proposed public API

### Naming and target selection

`Get` and `Install` are approved PowerShell verbs; `PSModuleUpdate` is a focused singular noun. The scoped Gallery/GitHub search found no exact published PMU package or convincing exact command collision. This does not reserve the names; repeat the check before publication. Consumers should use module-qualified commands or retained exported `CommandInfo` objects from the explicitly selected PMU module. [M9]

Recommend **explicit `-Module <PSModuleInfo>` rather than a name-only parameter in v1**. A name does not identify which active copy/path is updating itself, especially with multiple loaded versions or a development build. Requiring one existing object adds little integration code and avoids call-stack inference, target auto-import or choosing the highest installed version. `-Name 'Gerber'` remains a possible future convenience only if it errors on ambiguity; it is not necessary for the initial API.

The object's name, GUID, base version, prerelease metadata and actual module path supply identity. Validate that it represents the active consumer in this process and a supported installed layout. Reject empty/ambiguous identity and development/source imports; do not manufacture identity from the current directory.

### `Get-PSModuleUpdate`

| Parameter | Proposed contract |
| --- | --- |
| `Module` | Mandatory scalar `System.Management.Automation.PSModuleInfo`; consumer's active module, not PMU's own module object |
| `Repository` | Mandatory scalar registered repository name; literal only, no wildcards, arrays or all-repository search |
| `Policy` | Optional validated hashtable with the small declarative schema below; reject unknown keys/types instead of silently ignoring them |
| `Credential` | Optional `PSCredential` passed to the provider for this call only; otherwise use configured supported repository authentication |

| Policy field | Default and meaning |
| --- | --- |
| `Channel` | `Stable`; alternative `IncludePrerelease` includes stable and preview releases, not preview-only |
| `Scope` | `CurrentUser`; v1 blocks AllUsers/mixed/custom layouts rather than silently changing/shadowing their scope |
| `ExpectedRepositoryUri` | Optional deployment-approved endpoint; Gerber's reference integration supplies it. If omitted, the explicit registered source is the initial authority and must be visible in the plan |
| `VersionRange` | Optional provider-supported NuGet constraint, no invented range syntax; no constraint means newest eligible release, including a newer major |

This is a data schema, not an extensibility framework: no scriptblocks or consumer configuration objects. These fields group coherent selection policy while keeping four explicit command parameters. Consumers needing a major-version ceiling use a tested range; PMU does not silently assume one.

The command performs read-only source/installed-state checks and remote discovery. It does not register repositories, save preferences, import the target, install/update PMU or trust a feed. Credential providers/vaults may use their own caches; "read-only" describes PMU/package mutation, not an assertion that external authentication software never writes a token cache.

**Selection:** use provider discovery/version constraints and standard PowerShell version facilities, not a new NuGet resolver or lexical string sorting. Preserve the provider's full normalized version including prerelease. Stable excludes previews; IncludePrerelease selects the greatest eligible release whether stable or preview. Target must be newer than the active version; no downgrade/reinstall to implement a channel switch. Test normal three-part versions, supported four-part manifest versions, numeric/text prerelease identifiers and normalization; reject unsupported comparisons explicitly rather than guess.

**Return:** exactly one data-only object with `PSTypeName` `PSModuleUpdate.UpdatePlan` and `SchemaVersion=1`. A PowerShell type name helps tooling, not provenance/security. Do not require `using module` or public PowerShell classes merely to consume the result.

| Plan fields | Meaning |
| --- | --- |
| `SchemaVersion`, `CreatedAtUtc`, `PmuVersion`, `ProviderName`, `ProviderVersion` | Contract/diagnostic context; time is informational, not an authorization expiry mechanism |
| `ModuleName`, `ModuleGuid`, `ActiveVersion`, `ActivePath` | Consumer identity and full running version |
| `RepositoryName`, `RepositoryUri`, `RepositoryApiVersion`, `RepositoryTrusted` | Resolved source snapshot |
| `Channel`, `VersionRange`, `Scope`, `DestinationRoot` | Effective policy and provider-derived destination |
| `TargetVersion`, `TargetIsPrerelease` | Exact selected top-level version, null when none applies |
| `UpdateAvailable`, `Disposition`, `Reason` | Separate availability from whether an install is needed/allowed |
| `ObservedInstalledVersions`, `TargetInstalledPath`, `RestartRequired` | Target-specific observations, not a global module inventory |
| `RequiresRepositoryTrust`, `RequiresLicenseAcceptance`, `DependencySummary` | Known prerequisites/metadata; unknown dependency/license details are marked unknown, not invented |

Dispositions are `UpdateAvailable`, `UpToDate`, `AlreadyInstalledRestartRequired` and `ActionRequired`. `UpdateAvailable` means a newer eligible release exists; `Disposition` determines the next action. A newer exact target already verified on disk yields `AlreadyInstalledRestartRequired`, not another install. Unsupported layout or known same-directory replacement risk yields `ActionRequired`. A network/authentication failure is an error, never `UpToDate`.

An absent consumer package in the chosen repository is a discovery error, not proof of being current. If the package exists but no release satisfies the channel/range above the active version, return `UpToDate` with a precise reason such as `NoNewerEligibleRelease`. If a verified newer version is already installed in the destination and the proposed target would go backwards relative to that state, return `ActionRequired` explaining the installed/channel conflict; do not repeatedly propose an installation that application would reject.

### `Install-PSModuleUpdate`

| Parameter | Proposed contract |
| --- | --- |
| `Update` | Mandatory one live UpdatePlan object; pipeline-by-value permitted, no property-name binding of arbitrary package fields |
| `Credential` | Optional per-call `PSCredential`; must be supplied again if direct credentials were used for discovery |
| `AcceptLicense` | Explicit permission for the selected operation's license requirements; never inferred from update consent |
| `TrustRepository` | Explicit operation-scoped permission to use the displayed untrusted source; maps to the provider flag without changing its saved trust setting |
| Common `WhatIf` / `Confirm` | `SupportsShouldProcess` at the mutation boundary; no PMU custom yes/no prompt |

There are no `Name`, `Repository`, `Version`, `Scope`, `Force`, `Reinstall` or arbitrary install-script overrides. To change the action, obtain another plan and confirmation. Repository trust and license acceptance are separate choices, not a broad force switch.

Before mutation, validate schema and all fields, reacquire active/installed/source state, enforce policy and check exact target availability. Reject repointed sources, changed active identity/path, incompatible provider/PMU context, changed destination or suspect existing target. The target version is never recomputed as "latest". Module/package metadata available before installation is checked then; definitive installed manifest/GUID verification follows installation. If the feed lacks pre-install GUID metadata, this is a post-install detection limit, not proof of pre-install authenticity.

Plans are in-process data, not signed authorization tokens. A manufactured/edited `PSCustomObject` is not made trustworthy by its `PSTypeName`; field validation and fresh observations prevent common mistakes, not a malicious caller already able to execute PowerShell. Persisted/deserialized plans are outside the initial contract. No registration database, signed-plan framework or secret approval flag is needed.

Use exact `Install-PSResource` with the plan's literal name, full target version, repository and explicit scope, rather than relying on how the old copy was originally installed. Forward credentials only to that provider call. Do not enable reinstall, change trust, skip dependencies or accept licenses implicitly. Ordinary declared-dependency resolution remains provider-owned.

**Return:** one `PSModuleUpdate.UpdateResult` with `SchemaVersion`, `Outcome`, target identity/source, `RequestedVersion`, `VerifiedInstalledVersion`, `InstalledPath`, unchanged `ActiveVersion`, `VerificationStatus`, `RestartRequired`, observed declared-dependency changes where available, and safe `RecoveryGuidance`. Outcomes are `Installed`, `AlreadyInstalled`, `Cancelled` and `WhatIf`. Operational failure terminates; it is not a success-shaped `Outcome=Installed` with a warning.

### Errors, idempotency and streams

| Error family | Example stable identifiers and behavior |
| --- | --- |
| Input/identity | `PMU.InvalidRequest`, `PMU.InvalidPlan`, `PMU.ModuleIdentityMismatch`, `PMU.UnsupportedInstallation` |
| Dependency/source | `PMU.ProviderUnavailable`, `PMU.ProviderIncompatible`, `PMU.RepositoryUnavailable`, `PMU.RepositoryChanged`, `PMU.RepositoryTrustRequired` |
| Discovery/access | `PMU.DiscoveryFailed`, `PMU.AuthenticationFailed`, `PMU.PermissionDenied`, `PMU.LicenseAcceptanceRequired` |
| Apply/verification | `PMU.UpdateInProgress`, `PMU.PlanStale`, `PMU.InstallationFailed`, `PMU.VerificationFailed` |

Use terminating `ErrorRecord`s with appropriate categories, safe target/context, recovery text and preserved provider error identity where safe. Do not promise to distinguish DNS, timeout, authentication and arbitrary provider failures when the provider does not expose enough evidence; preserve an honest general category. Attach safely observed partial-state details to failure context. Redact tokens, credential values and sensitive authenticated URLs from all streams.

Reapplying a valid plan under the PMU lock is idempotent: verify the exact target in the expected scope and return `AlreadyInstalled` without calling the installer. A merely existing folder, different GUID, incomplete installation or another scope is not sufficient. A newer installed version or changed active state requires a fresh plan rather than an implicit downgrade. Retain no mutable "already updated" flag.

`-WhatIf` may revalidate/discover and can fail offline; it must not install, bootstrap dependencies, alter settings/trust or perform repair. Return `WhatIf` without acquiring a mutation lock. A declined native `ShouldProcess` returns `Cancelled`. Results use the success stream; progress/verbose/warnings remain separate. Normal library operation produces no banner or terminal-formatted table.

PMU adds no custom prompts beyond native `ShouldProcess`. Preflight known trust/license requirements; in noninteractive use require explicit permissions and usable credentials or fail actionably. Provider contract tests must prove that a trust/license/vault prompt cannot unexpectedly hang automation. `-Confirm:$false` alone is **not** sufficient: stable provider tests explicitly document an untrusted-repository prompt even with that flag. [M3]

## 7. Repository and authentication design

### Source identity and registration

Support **PSGallery, compatible NuGet v2/v3 feeds and Azure DevOps Artifacts** through registered PSResourceGet repositories. PMU consumes their registrations; it does not create, replace, reset, reprioritize or trust them. PowerShellGet and PSResourceGet have separate repository stores; migrating Nova's installer does not imply its old registration automatically exists in the new store. [M4] [M7]

Validate a single literal repository name and resolve its URI/API version. For remote repositories require HTTPS and reject embedded credentials; do not strip meaningful organization/project/feed paths when comparing endpoints. Use URI-aware comparison with only safe normalization. Consumer-supplied `ExpectedRepositoryUri` detects a wrong initial registration; plan/apply snapshots detect a later change. Recheck trust and nonsecret authentication configuration changes without copying secrets into the plan. Never fall back to another feed after a failure.

Gerber's default approved source is the documented PSGallery registration at `https://www.powershellgallery.com/api/v2`. A private deployment may choose an administrator-approved name/endpoint through validated configuration; an arbitrary project resource or current directory cannot override it.

### Supported mechanisms

| Mechanism | PMU contract and limitations |
| --- | --- |
| Public PSGallery | Standard provider discovery/install; no credential object normally needed |
| Direct `PSCredential` | Pass through on both commands. PAT/password remains a secure credential value, never a new plaintext PMU parameter or saved result |
| Registered `CredentialInfo` | Existing SecretManagement vault/secret reference; vault and secret setup/unlock stay outside PMU. Optional SecretManagement dependencies are not imposed on public-feed users |
| Azure Artifacts Credential Provider | Stable PSResourceGet 1.2.0 integration; use supported cached/unattended credentials, not a custom PMU Entra/PAT implementation |
| Private NuGet feeds | Provider-supported API/authentication combinations, qualified against representative controlled v2/v3 feeds; not a guarantee for every NuGet-compatible server |
| Offline | Ordinary Gerber operation unaffected. Remote update discovery/install fails explicitly; no automatic cross-source fallback or stale "up to date" claim |

The repository registration API supports `V2`, `V3`, `NugetServer`, `Local` and `ContainerRegistry`. PMU's initial product support should cover the requested remote NuGet repositories only. Local/offline repository workflows and container registries can be separately scoped; do not advertise every provider API type as a tested PMU feature. [M4]

### Azure Artifacts evidence and constraints

PSResourceGet 1.2.0 supports Azure credential-provider discovery and automatically associates recognized Azure feed registrations with `AzArtifacts` unless configured otherwise. Official registration documentation describes direct credentials and SecretManagement references. Stable source searches plugin paths/default NuGet locations/Visual Studio and invokes the credential provider with `-NonInteractive -IsRetry`; a DLL is launched using `dotnet`. Consequently, a PMU call must **not** promise an interactive Entra login window or device-code flow. Pre-authentication/cache or supported unattended setup is required. [M1] [M4] [M5]

Azure Artifacts Credential Provider currently documents Windows/macOS/Linux support. Observed release v2.0.5 is dated 2026-09-28. Its global dotnet-tool route requires SDK 9.0.200 or later, whereas the plugin route supports .NET 8 assets; .NET 8 plugin support dates from provider 1.3.0. A PowerShell 7.4 installation is not proof that a separately invocable compatible `dotnet` host/plugin is installed. New self-contained provider assets do not automatically prove compatibility with PSResourceGet 1.2.0's DLL-oriented Unix discovery. Test a concrete supported plugin/runtime profile instead of inventing a universal credential-provider minimum. [M5] [M6]

Organization-scoped and project-scoped feeds, upstream packages, packaging-read permissions, expired/revoked PATs, cached Entra credentials, unattended identity and unavailable vault/provider cases require isolated integration tests. PMU must not read Gerber's ADO PAT store or broaden its permissions automatically. Pipeline authentication tasks and provider environment variables remain deployment concerns; do not copy their secret values into Gerber configuration.

Provider support for v3 dependencies is evidenced, but transitive source selection and authentication must be qualified. Test that a private dependency cannot silently fall back to an unrelated public feed. If the standard engine cannot meet the chosen source policy, narrow supported scenarios or obtain a decision; do not introduce a custom resolver.

## 8. Distribution architecture comparison

Both alternatives keep PMU an independent project. Independence does not itself decide runtime versus build-time distribution.

| Concern | A. Lazy runtime module | B. Versioned build-time incorporation |
| --- | --- | --- |
| Consumer setup | Separate compatible PMU/provider installation when update is used | No separately installed PMU at runtime |
| Core startup | Independent if not in Gerber RequiredModules and not touched at import | Independent of external PMU, but incorporated code belongs to Core |
| Independent PMU releases | Compatible fixes usable without republishing consumers | Each consumer must refresh, rebuild and release |
| Offline behavior | Existing installation works; missing PMU blocks only update | Updater present, but discovery/install still needs a reachable source |
| Compatibility | Explicit API/range checks; loaded-version conflicts must fail clearly | Component-version lock and namespace compatibility checked at build |
| Failure isolation | Broken PMU can be repaired/replaced without replacing Gerber | Broken incorporated updater requires new Core/manual package repair |
| Security fix propagation | Central runtime release plus administrator/user adoption | Central source fix plus every consumer rebuild; pinned versions alone do not propagate it |
| Distribution/provenance | Ordinary signed/controlled package delivery and PMU manifest identity | Requires an immutable component artifact, hash/version, license notices and consumer provenance record |
| Nova build support | Normal PowerShell module integration; build tooling stays separate | No established external-component acquisition/incorporation feature found in the inspected builder |
| Command isolation | Two exported names; explicit import and command qualification | Consumer-private renamed functions/resources; collision/namespace transformation needs tests |
| Maintenance | One deployed API implementation; small consumer adapters | One maintained source, multiple deployed copies and refresh pipelines |
| Bootstrap/recovery | Additional optional dependency, repaired with standard commands | Fewer runtime components, but harder to replace updater independently |

If B were chosen, consumers would need a reviewed pinned PMU source/component package acquired during build, not a floating branch, Git submodule assumed present, runtime download or remotely evaluated script. Build integration would verify artifact identity/hash, retain upstream MIT notices, record PMU version in the consumer package, isolate all private symbols/resources, and run shared contracts against the incorporated result. Those mechanisms do **not** already exist merely because Nova concatenates project source files. [N14]

Do not implement both distribution modes to avoid choosing. Maintaining runtime and incorporated APIs/test matrices without a demonstrated consumer need defeats the goal of minimal integration.

## 9. Recommended distribution model

Choose **A: independently packaged PMU, loaded only for an explicit update operation**.

This better fits independent maintenance, adoption by modules beyond Gerber/Nova, ordinary PowerShell packaging and independent updater repair. The G-4A0 shared-source choice minimized initial bootstrap, but creates a component-distribution pipeline and ties fixes to consumer releases. Current evidence favors accepting a small optional setup cost instead of building that infrastructure.

The consumer's private dependency adapter should:

1. Run only when its update feature is invoked; no startup PMU discovery.
2. Inspect already loaded PMU/provider versions before choosing installed versions.
3. Select the highest installed **stable compatible** PMU version from an explicitly supported range, verify expected manifest identity and import its exact path.
4. Refuse an incompatible already-loaded version rather than unload/reload modules or binary dependencies mid-session.
5. Invoke the selected module's exported commands; never allow unrelated command shadowing to select the updater.
6. Explain missing/broken/incompatible dependencies using ordinary setup/repair instructions. No silent installation.

Gerber must not add PMU to `Manifest.RequiredModules`. PMU itself may declare its PSResourceGet minimum as an ordinary dependency and enforce its tested major/capability policy at operation time. Proposed initial provider compatibility is stable `>=1.2.0,<2.0.0`, **with actual supported versions limited to the tested matrix**, not a promise that all future 1.x releases work. No automatic PowerShellGet fallback or preview-provider selection.

After a stable PMU API exists, consumers should publish an explicit supported PMU major/range; do not invent a released PMU version or GUID in this report. Version compatibility, module identity and selected import path are checked locally, without a remote PMU update check.

Proposed repository layout, not created here:

```text
PSModuleUpdate/
  project.json                 # metadata if the Nova build toolchain is selected
  src/public/                  # Get-PSModuleUpdate, Install-PSModuleUpdate
  src/private/                 # identity, planning, provider and verification helpers
  tests/public/                # public command contracts
  tests/private/               # deterministic behavior and provider-adapter tests
  tests/integration/           # isolated feeds/module roots and consumer fixtures
  docs/                        # API help, support matrix, authentication and recovery
  examples/                    # minimal consumer integration, no private Core APIs
  LICENSE
  CHANGELOG.md
```

PMU may use Nova as pinned **development/build tooling** without requiring Nova at runtime. That does not create a runtime circular updater dependency. Toolchain selection is separate from the recommended runtime distribution model. Preserve Nova's MIT notices if substantial implementation is reused; final PMU license, ownership and package publication rights need approval. [N15]

## 10. PMU's own update strategy

**PMU does not automatically update itself, and updating Gerber does not first update PMU.**

Users/administrators install or update PMU through normal PSResourceGet commands from an approved source. Select a compatible version explicitly when recovering or when consumers impose an upper bound. An ordinary provider update may be used deliberately; there is no need to add a PMU-self-update command.

| State when `/update` is requested | Proposed response |
| --- | --- |
| Compatible PMU/provider installed | Lazy import and proceed |
| PMU missing | Explain that only update is unavailable; show reviewed standard installation guidance |
| PMU older than supported range | Explain supported range and standard upgrade path; no automatic bootstrap |
| PMU incompatible/newer major already active | Do not replace it in-process; use a compatible install in a fresh session |
| Broken PMU import | Preserve actionable context; recommend standard exact-version reinstall/repair without PMU |
| Provider missing/incompatible | Explain provider requirement; ordinary package/setup repair, no alternative package backend |
| Offline | Retain normal Gerber operation; setup/update remains unavailable until source access is restored |

For recovery, a fresh PowerShell process can run ordinary `Install-PSResource -Name PSModuleUpdate -Version <known-good> -Repository <approved> -Scope CurrentUser`, adding `-Reinstall` only when deliberate repair is required. This is design notation, not an executed command or a license/trust bypass. If PSResourceGet itself is unusable, use Microsoft's documented ordinary installation/recovery route or administrator-managed package deployment; do not require PMU to repair its provider.

No dependency is permitted to rely on successful PMU execution for its own manual repair. Gerber remains usable without the updater. No automatic recursive engine update, hot reload, startup download or circular bootstrap chain is necessary.

## 11. End-to-end update lifecycle

| Step | Contract |
| --- | --- |
| 1. Identify consumer | Consumer passes its actual active module object; PMU validates name/GUID/path and supported installation |
| 2. Determine active state | Read base version plus prerelease; independently inspect this target's installed copies and destination |
| 3. Discover | Resolve the one approved repository and call standard provider discovery with effective channel/range/authentication |
| 4. Select | Select newest eligible version greater than active; no implicit downgrade or channel-persistence change |
| 5. Plan | Return exact target/source/scope, identity, active/installed observations, prerequisite flags and disposition |
| 6. Approve | Consumer renders that plan and obtains its own user consent; PMU library uses native `ShouldProcess` for scripting |
| 7. Install | After preflight/consent, acquire a small PMU coordination lock, revalidate under it and delegate exact installation |
| 8. Verify | Check provider observations and installed manifest identity/full version/path/scope; do not import the target into the running consumer |
| 9. Report | Return verified installed state separately from unchanged active state, including any safely observed partial state on error |
| 10. Activate | User starts a fresh PowerShell session; PMU never forces a Core reload |

Discovery and installation can race with publication. Binding the plan to one exact top-level version is worthwhile and inexpensive because the provider already supports it. A newly published version does not invalidate an otherwise valid plan or authorize installing that newer version. If the approved version is removed/unavailable, fail explicitly; do not replace it with "latest".

Exact version is not an immutable-content guarantee: a private feed able to replace package bytes at the same version can undermine that expectation. Prefer immutable feed policy and controlled publishers. PMU must not claim package-content attestation merely because version/name/source match.

The lock coordinates **PMU attempts only**, keyed by validated module identity and canonical destination/scope. Use a short-lived OS-released mechanism with bounded waiting/fail-fast reporting, not a durable lock flag or transaction journal. Final cross-platform primitive is an implementation detail requiring tests. Other package tools do not honor it; revalidation/verification and recovery remain necessary.

## 12. Gerber integration design

### Existing infrastructure and integration points

Gerber's `Invoke-Gerber` initializes the command registry and runs its terminal loop. Core definitions and dispatch own command routing; handlers return a Boolean exit signal or null. A raw PMU plan/result must be captured and rendered, not accidentally returned as a handler result. `/update` is not presently registered. [G5] [G6] [G7]

Reuse the existing user configuration reader/path resolver/atomic writer, including `GERBER_CONFIG_PATH`, platform config paths, schema validation and preservation of unrelated fields. Missing configuration is not an error; corrupt configuration remains actionable rather than silently reset. No update-specific section is implemented today. [G8] [G9] [G10]

Propose an optional `updates` section with `channel`, and, for private deployments, validated `repository`/`repositoryUri`. Missing fields use Stable and the approved PSGallery endpoint. A preview choice for one operation must not silently persist a different channel. Do not add notification cadence, startup checks or preference-writing side effects to a read-only check.

The current CLI version helper reads the numeric module version and has a project-file fallback. Do not reuse it unchanged as prerelease-aware installed identity detection; capture the actual Core module object instead. Lazy Nova installation for `/plugins create` demonstrates optional-dependency UX, but `/update` must not install/update Nova or invoke plugin setup. [G11] [G12]

### Proposed user interaction

This is a **CLI slash-command** interaction, not PowerShell parameter syntax:

```text
/update

Checking Gerber updates from PSGallery...
Gerber <active> -> <target> (<channel>)
Source: https://www.powershellgallery.com/api/v2
Scope: CurrentUser
The new version will be available in a new PowerShell session.

1. Cancel
2. Install Gerber <target>
```

Use Gerber's shared confirmation helper with an explicit **cancel default**; its generic default is otherwise action. Bare Enter cancels. Esc returns locally, Ctrl+C remains clean, and recoverable errors stay in Gerber with owned messages. Show trust/license decisions separately if required, before the final exact install confirmation; do not hide them inside "update everything". [G13]

On success:

```text
Gerber <target> is installed.
This session is still running <active>.
Start a new PowerShell session to use the update.
```

If the target is already verified on disk, report that and restart guidance without reinstalling. If PMU is missing, show that only updating is unavailable and provide setup guidance; do not silently bootstrap or add a second unexplained consent action. Result-only views return to the root chooser after continue, not an automatic repeat install.

`/update` targets **Gerber Core only**. No plugin discovery/update pass, no Nova update, no changed approval GUIDs and no ADO/secrets dependency. Existing settings and plugin approvals remain outside versioned package directories. Plugin compatibility after a Core upgrade is a distinct product policy, not permission to update plugins automatically. [G14]

### Proposed PowerShell integration example

This is API design notation **inside a future consumer wrapper**, not Gerber source added by this task. Dependency selection, shared Gerber confirmation/rendering and recovery handling are intentionally not implemented here. Assume the wrapper has already loaded a verified compatible PMU module and obtained exact-action consent.

```powershell
$update = PSModuleUpdate\Get-PSModuleUpdate `
    -Module $ExecutionContext.SessionState.Module `
    -Repository 'PSGallery' `
    -Policy @{
        Channel = 'Stable'
        Scope = 'CurrentUser'
        ExpectedRepositoryUri = 'https://www.powershellgallery.com/api/v2'
    }

if ($update.Disposition -eq 'UpdateAvailable') {
    $result = PSModuleUpdate\Install-PSModuleUpdate `
        -Update $update `
        -Confirm:$false
}
```

The module object must be captured in Gerber's scope; evaluating the same expression inside PMU would identify PMU, not Gerber. The example omits trust/license switches deliberately: those permissions cannot be inferred from the existence of an update or `-Confirm:$false`. A PowerShell automation consumer can use native `-WhatIf`/`-Confirm` instead of Gerber's custom confirmation; Gerber avoids a redundant native install prompt only after its own consent.

### PowerShell cmdlet UX design review

| Principle/heuristic | Proposed PMU cmdlet decision |
| --- | --- |
| Atlassian 1: established conventions | Approved verbs, named parameters, native streams |
| Atlassian 2: built-in help | Command help with source/authentication/recovery examples |
| Atlassian 3: visual progress | Provider/PMU phase progress, suppressed in noninteractive use |
| Atlassian 4: reaction for actions | Explicit plan/result/cancel outcomes |
| Atlassian 5: readable errors | Stable ErrorRecord identifiers and safe context |
| Atlassian 6: skim reading | Structured objects, no banner |
| Atlassian 7: next best step | Restart or exact manual recovery guidance |
| Atlassian 8: useful options | Validated declarative policy; no custom prompt callbacks |
| Atlassian 9: easy exit | WhatIf/Confirm and cancellation semantics |
| Atlassian 10: flags over args | Named parameters, not positional package specifications |
| Nielsen 1: visible status | Separate active/installed/verification state |
| Nielsen 2: real-world language | "Installed" is distinct from "active" |
| Nielsen 3: user control | No automatic bootstrap/reload |
| Nielsen 4: consistency | Stable object/error contracts |
| Nielsen 5: error prevention | Exact plan and source/identity checks |
| Nielsen 6: recognition | Inspectable plan and named fields |
| Nielsen 7: efficient use | Two operations and native automation |
| Nielsen 8: minimalism | No registration/framework |
| Nielsen 9: recovery | Explicit partial-state and repair context |
| Nielsen 10: documentation | API/authentication/recovery help |

Cmdlet risks under Atlassian 8/9 and Nielsen 3/5 are unexpected provider/vault prompts and confirmation bypasses. Preflight prerequisites, require explicit noninteractive permissions and keep native install consent distinct from trust/license decisions. Under Nielsen 1/2, success wording must distinguish installed and active versions.

### Gerber slash-command UX design review

| Principle/heuristic | Proposed Gerber CLI decision |
| --- | --- |
| Atlassian 1: established conventions | Existing registry/menu model; no invented shell flags |
| Atlassian 2: built-in help | `/help` and `/update` guidance |
| Atlassian 3: visual progress | Checking/installing/verifying states |
| Atlassian 4: reaction for actions | Visible up-to-date, cancel, success and failure views |
| Atlassian 5: readable errors | Gerber-owned message plus next action |
| Atlassian 6: skim reading | Short identity/source/scope summary |
| Atlassian 7: next best step | New-session/setup guidance |
| Atlassian 8: useful options | Visible cancel/default and explicit channel |
| Atlassian 9: easy exit | Cancel-default, Esc/back, clean Ctrl+C |
| Atlassian 10: flags over args | No positional package/source arguments in initial slash flow |
| Nielsen 1: visible status | Progress and truthful completion |
| Nielsen 2: real-world language | "Start a new PowerShell session" |
| Nielsen 3: user control | Explicit consent and local cancellation |
| Nielsen 4: consistency | Existing menu and continue routing |
| Nielsen 5: error prevention | Display exact target, source and scope |
| Nielsen 6: recognition | Choices shown before confirmation |
| Nielsen 7: efficient use | One direct Core command |
| Nielsen 8: minimalism | No plugin/module inventory |
| Nielsen 9: recovery | Stay in loop with actionable safe guidance |
| Nielsen 10: documentation | In-product help and setup instructions |

CLI risks under Atlassian 1/9 and Nielsen 3/4 are provider prompts escaping Gerber's menu and duplicate confirmation. Correct them through separated prerequisite decisions, one final Gerber install consent and tested provider invocation. Under Nielsen 1/2, use the proposed installed/active wording rather than "Gerber is now running the update".

These are separate surface-specific design reviews, **not executed terminal acceptance**; future PTY/tracer evidence is required.

## 13. NovaModuleTools migration design

### Preserve the external contract first

Nova's actual public command is `Update-NovaModuleTool` with legacy alias `Update-NovaModuleTools`; its source filename is `UpdateNovaModuleTools.ps1`. Keep those names, CLI routing, preference commands/path, notification triggers, prerelease consent and `ShouldProcess` behavior unless separately approved. Its existing provider is PowerShellGet, while publishing already uses PSResourceGet; do not conflate the stores or assume equivalent installation provenance. [N1] [N2] [N16]

After successful Gerber validation, Nova's wrapper can pass its active module plus effective settings to PMU and adapt PMU plan/results into the legacy observable contract. The current saved Boolean enables prerelease notifications **and update eligibility**, default true. Translate that meaning deliberately, not to Gerber's Stable default.

PMU's greatest-eligible-version rule can differ from Nova's current prerelease-first branch. Exact target/source binding, explicit scope, installed verification, already-installed/restart handling and richer errors are also observable changes. Preserve existing UX/fields wherever sound, but approve and test changed semantics rather than claim a perfectly behavior-preserving replacement.

### Replace versus retain

| Replace after migration qualification | Retain in Nova |
| --- | --- |
| Raw Find-Module lookup script/runspace plumbing where PMU covers the approved check behavior | Build/scaffold notification triggers and notification presentation |
| Nova-only copies of generic version/eligibility/update-plan orchestration | Public update command/alias, CLI routing and ShouldProcess adaptation |
| `Invoke-NovaModuleSelfUpdate` and its Update-Module adapter when no callers remain | Preference Get/Set commands, settings path and existing meaning |
| Generic install/error/completion state now supplied by PMU | Nova-specific release notes, project guidance and consumer-facing messages |

No redundant code is removed until callers, built-module tests and notification paths use the replacement. Do not remove general shared-resource helpers used elsewhere merely because the updater stops using them.

### Migration sequence and regression evidence

1. Complete Gerber's PMU release qualification first; capture the supported PMU/provider contract.
2. Run Nova's existing behavior tests green before refactoring; characterize affected public results, lookup timeouts, notifications, approval and error behavior.
3. Introduce the optional PMU dependency adapter and wrapper mapping in a separately approved task. Preserve normal Nova operation without PMU; acknowledge that its update command may now need optional setup where the old updater worked without PMU.
4. Validate PowerShellGet-installed Nova copies with the PSResourceGet-based exact-install path, full prerelease identity and supported scope. Do not silently switch an AllUsers or custom deployment to CurrentUser.
5. Retain legacy result fields where meaningful, map `Updated` only after verified install, and publish intentional differences. Fetch/display release notes separately so a notes failure cannot erase an installation outcome.
6. Remove redundant updater implementation only after replacement evidence passes. Release migration guidance and standard recovery commands.

Existing public tests cover no-update, preview cancellation, execution, release-note summary and WhatIf; the built-module integration test verifies the alias and permits the expected Gallery-unavailable error. That integration test is not proof of successful real installation. Keep applicable public assertions and add isolated real provider contracts, not only mocked PMU calls. Adapter-specific Update-Module assertions will be replaced with exact PMU/provider-contract checks when that adapter is intentionally removed, without weakening public behavior assertions. [N10] [N17] [N18]

Additional migration cases: stable/prerelease ordering differences, same-base preview replacement, already installed but inactive target, PMU/provider absence or incompatible loaded versions, separate repository stores, corrupt preference compatibility, timeout/offline notifications, and post-install notes failure. A changed error ID/result schema requires compatibility mapping or explicit release approval, not silent substitution.

The initial PMU API has no notification scheduler or custom lookup-deadline parameter. Nova's short notification deadline must not disappear because the backend changes: retain/adapt its bounded execution wrapper to call PMU until equivalent cancellation/timing is proven. A provider's normal request timeout is not automatically equivalent to Nova's 3-second notification budget or 10-second explicit lookup budget. This is a consumer-specific integration requirement, not grounds to add a scheduling framework to PMU.

## 14. Security and recovery considerations

| Concern | Proposed control and honest limit |
| --- | --- |
| Wrong consumer | Active module object, literal name, GUID and path checks; reject ambiguous/source-imported cases. GUID is identity metadata, not a publisher signature |
| Wrong source | Expected URI where supplied, source snapshot/revalidation, no repository wildcard or fallback. Does not protect against a compromised approved feed |
| Trust/authenticity | Trust flag suppresses a repository consent prompt; it is not package signing, publisher approval or content integrity proof |
| Package authenticity | Use standard provider checks and controlled publishers/immutable feeds. Windows Authenticode checking is platform-specific, not a cross-platform authenticity guarantee. Stronger policy requires an explicit requirement and evidence |
| Credentials | Provider/vault-owned authentication, least-privilege read credentials, no secrets in plans/config/logs. Sanitization must include provider diagnostics |
| Target drift | Exact top-level version; revalidate name/source/policy under the lock. Does not freeze every transitive dependency or stop feed-side byte replacement |
| Concurrent attempts | Small process-safe PMU coordination lock plus state rechecks. External package tools remain uncoordinated |
| Permissions/scope | Explicit CurrentUser-first support; no elevation, forced overwrite or silent user-scope shadowing of AllUsers |
| Imported module/files | Do not unload/reload the running consumer or its dependencies; preserve active version reporting and require a new session |
| Interrupted/partial install | Stop on provider errors, inspect safely observable state and report partial target/dependencies. No success because a folder exists; no blind deletion/reinstall |
| Coexisting versions | Preserve known-good older numeric versions; do not clean them up as part of update |
| Preview directory reuse | Different prerelease labels may share one numeric folder. Detect likely same-directory/in-use replacement and return ActionRequired pending a proven safe path |
| Rollback | No automatic transactional rollback. Standard exact known-good reinstall/fresh-session import is recovery, not guaranteed restoration of all filesystem/dependency effects |
| Network/offline | Explicit discovery/install error, no false no-update result, no cross-feed fallback; ordinary consumer use remains available |

PowerShellGet documents same-base prerelease directory reuse. Do not assume PSResourceGet behaves safely or identically under every in-use transition; qualify it before promising preview updates. For unsafe same-directory transitions, the initial policy is to stop Gerber and perform ordinary exact installation from another session, not build a helper executable or deferred transaction engine. [M10]

Successful install verification means observed manifest identity/full version/destination match. It does not prove every file is healthy or every future import succeeds. Qualification includes a fresh-process import smoke test; production PMU must not execute arbitrary updated module initializers inside the consumer just to claim verification.

On failure, provide a reviewed manual command with exact name/version/repository/scope and no embedded credentials. Explain whether the old active session remains usable, which target is incomplete/unknown and when a fresh process is needed. Reinstall/cleanup is a deliberate operator action; retain settings and approvals. Dependency installation can have partial effects even when the top-level update fails.

This is an architecture risk analysis, not a penetration test or a claim that current Nova/Gerber installations were exploited. No live interruption, locking, credential or package-integrity test was performed.

## 15. Compatibility and test strategy

### Evidence versus proposed support

| Area | Evidence now | Required before a PMU support claim |
| --- | --- | --- |
| PowerShell 7.4 | Both consumers target 7.4; official provider release history supports it | Run PMU contracts on actual 7.4, not only a newer local host |
| Windows/macOS/Linux | Providers document cross-platform operation; stable tests include platform-specific scope cases | Isolated install, verification, cancellation and recovery matrix on all three |
| PSResourceGet 1.2.0 | Stable release/source supports exact versions, v3 dependencies and Azure provider integration | Execute adapter contracts against that version; extend matrix for later stable versions |
| Public PSGallery | Standard documented reference source | Controlled integration plus explicit authorized smoke testing; no developer-store mutation |
| Private v2/v3 feeds | Provider capability and stable source/tests | Representative controlled repository, auth and transitive-dependency contracts |
| Azure Artifacts | Documented integration and stable credential-provider source | Real isolated feeds with approved credentials and tested plugin/runtime profiles |
| Same-base previews/in-use files | Known layout risk; provider-specific safety unverified | Windows locking and Unix behavior, path reuse, interruption and manual recovery tests |
| AllUsers/custom layouts | Provider supports scopes, but PMU policy/permissions not qualified | Initially reject; separately approve and qualify before enabling |

### Required suites

| Suite | Focused observable scenarios |
| --- | --- |
| Deterministic identity/planning | Active versus highest-installed; correct GUID/path; stable/preview precedence; no downgrade; ranges; four-part versions/normalization; malformed source/policy |
| Public API/streams | One plan/result, native WhatIf/Confirm, no accidental pipeline output, rejected deserialized/invalid plan, no secret serialization |
| Provider contracts | Exact stable/preview install; source binding/repoint; scope; declared dependencies; trust/license behavior; no install on WhatIf; provider errors |
| Idempotency/concurrency | Already verified target no-op, wrong/incomplete target not success, duplicate PMU processes, external installer interference |
| Failure/recovery | Offline/auth/permissions, process interruption, partial dependency/target installation, locked files, exact manual repair without PMU |
| Bootstrap/isolation | Consumer starts/works with missing/broken PMU, incompatible loaded provider/PMU, explicit import path and command shadowing |
| Gerber integration | Core-only target, settings/approvals preserved, result consumed by handler, default Enter cancel, Esc/back, Ctrl+C, recoverable errors |
| Nova migration | Existing public/CLI/preference behavior, intentional selection changes, PowerShellGet-origin installation, notifications and notes after install |

Use disposable module roots, repositories and processes; do not update a developer's real Gerber/Nova installation to obtain evidence. Private-feed tests require separate access/authorization. Validate installed artifacts as well as source mocks; declarations and mocked adapter calls do not prove platform/authentication support.

Future implementation follows repository test-first requirements: red/green for new PMU/Gerber behavior, green characterization before Nova restructuring, preserved public assertions, and current measured code quality for touched supported code. Gerber's quality wrappers remain ScriptAnalyzer, build/unit/integration and the full terminal gate. `/update` needs registry-derived discovery/dispatch/workflow/navigation/rendering/error coverage plus actual happy/cancel/recovery traces with `GERBER_PROMPT_TRACE=1`; a design checklist is not those executions.

### This task's verification boundary

Only report structure, local references, formatting and unchanged write scope are validated here. Application/provider tests, real feeds, runtime examples, PTY traces and cross-platform installation remain **unverified**, because no implementation or live update was authorized. ScriptAnalyzer/build/CodeScene code scoring are **not applicable** to this prose-only deliverable; no supported code was modified and no executable example is part of the project's test/build flow.

README, contribution guidance, changelog and release notes were reviewed. They remain unchanged because this task creates no released command, setting or workflow. PLAN, ARCHITECTURE, DECISIONS and G-4A0 are preserved rather than edited to imply approval.

## 16. Proposed implementation phases

These phases describe separately authorized follow-on work, not execution started by this report.

| Phase | Deliverable | Exit evidence |
| --- | --- | --- |
| 0. Approve design | Decide API, runtime model, ownership/license, support/scope, trust and recovery policy | Decisions in section 17 recorded; no repository created by inference |
| 1. Provider qualification | Disposable PSResourceGet 1.2.0 spike and minimal identity/selection fixtures | Exact version/source/scope, private v2/v3/Azure auth, dependency and preview/path evidence; revise design if standard provider cannot meet it |
| 2. Independent PMU implementation | Authorized PMU project, two commands, validated plan/results, narrow provider adapter and recovery docs | Test-first public contracts, isolated install/failure matrix, compatible packaging/help and measured quality; no consumer migration yet |
| 3. Gerber reference integration | Core-only `/update`, lazy dependency selection, existing config/UI and fresh-session guidance | Core works without PMU; deterministic/built-module/provider integration, PTY inventory/coverage and actual trace acceptance |
| 4. Gerber qualification and release | Supported PMU/provider/platform/auth matrix and operational recovery evidence | Approved support claims, no startup/runtime dependency leak, no plugin/Nova updates; explicitly authorize any publication separately |
| 5. Nova migration | Preserve wrappers/preferences, map results, remove redundant updater only after replacement passes | Green characterization then replacement evidence, origin/provider compatibility and notification regressions; approved release differences |
| 6. Broader adoption | Minimal consumer example and supported contract documentation | A non-Gerber/Nova fixture integrates without private APIs, callbacks or consumer configuration dependencies |

The order is deliberate: Nova is not the extraction guinea pig, and a public release does not occur merely because local tests pass.

## 17. Open decisions requiring approval

| Decision | Recommendation | Consequence before coding |
| --- | --- | --- |
| Build versus adopt | Build only thin PMU orchestration over PSResourceGet | Approve independent maintenance cost; reopen if a complete suitable existing library emerges |
| Distribution | Lazy runtime module only, not incorporation | Accept optional setup cost; no dual distribution implementation |
| API/identity | Get/Install pair, explicit active PSModuleInfo, no registration/callbacks | Approve departure from illustrative name-only syntax; actual module/command names rechecked before publishing |
| Foundation/support | Stable PSResourceGet 1.2.0 minimum and qualified stable 1.x versions | Approve provider qualification matrix and dependency setup policy; no preview/fallback backend |
| PMU compatibility/bootstrap | Consumer-owned supported range, explicit lazy import; manual setup/repair | Decide supported PMU major once API stabilizes; no automatic PMU self-update |
| Scope/provenance | CurrentUser-first, block AllUsers/mixed/custom/source builds | Accept manual guidance for unsupported deployments or fund separate qualification |
| Channel and major upgrades | Gerber Stable default; IncludePrerelease explicit; no downgrade; range when a major ceiling is needed | Decide whether initial Gerber policy permits all newer majors or supplies a compatibility ceiling |
| Source/authentication | Registered HTTPS NuGet feeds, expected endpoint in Gerber, provider-owned credentials | Approve private-feed configuration exposure and supported Azure credential profiles |
| Trust/license/authenticity | Explicit separate permissions; no implicit trust/license changes or universal signing claim | Decide whether stronger publisher authenticity is a release prerequisite |
| Recovery/preview policy | No automatic rollback; retain older numeric versions; block unsafe in-use same-folder replacement | Accept manual exact-version recovery and external-session preview transitions where necessary |
| Nova compatibility | Preserve public commands/preferences first; approve intentional selection/scope/error changes later | Migration only after Gerber validation, with explicit legacy-result mapping |
| Ownership/license | Independent maintainers/repository; preserve MIT notices; choose final PMU license explicitly | Assign security-fix/release/support ownership and publication rights |

**Stop condition:** G-4A1 ends with this report. No PSModuleUpdate repository/module, Gerber `/update`, Nova migration, runtime dependency, pipeline change, commit, push or publication is authorized by the design.

## Source references

Reference groups below identify actual inspected implementation and documentation. Nova links point to the sibling checkout; external findings are dated research, not perpetual maintenance/support claims.

### Gerber

- **G1:** [PLAN.md](../../PLAN.md), G-4A/Core roadmap.
- **G2:** [ARCHITECTURE.md](../../ARCHITECTURE.md), Core/CLI/plugin boundaries.
- **G3:** [DECISIONS.md](../../DECISIONS.md), existing product decisions.
- **G4:** [project.json](../../project.json), version, GUID, runtime and dependencies.
- **G5:** [Invoke-Gerber.ps1](../../src/public/Invoke-Gerber.ps1), startup/registry lifecycle.
- **G6:** [Get-GerberCoreCommandDefinitionList.ps1](../../src/private/cli/Get-GerberCoreCommandDefinitionList.ps1), Core command inventory.
- **G7:** [Invoke-GerberRegisteredCommand.ps1](../../src/private/cli/Invoke-GerberRegisteredCommand.ps1), handler result contract.
- **G8:** [Get-GerberUserConfiguration.ps1](../../src/private/config/Get-GerberUserConfiguration.ps1), read/default/error behavior.
- **G9:** [Save-GerberUserConfiguration.ps1](../../src/private/config/Save-GerberUserConfiguration.ps1), atomic replacement.
- **G10:** [Resolve-GerberUserConfigPath.ps1](../../src/private/config/Resolve-GerberUserConfigPath.ps1), override/platform paths.
- **G11:** [Initialize-GerberCommandRegistry.ps1](../../src/private/cli/Initialize-GerberCommandRegistry.ps1), current display-version helper.
- **G12:** [Confirm-GerberPluginDevelopmentTool.ps1](../../src/private/plugins/Confirm-GerberPluginDevelopmentTool.ps1), optional Nova tooling precedent.
- **G13:** [Read-GerberConfirmationPrompt.ps1](../../src/private/cli/Read-GerberConfirmationPrompt.ps1), explicit action/cancel default.
- **G14:** [Plugin API v1 capabilities](plugin-api-v1-capabilities.md) and [plugin creation](../plugins-create.md), independent plugin/development boundaries.

### NovaModuleTools

- **N1:** [UpdateNovaModuleTools.ps1](../../../NovaModuleTools/src/public/UpdateNovaModuleTools.ps1), public name/alias/approval.
- **N2:** [GetNovaModuleSelfUpdateWorkflowContext.ps1](../../../NovaModuleTools/src/private/update/GetNovaModuleSelfUpdateWorkflowContext.ps1), explicit lookup/preference/plan orchestration; additional trigger/timeout evidence is catalogued in [G-4A0](G-4A0-shared-self-update-analysis.md#appendix-a-source-evidence).
- **N3:** [GetNovaInstalledModuleVersionInfo.ps1](../../../NovaModuleTools/src/private/update/GetNovaInstalledModuleVersionInfo.ps1), active semantic version.
- **N4:** [ModuleUpdateLookup.ps1.txt](../../../NovaModuleTools/src/resources/update/ModuleUpdateLookup.ps1.txt), standard Find-Module discovery.
- **N5:** [GetNovaModuleSelfUpdatePlan.ps1](../../../NovaModuleTools/src/private/update/GetNovaModuleSelfUpdatePlan.ps1), candidate selection.
- **N6:** [ConvertToNovaModuleSelfUpdatePlan.ps1](../../../NovaModuleTools/src/private/update/ConvertToNovaModuleSelfUpdatePlan.ps1), plan/result fields.
- **N7:** [InvokeNovaModuleSelfUpdate.ps1](../../../NovaModuleTools/src/private/update/InvokeNovaModuleSelfUpdate.ps1), installation adapter entry.
- **N8:** [InvokeNovaModuleUpdateCommand.ps1](../../../NovaModuleTools/src/private/update/InvokeNovaModuleUpdateCommand.ps1), raw standard Update-Module boundary.
- **N9:** [InvokeNovaModuleSelfUpdateWorkflow.ps1](../../../NovaModuleTools/src/private/update/InvokeNovaModuleSelfUpdateWorkflow.ps1), install errors, completion and release notes.
- **N10:** [UpdateNovaModuleTools.Tests.ps1](../../../NovaModuleTools/tests/public/UpdateNovaModuleTools.Tests.ps1), public workflow/WhatIf/cancel tests.
- **N11:** [ReadNovaUpdateNotificationPreference.ps1](../../../NovaModuleTools/src/private/update/ReadNovaUpdateNotificationPreference.ps1), default/read behavior.
- **N12:** [Get-NovaUpdateNotificationPreference help](../../../NovaModuleTools/docs/NovaModuleTools/en-US/Get-NovaUpdateNotificationPreference.md) and [Set-NovaUpdateNotificationPreference help](../../../NovaModuleTools/docs/NovaModuleTools/en-US/Set-NovaUpdateNotificationPreference.md), consumer preferences.
- **N13:** [GetResourceFilePath.ps1](../../../NovaModuleTools/src/private/shared/GetResourceFilePath.ps1), resource resolution; [G-4A0](G-4A0-shared-self-update-analysis.md) traces the lookup resource callers.
- **N14:** [BuildModule.ps1](../../../NovaModuleTools/src/private/build/BuildModule.ps1), project source assembly, not a component-acquisition feature.
- **N15:** [LICENSE](../../../NovaModuleTools/LICENSE) and [project.json](../../../NovaModuleTools/project.json), licensing/runtime/dependencies.
- **N16:** [Update-NovaModuleTools help](../../../NovaModuleTools/docs/NovaModuleTools/en-US/Update-NovaModuleTools.md) and [README](../../../NovaModuleTools/README.md); publishing/provider-store evidence is catalogued in [G-4A0](G-4A0-shared-self-update-analysis.md#appendix-a-source-evidence).
- **N17:** [UpdateNovaModuleTools.Integration.Tests.ps1](../../../NovaModuleTools/tests/public/UpdateNovaModuleTools.Integration.Tests.ps1), built alias/WhatIf with permitted lookup failure.
- **N18:** [GetNovaModuleSelfUpdatePlan.Tests.ps1](../../../NovaModuleTools/tests/private/update/GetNovaModuleSelfUpdatePlan.Tests.ps1) and [InvokeNovaModuleUpdateCommand.Tests.ps1](../../../NovaModuleTools/tests/private/update/InvokeNovaModuleUpdateCommand.Tests.ps1), planning and provider delegation tests.

### Microsoft and provider evidence

- **M1:** [PSResourceGet release notes](https://learn.microsoft.com/en-us/powershell/gallery/powershellget/psresourceget-release-notes?view=powershellget-3.x) and [stable v1.2.0 release](https://github.com/PowerShell/PSResourceGet/releases/tag/v1.2.0).
- **M2:** [Install-PSResource reference](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/install-psresource?view=powershellget-3.x), including the live v3-dependency warning; [Find-PSResource](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/find-psresource?view=powershellget-3.x).
- **M3:** [Stable 1.2.0 v3 installation tests](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/test/InstallPSResourceTests/InstallPSResourceV3Server.Tests.ps1), exact versions, prerelease, dependency count and manual trust/license cases.
- **M4:** [Register-PSResourceRepository](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/register-psresourcerepository?view=powershellget-3.x), repository APIs, CredentialInfo and Azure provider selection.
- **M5:** [Stable 1.2.0 CredentialProvider.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/CredentialProvider.cs), actual discovery and noninteractive invocation.
- **M6:** [Azure Artifacts Credential Provider documentation](https://github.com/microsoft/artifacts-credprovider), [v2.0.5 release](https://github.com/microsoft/artifacts-credprovider/releases/tag/v2.0.5) and [v1.3.0 .NET 8 release](https://github.com/microsoft/artifacts-credprovider/releases/tag/v1.3.0).
- **M7:** [PowerShellGet Update-Module](https://learn.microsoft.com/en-us/powershell/module/powershellget/update-module?view=powershellget-2.x), provenance/version/scope behavior.
- **M8:** [PowerShellGet 2.2.5 Gallery metadata](https://www.powershellgallery.com/packages/PowerShellGet/2.2.5) and [legacy PowerShellGet repository](https://github.com/PowerShell/PowerShellGetv2).
- **M9:** [Approved PowerShell verbs](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands). Name searches used public Gallery package lookup and indexed GitHub repository/code search; no reservation was made.
- **M10:** [PowerShellGet prerelease module support](https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support?view=powershellget-2.x), numeric-directory/prerelease coexistence limits.

### Other investigated projects

- **T1:** [ModuleFast project/README](https://github.com/JustinGrote/ModuleFast), [v0.6.1 release](https://github.com/JustinGrote/ModuleFast/releases/tag/v0.6.1) and repository LICENSE.
- **T2:** [MaintainModule project/README](https://github.com/rwidmark/MaintainModule) and [Gallery package](https://www.powershellgallery.com/packages/MaintainModule).
- **T3:** [AzureArtifactsPowerShellModuleHelper project/README](https://github.com/deadlydog/AzureArtifactsPowerShellModuleHelper) and [Gallery 2.4.9](https://www.powershellgallery.com/packages/AzureArtifactsPowerShellModuleHelper/2.4.9).
- **T4:** [PSModuleUpdater](https://github.com/DeanAmiridis/PSModuleUpdater).
- **T5:** [PoSh-SelfUp-Module](https://github.com/KSchu26/PoSh-SelfUp-Module).
