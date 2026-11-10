# Gerber Core and plugin updates

Gerber owns update presentation, repository policy and confirmation.
PSModuleUpdate (PMU) owns package discovery, version selection, installation,
verification and recovery. NovaModuleTools supplies the separate plugin-development
build/test/publication toolchain. Plugins are independent modules, not Core dependencies.

## Requirements

Gerber requires NovaModuleTools and PSModuleUpdate. The declared minimum PMU
version is `0.2.0`.

**Plugin updates require a PSModuleUpdate release that exports
`Get-PSModuleUpdateTargetManifest`.** The declared minimum alone does not
guarantee that capability: PMU `0.2.0` does not export it. Without the capability,
selected plugin candidates cannot be verified and are blocked before installation.
Dependency installation or replacement is a separate PowerShell operation;
`/update` does not bootstrap PMU. Building Gerber does not replace an installed
or already-loaded dependency.

Gerber itself is published on PSGallery as a preview:

```powershell
Install-Module Gerber -Scope CurrentUser -AllowPrerelease
```

## Official Core repository

**PSGallery is the fixed, sole official Core source**, with endpoint
`https://www.powershellgallery.com/api/v2` and **CurrentUser** scope.
Startup and manual checks explicitly select it. User settings, environment
variables and plugins cannot change that binding; no alternate-feed fallback exists.

Gerber does not automatically register repositories or ask for Core repository
credentials. A missing or repointed PSGallery registration is a discovery failure,
not permission to use another source. Obsolete `updates.modules.Gerber` settings
are ignored without rewriting unrelated configuration.

## Shared stable/prerelease policy

Inside Gerber, run:

```text
/update policy
```

Choose **Stable only** (default) or **Include prereleases**. Gerber is currently
distributed as previews, so select Include prereleases to receive preview updates.
Stable excludes newer previews even when the installed version is a preview;
an eligible stable release can supersede an installed prerelease. PMU handles
version eligibility and ordering.

The current choice is preselected. Enter saves it; Esc leaves it unchanged.
After saving, Enter returns to `/update`. Saving the same choice does not rewrite
configuration. Save errors leave the active policy unchanged.

The choice applies to Core startup checks and manual Core/plugin checks.
Startup never checks plugins. Policy selection performs no discovery or
installation, and a change clears the old startup notification. Run `/update list`
again before installing; plans from another channel are rejected.

The setting is optional in schema-version-1 `GerberCore.json`:

```json
{
  "schemaVersion": 1,
  "coreUpdates": {
    "channel": "IncludePrerelease"
  }
}
```

Missing settings mean `Stable` without creating a file; explicit invalid values
or types are configuration errors. `GERBER_CONFIG_PATH` selects the same absolute
Core configuration file for startup and manual checks, not another repository or
installation scope. Noninteractive policy dispatch does not change settings.

## Startup notification

`Invoke-Gerber` (alias `gerber`), not `Import-Module`, attempts a Core-only check
in a noninteractive child PowerShell process with a 2,000 ms wait budget.
Slow probes are terminated. An eligible update produces a home-screen notification
referring to `/update list`, retained across redraws.

There is no persistent cache, installation, consent prompt, credential request or
native credential-store access. Offline, timeout and unsuccessful checks leave
Gerber usable. Failed discovery or no matching package is never called “up to date”.

## Review and install

`/update` opens the **list**/**policy** submenu; Enter selects list. To check directly:

```text
/update list
```

Each invocation checks afresh. The aligned overview shows component, name,
installed/available versions, repository and status, with the shared channel
beneath the table. PMU's target is retained even for equal installed/available
versions with `UpToDate`; no installation is offered in that case.

Plugin rows include only already installed, discovered, associated, approved and
enabled plugins. With plugin rows present, Up/Down and Space select available
components; Enter reviews them. Unavailable and blocked rows remain visible but
cannot be selected. An empty selection cancels. If nothing is available, Enter
returns without a chooser, installation prompt or cancellation message.

Selected plugin packages are temporarily downloaded for exact-manifest inspection
without installation or a separate inspection prompt. Gerber verifies manifest
GUID, Plugin API v1 and `MinimumGerberVersion`. A permitted required Core update
is visibly added to the combined preview; a plugin is blocked if no permitted
Core target satisfies it. Required operation-local repository trust and package
license acceptance are included in the operation; users remain responsible for
the packages they select.

The final preview lists full versions, Core requirements, source URIs and scope.
**Cancel is the default**: bare Enter installs nothing. Esc uses the shared
back-navigation rules. Noninteractive update views show status only and never
prompt, request credentials or install.

After acceptance, PMU receives the original live plans, sequentially and Core
first when required. A Core failure blocks dependent plugins, not independent
selections. Individual failures do not stop later independent attempts;
cancellation does. There is no first installation, hot reload or batch rollback.
Results distinguish installation, verification, recovery and fresh-process
activation. Activation failure does not relabel an installed package as uninstalled.

## Plugin repositories

Each plugin declares this metadata in `project.json` under
`Manifest.PrivateData.Gerber`; Nova carries it into the installed manifest:

```json
{
  "Repository": {
    "Name": "ExampleFeed",
    "Uri": "https://packages.example.test/api/v2"
  }
}
```

Gerber reads the current installed manifest, not cached module PrivateData.
The overview shows `Name`, including unavailable/no-package results; PMU and
trust confirmations use the canonical `Uri`. Different plugins can use different
feeds without affecting Core.

Absent metadata defaults to PSGallery and its official endpoint. Invalid explicit
metadata, including `REPLACE_WITH_REPOSITORY_URI`, never falls back or triggers a
lookup against PSGallery. URIs must be absolute and contain no credentials,
query or fragment. Do not add an `Update` intermediary or store credentials here.

Legacy `RepositoryUri` remains supported: the official Gallery URL displays
PSGallery, while other URLs display as URLs. The canonical `Repository` object
takes precedence when both keys exist.

Gerber derives a plugin's existing numeric CurrentUser or AllUsers installation
scope without substituting another installation; PMU independently validates it.
Repository credentials use per-operation secure input and are neither saved in
metadata nor fetched from native credential storage.

## Restart and recovery

After verified installation requiring restart, or discovery of a newer Core
already installed, the next-step chooser defaults to **Continue with current
version**. Enter or Esc continues with a retained restart reminder.
**Exit Gerber** returns to PowerShell; it does not unload modules or restart it.
Supported console hosts also offer **Exit Gerber and PowerShell**, which closes
that session. Other hosts require restarting the session from the host itself.
Start PowerShell again, then run `gerber`. Core and plugins never hot reload.

For other outcomes, the continue screen returns to `/update`. Cancelled, failed,
unverified, no-package and up-to-date outcomes do not imply a successful update.
Follow displayed recovery guidance and preserve PMU journals/backups when requested;
never assume rollback succeeded. Obtain a fresh plan with `/update list` before retrying.

Unsupported installation layouts need a supported numeric-version module directory.
For locally copied installations without native provider metadata, automatic
replacement depends on PMU's `ReplaceUnmanagedInstallation` support. Otherwise,
follow the reinstall-from-PSGallery guidance, restart PowerShell and retry.
Gerber does not manufacture provider metadata, migrate flat-only installations or
automatically delete local copies.

No matching package is distinct from repository failure only when PMU supplies
the structured `PMU.PackageNotFound` identifier. Other discovery failures remain
`Unavailable`; Gerber does not issue a second query or parse error text to guess.
Neither result proves Core is current or offers installation.

## Known limitation

Live update has been verified on macOS only. Do not assume complete
Windows/Linux live installation or failure/recovery coverage.
