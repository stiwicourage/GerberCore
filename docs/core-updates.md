# Gerber Core updates

Gerber uses PSModuleUpdate (PMU) for Core discovery, version selection,
installation, verification and recovery. Gerber owns the repository policy,
the overview and your confirmation. Both PMU and NovaModuleTools remain required
modules; Nova's plugin-development operations are unrelated to update installation.
**Plugin updates are planned, not implemented in this phase.**

## PMU dependency and deployment

Gerber requires numeric PMU **0.2.0** or later, as declared in `project.json`.
PMU 0.2.0 is published on PSGallery and includes the earlier installed-copy
scan correction. Gerber does not add its own version comparator.

The historical unpublished-dependency blocker is resolved. Installing or updating
the dependency remains a separate, explicitly approved deployment action, not part
of `/update`. An installation with only an older PMU cannot satisfy the current
minimum. Local qualification may use a built PMU artifact on an isolated session
module path, never edits to installed modules. Gerber does not automatically migrate,
delete or clean up local Gerber copies or module directories.
Updating this checkout or building Gerber does not replace an installed or
already-loaded PMU. The actual `gerber` launcher must resolve the new dependency
separately before source-level qualification applies to that session.

## Official Core repository

**PSGallery is the permanent, sole official Gerber Core distribution channel.**
This is an application-owned binding, not a configurable default. Startup and
`/update list` explicitly pass `PSGallery` to PMU. User settings, environment variables
and plugin configuration cannot override it. There is no repository chooser or
fallback to another feed.

Core also supplies PMU with the expected official endpoint,
`https://www.powershellgallery.com/api/v2`. A missing or repointed PSGallery
registration is a discovery failure, not permission to use another repository.
Gerber does not register repositories or ask for Core repository credentials.

Successful discovery can find no matching or eligible package. This is not a configuration error, does
not prove the installed version is current and does not offer installation.
Gerber never invents package versions or update results.

## Existing settings and plugin repositories

G-4A7R supersedes G-4A7's provisional configurable Core binding. The entire old
`updates.modules.Gerber` binding, including `repository`, `policy` and
`credential`, is ignored. No migration or configuration rewrite is performed;
unrelated settings and plugin configuration are left intact. `GERBER_CONFIG_PATH`
selects the user configuration file for the Core channel as well as other user
settings; it cannot override Core's repository, endpoint or installation scope.

Plugins have independently configurable repositories owned by Gerber; different
plugins may use different feeds. Both Core and plugins use PMU, but Core's
resolver does not consult plugin metadata or configuration. The per-plugin
contract and plugin update implementation remain **G-4A9**; this task adds neither.

## Prerelease policy

Core defaults to PMU's **Stable** channel and always uses **CurrentUser** scope.
For an installed `0.1.0-preview`, discovery leaves it unchanged and displays its
prerelease label. PMU understands installed prerelease metadata and compares
semantic versions: stable `0.1.0` can supersede `0.1.0-preview`, as can a newer
stable release. Newer prereleases are excluded by the Stable channel, even
when the installed version is a preview.

Run `/update policy` to choose **Stable only** or **Include prereleases**.
The latter passes PMU's `IncludePrerelease` channel, making both stable releases
and eligible previews available. The current choice is displayed and preselected;
use arrow keys to choose, `Enter` to save, or `Esc` to return without changes.
After saving, `Enter` returns to the `/update` submenu. Reselecting the same channel
does not write configuration.

The choice persists in the existing user configuration (schema version 1):

```json
{
  "schemaVersion": 1,
  "coreUpdates": {
    "channel": "IncludePrerelease"
  }
}
```

A missing section or channel means `Stable` and does not create a config file.
Explicit invalid values or types are configuration errors, not silent defaults.
Other settings are preserved. Save failures leave the active channel unchanged;
check the displayed configuration-path/write-permission guidance and retry.
Noninteractive dispatch does not open a chooser or change settings.

Policy selection performs no discovery or installation. The next `/update list`
uses the saved channel immediately, and the next startup uses the same file,
including when `GERBER_CONFIG_PATH` is set. Changing the channel clears an old
startup notification; it does not trigger a replacement check.
All eligibility, ordering and exact-version selection remain PMU's responsibility,
not custom string comparisons in Gerber.

## Startup notification

`Invoke-Gerber` (or `gerber`), **not `Import-Module`**, attempts a Core check using
the executing module and fixed PSGallery binding. An eligible available version is shown
on the home screen with a reference to `/update list`. The notification remains visible
on home-screen redraws for that session.

The provisional startup probe runs in a separate noninteractive PowerShell
process with a 2,000 ms wait budget; slow probes are terminated. There is no
persistent cache, installation or installation prompt. Offline, timeout,
unpublished-package and other unsuccessful checks leave Gerber usable and never
claim "up to date". Startup never opens native credential storage or requests
credentials. Only an eligible available update produces a notification.

## Review and install

`/update` opens the standard inline submenu with **list** and **policy**.
Enter at that chooser selects **list**; Esc returns one menu level.
To check directly, run:

```text
/update list
```

Each invocation checks afresh and shows a Core row with installed version,
available version, PSGallery and status. Core never reports `Unconfigured`.
The selected channel is shown beneath the overview and again in the installation
confirmation. If the channel changes after discovery, the old plan is rejected:
run `/update list` again before installing.
When PMU returns installed `0.1.0`, target `0.1.0` and `UpToDate`, the
**Available** column remains `0.1.0`, the status remains `UpToDate`, and
no installation is offered. Gerber maps PMU's plan directly; it does not
re-query the gallery or compare versions to decide whether to show a target.
No matching package or no eligible release under the selected channel is distinguished from a
repository/discovery failure when PMU supplies its structured
`PMU.PackageNotFound` result; none of these offers installation.
Only an available update offers installation. The confirmation retains the
overview and scope, explains any required operation-local repository trust or
license acceptance, and defaults to **Cancel**. Bare `Enter` cancels; `Esc`
backs out through Gerber's shared navigation. Noninteractive update views
do not prompt, access native credentials or install.

After acceptance, Gerber passes the original live PSGallery-bound PMU plan to
`Install-PSModuleUpdate`; it does not implement its own installer, locks or rollback.
Results show verification/recovery status and restart guidance when required.
After a verified successful installation requiring restart, or discovery status
`RestartRequired` for a newer Core already installed, the standard chooser offers
**Continue with current version** (default) and **Exit Gerber**. Bare Enter or
Esc continues to the `/update` menu with a restart reminder retained on home-screen
redraws. Exit returns from Gerber only: it does not restart or close PowerShell,
spawn another shell, or reload Core/plugins. **Restart PowerShell, then run
`gerber`** to use the installed Core.

Core is never hot reloaded. Cancelled, unverified, failed, no-package and up-to-date
outcomes do not offer this exit chooser. On failure, follow the displayed recovery guidance;
do not assume installation or rollback succeeded. Run `/update list` again to recheck.
For outcomes without the restart chooser, `Press Enter to continue` returns to
the `/update` chooser. Esc from policy
selection also returns to that chooser; a further Esc goes back toward home.

## Qualification and remaining scope

Core behavior has automated coverage using mocked PMU boundaries, disposable child
processes, built-module import and PTY terminal scenarios. Earlier local
qualification used macOS/PowerShell 7.4.21. On 2026-10-27, a user-reported live
PSGallery update from Gerber `0.2.0` to `0.2.1-preview` completed with
`Verification: Verified` and `Recovery: NotRequired`; the next check correctly
reported `RestartRequired`. This is happy-path evidence, not complete
installation/recovery qualification or live-update qualification on Windows/Linux,
Azure Artifacts or Nexus. A read-only lookup and PMU's own provider/platform
results are not substitutes for Gerber integration evidence.

Hosted tests at revision `d599443` passed on 2026-10-29 with 1,858 unit tests,
17 integration tests and 96.54% coverage; two native credential scenarios were
opt-in skips in that run. The separate Windows/Linux/macOS matrix passed both
credential scenarios per platform, not live Core updates. See
[G-4A7R evidence](../PLAN.md#g-4a7r-closure-evidence-and-remaining-work).

The earlier installed PMU `0.1.0-preview` exposed two separate limitations:

- Its installed-copy scan treats subdirectories of an existing flat,
  unversioned CurrentUser Gerber installation as version candidates. Ordinary
  `en-US`/`resources` directories then cause `PMU.ModuleIdentityMismatch`
  before repository discovery. Upstream `0.1.1-preview` corrects this scan:
  legacy `en-US`/`resources` directories without a module manifest beside
  numeric version installations are ignored, while genuine invalid candidates
  are still rejected. A flat-only copy is not selected as a versioned
  installation or migrated. Gerber consumes that correction through its
  current numeric `0.2.0` minimum, which includes the correction; PMU owns the
  layout regression tests.
- When PSResourceGet throws `PackageNotFound`, published PMU 0.2.0 replaces that
  identifier with `PMU.DiscoveryFailed` and withholds the original diagnostics.
  Gerber cannot safely classify that failure as successful no-package discovery.
  `NoMatchingPackage` is used only for PMU's explicit `PMU.PackageNotFound`.
  Gerber does not add a second package query or parse error text to guess.

The upstream `PackageNotFound` correction and broader live-update/recovery
qualification remain open. A local correction must not be presented as a
published or deployed fix, and the dependency minimum is not raised speculatively.
Historically, a read-only PSResourceGet lookup returned no Gerber package in
PSGallery and direct PMU lookup stopped at the identity issue before the correction.
Those earlier observations are not current feed state.

**Read-only verification, 2026-10-25:** the public `Get-PSModuleUpdate` command
from built PMU `0.1.1-preview`, supplied the installed versioned Gerber `0.1.0`
module and official PSGallery Stable/CurrentUser policy, returned
`InstalledVersion: 0.1.0`, `TargetVersion: 0.1.0`, `Disposition: UpToDate`.
This verifies the original local mixed-layout lookup against the actual feed.
No global module/repository changes or installation were performed.
It does not qualify a flat-only installation, dependency bootstrap or the
complete live installation/recovery path.
It also does not qualify a different executing Gerber version, such as a local
`0.1.1-preview`. If that session's PMU check fails, Available remains `-` and
status remains `Unavailable`; Gerber must not infer currency from the `0.1.0`
probe, perform another gallery query or compare versions itself.

**Later installed-launch diagnosis, 2026-10-25:** the user's locally published
Gerber and PMU were both `0.1.1-preview` in flat-only layouts, without numeric
version folders. Installed PMU contained the corrected candidate filter.
Public discovery returned `PMU.UnsupportedInstallation`:
`No existing installation was found in the requested scope.`
This is the unsupported flat-only installation boundary, not the old identity
scan error or a PSGallery failure. The corrected source does not select or
migrate that flat copy; qualification of a supported installation remains a
separate approved action. No installation mutation is performed by this change.
An exact real-launch PTY check through the user's `gerber` launcher reproduced
Available `-` / `Unavailable` and returned safely to the home prompt.

Gerber now maps the structured `PMU.UnsupportedInstallation` identifier to
generic supported-layout guidance: install Gerber in a supported numeric-version
module directory, restart PowerShell and retry `/update list`. This identifier can
have multiple causes; Gerber does not parse exception text or label every case
as flat-only. The message assumes neither successful installation nor rollback,
and the update view offers no installation for this discovery failure.
An already-installed/running Gerber copy retains its old diagnostic until the
user separately updates that copy; editing this checkout does not change it.

Plugin repository association, per-plugin selection, approval/GUID continuity
and post-update activation still need their separate G-4A9 implementation and tests.
The authoritative [G-4A5 architecture](architecture/G-4A5-update-architecture.md)
and [D-017](../DECISIONS.md) include the G-4A7R repository-policy clarification.
