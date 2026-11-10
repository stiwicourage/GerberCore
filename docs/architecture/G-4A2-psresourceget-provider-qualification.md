# Update provider and result reference

Audience: Gerber Core maintainers. This is a consumer contract, not a
provider/platform qualification report.

## Provider ownership

PSModuleUpdate supplies generic package operations over its provider.
Gerber does not issue a second package query, implement its own installer or
infer version eligibility from display strings.
The original live plan is retained from discovery through confirmed installation.

## Discovery results

| Result | Gerber behavior |
| --- | --- |
| Available | Show the exact eligible target and offer review/confirmation |
| UpToDate | Retain PMU's installed/target values; offer no installation |
| RestartRequired | Explain that a newer Core is already installed and the session must restart |
| `PMU.PackageNotFound` | Show NoMatchingPackage, with no plan or installation offer |
| Other discovery failure | Show Unavailable, never infer currency |
| `PMU.UnsupportedInstallation` | Show supported-layout guidance; missing native metadata can require reinstallation |

Gerber uses structured error identifiers, not exception-text guessing for
no-package classification. A failed or empty check is never evidence that Core
is up to date. Repository failure never triggers fallback to another source.

## Installation results

Report installation outcome separately from verification, recovery and activation.
Do not treat an activation failure as proof that package installation failed.
Preserve PMU recovery guidance and journals/backups when required; do not assume
rollback succeeded. Recheck before retrying.

Live update has been verified on macOS only. Provider-only tests do not establish
complete Gerber installation/recovery behavior on other platforms or feeds.

See [user guidance](../core-updates.md) and
[scope/channel reference](G-4A2-FIX2-installation-scope-and-prerelease-replacement.md).
