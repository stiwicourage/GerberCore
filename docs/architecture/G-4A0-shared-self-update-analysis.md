# Update ownership reference

Audience: maintainers of Gerber Core and plugin authors.

## Responsibility boundaries

| Component | Owns |
| --- | --- |
| Gerber Core | Interactive commands, configuration, plugin lifecycle, repository policy, update presentation and consent |
| PSModuleUpdate | Generic discovery, package/version selection, installation, verification, locks and recovery |
| NovaModuleTools | Plugin-development build, tests, packaging and local publication |
| Plugin module | Its authored functionality and installed repository metadata |

NovaModuleTools and PSModuleUpdate are required Core runtime modules.
Plugins are separate modules, never Core dependencies. Neither Nova's lifecycle
operations nor PMU installation runs merely because Gerber is imported.

## User entry points

- `Invoke-Gerber` attempts a notification-only Core update check.
- `/update list` discovers afresh, includes eligible installed plugins and requires
  installation confirmation, defaulting to Cancel.
- `/update policy` changes the shared stable/prerelease channel without checking
  or installing anything.

Core is fixed to official PSGallery and CurrentUser scope. Plugin repositories
do not override it. No component is hot reloaded in the running session.

See the [current update architecture](G-4A5-update-architecture.md) and
[user workflow](../core-updates.md). Project decisions and execution evidence
belong in the repository's decision/work registers, not in this reference.
