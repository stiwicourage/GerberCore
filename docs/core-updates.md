# Gerber Core updates

Gerber uses PSModuleUpdate (PMU) for Core discovery, version selection,
installation, verification and recovery. Gerber owns the repository policy,
the overview and your confirmation. Both PMU and NovaModuleTools remain required
modules; Nova's plugin-development operations are unrelated to update installation.
**Plugin updates are planned, not implemented in this phase.**

## Official Core repository

**PSGallery is the permanent, sole official Gerber Core distribution channel.**
This is an application-owned binding, not a configurable default. Startup and
`/update` explicitly pass `PSGallery` to PMU. User settings, environment variables
and plugin configuration cannot override it. There is no repository chooser or
fallback to another feed.

Core also supplies PMU with the expected official endpoint,
`https://www.powershellgallery.com/api/v2`. A missing or repointed PSGallery
registration is a discovery failure, not permission to use another repository.
Gerber does not register repositories or ask for Core repository credentials.

**Gerber Core has not yet been published to PSGallery.** Successful discovery
can therefore find no matching package. This is not a configuration error, does
not prove the installed version is current and does not offer installation.
Gerber never invents package versions or update results.

## Existing settings and plugin repositories

G-4A7R supersedes G-4A7's provisional configurable Core binding. The entire old
`updates.modules.Gerber` binding, including `repository`, `policy` and
`credential`, is ignored. No migration or configuration rewrite is performed;
unrelated settings and plugin configuration are left intact. Changing
`GERBER_CONFIG_PATH` does not change Core update policy.

Plugins have independently configurable repositories owned by Gerber; different
plugins may use different feeds. Both Core and plugins use PMU, but Core's
resolver does not consult plugin metadata or configuration. The per-plugin
contract and plugin update implementation remain **G-4A9**; this task adds neither.

## Prerelease policy

Core explicitly selects PMU's **Stable** channel and **CurrentUser** scope.
The installed `0.1.0-preview` remains unchanged and is displayed with its
prerelease label. PMU understands installed prerelease metadata and compares
semantic versions: stable `0.1.0` can supersede `0.1.0-preview`, as can a newer
stable release. Newer prereleases are excluded by the Stable channel, even
when the installed version is a preview. There is no user-selectable Core
channel in this implementation.

PMU also supports `IncludePrerelease`; Gerber does not enable it for Core.
All eligibility, ordering and exact-version selection remain PMU's responsibility,
not custom string comparisons in Gerber.

## Startup notification

`Invoke-Gerber` (or `gerber`), **not `Import-Module`**, attempts a Core check using
the executing module and fixed PSGallery binding. An eligible available version is shown
on the home screen with a reference to `/update`. The notification remains visible
on home-screen redraws for that session.

The provisional startup probe runs in a separate noninteractive PowerShell
process with a 2,000 ms wait budget; slow probes are terminated. There is no
persistent cache, installation or installation prompt. Offline, timeout,
unpublished-package and other unsuccessful checks leave Gerber usable and never
claim "up to date". Startup never opens native credential storage or requests
credentials. Only an eligible available update produces a notification.

## Review and install

Inside Gerber, run:

```text
/update
```

Each invocation checks afresh and shows a Core row with installed version,
available version, PSGallery and status. Core never reports `Unconfigured`.
No matching package or no eligible stable release is distinguished from a
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
Core is never hot reloaded. On failure, follow the displayed recovery guidance;
do not assume installation or rollback succeeded. Run `/update` again to recheck.
`Press Enter to continue` returns to the root workflow.

## Qualification and remaining scope

Core behavior is exercised using mocked PMU boundaries, disposable child
processes, built-module import and PTY terminal scenarios on macOS/PowerShell
7.4.21. This is **not** live Gerber installation qualification against PSGallery,
Azure Artifacts or Nexus, nor Gerber Windows/Linux qualification. A read-only
package lookup is not installation qualification. PMU's own
provider/platform results do not establish Gerber integration support.

Two limitations were observed with the installed PMU `0.1.0-preview`:

- Its installed-copy scan treats subdirectories of an existing flat,
  unversioned CurrentUser Gerber installation as version candidates. Ordinary
  `en-US`/`resources` directories then cause `PMU.ModuleIdentityMismatch`
  before repository discovery. Gerber reports Unavailable and PSGallery,
  not Unconfigured; no installation layout is migrated or bypassed.
- When PSResourceGet throws `PackageNotFound`, PMU currently replaces that
  identifier with `PMU.DiscoveryFailed` and withholds the original diagnostics.
  Gerber cannot safely classify that failure as successful no-package discovery.
  `NoMatchingPackage` is used only for PMU's explicit `PMU.PackageNotFound`.
  Gerber does not add a second package query or parse error text to guess.

These are blockers to complete live Core-update qualification, not passing
integration checks. A real read-only PSResourceGet lookup returned no Gerber
package in PSGallery; direct PMU lookup on the current installation stopped at
the identity issue above. No live update installation was attempted. Both PMU
behaviors need an upstream correction before that live path can be qualified.

Plugin repository association, per-plugin selection, approval/GUID continuity
and post-update activation still need their separate G-4A9 implementation and tests.
The authoritative [G-4A5 architecture](architecture/G-4A5-update-architecture.md)
and [D-017](../DECISIONS.md) include the G-4A7R repository-policy clarification.
