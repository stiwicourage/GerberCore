# Release notes

This file summarizes user-visible commands, configuration and migration changes.
`CHANGELOG.md` is the exhaustive release history.

## [Unreleased]

### Added

- Plugin manifests must declare `PrivateData.Gerber.Conformance = @('RootNavigation')`. Gerber rejects plugins without it and states which behavior is not supported. Migration: add the declaration after making every plugin flow return quietly on a quick double Escape.

### Changed

### Removed

### Fixed

## [0.5.0] - 2026-11-22

## [0.4.0] - 2026-11-16

### Added

- README documents the `GerberCore.json` schema; `schemaVersion` 1 is unchanged.
- Plugin API v1 documentation covers namespaces, conflicts and post-1.0.0 compatibility; the API itself is unchanged.
- New plugin projects include a namespace registry gate (script and workflow) that fails when another plugin published the namespace first.
- `/plugins install` refuses a plugin whose namespace an installed plugin already uses; rename or uninstall the installed plugin first.
- `/plugins install` installs a plugin from PowerShell Gallery after a namespace ownership check; enable it afterwards with `/plugins enable`.

### Changed

- The `/plugins` description lists all its subcommands.

### Removed

- `/plugins info <plugin>` is removed. Open `/plugins list`, select a plugin and
  press Enter to see its details.

## [0.3.2] - 2026-11-10

### Added

- After an update requiring restart, supported console hosts offer **Exit Gerber
  and PowerShell**. Other hosts provide guidance to restart the session from the
  host. **Continue with current version** remains the default; exiting Gerber
  alone does not unload the module.

### Changed

- `/update list` inspects selected packages without a separate inspection prompt.
  Selection, installation confirmation and results use compact per-component
  lines, retaining versions, source, scope and required Core versions.
- Plugin lifecycle guidance is explicit: disable with `/plugins disable` inside
  Gerber; uninstall the PowerShell module outside Gerber to remove or revoke it.
  There are no remove or revoke commands.
- Installing Gerber installs **Gerber.AzureDevOps** again, alongside
  **NovaModuleTools** and **PSModuleUpdate**.

### Fixed

- Plugin update failures show actionable reasons, and the installation preview
  labels required Core versions as minimums.
- Manually copied installations can be replaced during updates when the installed
  PMU supports `ReplaceUnmanagedInstallation`; older PMU versions retain
  reinstall guidance.
- Installation documentation now uses the published PSGallery preview with
  `Install-Module Gerber -Scope CurrentUser -AllowPrerelease`.

## [0.3.1] - 2026-11-10

### Added

- After an update requiring restart, supported console hosts offer **Exit Gerber
  and PowerShell**. Other hosts provide guidance to restart the session from the
  host. **Continue with current version** remains the default; exiting Gerber
  alone does not unload the module.

### Changed

- `/update list` inspects selected packages without a separate inspection prompt.
  Selection, installation confirmation and results use compact per-component
  lines, retaining versions, source, scope and required Core versions.
- Plugin lifecycle guidance is explicit: disable with `/plugins disable` inside
  Gerber; uninstall the PowerShell module outside Gerber to remove or revoke it.
  There are no remove or revoke commands.

### Removed

- Product-plugin runtime dependencies. Core requires only **NovaModuleTools** and
  **PSModuleUpdate**; plugins are installed separately.

### Fixed

- Plugin update failures show actionable reasons, and the installation preview
  labels required Core versions as minimums.
- Manually copied installations can be replaced during updates when the installed
  PMU supports `ReplaceUnmanagedInstallation`; older PMU versions retain
  reinstall guidance.
- Installation documentation now uses the published PSGallery preview with
  `Install-Module Gerber -Scope CurrentUser -AllowPrerelease`.

## [0.3.0] - 2026-11-08

### Added

- `/update` provides **list** and **policy**. `/update list` checks Core and eligible
  installed plugins afresh, shows installed/available versions and repository,
  and requires confirmation with **Cancel** as the default. Startup checks Core
  only and never installs, asks to install or requests credentials.
- `/update policy` saves **Stable only** (default) or **Include prereleases** for
  startup Core checks and manual Core/plugin checks. Selecting policy performs
  no installation. Core always uses the official PSGallery source and CurrentUser
  scope, without a repository override or automatic registration.
- Plugin update selection uses a shared checkbox overview. Candidate manifests
  are checked for GUID, Plugin API v1 and required Core version; a permitted Core
  update is added visibly when needed. Updates run sequentially, with dependent
  plugins blocked on Core failure while independent updates can continue.
  Results distinguish installation, verification, recovery and fresh-process
  activation. There is no first installation, hot reload or batch rollback.
  Plugin updates require a PMU release exporting
  `Get-PSModuleUpdateTargetManifest`; see [update requirements](docs/core-updates.md#requirements).
- Plugin repositories use `PrivateData.Gerber.Repository` with display `Name` and
  canonical `Uri`. Absent metadata uses PSGallery; invalid explicit metadata never
  falls back. Legacy `RepositoryUri` remains supported, with canonical metadata
  taking precedence. Repository credentials are operation-local.
- `Test-GerberPluginBoundary -Path <project>` checks authored plugin source for
  identifiable private Core dependencies without executing it. Diagnostics name
  source locations and public-API resolutions; `PublicApi` lists capabilities.
  This static development check is not a sandbox.
- `/plugins create` generates a working plugin project with a permanent manifest
  GUID, tests, boundary-check script, changelog and agent guidance. It asks for a
  suffix behind the fixed `Gerber.` prefix, description, namespace, repository
  and destination parent, then validates before approval. It never overwrites
  existing destinations or installs/loads the generated module. PSGallery is
  preselected; a custom repository takes a name and URI. Unknown URIs become an
  explicit placeholder that must be replaced before remote publishing or updates.
  See [plugin creation](docs/plugins-create.md).
- Plugin approval, association and enabled state persist by manifest GUID.
  Unknown plugins require approval before import; decline is the default.
  Declines persist, and noninteractive discovery skips unknown plugins.
  `/plugins enable` explicitly approves and activates a selected inactive plugin.
  `/plugins disable` removes its commands immediately while retaining approval
  and installation. GUID approval does not authenticate a publisher.
- `/plugins list` and `/plugins info <plugin>` inspect inventory by GUID or unique
  module name without importing unknown, declined or disabled plugins. Missing
  associated plugins remain visible; generated name/version can be displayed
  before installation.
- Identity-bound Plugin API v1 Configuration.Read/Save persists each plugin's
  module-named JSON beside Core configuration, with strict JSON errors and atomic
  writes. Shared UI, HTTP metadata, Secrets and Clipboard capabilities support
  plugins without private Core dependencies.
- The interactive palette supports slash completion, plain-text leaf-action
  search, highlighted suggestions, help previews, nested menus and optional
  `GERBER_PROMPT_TRACE=1` tracing. Roots prioritize `/exit`, `/help`, `/plugins`,
  `/update`, followed by other active roots alphabetically.
- Esc returns one level; double Esc within 200 ms returns to the root prompt.
  `/tools create-uuid` generates and optionally copies UUIDs; Enter repeats.
  `/tools base-64 encode` and `decode` convert UTF-8 text and reopen after continue.
- `/secrets` provides `list`, `get`, `test`, `set` and `remove` using native
  credential storage. Values require confirmation before terminal reveal,
  overwrite or removal; identifiers can be listed/tested without retrieving
  values. No plaintext fallback is used.

### Changed

- Gerber requires NovaModuleTools for plugin development and PSModuleUpdate
  `0.2.0` or later for update mechanics. Their operational workflows do not run
  merely because Gerber is imported.

### Fixed

- Empty plugin menus disappear when the last active contribution is disabled;
  shared roots retain other plugins' actions. Menus, completion, help and direct
  lookup use the same tree.
- Unreadable module-search paths no longer prevent discovery.
- Unsupported Core installation layouts receive numeric-version directory and
  restart guidance. Local installations lacking provider metadata receive
  reinstall guidance when automatic replacement is unavailable.
- Windows credential target formatting preserves Gerber identifiers and existing
  macOS/Linux storage.
- Recoverable errors stay inside Gerber with actionable messages. Shared menu
  navigation returns through parent menus and honors double Escape.

## [0.2.0] - 2026-10-27

### Added

- `/update policy` saves **Stable only** (default) or **Include prereleases** in
  the optional `coreUpdates.channel` setting. Startup and manual Core checks use
  the saved channel; selecting a policy installs nothing.
- `/update` opens a **list**/**policy** submenu. `/update list` runs a fresh
  check and returns to the submenu after the results.

### Changed

- Gerber requires PSModuleUpdate `0.1.1` or later. `/update` does not install
  PSModuleUpdate for you.

### Fixed

- Update checks on an unsupported Core installation layout explain the
  supported numeric-version module directory and restart, instead of blaming
  PSGallery.
- A locally copied Core installation without provider metadata gets PSGallery
  reinstall guidance.

## [0.1.0] - 2026-10-25

### Added

- `Invoke-Gerber` (alias `gerber`) starts the interactive multitool with
  `/tools`, `/list`, `/secrets`, `/plugins`, `/update`, `/help` and `/exit`.
  The prompt supports slash completion, plain-text action search, help previews
  and nested menus. Esc goes back one level; double Esc within 200 ms returns to
  the root prompt.
- `/tools create-uuid` generates a UUID and copies it when possible.
  `/tools base-64 encode` and `decode` convert one-line UTF-8 text.
- `/secrets` provides `list`, `get`, `test`, `set` and `remove` using native
  credential storage. Revealing, overwriting and removing values require
  confirmation; there is no plaintext fallback.
- `/update` checks Gerber Core on PSGallery, shows installed and available
  versions and asks for confirmation with **Cancel** as the default. The startup
  check only notifies.
- Unknown plugins require approval by manifest GUID before import; decline is the
  default and is remembered. Noninteractive sessions skip unknown plugins.
- `/plugins`, `/plugins list` and `/plugins info <plugin>` inspect plugins
  without importing them. `/plugins enable` and `/plugins disable` take effect
  immediately and persist across restarts.
- `/plugins create` generates a Plugin API v1 plugin project with tests and
  agent guidance. It never overwrites an existing destination or installs the
  module.
- `Test-GerberPluginBoundary -Path <project>` reports private Core dependencies
  in plugin source without running it.
- Setting `GERBER_PROMPT_TRACE=1` writes prompt tracing to
  `.gerber/prompt-debug.log`.
- Network calls time out after 5 seconds (connection) or 15 seconds (operation)
  with DNS and timeout hints.

### Changed

- Gerber requires NovaModuleTools and PSModuleUpdate.

### Fixed

- On Windows, secrets use the `gerber://credentials` service name required by the
  credential provider. Storage on macOS and Linux is unchanged.

[Unreleased]: https://github.com/stiwicourage/GerberCore/compare/0.5.0...HEAD
[0.5.0]: https://github.com/stiwicourage/GerberCore/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/stiwicourage/GerberCore/compare/0.3.2...0.4.0
[0.3.2]: https://github.com/stiwicourage/GerberCore/compare/0.3.1...0.3.2
[0.3.1]: https://github.com/stiwicourage/GerberCore/compare/0.3.0...0.3.1
[0.3.0]: https://github.com/stiwicourage/GerberCore/compare/0.2.0...0.3.0
[0.2.0]: https://github.com/stiwicourage/GerberCore/compare/0.1.0...0.2.0
[0.1.0]: https://github.com/stiwicourage/GerberCore/releases/tag/0.1.0
