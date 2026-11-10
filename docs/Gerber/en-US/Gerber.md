---
document type: module
Help Version: 1.0.0.0
HelpInfoUri: ''
Locale: en-US
Module Guid: ec5ae6fe-540b-48c2-a6d1-cb39aac6c444
Module Name: Gerber
ms.date: 11/09/2026
PlatyPS schema version: 2024-05-01
title: Gerber Module
---

# Gerber Module

## Description

Gerber Core is an interactive DevOps multitool for PowerShell 7.4 or later.
It provides a slash-command palette, shared menus, native credential storage,
UUID/Base64 tools and update management. Core requires NovaModuleTools and
PSModuleUpdate; plugins are separate modules, never Core dependencies.

Use `Invoke-Gerber` (alias `gerber`) to start the interactive multitool.
Plugin authors use `Test-GerberPluginBoundary` to check for identifiable private
Core dependencies without executing source. This static check is not a sandbox.

Gerber is published on PSGallery as a preview. Install from PowerShell with
`Install-Module Gerber -Scope CurrentUser -AllowPrerelease`.
Inside Gerber, `/help` shows the active registry; `/update policy` chooses stable
or prerelease updates. Plugin commands appear only while active plugins contribute
them. Disable inside Gerber; uninstall a plugin's PowerShell module outside Gerber
to remove or revoke it.

## Gerber Cmdlets

### `PS> Invoke-Gerber`

Starts the interactive Gerber DevOps multitool.

### `PS> Test-GerberPluginBoundary`

Checks authored plugin source for identifiable private Gerber Core dependencies.
