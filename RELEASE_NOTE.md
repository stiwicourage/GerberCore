# Release notes

## [Unreleased]

### Changed

### Fixed

### Added

### Changed

### Fixed

### Persistent plugin approval and lifecycle state

### Read-only plugin management

### Enforced interactive regression coverage

## [0.3.0] - 2026-11-08

### Changed

- Gerber requires numeric PSModuleUpdate `0.2.0`, available from PSGallery.
  Dependency installation is a separate approved action, not automatic
  installation or cleanup of local Gerber. An up-to-date `0.1.0` remains visible
  in Available with no install offer.

### Fixed

- Empty product menus no longer appear. Shared roots and nested menus remain
  available while any active plugin contributes an action, and update
  immediately after enable/disable across menus, completion and help.
- Unreadable module-search paths no longer prevent plugin discovery or
  `/update list` from completing.
- Unsupported Core installation layouts now get supported numeric-version
  directory/restart guidance instead of a PSGallery/connection diagnosis.
  No automatic migration, installation or rollback is implied. An existing
  installed Gerber copy needs a separate update to receive this message.
- Locally copied or published Core installations that lack native provider
  metadata now specifically instruct users to reinstall the current Gerber
  version from PSGallery before retrying `/update list`.

### Added

- `/update` opens the shared **list**/**policy** submenu. `/update list`
  checks Gerber Core in its fixed official PSGallery repository and shows
  installed/available versions before asking whether to install. Cancel is the
  default; results explain verification, recovery and when to restart PowerShell.
  Verified success requiring restart, or discovery of a newer Core already
  installed, now offers **Exit Gerber** or **Continue with current version**.
  Continue is the default; Esc also continues with the restart reminder retained.
  Exiting Gerber does not restart PowerShell: restart PowerShell yourself, then
  run `gerber`. Core and plugins are not reloaded in-process.
  Startup can notify about an available version but never installs or asks to
  install or request credentials. No Core repository setup or override is
  supported; old Core update settings are ignored. `/update policy` saves
  **Stable only** (the default) or **Include prereleases** for both startup and
  manual checks. Changing it installs nothing; Enter after saving returns to the
  `/update` menu. Installation still defaults to Cancel.
  Stable promotion from an installed preview remains supported. No eligible
  matching package remains a legitimate result and does not prove Core is current.
  `/update list` also checks eligible installed plugins and offers checkbox
  selection, with a visibly added Core update when required. Core and plugins
  appear together in the same aligned overview table, with a blank line before
  the channel and no per-plugin information lines. When no update is available,
  Enter returns without a chooser or cancellation message. Plugin manifests
  declare `PrivateData.Gerber.Repository` with a display `Name` and canonical `Uri`.
  Names stay visible when lookup fails; PMU and trust prompts retain the URI.
  Absent metadata uses PSGallery; invalid explicit metadata never falls back.
  Legacy `RepositoryUri` still works, with canonical metadata taking precedence.
  Trust/license-gated package
  inspection asks separately before the combined default-Cancel install prompt.
  Updates run sequentially; dependent plugins are blocked on Core failure while
  independent updates continue. Results distinguish installed packages from
  fresh-process activation failures. Credentials last for this operation only.
  No first installation, hot reload or batch rollback is included.
  **Delivery limitation:** the new PMU inspection API is local and unpublished;
  the declared minimum remains 0.2.0. This does not qualify hosted or live plugin
  updates. See [Core and plugin updates](docs/core-updates.md).

- Plugin authors can run `Test-GerberPluginBoundary -Path <project>` from
  installed Gerber to find identifiable private Core dependencies before building
  or installing a plugin. Diagnostics show the source location, dependency and
  public-API resolution; `PublicApi` lists implemented operations.
  Generated projects include `./scripts/Test-PluginBoundary.ps1` and matching
  agent guidance, and creation rejects invalid source before approval.
  This static development check is not a sandbox and does not change existing
  plugin approvals, discovery or execution.

- `/plugins create` creates a working Gerber plugin: enter `MyCompany` to get
  `Gerber.MyCompany`, choose its `mycompany` command namespace, repository and destination parent,
  then let Gerber build and test it before approval. Existing files are never overwritten.
  PSGallery is preselected and writes its name and official URI without extra
  questions. Another repository asks for its name, then URL; blank names can
  be corrected locally. Enter for an unknown URL writes
  `REPLACE_WITH_REPOSITORY_URI` in `Repository.Uri`; replace it in `project.json`
  and rebuild before remote publishing or updates. Esc cancels without generation.
  Local build, tests and local publication remain available.
  Explained, separated fields show actual defaults; the completion summary states
  the repository name and URI, generated metadata and **Installed: No**. Before installation, `/plugins list`
  and `/plugins info` already show the known name/version without loading anything.
  Projects include a canonical manifest GUID, a complete Unreleased changelog and
  Gerber-specific agent resources led by AGENTS.md with thin Claude/Copilot bridges.
  Nova is a required Gerber runtime dependency for plugin development; its
  lifecycle operations run on demand, and the existing missing-tool installation
  fallback requires consent. From the generated project run `Publish-NovaModule -Local`, restart
  Gerber, and try `/mycompany hello`. See [plugin creation](docs/plugins-create.md)
  for cancellation, recovery and local installation details.

### Changed

- Examples and historical notes now use neutral organizations and endpoints. Existing user configuration and credentials are unchanged.

- Clarified the [runtime dependency contract](docs/architecture/G-4A5-update-architecture.md):
  Gerber requires both NovaModuleTools for plugin development and PSModuleUpdate
  for generic update mechanics. Neither dependency's operational workflows run
  merely because Gerber is imported; updates are never installed automatically.

### Fixed

- Corrected Windows credential target formatting without changing existing
  macOS/Linux credential storage or Gerber credential identifiers.

- Fixed local quality validation without changing Gerber's Core update behavior
  or required runtime dependencies. Intentional `Write-Host` output remains allowed.

## New Features

### Persistent plugin approval and lifecycle state

Gerber now asks before loading a plugin whose manifest GUID has not previously been approved. The approval screen identifies the plugin by name, GUID, version, publisher metadata, and location, with decline as the default.

Gerber now also persists plugin association and enabled/disabled state in the same user configuration. The first successful approval approves the GUID, associates the plugin with the user's Gerber environment, and enables it without a second prompt. Existing approved plugins without an explicit association record remain usable and pick up lifecycle state lazily the next time Gerber discovers them.

Declined decisions are now persisted too, so Gerber does not prompt again for the same unknown plugin on the next startup. Users can change that decision explicitly through `/plugins enable`.

Associated disabled plugins stay approved, but Gerber does not import them, execute `Get-GerberPlugin`, or register their commands until `/plugins enable` reenables them. Missing modules do not delete the saved association record. Noninteractive sessions load already approved and enabled plugins and skip unknown plugins without prompting or autoapproval. GUID approval identifies the selected plugin but is not a cryptographic signature or publisher-authenticity guarantee.

### Read-only plugin management

Gerber Core now includes the first user-facing plugin-management commands:

- `/plugins` shows a compact overview of every plugin identity Gerber currently knows about
- `/plugins list` shows the merged plugin inventory across discovered manifests, persisted configuration, and current-session loaded state
- `/plugins info <plugin>` shows detailed metadata and lifecycle state for one plugin by manifest GUID or unique module name

These commands stay read-only. They do not approve, decline, associate, enable, disable, remove, revoke, install, or uninstall anything.

**Key behaviors:**
- **Declined plugins remain visible:** a plugin declined earlier stays visible in `/plugins` even if it was never associated or is not currently discoverable
- **Missing associated plugins remain visible:** Gerber shows the persisted GUID and lifecycle state without inventing missing metadata
- **No unsafe inspection imports:** Gerber uses safe manifest inspection plus the existing registry cache, so unknown, declined, and disabled plugins are not executed just to render plugin management
- **Clear lifecycle distinctions:** approval, association, enabled/disabled state, and current loaded state are shown separately; declined is not disabled, and future revoke semantics remain distinct

`/plugins enable` lists installed inactive plugins, including previously declined plugins. Selecting one counts as approval without another confirmation. `/plugins disable` removes an active plugin's commands while preserving approval and leaving its module installed. Both actions persist across sessions and update menus, completion, and command dispatch immediately without restarting Gerber.

Root browsing and completion show `/exit`, `/help`, `/plugins`, and `/update` first, in that order, followed by all remaining Core and active plugin root commands alphabetically. Submenu ordering is unchanged.

### Enforced interactive regression coverage

Gerber now generates its terminal command inventory from the effective built Core/plugin registry
and verifies executable PTY coverage for command discovery, dispatch, workflows, navigation,
rendering, and error recovery. Full quality runs fail when required coverage is missing, stale, or
did not execute successfully, and publish JSON plus Markdown coverage reports under
`artifacts/terminal/runs/<run-id>/`.

This file summarizes public cmdlet, CLI, configuration, and migration changes for Gerber.
`CHANGELOG.md` remains the exhaustive record of all changes in each release. **UNRELEASED** changes will be included in the next **stable** release!

## [Unreleased]

### Added

- Added `/plugins enable` and `/plugins disable` to activate inactive plugins, including previously declined plugins, or deactivate active plugins without revoking approval or uninstalling their modules. Explicit enable counts as approval; changes persist and take effect without a restart.
- Root command browsing and completion now prioritize `/exit`, `/help`, `/plugins`, and `/update` in that order, then sort all other Core and active plugin root commands alphabetically.
- Added **G-UX1 — Double Escape to Root** so Gerber users can press `Esc` once to go back one level or press `Esc Esc` within 200 ms to jump directly to the root prompt without exiting Gerber or executing a command. The shortcut now works through the shared Core prompt/menu infrastructure, including nested subcommand prompts, continue screens, Base64 flows, and plugin-driven terminal views that use Gerber's shared prompt handling.
- Introduced the interactive `Invoke-Gerber` / `gerber` DevOps multitool for local terminal sessions.
- Added `/tools`, `/list`, `/secrets`, `/help`, and `/exit` inside the Gerber command palette, now starting from a minimal prompt-first home screen that shows `/ commands · esc back` beneath the empty root prompt, with interactive slash-command autocomplete and plain root action search across executable leaf commands, immediate visual highlighting for the visible default suggestion in chooser prompts such as the root `/` list, root action-search matches, `/tools`, `/list`, and `/secrets`, visual selection highlighting for arrow-key suggestion lists, Enter-to-accept suggestion flow, inline submenu prompts for slash commands such as `/tools`, `/list`, and `/secrets`, submenu-scoped prompt behavior, help previews, and optional prompt tracing through `GERBER_PROMPT_TRACE=1`.
- Added `/tools create-uuid` so users can generate a standard hyphenated UUID immediately, copy it to the clipboard when possible, press `Enter` to generate another, and use `Esc` to go back to `/tools`.
- Added `/tools base-64` with nested `encode` and `decode` actions for one-line UTF-8 text so users can convert Base64 values without leaving Gerber, return directly to the selected action after `Press Enter to continue`, use `Esc` to get back to the main Gerber menu from interactive prompts and continue screens, see the result in the terminal, and copy it to the clipboard when possible.
- Added `/secrets` with nested `list`, `get`, `test`, `set`, and `remove` actions backed by Gerber secure credential storage so users can manage Gerber-owned credentials inside the same slash-command menu, inspect identifiers without exposing values, copy a selected value to the clipboard before any terminal reveal when possible, confirm before revealing, overwriting, or removing values, and receive actionable errors when secure credential storage is unavailable.
- Improved HTTP resilience with explicit connection timeouts (`5s`) and operation timeouts (`15s`) so unreachable endpoints fail fast instead of hanging indefinitely.
- Gerber now stays inside the interactive menu when a recoverable runtime error happens and shows an actionable in-app error message instead of exiting to the PowerShell prompt.

### Changed

### Deprecated

### Removed

### Fixed

- Fixed **G-UX1-FIX1 — Shared Plugin Menu Navigation Regression** so `/plugins` now follows the same shared Core submenu contract as the other nested Gerber menus. Entering `/plugins` keeps plugin navigation inside the shared parent menu, `Esc` from `/plugins list` or `/plugins info` returns to `/plugins`, `Esc` from plugin details returns to the list, and rapid double-`Esc` still jumps directly to the root prompt.

### Security

