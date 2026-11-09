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

Gerber is an interactive DevOps multitool for the terminal. It provides a slash-command palette, shared menus, secure credential handling and a plugin platform that product plugins build on.

Use the module to start the interactive multitool with `Invoke-Gerber` (alias `gerber`), or to validate that authored plugin source depends only on the public Plugin API with `Test-GerberPluginBoundary`.

## Gerber Cmdlets

### `PS> Invoke-Gerber`

Starts the interactive Gerber DevOps multitool.

### `PS> Test-GerberPluginBoundary`

Checks authored plugin source for identifiable private Gerber Core dependencies.
