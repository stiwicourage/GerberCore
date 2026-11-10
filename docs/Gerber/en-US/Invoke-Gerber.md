---
document type: cmdlet
external help file: Gerber-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Gerber
ms.date: 11.02.2026
PlatyPS schema version: 2024-05-01
title: Invoke-Gerber
---

# Invoke-Gerber

## SYNOPSIS

Starts the interactive Gerber DevOps multitool.

## SYNTAX

### __AllParameterSets

```powershell
Invoke-Gerber [<CommonParameters>]
```

## ALIASES

This cmdlet has the following aliases,
- gerber

## DESCRIPTION

`Invoke-Gerber` starts Gerber Core's interactive command palette in the current
working directory. Core provides `/exit`, `/help`, `/plugins`, `/update`,
`/secrets` and `/tools`. Plugins are separate modules, not Core dependencies.
Plugin-contributed commands appear only while active plugins contribute them.
Menus, completion, help and direct lookup share the active registry.

Type `/` to browse or plain text such as `uuid` to search executable leaf actions.
Use Up/Down to select, Tab to complete and Enter to accept the highlighted
suggestion and execute a complete command. Roots prioritize `/exit`, `/help`,
`/plugins`, `/update`; remaining roots are alphabetical. Bare submenu commands
open inline choosers. Esc returns one level; double Esc within 200 ms returns to
the root prompt without exiting.

Startup attempts a bounded, noninteractive Core-only update check through
PSModuleUpdate. An available-version notification refers to `/update list`.
Startup never installs, asks for installation consent, requests credentials or
checks plugins. Failed checks leave the session usable without claiming currency.
Importing the module alone performs no update check or Nova lifecycle operation.

`/update list` checks Core and eligible installed plugins afresh. Core is bound to
official PSGallery and CurrentUser scope, without override, automatic repository
registration or alternate-feed fallback. Plugin repositories come from the installed
manifest's `PrivateData.Gerber.Repository` object: `Name` is displayed; `Uri` is
passed to PMU. Absent metadata defaults to PSGallery; invalid explicit metadata
never falls back. Legacy `RepositoryUri` is supported; canonical metadata wins.

With plugin rows present, Up/Down and Space select available updates, then Enter
reviews them. Selected packages are temporarily downloaded for manifest inspection
without a separate inspection prompt. A required permitted Core update is visibly
added; unsatisfied requirements block the dependent plugin.
Installation confirmation defaults to Cancel. With nothing available, continue
returns without a selection or installation prompt.

Updates run sequentially through PMU, Core first when required. Dependent plugins
are blocked on Core failure; independent selections can continue. Cancellation
stops later attempts. Results distinguish installation, verification, recovery and
fresh-process activation. Activation failure does not erase successful installation.
There is no first installation, hot reload or batch rollback. Repository credentials
are operation-local, not saved in metadata or fetched from native storage.

`/update policy` saves Stable only (default) or Include prereleases for Core startup
and manual Core/plugin discovery. Select Include prereleases to receive preview
updates. Enter saves the current selection; Esc leaves it unchanged. Policy
selection performs no discovery or installation; a change clears the old startup
notification and requires a fresh `/update list` plan.

After an update requiring restart, Continue with current version is the default;
Esc also continues with a retained reminder. Exit Gerber returns to PowerShell
without unloading modules. Console hosts also offer Exit Gerber and PowerShell;
other hosts require restarting the session from the host. Restart PowerShell,
then run `gerber` to activate installed updates.

`/plugins list` and `info` are read-only and do not import unknown, declined or
disabled plugins for inspection. Unknown plugins require GUID approval before
import, with decline as the default. Decisions persist across sessions. Approval
survives routine version updates but does not authenticate a publisher.
`/plugins enable` explicitly approves and activates a selected installed inactive
plugin without another approval prompt. `/plugins disable` removes its commands
immediately while preserving approval and installation. There are no remove or
revoke commands; uninstall the PowerShell module outside Gerber to remove or revoke it.

`/plugins create` asks for a suffix behind the fixed `Gerber.` prefix,
description, unused namespace, repository and destination parent (cwd by default).
PSGallery is preselected and writes an explicit Repository object. A custom source
takes a name and safe absolute URI; unknown URIs become
`REPLACE_WITH_REPOSITORY_URI`, which must be replaced and rebuilt before remote
publishing or updates. Creation validates a staged Plugin API v1 Nova project
without overwriting existing files, then approves, associates and enables the GUID.
It does not install or load the plugin. Generated name/version are available to
read-only inventory before installation. NovaModuleTools and PSModuleUpdate are
required runtime modules; Nova lifecycle operations run on demand.

`/tools create-uuid` displays a hyphenated UUID and copies it when possible; Enter
repeats and Esc returns to tools. `/tools base-64 encode` and `decode` convert
UTF-8 text, optionally copy results and reopen after continue. Invalid input
produces a recoverable error.

`/secrets` offers list, get, test, set and remove backed by native credential
storage. Listing and testing do not retrieve values. Get copies when possible
before asking to reveal the value. Set uses non-echoing input and confirms
overwrite; remove confirms deletion. No plaintext fallback is used.

## EXAMPLES

### Example 1

Start Gerber from PowerShell.

```powershell
Invoke-Gerber
```

### Example 2

Start the same session through its alias.

```powershell
gerber
```

### Example 3

After starting Gerber, use built-in help and Core tools.

```text
/help
/tools create-uuid
/tools base-64 encode
/tools base-64 decode
```

### Example 4

Inside Gerber, inspect plugins and choose the preview update channel before
checking available updates. Review the confirmation; Cancel is the default.

```text
/plugins list
/update policy
/update list
```

### Example 5

Inside Gerber, list stored identifiers or check one without retrieving its value.

```text
/secrets list
/secrets test
```

## PARAMETERS

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None

You cannot pipe input to this cmdlet.

## OUTPUTS

### None

Gerber renders terminal-oriented status and help rather than returning pipeline objects.

## NOTES

Requires PowerShell 7.4 or later, NovaModuleTools and PSModuleUpdate.
Plugin updates additionally require a PMU release exporting
`Get-PSModuleUpdateTargetManifest`; the numeric minimum alone does not guarantee it.
Live update has been verified on macOS only.

The startup child-process wait budget is 2,000 ms, without a persistent cache.
Noninteractive update views do not prompt or install. Failed discovery remains
Unavailable; NoMatchingPackage requires PMU's structured PackageNotFound identifier.
Neither result proves Core is current or offers installation.

Core configuration uses `GerberCore.json` in the platform-resolved user directory.
`GERBER_CONFIG_PATH` overrides the absolute Core file; a legacy `config.json` filename
selects sibling `GerberCore.json`. Plugin JSON files follow the Core file's directory,
using each module name. Plugin Configuration.Read/Save is identity-bound, with
missing-file null results, strict JSON errors and atomic writes.
The optional `coreUpdates.channel` is Stable or IncludePrerelease. Missing values
default without creating configuration; explicit invalid values are errors.
Obsolete `updates.modules.Gerber` settings cannot override PSGallery.

Credential identifiers are case-insensitive `gerber:<scope>:<name>` values; plugin
credentials use the manifest GUID's namespace. Secrets belong in native storage,
not JSON or traces. Linux storage needs a desktop Secret Service session, D-Bus
and libsecret. Unavailable storage fails with guidance, not plaintext fallback.

Set `GERBER_PROMPT_TRACE=1` before launch to write JSON lines under
`.gerber/prompt-debug.log` in cwd. Ordinary prompt input can appear in traces;
review and redact before sharing.

## RELATED LINKS

- [Test-GerberPluginBoundary](./Test-GerberPluginBoundary.md)
- [Gerber project](https://github.com/stiwicourage/GerberCore)
