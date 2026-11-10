# PSModuleUpdate integration reference

Audience: Gerber Core maintainers.

## Public engine boundary

Gerber calls PMU rather than implementing a second updater:

| PMU operation | Gerber use |
| --- | --- |
| `Get-PSModuleUpdate` | Discover an eligible target and retain its original live plan |
| `Get-PSModuleUpdateTargetManifest` | Inspect an exact selected plugin candidate without importing or installing it |
| `Install-PSModuleUpdate` | Install the confirmed original plan and report verification/recovery |

The target-manifest operation is a plugin-update requirement beyond the declared
numeric minimum. See [requirements](../core-updates.md#requirements).

## Policy and consent

Core discovery passes the executing module, explicit PSGallery repository,
official endpoint, shared channel and CurrentUser scope. Plugin discovery uses
the current installed manifest's repository and the selected installation's scope.
PMU owns package eligibility and exact-version selection; Gerber validates plugin
GUID, API compatibility and minimum Core requirements.

Plans are not serialized into user configuration. A channel change requires fresh
discovery. Available candidates are inspected before a combined, default-Cancel
installation prompt. Trust/license options apply to the operation, not a blanket
permission for future updates.

## Results

Installation, verification, recovery and fresh-process activation are distinct.
Dependent plugins are blocked when required Core installation fails; independent
updates can continue. User cancellation stops future attempts.
There is no batch rollback or in-process hot reload.

See [update architecture](G-4A5-update-architecture.md) and
[provider/result handling](G-4A2-psresourceget-provider-qualification.md).
