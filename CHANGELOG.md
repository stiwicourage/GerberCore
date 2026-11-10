# Changelog

All notable changes to this project will be documented in this file and **UNRELEASED** changes will be included in the next **stable** release!

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Deprecated

### Removed

### Fixed

### Security

## [0.3.1] - 2026-11-10

### Added

- After an update that needs a restart, `/update list` offers **Exit Gerber and
  PowerShell** in PowerShell console hosts, because exiting Gerber alone leaves
  the old module loaded. Other hosts (VS Code, ISE, remote) get guidance to
  restart the session from the host.

### Changed

- Simplified `/update list`: selected packages are inspected without a separate
  consent prompt, each checkbox is a single line (`Name  from -> to  (Repository)`),
  the installation confirmation is a compact per-component plan with one source
  and scope line, and results show one status line per component with details
  only when they need attention.

### Removed

- Gerber Core no longer requires the `Gerber.AzureDevOps` plugin module.
  Product integrations are installed separately and Core depends only on
  NovaModuleTools and PSModuleUpdate.

### Fixed

- `/update list` now shows the actionable reason when a plugin installation fails
  instead of a generic message, and the confirmation states the required Core as
  a minimum (`requires Core >= X`).
- `/update list` can update Core and plugins that were copied manually (no
  PowerShell provider metadata) when the installed PSModuleUpdate supports
  `-ReplaceUnmanagedInstallation`; older versions keep the reinstall guidance.

## [0.3.0] - 2026-11-08

### Added

- Added community health files for outside contributors: `SECURITY.md`,
  `CODE_OF_CONDUCT.md`, GitHub bug-report and feature-request issue forms,
  `.github/CODEOWNERS`, weekly Dependabot updates for GitHub Actions, and a
  "Getting started" section in `CONTRIBUTING.md`.
- Added identity-bound Plugin API v1 `Configuration.Read` and
  `Configuration.Save` for schema-free, module-named JSON files beside Core
  configuration, with strict JSON errors and atomic publication. Added the
  concrete shared UI and HTTP metadata operations used by product plugins.
- Added G-4A9 installed-plugin update selection to `/update list`, using the
  existing shared channel and per-plugin `PrivateData.Gerber.Repository`
  descriptors (`Name` for display, canonical `Uri` for PMU). Names survive
  unavailable/no-matching-package lookup results. Absent metadata defaults to
  PSGallery and its official URI; invalid declarations never fall back.
  Legacy `RepositoryUri` remains supported, mapping the official Gallery URL
  to PSGallery and retaining custom raw URL display until a name is added.
  Canonical metadata wins when both keys exist. Current installed manifests
  remain authoritative over cached module metadata; trust prompts retain URLs.
  Only installed, associated, approved, enabled plugins participate; startup
  remains Core-only. Shared checkbox selection, separately confirmed
  trust/license-gated package inspection and a default-Cancel combined install
  preview show versions, source, scope and visibly auto-added required Core.
  Core and plugins share one aligned overview table, including in the selection
  screen, with a blank line before the shared channel and no per-plugin
  information footer. No available updates return through the continue prompt
  without a chooser or misleading cancellation message.
  PMU installs the original plans sequentially, Core first; dependency failures
  block dependent items while independent updates continue, and cancellation
  stops future attempts. Results separate installation, verification, recovery
  and fresh-process activation, retaining Installed when activation fails.
  Credentials are operation-only; no first install, hot reload or batch rollback.
  Added mirrored UI tests, disposable PTY regression fixtures and affected help.
  The new PMU target-manifest inspection API remains locally implemented,
  unpublished and undeployed; numeric minimum stays 0.2.0. No hosted/live
  qualification implied.
- Added repository selection to `/plugins create`. PSGallery is preselected and
  generates an explicit `Manifest.PrivateData.Gerber.Repository` object with
  `Name = PSGallery` and its official `Uri`, without additional questions.
  Another repository asks for a name followed by a safe absolute URL, or writes
  `REPLACE_WITH_REPOSITORY_URI` in `Repository.Uri` when unknown. Requests,
  results, generated JSON and manifests retain the canonical descriptor.
  The completion summary shows name and URI plus placeholder replacement
  guidance. Blank names and unsafe URLs can be corrected locally; Esc at the
  chooser, name or URI cancels without generation.
  An unreplaced placeholder remains invalid for updates without Gallery fallback.

### Changed

- Core defaults to `GerberCore.json`; each plugin can use its own module-named
  JSON file in the same directory. Legacy file overrides resolve to the named
  Core sibling.
- Core update completion now offers **Exit Gerber** or **Continue with current
  version** after verified success requiring restart, or discovery of an
  already-installed newer Core. Continue is the default and Esc also continues.
  Restart guidance remains visible; exiting Gerber does not restart PowerShell.
  Restart PowerShell, then run `gerber`; Core/plugins are not hot reloaded.

### Fixed

- Plugin-created projects now stamp `MinimumGerberVersion` with the semantic
  version of the Gerber module that generated them, including prerelease
  metadata, instead of the hard-coded `0.1.0-preview`.
- Empty menu-only roots and intermediate submenus are removed from the active
  command tree. `/branch`, `/list`, `/pipelines` and `/repository` appear only
  with available plugin actions; shared roots retain other active contributors.
  Enable/disable refreshes menus, suggestions, help and direct command lookup
  without duplicate commands. Standalone Core actions remain available.
- Plugin discovery now skips unreadable module-search roots instead of
  terminating the plugin inventory or `/update list` with a permission error.
  Accessible plugins and Core update checks remain available; filesystem
  permissions and configured module paths are unchanged.
- Corrected Core update documentation to match the declared PSModuleUpdate
  0.2.0 minimum and its Gallery availability. Recorded user-confirmed live
  installation separately from the locally corrected, unpublished provider
  error classification and outstanding platform/recovery qualification; no
  Gerber dependency or runtime behavior changes are included in this
  documentation correction.

## [0.2.0] - 2026-10-27

### Added

- Added `/update policy` with persistent **Stable only** (default) and
  **Include prereleases** channels in optional `coreUpdates.channel` user
  configuration. Startup and manual discovery share the validated PMU policy;
  installation rejects plans from a changed channel while retaining the fixed
  PSGallery endpoint, CurrentUser scope and default-Cancel confirmation.
  Selection performs no discovery or installation, preserves unrelated settings
  and ignored legacy bindings, and clears stale startup notifications.
  `/update` now opens the shared **list**/**policy** submenu; `/update list`
  performs the fresh check and returns to that chooser after results.
  Continuing after a policy selection also returns to `/update`, with
  `/update list` highlighted, instead of reopening the policy chooser.

### Changed

- Raised the minimum PSModuleUpdate dependency from numeric `0.1.0` to `0.1.1`
  for upstream mixed-layout installed-copy discovery, without changing Gerber's
  version or its PMU-owned update decisions. Added built-module and terminal
  contracts preserving Available `0.1.0` / `UpToDate` when installed equals
  available, with no installation offer. `/update` does not bootstrap PMU;
  dependency installation remains a separate approved action.
  No automatic local Gerber migration or cleanup is performed. The separate
  upstream `PackageNotFound` issue and complete live-install qualification remain.

### Fixed

- Core update discovery now maps structured `PMU.UnsupportedInstallation` to
  supported numeric-version module directory and restart guidance, rather than
  blaming PSGallery registration/connectivity. It neither parses provider text
  nor assumes every unsupported installation is flat-only, and claims no
  installation or rollback success. Flat-only migration remains unsupported;
  existing installed Gerber copies need a separate update for the diagnostic.
- A Core installation missing native provider metadata now gets explicit
  locally-copied/published diagnosis and PSGallery reinstall guidance instead of
  incorrect numeric-directory guidance. Other unsupported layouts keep the
  generic safe message; provider secrets remain hidden.

## [0.1.0] - 2026-10-25

### Added

- Added Gerber Core update management through `/update`: fresh PSModuleUpdate
  discovery, compact version/repository overview, default-cancel installation
  confirmation and verification/recovery/restart guidance. Startup checks are
  bounded and notification-only. Core is permanently bound to PSGallery and its
  official endpoint, with explicit PMU Stable/CurrentUser policy, no configuration,
  environment or plugin override and no fallback. Obsolete Core update settings
  are ignored without rewriting unrelated configuration. Structured PMU
  no-matching/eligible-package outcomes (Core is not published yet) are
  distinguished from repository
  failure; Core never reports Unconfigured or requests credentials.
  PMU handles installed previews and stable promotion without custom comparisons.
  Plugin updates and their independent repository bindings remain G-4A9.

- Added **G-3F1 — development-time Plugin API v1 boundary guardrails**.
  - Exported `Test-GerberPluginBoundary -Path <project>` validates uninstalled
    authored PowerShell without starting Gerber, invoking plugin code, requiring
    Nova lifecycle operations or a private Core checkout, or reading/writing user
    settings. This functional independence does not waive Gerber's required modules.
  - Derives private function ownership from actual installed module definitions
    and exports, and public capabilities/equivalents from existing API v1
    scriptblocks rather than maintaining a duplicate API list or prefix ban.
  - AST checks known private direct/literal dynamic calls and lookups, explicit
    implementation imports, and identifiable Core module-scope/session-state
    access; respects plugin/local function ownership, comments and ordinary
    strings. Returns deterministic actionable source diagnostics and public API
    operation inventory; documents conservative dynamic-analysis limits.
  - Checks staged generation before Nova execution, finalization and approval,
    preserving cleanup and GUID lifecycle semantics. Generated validation script,
    README, canonical agent guide, developer role, instructions and skills put
    boundary validation before the normal Nova flow and request missing public
    capabilities instead of importing private Core.
  - Adds public PlatyPS help, source-mirrored and installed-module tests,
    transactional invalid-source cleanup and isolated generated-project coverage.
    This is not a PowerShell sandbox or a runtime discovery/permission change.

- Added **G-3D1 / G-3D1-FIX1 — transactional `/plugins create` and G-3E1 agent-first scaffolding** using Core's existing registry, plugin menu and shared inputs.
  - Presents an introduction and separated explained fields for a suffix behind an immutable `Gerber.` prefix, description, unused namespace and destination parent, with dynamic cwd/child defaults and an actual metadata/state/next-steps summary; never overwrites the child or claims installation.
  - Gerber-owned templates generate a complete Plugin API v1 project with one canonical manifest GUID, functional namespaced hello, unit/public API integration tests and Nova lifecycle documentation. Nova generates the manifest and module root; `PrivateData.Gerber` no longer duplicates the GUID.
  - Generated name/initial version persist as optional GUID-keyed association display metadata before installation; installed manifest metadata wins and list/info remain read-only. Old metadata-free associations retain the GUID fallback.
  - Generates the requested full six-category Unreleased changelog and canonical AGENTS.md, thin Claude/Copilot bridges, scoped instructions, a plugin developer role and three actionable command/API/Nova workflow skills without private Core dependencies.
  - Stages generation, runs Nova build/unit/integration checks and isolated Core registry registration, then finalizes and explicitly approves, associates and enables that same GUID. Creation does not install/load the module.
  - Cleans only owned staging data on validation failure; preserves the recoverable final project with an exact partial-state error if configuration persistence fails.
  - Retains an invocation-time Nova availability check and installation with explicit consent when missing; this handler safeguard does not make Nova optional at Gerber import. Adds isolated local-publish/fresh-start discovery and focused PTY cancellation/recovery/trace coverage without changing enable/disable semantics.

- Added **G-3C2 — `/plugins enable` and `/plugins disable`**.
  - `/plugins enable` lists installed plugins that are not active (declined, pending or approved-but-disabled), treats the selection as explicit approval, persists it in the existing plugin lifecycle state, and registers the plugin's commands immediately.
  - `/plugins disable` lists active plugins, persists the disabled state while preserving approval, and removes the plugin's commands immediately; the PowerShell module is not uninstalled.
  - Both actions update menus, completion, and command dispatch without restarting Gerber, and their persisted state survives restarts. Enabling an already-active plugin does not repeat import, initialization, or persistence.
  - Registration rejects cross-plugin parent references and conflicting active module names while preserving valid nested commands and contributions beneath shared Core parents.
  - Registry changes are staged independently of the live command tree. Failed registration or disable operations restore the previous registry and lifecycle configuration where possible, with explicit diagnostics if rollback also fails.

- Added **G-UI2 — prioritized root command ordering**: `/exit`, `/help`, `/plugins` and `/update` always come first in that order, followed by all other root commands (Core and plugin) alphabetically. Submenu ordering is unchanged.

- Added **G-UX1 — Double Escape to Root** across Gerber's shared terminal navigation.
  - A single `Esc` still goes back one menu level at a time.
  - A second `Esc` within 200 milliseconds now returns directly to the Gerber root prompt from shared prompts, menus, continue screens, and plugin-driven terminal flows that use the shared Core prompt infrastructure.
  - The double-Escape state is tracked centrally with monotonic elapsed-time checks, survives ordinary screen transitions, reuses the existing visible-root prompt request path, and clears pending input safely so rapid Escape input does not execute stale commands.

- Added persistent GUID-based plugin approval plus plugin lifecycle state before plugin import or execution.
  - Reads candidate module manifests without executing plugin code and rejects malformed or invalid-GUID candidates with controlled diagnostics.
  - Stores normalized approved GUIDs under `plugins.approved`, normalized declined GUIDs under `plugins.declined`, and associated plugin records under `plugins.associated.<guid>.enabled` in the existing atomic user configuration, preserving unrelated settings and approval across ordinary plugin updates.
  - Newly approved plugins are immediately associated and enabled without a second prompt, while previously approved plugins without an explicit association record stay usable and acquire lifecycle state lazily on rediscovery.
  - Declined plugins now persist that decision too, so Gerber skips the same unknown plugin on later startups instead of prompting again every time.
  - Uses Gerber's existing confirmation UI with decline as the default; declined or noninteractively discovered unknown plugins are skipped without blocking Core startup.
  - Prevents disabled associated plugins from importing, executing `Get-GerberPlugin`, or registering slash commands, while preserving their approval and association records across restarts and temporary module absence.
  - Treats GUID approval as identity and user intent, not as cryptographic proof of publisher or code authenticity.

- Added the first read-only plugin management commands in Gerber Core.
  - `/plugins` now shows one overview of all plugin identities known to Gerber, including approved, declined, disabled, unknown, loaded, and missing entries.
  - `/plugins list` now merges discovered manifest metadata, persisted approval/decline decisions, persisted association state, and current-session loaded state by manifest GUID without duplicate rows.
  - `/plugins info <plugin>` now supports lookup by manifest GUID or unique module name and reports controlled errors for malformed GUIDs, unknown plugins, and ambiguous names.
  - Declined plugins remain visible and inspectable even when they were never associated or are no longer currently discovered.
  - Read-only inspection does not trigger approval prompts, import unknown/declined/disabled plugin code, or modify `config.json`.

- Added registry-derived interactive command inventory and PTY coverage enforcement for Gerber Core,
  with separate discovery, dispatch, workflow, navigation, rendering, and error/recovery categories.
  The bundled `Gerber.TerminalFixture` now has a separate generic Plugin API contract inventory and
  coverage report, while product plugins own their product-specific terminal regressions.

- Added the interactive `Invoke-Gerber` / `gerber` multitool for local terminal workflows.
  - Includes `/tools`, `/list`, `/secrets`, `/help`, and `/exit`
  - Starts with a minimal prompt-first home screen, shows `/ commands · esc back` beneath the empty root prompt, and supports both slash-command root browsing and plain root action search across executable leaf commands, interactive autocomplete, immediate visual highlighting for the visible default suggestion in chooser prompts such as the root `/` list, root action-search matches, `/tools`, and `/secrets`, visual selection highlighting for arrow-key suggestion lists, Enter-to-accept suggestion flow, inline submenu prompts for slash commands such as `/tools`, `/list`, and `/secrets`, one-level-at-a-time `Esc` back-navigation that returns from a top-level submenu to the visible root `/` chooser before the blank home prompt, and help previews in the same terminal session
  - Adds optional `GERBER_PROMPT_TRACE=1` prompt tracing that writes `.gerber/prompt-debug.log` for terminal-specific autocomplete troubleshooting
  - `/tools create-uuid` generates a standard hyphenated UUID with no braces, shows it in the terminal, copies it to the clipboard when possible, makes `create-uuid` the default `/tools` action, and lets `Enter` generate another UUID while `Esc` returns to the `/tools` chooser
  - `/tools base-64` adds nested `encode` and `decode` actions for one-line UTF-8 text, shows results in the terminal, copies them to the clipboard when possible, returns to the selected action after `Press Enter to continue`, supports `Esc` as a return-to-menu shortcut from interactive prompts and continue screens, and keeps recoverable decode errors inside the interactive tool flow
  - `/secrets` adds nested `list`, `get`, `test`, `set`, and `remove` actions backed by secure credential storage, lists only Gerber-owned identifiers, copies a selected secret value to the clipboard before any terminal reveal when possible, confirms before revealing, overwriting, or removing values, and fails clearly without a plaintext fallback when secure credential storage is unavailable
- Added mirrored Pester coverage and PlatyPS command help for the new Gerber command surface
- Improved HTTP resilience for Gerber network calls with explicit connection timeouts (`5s`) and operation timeouts (`15s`) so unreachable endpoints fail fast instead of hanging indefinitely.
- Centralized common HTTP transport error hints for DNS failures and timeouts across Gerber network flows, while keeping caller-specific guidance in the relevant commands.
- Fixed the interactive Gerber menu so recoverable runtime errors show an in-app error and return to Gerber instead of dropping back to the PowerShell prompt.

### Changed

- Replaced identifying example organizations, profiles, endpoints and plugin names with neutral sample data across fixtures, metadata, help and preserved historical documentation. Runtime behavior and credential identities in user-owned storage are unchanged.

- Corrected the runtime dependency architecture: both NovaModuleTools and
  PSModuleUpdate remain required modules. The owner decision supersedes D-002's
  Nova exclusion while preserving Core/plugin boundaries. Nova supports
  application-exposed plugin development/build/package/local publication; PMU
  independently supplies generic updates. Historical recommendations are retained
  with supersession references; current Core behavior and planned plugin updates
  are distinguished explicitly.

### Added

- Added version number to Gerber menu header (now displays "Gerber #0.1.0-preview - DevOps Multitool") so users can confirm the module has been reloaded after rebuilds

### Fixed

- Corrected Windows native credential service names to use the absolute
  `gerber://credentials` URI required by the provider. Writes, reads, listing,
  existence checks and removal share that mapping; macOS and Linux retain their
  existing `credentials` service and stored entries.

- Restored local quality validation: the owner-approved `PSAvoidUsingWriteHost`
  exclusion preserves intentional terminal/CI output, while all other analyzer
  findings still fail the gate. CI path composition now uses named parameters,
  and `project.json` has its required trailing newline without metadata changes.

- Fixed **G-UX1-FIX1 — Shared Plugin Menu Navigation Regression**.
  - `/plugins` now reuses Gerber's shared submenu navigation contract instead of a plugin-specific dispatch path.
  - Single `Esc` from `/plugins list` and `/plugins info` now returns to `/plugins`, while single `Esc` from plugin details opened through `/plugins list` still returns to the list view first.
  - Double `Esc` within 200 milliseconds still returns directly to the root prompt from nested plugin-management views.
  - Direct `/plugins list` and `/plugins info` execution continues to use Gerber's existing command-resolution behavior without inventing a separate navigation history.

