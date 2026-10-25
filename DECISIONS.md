# Gerber — Product and Architecture Decisions

> Reconstructed 2026-10-10 from the user's explicit statements, supplied screenshots, G-1A.md and G-1A_response.md. **This is a working reconstruction, not a verbatim recovery of every prior chat.** Explicit user decisions override older G-1A proposals. No repository was changed.

## Decision status legend
- **DECIDED** — explicitly stated by the product owner.
- **DESIGN DETAIL OPEN** — direction decided; exact implementation remains to be specified.
- **HISTORICAL** — previous option, superseded.

### D-001 — Product and compatibility (DECIDED)
Gerber is a free, proprietary, extensible, agent-first PowerShell product intended for public distribution at 1.0.0. Before 1.0.0 there is only one user and one installation to consider; breaking changes are allowed. Do not add migrations, compatibility shims, or legacy behavior solely to preserve pre-1.0 installations. The private Core repository may publish its compiled/distributed PowerShell module publicly through PowerShell Gallery.

### D-002 — Core boundary (DECIDED; Nova restriction superseded 2026-10-24)
Core is usable without Gerber.ExampleOrg, any other plugin, ADO or a PAT. Plugins extend Core through the public Plugin API, not private Core functions. Generic Core features need not be moved to plugins simply to minimize Core's size. Gerber.ExampleOrg is a consumer, never a Core dependency.

**Historical wording:** the 2026-10-10 reconstruction said "Core is fully usable without Gerber.ExampleOrg, any other plugin, ADO, PAT, or NovaModuleTools." It recorded Core independence alongside public-only plugin integration; it did not record a separate rationale for excluding Nova. The project owner's current decision **supersedes only the NovaModuleTools exclusion**, not the other boundaries above. Both NovaModuleTools and PSModuleUpdate are required runtime dependencies through `RequiredModules`: Nova supports Gerber's plugin-development functionality, and PMU supplies generic update mechanics. See D-017 and [G-4A5](docs/architecture/G-4A5-update-architecture.md#11-historical-reconciliation). Required dependency resolution does not require Nova build/package/publish operations on every startup.

### D-003 — Plugin identity and approvals (DECIDED)
The PowerShell module manifest GUID is the permanent plugin identity. Persistent user configuration stores approved GUIDs. An unknown discovered plugin requires explicit user approval before executing its plugin code. Once approved, a GUID stays approved through subsequent versions/upgrades; do **not** require approval on every routine update. Names and command namespaces are distinct from GUID identity. GUID alone is an identifier, not cryptographic proof of publisher or code integrity.

Implemented G-3A1 / G-3A2 detail: Core reads candidate manifests with
`Import-PowerShellDataFile`, validates the GUID before import, and stores normalized
GUIDs in `plugins.approved` within schema-version-1 user configuration. Declined
decisions persist under `plugins.declined`; association records under
`plugins.associated` retain an `enabled` Boolean. Approval defaults to decline.
Noninteractive startup skips unknown GUIDs and never autoapproves them.
New approvals associate and enable immediately; legacy approvals gain that record
on rediscovery. Disabled plugins remain approved and associated but are not
imported or registered. Read-only list/info inspect lifecycle state without
importing additional plugin code. Enable/disable and create reuse that lifecycle;
publisher authentication, signatures, hash pinning and revocation feeds remain
outside it.

G-3D1-FIX1 stores optional generated `name` and initial `version` alongside
`enabled` in the GUID-keyed association, in the same persistence operation.
These values are display fallback only while no installed/loaded metadata is
available; manifest metadata wins after discovery. Older records need no
migration. List/info remain read-only and never import/install/approve.

### D-004 — Gerber-generated plugin auto-approval (DECIDED)
`/plugins create` creates a unique manifest GUID, generates and validates a working plugin, then records that GUID as approved, associates the plugin with Gerber and enables it, without an additional approval prompt. Only commit registration/approval after successful generation, build, tests and Core integration. A failed generation must not leave a partially approved plugin or destroy pre-existing files.

### D-005 — Enable, disable, remove and revoke (DECIDED intent; runtime details OPEN)
- **Enable:** make an associated approved plugin's functionality available.
- **Disable:** make its functionality unavailable without removing approval or uninstalling the PowerShell module. The persisted disabled state must survive restart and must block module import plus command registration, not merely hide commands after load.
- **Remove:** disconnect plugin from Gerber, remove its registrations and its approval, but **do not uninstall the PowerShell module from the computer**.
- **Revoke:** remove/flag approval, but retain the plugin's registry association and offer a security warning, allowing the user to decide whether to continue using it. The user explicitly rejects silently treating revoke as uninstall/remove or unconditional permanent blocking.
- Future centrally supplied compromised-GUID warnings/revocation information are envisioned. **OPEN:** precise user override workflow, persistence, command reachability and security semantics; no claim that a removed approval alone is safe if execution is still allowed.

### D-006 — Advanced plugin trust (DEFERRED)
Future certificate/signature/publisher-based preapproval, potentially for trusted vendors, is an idea, not a current implementation requirement. Do not replace GUID-based persistent approval with per-update hash reapproval now. Revisit publisher authentication and GUID spoofing risks before public distribution.

### D-007 — Gerber plugin administration (DECIDED)
Use the existing slash-command model. `/plugins` is the management entry point; list/info, enable/disable and create are implemented. G-3C4 needs no separate approve command because selecting `/plugins enable` explicitly approves a declined plugin. Remove, explicit decline and revoke management are not Core 1 scope; `install` and `update` remain future capabilities. Gerber manages availability inside Core, not necessarily OS-level module installation. Avoid command namespace collisions and silent last-loaded-wins behavior. Keep **declined**, **disabled**, and future **revoked** semantics distinct.

### D-008 — Plugin creation experience (DECIDED)
`/plugins create` asks for the module **suffix only**, behind an immutable `Gerber.` prefix (`MyCompany` → `Gerber.MyCompany`), description, real unused command namespace (`mycompany`), and destination **parent**, defaulting to cwd with a new `Gerber.MyCompany` child. It rejects invalid/traversal input and existing destinations, permits correction, and uses shared Escape navigation. Gerber owns plugin-specific templates; Nova provides build/test/package/publish, not a new generic generator. The existing creation handler checks Nova availability on invocation and offers installation with consent if missing; declining leaves files and approval unchanged. This handler safeguard does not make Nova optional at module import: D-017 supersedes that implication of the earlier lazy-tooling description.

G-3D1 generates a working Plugin API v1 project with one new permanent manifest GUID, Get-GerberPlugin, functional `/mycompany hello`, unit/public API registration integration tests, README and version/changelog metadata. Nova generates the manifest/module root from project.json; no source psm1/psd1 is authored. Build/tests and actual Core registration must pass in staging before finalization and GUID approval/association/enabling. Creation itself does not install/load the module; local publish and next-start discovery use the same approved GUID without another prompt. No ADO, PAT or customer dependencies are required.

G-3D1-FIX1 uses a clear introduction and separated field headings, explanations,
examples and live cwd/child defaults through the existing UI. Completion states
actual Name, Version, Namespace, Location, Approval, Association, Enabled and
Installed (No), with a safely quoted PowerShell location, local publish, restart
and hello guidance. Preserve recovery/cancellation and avoid extra confirmation.
Only `Manifest.GUID` appears in project identity metadata; remove the redundant
`PrivateData.Gerber.Guid` while retaining the public definition's matching GUID.
The generated changelog uses the requested introduction and all six standard
Unreleased categories, with the real namespaced hello under Added.

### D-009 — Agent-first scaffolding (DECIDED)
Generated plugins must include local, usable AI-agent guidance (AGENTS.md and relevant agent/skill instructions) sufficient for a coding agent to understand architecture, public Plugin API, commands, build, test and versioning without repeatedly asking the developer. Do not duplicate all Core documentation or assume all coding agents share discovery conventions.

G-3E1 implements that hierarchy: canonical agent-neutral AGENTS.md; short
CLAUDE.md and Copilot bridges; three path-scoped instruction files; one plugin
developer role; three skills for command changes, public capabilities and Nova
lifecycle validation. The guide embeds only the necessary public API contract
and real generated-example workflow, not private Core dependencies or fictitious
CI tooling. Role definitions describe ownership; skills describe actionable steps.

### D-010 — Credentials architecture (DECIDED; supersedes G-1A options)
The chosen implementation is a Core-owned credential abstraction backed currently by **Devlooped CredentialManager** and OS credential storage (macOS Keychain verified). Plugins call Gerber's Secrets API; they do not depend on the backend. Credential identities for plugins are namespaced by plugin GUID. Gerber's UI should show Gerber terminology and credential names, **not vendor/backend branding** in every result. Documentation may identify dependency and version. The earlier SecretManagement/SecretStore plus environment-variable-PAT design is historical, not the active target.

### D-011 — Secrets and ADO UX (DECIDED)
Gerber should retrieve PAT through its credential abstraction, prompting securely only when missing/invalid, with lazy ADO setup and persistent user-specific config. Never put raw PAT in config, logs, traces or plugin-visible objects. Plugins should use opaque ADO handles. A user should not have to enter a vault password on every ADO use. Prior discussions about passwordless SecretStore were superseded by choosing OS credential storage; do not reintroduce them as active requirements.

### D-012 — Testing and quality (DECIDED)
Use NovaModuleTools/Pester for unit and integration tests; existing PTY framework for focused real terminal regressions. PSScriptAnalyzer zero findings is Definition of Done; preserve coverage and CodeScene quality gates. Tests of Core must not depend on Gerber.ExampleOrg, real Keychain, customer network or live ADO. Avoid a new sweeping PTY expansion. Keep Copilot tasks bounded with clear stopping criteria; no autonomous hours-long fixture expansion.

### D-013 — Cross-platform (DECIDED)
Target Windows, macOS and Linux; macOS is the primary development and hands-on verification environment. Windows/Linux can be verified with suitable VMs or colleagues; do not invent claims of completed platform verification.

### D-014 — Distribution and licensing (DECIDED; repository clarified G-4A7R)
PSGallery is the permanent, sole official Gerber Core distribution channel and
cannot be overridden by users, environment variables, user configuration or
plugin configuration. This is a fixed application-owned binding, not a
configurable default. The 2026-10-25 read-only PMU probe found stable Core 0.1.0;
this is not live installation qualification. Plugins may come
from independently configured public/private repositories, Azure Artifacts,
local modules and company sources. The product owner does not want Gerber to
police downstream users' compliance with a third-party credential library's
licensing. Record exact license obligations in dependency documentation, without
inventing blanket legal guarantees.

### D-015 — Persistent documentation (DECIDED)
Maintain `PLAN.md` (roadmap/status), `ARCHITECTURE.md` (current design), and `DECISIONS.md` (decisions and rationale). Agent instructions should reference them. Mark implementation status only from verified code/evidence, not assumptions or future proposals.

### D-016 — Development-time plugin boundary guardrails (G-3F1)

Enforce the existing public-only integration rule during development and staged
generation, not by pretending PowerShell is sandboxed. Export the smallest
standalone validation command, `Test-GerberPluginBoundary`, usable from installed
Gerber on an uninstalled plugin without invoking Nova build/test operations,
starting the interactive host or requiring a Core checkout. This command's
functional independence does not waive Gerber's required modules (D-017).
Keep Nova's standard build/test flow and add a generated convenience gate plus
agent instructions to inspect public capabilities and request missing ones.

Derive Core private ownership from real installed function definitions minus
exports, and operation names/equivalents from the existing API v1 declarations.
Do not maintain a drifting duplicate API list or ban all `Get-Gerber*` names.
Use AST command/import context, respect plugin/local declarations, report stable
file/line/dependency/reason/resolution diagnostics and document dynamic limits.
Explicit Core implementation imports and module session-state access are not
approved alternatives to public capabilities. Unknown/computed dependencies
still require human review; no claim of complete runtime enforcement is made.

Run the boundary check before staged Nova execution and before move/approval,
using existing cleanup and GUID lifecycle semantics. Do not change installed
plugin discovery, approvals, enable/disable, inventory, registration or handlers.
No Gerber.ExampleOrg, Nova, installation-management or release-automation changes belong
to this task.

### D-017 — Runtime dependencies and updates (DECIDED; Core implemented in G-4A7, plugins planned)

Authoritative contract: [G-4A5](docs/architecture/G-4A5-update-architecture.md). Recorded 2026-10-23 and clarified 2026-10-24 from explicit project-owner decisions; this entry supersedes conflicting update recommendations in G-4A0, G-4A1 and G-4A2, and the Nova exclusion in D-002. Historical report labels are not authority over this current decision.

- PSModuleUpdate (PMU) is the shared, generic, independent update engine over PSResourceGet; it contains no Gerber, Nova, ADO or Nexus logic and no vendor-specific engines.
- **Both NovaModuleTools and PSModuleUpdate are required runtime dependencies**, declared through `RequiredModules`. Nova supports Gerber's plugin-development lifecycle: Gerber owns creation workflows/templates, while Nova provides build, test, packaging and local publication. Nova is not exclusively Gerber-repository development tooling, but those operations need not run at startup.
- PMU supplies update discovery, version selection, package installation, verification, locking and rollback/recovery, independently of Gerber and Nova. The optional/lazy PMU recommendation is rejected. A missing or incompatible required module may block import; an unreachable update repository must never block startup.
- Gerber checks for Core updates at startup: informational only, refers to `/update`, never installs, prompts, updates plugins or changes configuration. Failure is never reported as "up to date".
- `/update` is the central command for Core **and** plugins, using the same PMU engine, always with a fresh check. Core integration is implemented first; plugin updates follow in a separate phase. It presents a compact table (name, installed, available, repository); the user can eventually pick individual updates.
- **G-4A7R Core policy:** always explicitly pass PSGallery to PMU, with its official endpoint pinned. No user/environment/plugin override, repository-selection prompt or alternative-repository fallback is supported. No matching package is not a configuration error.
- **Plugin policy (G-4A9):** repositories are independently configurable per plugin through Gerber-owned metadata/configuration, with no inference from names or cross-repository fallback. Plugins may use different repositories; this does not supply or modify Core's binding. Both Core and plugins use PMU.
- Gerber owns its CLI/UX, plugin creation, configuration, credentials, repository selection, update presentation/confirmation and coordination of Core/plugin updates; PMU owns generic update mechanics, not Gerber-specific UI/configuration. Nova build/package/publication is distinct from PMU update installation; do not duplicate PMU inside Gerber. Credentials are not persisted in plans or logs. Plugin approval and GUID-based trust are unchanged.
- PMU CI success (run 39953682511) is not Gerber integration. Nexus is unverified. No release or publication is part of this decision.
- **Historical G-4A5 source inspection 2026-10-24:** `project.json` already declared NovaModuleTools `3.4.2` and PMU `0.1.0`; `/plugins create` invoked Nova validation, but Core `/update` and PMU calls were absent. The then-existing generated manifest was stale. These were source/artifact findings, not executed import or update qualification.
- **Verified locally in [G-4A6](docs/architecture/G-4A6-runtime-dependency-qualification.md):** exact Nova 3.4.2 generates both requirements; offline imports with PMU 0.1.0-preview pass on macOS/PowerShell 7.4.21 and 7.6.6, while missing/too-old dependencies fail as expected. Numeric ModuleVersion is a minimum, not a package/channel pin; the original generated artifact was preserved.
- **Implemented G-4A7:** Core startup discovery and fresh `/update` discovery/confirmed installation use PMU; normal Nova builds regenerate both required-module declarations. Startup never installs or requests installation consent. Core is not hot reloaded. Plugin update management remains planned.
- **Historical G-4A7 choice, superseded by G-4A7R:** the provisional `updates.modules.Gerber` repository/policy/credential binding was configurable. It is now ignored in full, without migration or unrelated plugin-configuration changes. No second Core configuration mechanism replaces it.
- **G-4A7R channel policy:** explicit PMU Stable/CurrentUser, with prerelease-aware installed identity. PMU can promote `0.1.0-preview` to stable `0.1.0` or a newer stable release; newer prereleases are excluded. Gerber performs no custom version comparison and its declared version is unchanged. Core never retrieves or requests credentials.
- **Current dependency correction, 2026-10-25:** require numeric PMU `0.1.1` (upstream source `0.1.1-preview`) for mixed-layout installed-copy discovery. PMU ignores legacy resource directories without module manifests beside numeric installations, still rejects genuine invalid candidates, and does not select or migrate a flat-only copy as a versioned installation. Gerber's existing mapping retains Available `0.1.0` / `UpToDate` for equal installed/target versions, with no installation offer or second query. PMU 0.1.1 is not yet published; dependency bootstrap is a separate approved action, with no automatic local Gerber migration or cleanup. The separate upstream `PackageNotFound` classification issue and complete live-install qualification remain unresolved.
- **Read-only evidence, 2026-10-25:** public `Get-PSModuleUpdate` from built PMU `0.1.1-preview` returned installed/target Gerber `0.1.0` and `UpToDate` against official PSGallery with Stable/CurrentUser policy and the installed versioned module. This confirms the local mixed-layout/feed lookup, not live installation or dependency deployment; no global module/repository changes were made.
- Startup retains a 2,000 ms noninteractive child-process budget and no persistent cache. Only eligible available updates notify and refer to `/update`; startup never installs or seeks installation consent. `/update` discovers afresh, defaults to Cancel and uses the original PMU plan only after explicit confirmation. Root command priority is exactly `/exit`, `/help`, `/plugins`, `/update`; other roots remain alphabetical. See [Core behavior](docs/core-updates.md).
- **OPEN:** long-term startup-budget/cache policy; G-4A9 plugin repository metadata/activation contract; remaining package-source, live-provider installation and Gerber Windows/Linux qualification. The Core repository and both required dependencies are **decided**, not open conflicts. Full quality readiness is separate from implemented behavior (see [PLAN.md](PLAN.md)).

## Known questions — do not silently decide
1. How precisely does a user override a revoked plugin warning, and what restrictions apply while revoked?
2. How should future module-discovery sources beyond local PowerShell module paths expose equally safe manifest metadata inspection?
3. How should GUID impersonation/collision be surfaced pending future signature-based trust?
4. Which `/plugins` actions are immediate within a running PowerShell session versus requiring reload/restart?
5. Exact config schema and canonical location must be read from the current code, not invented from examples.
