# Plugin API v1 capabilities

This document records the current **implemented** Plugin API v1 surface that Gerber Core exposes to installed plugins such as `Gerber.ExampleOrg`.

For a working minimal consumer, use [`/plugins create`](../plugins-create.md).
Gerber generates a namespace parent and `hello` leaf, using only the supplied
`UI.ReadSubcommand`, `UI.ShowTextBlock` and `UI.WaitForContinue` operations. Nova
generates the manifest from `project.json`, including `Manifest.PrivateData.Gerber`
(`Plugin: true`, `ApiVersion: "1"` and minimum Core version).
Only `Manifest.GUID` defines project identity; no redundant
`PrivateData.Gerber.Guid` is generated. The public plugin definition's `Guid`
still matches the canonical manifest GUID for registration.
Generated AGENTS.md embeds the relevant public capability contract and command
development workflow; thin tool bridges and focused skills reference that guide.

## Capability inventory

### UI

| Operation | Signature | Purpose |
| --- | --- | --- |
| `ReadSubcommand` | `($CommandName, $Command, $SubcommandTable)` | Reuse Gerber's inline submenu flow. |
| `ShowTextBlock` | `($Title, $Text)` | Render plugin result and error screens through Gerber-owned terminal UI. |
| `ShowScreenLines` | `($Title, $LineList)` | Render a Gerber-owned action screen before plugin work. |
| `ReadNumberedMenuSelection` | `($Prompt, $ScreenTitle, $ScreenText, $MenuItemList)` | Reuse Gerber's numbered chooser flow. |
| `ReadNumberedMenuPrompt` | `($Prompt, $ScreenTitle, $ScreenText, $MenuItemList)` | Reuse Gerber's generic numbered prompt flow. |
| `ReadCheckboxMenuPrompt` | `($PromptRequest)` | Reuse Gerber's checkbox prompt flow. |
| `ReadConfirmationPrompt` | `($Prompt, $ScreenTitle, $ScreenText, $PromptOptionSet)` | Reuse Gerber's confirmation prompt flow. |
| `ReadCommand` | `($Prompt, $SuggestionMode, $InputMode, $PromptContext, $TrimResult)` | Reuse Gerber's inline command-input prompt flow. |
| `ReadSecretText` | `($Prompt)` | Read a secret value with Gerber's secure input behavior and escape handling. |
| `StartScreen` | `($Name)` | Start a Gerber-owned screen region. |
| `WriteScreenLine` | `($Text = '')` | Write one Gerber-owned screen line. |
| `WriteProgressBar` | `($Current, $Total, $Prefix, $OverwritePreviousRender)` | Reuse Gerber's progress-bar rendering. |
| `WritePromptTrace` | `($EventName, $Data = @{})` | Emit prompt-trace events through Gerber's tracing infrastructure. |
| `WaitForContinue` | `()` | Return control through Gerber's continue-screen contract. |

### Ado

| Operation | Signature | Purpose |
| --- | --- | --- |
| `OpenConnection` | `($CommandLabel, $ProfileName = '')` | Resolve the default or an explicit named Azure DevOps connection through Gerber-owned profile selection and readiness. |
| `NewProjectUri` | `($Connection, $RelativePath, $QueryParameterMap = [ordered]@{})` | Build a connection-scoped Azure DevOps API URI without retrieving a PAT. |
| `InvokeGet` | `($Connection, $Uri, $RequestLabel)` | Execute a Core-owned authenticated Azure DevOps GET request. |
| `GetPendingApprovalList` | `($Connection, $EnvironmentId)` | Read pending pipeline approvals. |
| `GetEnvironmentList` | `($Connection)` | Read Azure DevOps environments. |
| `ResolvePipelineDefinitionFromUrl` | `($Connection, $PipelineUrl)` | Resolve a pipeline definition from a build URL. |
| `GetPipelineRunList` | `($RunListRequest)` | Read build/run metadata through a request object whose `Connection` is resolved by Core. |
| `StartPipelineRun` | `($RunRequest)` | Start a pipeline run through a request object whose `Connection` is resolved by Core. |
| `WaitPipelineRunCompletion` | `($RunWaitRequest)` | Poll a pipeline run through a request object whose `Connection` is resolved by Core. |
| `ApprovePipelineApproval` | `($Connection, $ApprovalId, $Comment)` | Approve a pending pipeline approval. |
| `StopPipelineRun` | `($Connection, $BuildId)` | Stop a pipeline run. |
| `GetBuildTagList` | `($Connection, $BuildId)` | Read build tags for a run. |
| `AddBuildTagIfMissing` | `($Connection, $BuildId, $Tag)` | Add a build tag when it is not already present. |
| `RemoveBuildTag` | `($Connection, $BuildId, $Tag)` | Remove a build tag from a run. |
| `AddBuildRetentionLeaseIfMissing` | `($Connection, $DefinitionId, $BuildId)` | Ensure a retention lease exists for a run. |
| `GetBuildRunUrl` | `($Connection, $BuildId)` | Build the Azure DevOps run URL from the selected connection without retrieving a PAT. |
| `GetWorkItemIdFromUrl` | `($WorkItemUrl)` | Parse a work-item ID from an Azure DevOps work-item URL. |
| `GetWorkItemFieldMap` | `($WorkItemRequest)` | Read work-item fields through a request object whose `Connection` is resolved by Core. |
| `UpdateWorkItemFields` | `($UpdateRequest)` | Apply generic work-item field updates through a request object whose `Connection` is resolved by Core. |

### ADO connection context

`OpenConnection` now returns a non-sensitive connection context rather than a PAT-backed opaque handle. The context keeps the selected profile bound to later operations:

```powershell
$defaultConnection = & $Gerber.Ado.OpenConnection '/repository review'
$namedConnection = & $Gerber.Ado.OpenConnection '/pipelines release common-data-model' 'SampleProject'

$namedConnection.ProfileName
$namedConnection.DeploymentType
$namedConnection.ServerUri
$namedConnection.CollectionUri
$namedConnection.ProjectName
$namedConnection.ProjectUri
```

Current public properties:

- `Id`
- `CommandLabel`
- `ProfileName`
- `DeploymentType`
- `ServerUri`
- `Organization`
- `Collection`
- `CollectionName`
- `CollectionUri`
- `ProjectName`
- `ProjectUri`

The connection context never includes a `Pat`, `Token`, or `CredentialIdentifier` property.

### Default and explicit profile behavior

- `OpenConnection '/command label'` uses the configured default profile when one exists.
- If no default exists, Core reuses the existing readiness flow: one-profile reuse, multi-profile selection, or first-use setup.
- `OpenConnection '/command label' 'SampleProject'` resolves that exact profile name case-insensitively and preserves the configured display casing in the returned context.
- An explicit profile never falls back to the default profile. If the profile is missing, Core reuses the existing readiness flow to configure that exact profile in interactive sessions and returns an actionable error in non-interactive sessions.

### Authentication and credential boundaries

- `OpenConnection` resolves connection metadata only. It does **not** retrieve a PAT.
- Authenticated ADO operations retrieve the PAT lazily through Gerber Core and the native credential store entry `gerber:ado:<profile>:pat`.
- Metadata-only operations such as `NewProjectUri` and `GetBuildRunUrl` do not trigger PAT lookup or PAT setup prompts.
- Plugins do not need to read `config.json`, construct credential identifiers, or access Keychain / Credential Manager directly.

### Multiple connections

Every ADO operation now uses the supplied connection context rather than re-reading the default profile implicitly:

```powershell
$example = & $Gerber.Ado.OpenConnection '/repository review' 'EXAMPLE'
$atlas = & $Gerber.Ado.OpenConnection '/list common-data-model' 'ATLAS'

$examplePullRequest = & $Gerber.Ado.GetPullRequest $example $pullRequestReference
$atlasRunUrl = & $Gerber.Ado.GetBuildRunUrl $atlas 6406
```

This allows multiple named connections to coexist in the same Gerber session without switching global state.

### Non-interactive behavior

When Gerber runs without interactive console input:

- missing explicit profiles fail with guidance to configure that exact profile and its native credential first
- missing PATs fail with guidance to configure secure credential storage and rerun interactively
- no prompts are shown during plugin execution

### Secrets

| Operation | Signature | Purpose |
| --- | --- | --- |
| `EnsureReady` | `($ActionLabel, $ScreenTitle)` | Verify that Gerber secure credential storage is available. |
| `Test` | `($PathSegmentList)` | Check whether a logical plugin-owned secret already exists without exposing storage details. |
| `GetText` | `($PathSegmentList)` | Retrieve a logical secret as plain text for immediate in-memory use. |
| `Set` | `($PathSegmentList, $Secret)` | Create or update a logical secret through Gerber's credential service. |
| `Remove` | `($PathSegmentList)` | Remove a logical plugin-owned credential. |

### Clipboard

| Operation | Signature | Purpose |
| --- | --- | --- |
| `CopyText` | `($Value)` | Copy plugin output through Gerber's clipboard abstraction and fallback messaging. |

## Ownership notes

- **UI** stays in Core because Gerber owns terminal rendering, prompt behavior, escape semantics, tracing, and continue routing across built-in commands and plugins.
- **Ado** stays in Core only for generic Azure DevOps infrastructure. Plugins receive an opaque connection handle rather than raw PAT values or the full Core configuration object.
- **Secrets** stay in Core because secure credential storage and logical-name translation are shared infrastructure rather than organization-specific behavior. Core maps each path to `gerber:plugin:<manifest-guid>:<path>`, where the plugin identity is the PowerShell module manifest GUID.
- **Clipboard** stays in Core because clipboard detection and fallback behavior are shared terminal infrastructure rather than plugin logic.

Plugin credential names are logically separated to prevent accidental collisions and normal API access across plugins. This is not process isolation or a security sandbox: plugins execute as PowerShell code in the user's process.

## Development-time boundary validation

Installed Gerber exports a development command that does not start the host,
require Nova, read user configuration, install the plugin or execute its source:

```powershell
Import-Module Gerber
$result = Test-GerberPluginBoundary -Path ./Gerber.MyCompany
$result.PublicApi
$result.Diagnostics | Format-Table File, Line, Dependency, Reason, Resolution -Wrap
if (-not $result.IsValid) { throw 'Fix plugin API boundary diagnostics.' }
```

`PublicApi` is a machine-readable object with operation-name arrays for `UI`,
`Ado`, `Secrets` and `Clipboard`, derived from the actual installed API v1
context. It is an inventory, not a duplicate parameter-schema declaration;
use the public reference above for operation signatures. Private ownership is
derived from actual Core function definitions (including same-file siblings)
minus module exports. There is no broad verb/prefix ban or hand-maintained list.

### Detection and diagnostics

The validator parses `.ps1`, `.psm1` and `.psd1` files recursively under authored
`src/` (including public/private subdirectories) and `scripts/`, and PowerShell
entrypoints/manifests at the project root. It does not scan test fixtures,
`dist/`, `artifacts/` or agent prose outside these authored roots.

Each diagnostic contains project-relative slash-normalized `File`, one-based
`Line` and `Column`, `Dependency`, `Reason` and actionable `Resolution`.
Results sort by file, line, column, reason and dependency, removing duplicates.
`IsValid` is false when diagnostics exist; `FileCount` records scanned files.
Missing paths or `src/` directories terminate; PowerShell syntax errors become
`ParseError` diagnostics. Source is never executed to determine a dependency.

| Case | Policy |
| --- | --- |
| Direct known private Core call; `& 'PrivateName'`; `Gerber\PrivateName` | `PrivateCoreCommand`; recommend an actual directly mapped public operation, otherwise explicitly say no equivalent is declared and request a capability. |
| `& $name` after one prior unconditional literal assignment in the same scriptblock; literal string concatenation | Recognized conservatively; reassigned, conditional and computed variables are not resolved. |
| Literal `Get-Command`/`gcm` lookup or `Invoke-Expression`/`iex` target | Identifiable private command names are reported, including literal expression commands with arguments. Explicit literal `-Module OtherModule` lookups respect external ownership; `-Module Gerber` retains Core ownership despite local same-name declarations. |
| Explicit `Import-Module`/`ipmo`, dot-source or `using module` path under `Gerber/src/private`, `Gerber/private` or `Gerber/internal`; direct `Gerber/Gerber.psm1` import | `CoreImplementationImport`; use the public manifest and injected context, not implementation modules/files. |
| `& (Get-Module Gerber) { ... }` or `(Get-Module Gerber).SessionState` | `CoreModuleScope`; use public capabilities rather than undocumented Core scope/state. Ordinary module inspection is allowed. |
| Public context operations, Core exports, external commands/modules | Allowed. |
| Plugin-owned functions across authored files and lexically local same-name functions | Allowed for unqualified calls; explicit Core qualification cannot be hidden by a local definition. |
| Comments and ordinary strings mentioning private names/imports | Ignored, except recognized execution/lookup contexts above. |

### Limits and lifecycle

This is a static development guardrail, not a security scanner, permissions
model or PowerShell sandbox. It does not follow aliases, execute expressions,
resolve arbitrary variables/interprocedural dataflow, establish runtime load
order, analyze external modules, or prove computed imports/commands safe.
An unqualified known private name is treated as Core-owned unless a plugin/local
function declares it. If an external public command has that same name, qualify
its external module or use an explicit literal `Get-Command -Module` lookup;
the validator does not load external modules to guess their exports.
It does not police every possible configuration/state access; only explicit
identifiable Core module scope/session-state access is diagnosed. Review those
unresolved dependencies manually and request missing public capabilities.

Generation checks staged authored source before Nova, plugin registration,
finalization or GUID approval. Invalid generation uses existing owned-stage
cleanup and never approves its GUID. Installed plugin discovery and execution,
unknown/known GUID approvals, inventory, enable/disable and registration retain
their existing contracts; validation is not a new runtime approval condition.
