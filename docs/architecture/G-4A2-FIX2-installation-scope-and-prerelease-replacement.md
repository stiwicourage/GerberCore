# Installation scope and prerelease reference

Audience: Gerber Core maintainers and users diagnosing updates.

## Installation identity

Core updates always target CurrentUser scope. Plugin updates derive the selected
installed module's numeric CurrentUser or AllUsers path and never substitute
another installation. PMU independently validates the installation during planning
and installation.

Unsupported layouts are discovery failures, not evidence of an unavailable feed.
Gerber does not migrate flat-only installations, invent provider metadata or
automatically delete old copies.

For manually copied modules without native provider metadata, Gerber passes
`ReplaceUnmanagedInstallation` only when installed PMU supports it. Otherwise,
follow the reinstall guidance, restart PowerShell and check again.

## Channel policy

`/update policy` selects Stable only (default) or Include prereleases, shared by
Core and plugin manual checks and Core-only startup checks.
The installed version retains its prerelease label. PMU owns eligibility and
ordering: a stable release can supersede an installed prerelease, while Stable
excludes newer previews.

Choosing a channel performs no discovery or installation. A changed channel
invalidates the old plan and clears an old startup notification. Check afresh
with `/update list` before confirming.

## Activation

Updating a package does not reload the running module. Restart PowerShell, then
run `gerber`. Continue with current version is the default next step; console
hosts also offer Exit Gerber and PowerShell. Other hosts require restarting
their PowerShell session from the host.

See [update workflow and recovery](../core-updates.md#restart-and-recovery).
