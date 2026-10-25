---
document type: cmdlet
external help file: Gerber-Help.xml
HelpUri: ''
Locale: en-US
Module Name: Gerber
ms.date: 10.22.2026
PlatyPS schema version: 2024-05-01
title: Test-GerberPluginBoundary
---

# Test-GerberPluginBoundary

## SYNOPSIS

Checks authored plugin source for identifiable private Gerber Core dependencies.

## SYNTAX

### __AllParameterSets

```
Test-GerberPluginBoundary [[-Path] <string>] [<CommonParameters>]
```

## ALIASES

## DESCRIPTION

Parses source without executing it.
Returns IsValid, FileCount, PublicApi and
deterministic Diagnostics.
This development check is not a PowerShell sandbox.

## EXAMPLES

### EXAMPLE 1

```powershell
$result = Test-GerberPluginBoundary -Path ./Gerber.Example
$result.Diagnostics | Format-Table File, Line, Dependency, Reason, Resolution -Wrap
if (-not $result.IsValid) { throw 'Fix plugin boundary diagnostics before building.' }
```

Checks an uninstalled plugin without executing its source. Invalid source produces
structured diagnostics; callers decide whether to fail their build.

### EXAMPLE 2

```powershell
(Test-GerberPluginBoundary -Path .).PublicApi
```

Inspects operations derived from the installed Core's actual API v1 declarations.
This does not start Gerber, load plugins or read user configuration.

## PARAMETERS

### -Path

Plugin project directory containing authored PowerShell under src.

```yaml
Type: System.String
DefaultValue: .
SupportsWildcards: false
Aliases: []
ParameterSets:
- Name: (All)
  Position: 0
  IsRequired: false
  ValueFromPipeline: false
  ValueFromPipelineByPropertyName: false
  ValueFromRemainingArguments: false
DontShow: false
AcceptedValues: []
HelpMessage: ''
```

### CommonParameters

This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable,
-InformationAction, -InformationVariable, -OutBuffer, -OutVariable, -PipelineVariable,
-ProgressAction, -Verbose, -WarningAction, and -WarningVariable. For more information, see
[about_CommonParameters](https://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

### System.Management.Automation.PSObject

One result with IsValid, FileCount, PublicApi and Diagnostics. Each diagnostic
contains project-relative File, one-based Line and Column, Dependency, Reason
and actionable Resolution. Diagnostics are sorted deterministically.

## NOTES

PowerShell 7.4 or later. Authored .ps1, .psm1 and .psd1 files beneath src and scripts
are parsed recursively, along with root PowerShell files. Generated dist/artifacts
and tests outside those authored roots are not scanned. Parse failures
are diagnostics; missing paths or src directories are terminating errors.

This is a development-time architecture check, not runtime isolation, permissions
or a PowerShell sandbox. It recognizes static commands and literal imports,
simple literal concatenation and unambiguous prior literal variable assignments.
It does not prove arbitrary dynamic targets safe, follow aliases or perform
interprocedural dataflow. Local/plugin-owned function declarations are respected.
Review computed dependencies manually and request missing public capabilities.

## RELATED LINKS

- [Invoke-Gerber](./Invoke-Gerber.md)
