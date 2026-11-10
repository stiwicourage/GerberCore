# Core and plugin update architecture

Audience: Gerber Core maintainers. For user steps, see
[Core and plugin updates](../core-updates.md).

## Runtime dependencies

NovaModuleTools and PSModuleUpdate are the only required Core runtime modules.
Plugins are separate modules, never dependencies of Core. Nova supports
application-exposed plugin development: Core owns templates and creation UX,
while Nova supplies build, tests, packaging and local publication. PMU owns
generic update mechanics. Required-module resolution is distinct from running
those operations.

The numeric manifest minimum is not a prerelease/channel pin and does not
guarantee every optional engine capability. Plugin updates require a PMU release
exporting `Get-PSModuleUpdateTargetManifest`; see
[the requirement note](../core-updates.md#requirements).

## Repository and channel policy

Core is permanently bound to PSGallery, endpoint
`https://www.powershellgallery.com/api/v2`, and CurrentUser scope.
User/environment/plugin settings cannot override it. No repository registration,
credential prompt or alternate-source fallback occurs for Core.
Obsolete `updates.modules.Gerber` settings are ignored.

Each plugin's installed manifest supplies `PrivateData.Gerber.Repository`
with display `Name` and canonical `Uri`. Missing metadata defaults to PSGallery;
invalid explicit metadata never falls back. Canonical metadata takes precedence
over legacy `RepositoryUri`. Plugin updates use the existing selected numeric
CurrentUser/AllUsers scope, not a substitute installation.

The optional `coreUpdates.channel` setting is Stable by default or
IncludePrerelease. Startup and manual checks share it; only manual checks include
plugins. Invalid explicit values fail configuration validation. Selecting a policy
does not check or install; a change requires fresh discovery.

## Startup boundary

`Invoke-Gerber`, not module import, attempts a Core-only child-process probe with
a 2,000 ms wait budget. The probe is noninteractive, has no persistent cache,
and never installs, accesses native storage or requests credentials.
Only an eligible available update produces a home-screen notification.
Failure never blocks startup or claims currency.

## Manual update flow

1. `/update list` obtains fresh Core and eligible plugin plans.
2. The overview keeps all status rows visible; only available updates are selectable.
3. Selected plugin packages are temporarily downloaded for exact-manifest
   inspection, without another inspection prompt. Core validates GUID, API v1
   and minimum Core requirements.
4. A permitted required Core update is visibly included. Unsatisfied dependencies
   block the plugin.
5. A combined source/scope/version preview requires confirmation, default Cancel.
6. PMU installs original plans sequentially, Core first when required.
7. Results distinguish installation, verification, recovery and isolated
   fresh-process activation.

Eligible plugins are installed, discovered, associated, approved and enabled.
Read-only discovery does not grant approval or offer first installation.
Dependency failure blocks dependent items; independent selections can continue.
Cancellation stops further attempts. There is no batch rollback or hot reload.
Credentials are operation-local, not persisted in metadata or retrieved from
native credential storage. Noninteractive views only render status.

## Restart and recovery

Verified installation requiring restart, or a newer Core already installed,
offers Continue with current version (default) and Exit Gerber. ConsoleHost also
supports Exit Gerber and PowerShell. Exiting Gerber alone does not unload modules.
Other hosts require restarting the PowerShell session from the host.

Follow PMU's recovery guidance and preserve its journals/backups where requested.
Gerber does not manufacture provider metadata or automatically migrate flat-only
installations. Unmanaged replacement is passed only if installed PMU supports it.
Failed discovery remains Unavailable; only structured PMU.PackageNotFound maps
to NoMatchingPackage.

## Implementation map

- [Core policy](../../src/private/config/Resolve-GerberCoreUpdatePolicy.ps1)
- [Startup check](../../src/private/update/Invoke-GerberStartupUpdateCheck.ps1)
- [Core discovery](../../src/private/update/Get-GerberCoreUpdateState.ps1)
- [Plugin eligibility](../../src/private/update/Test-GerberPluginUpdateEligibility.ps1)
- [Installed plugin repositories](../../src/private/update/Resolve-GerberPluginUpdateState.ps1)
- [Candidate inspection and dependencies](../../src/private/update/Resolve-GerberUpdateBatch.ps1)
- [Default-Cancel batch view](../../src/private/cli/Show-GerberUpdateBatchView.ps1)
- [Restart choices](../../src/private/cli/Get-GerberRestartMenuItemList.ps1)

<a id="11-historical-reconciliation"></a>
<a id="5-required-runtime-dependencies-decided-declarations-present"></a>

## Reference boundaries

This page describes the current consumer contract. Project history, dated
execution evidence and remaining release qualification belong in the repository's
decision/work registers. Live update has been verified on macOS only.
