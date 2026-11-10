# Gerber Core

Gerber is an interactive DevOps multitool for PowerShell: a terminal command
palette with developer utilities, secure credential storage and a shared plugin
platform. Core works without plugins. Integrations are separate PowerShell
modules, never Core dependencies.

## Install and run

Gerber is published on PSGallery as a **preview**. In PowerShell 7.4 or later:

```powershell
Install-Module Gerber -Scope CurrentUser -AllowPrerelease
Import-Module Gerber
Invoke-Gerber
```

The alias `gerber` starts the same session. Gerber targets macOS, Windows and
Linux terminals without a separate TUI framework.

### Requirements and dependencies

- **NovaModuleTools** provides the plugin-development build, test, packaging and
  local-publication toolchain.
- **PSModuleUpdate** provides update discovery, version selection, installation,
  verification and recovery.

Both are required runtime modules. Nova lifecycle operations do not run at
startup; importing Gerber alone does not check for updates. Secure storage loads
its bundled credential backend lazily, only for credential operations.
Linux credentials require a desktop Secret Service session, D-Bus and `libsecret`.

## Interactive commands

Gerber opens at a minimal prompt with `/ commands · esc back` guidance.
Enter these commands **inside Gerber**, not at the PowerShell prompt:

| Command | Purpose |
| --- | --- |
| `/exit` | Exit Gerber |
| `/help` | Show help generated from the active command registry |
| `/plugins` | Open plugin management |
| `/plugins list` | List discovered plugins and saved lifecycle records |
| `/plugins info <plugin>` | Inspect a manifest GUID or unique module name |
| `/plugins enable` | Select, approve and activate an installed inactive plugin |
| `/plugins disable` | Deactivate a plugin while keeping approval and installation |
| `/plugins create` | Generate and validate a working plugin project |
| `/update` | Open the update menu |
| `/update list` | Check Core and eligible installed plugins; review and confirm updates |
| `/update policy` | Choose the shared stable/prerelease update channel |
| `/secrets` | Open credential management: `list`, `get`, `test`, `set`, `remove` |
| `/tools` | Open the developer utilities menu |
| `/tools create-uuid` | Generate a UUID |
| `/tools base-64 encode` | Encode one line of UTF-8 text |
| `/tools base-64 decode` | Decode Base64 to UTF-8 text |

### Navigation

- Type `/` to browse commands, or plain text such as `uuid`, `base` or `help`
  to search executable leaf actions.
- Roots start with `/exit`, `/help`, `/plugins`, `/update`; remaining roots are
  alphabetical. Plugin-contributed roots appear only while an active plugin
  contributes available commands.
- Use Up/Down to browse suggestions, Tab to complete, and Enter to accept the
  highlighted suggestion and execute it when complete. Suggestions show a help
  preview and a visible selection highlight.
- Bare `/tools`, `/plugins`, `/update` and `/secrets` open inline submenus.
  Enter at `/tools` selects `create-uuid`; Enter at `/secrets` selects `list`;
  Enter at `/update` selects `list`.
- Esc goes back one menu level. A top-level submenu returns through the visible
  root `/` chooser before the blank home prompt. Double Esc within 200 ms jumps
  straight to the root prompt without exiting.
- Base64 actions reopen after the continue screen. UUID generation repeats with
  Enter and returns to `/tools` with Esc. `/secrets list` returns to its chooser;
  input-driven secret actions reopen their selected flow.

Menus, completion, `/help` and direct lookup share the same active command tree.
Several plugins can share a root; disabling one removes only its contribution.
Empty plugin containers disappear when the last contribution is disabled and
return when a contributor is enabled. Standalone Core commands remain available.

## Updates

`Invoke-Gerber` attempts a bounded, noninteractive **Core-only** startup check.
It can show an available-version notification, but never installs, asks for
installation consent, requests credentials or checks plugins. Failed checks
leave Gerber usable and never claim it is up to date.

Run `/update list` for a fresh overview of installed/available versions,
repository and status. Core always uses the official **PSGallery** endpoint
and **CurrentUser** scope. Settings, environment variables and plugins cannot
override that source. Gerber does not register repositories or fall back to
another feed; a missing or repointed registration needs correction outside Gerber.

`/update policy` saves **Stable only** (default) or **Include prereleases** for
Core startup and manual Core/plugin checks. To receive preview updates, select
Include prereleases. Enter saves the preselected choice; Esc leaves it unchanged.
Changing policy performs no discovery or installation, clears the old startup
notification and requires a fresh `/update list` before installation.

Eligible plugins are installed, discovered, associated, approved and enabled.
Their installed manifest declares `PrivateData.Gerber.Repository` with `Name`
and `Uri`: the name is displayed, and PMU receives the URI. Missing metadata
defaults to PSGallery; invalid explicit metadata never falls back. Legacy
`RepositoryUri` is supported, but the canonical object takes precedence.

When plugin rows exist, use Up/Down and Space to select available updates, then
Enter to review. Selected packages are temporarily downloaded for manifest
inspection without a separate inspection prompt. A required Core update is
visibly added when available; otherwise the dependent plugin is blocked.
**Cancel is the default** at installation confirmation. No available updates
means no selection or installation prompt.

PMU installs original plans sequentially, Core first when required. Dependent
plugins are blocked on Core failure; independent updates can continue.
Cancellation stops further attempts. Installation, verification, recovery and
fresh-process activation are reported separately: activation failure does not
erase a successful installation. There is no first installation, hot reload or
batch rollback. Repository credentials are operation-local, not stored in metadata
or retrieved from native credential storage.

After an update requiring restart, **Continue with current version** is the
default; Esc also continues and retains the restart reminder. **Exit Gerber**
returns to PowerShell without unloading Core. Supported console hosts also offer
**Exit Gerber and PowerShell**; other hosts require restarting the session from
the host. Restart PowerShell, then run `gerber` to use installed updates.

See [Core and plugin updates](docs/core-updates.md) for the plugin-update PMU
capability requirement, repository metadata and installation/recovery guidance.

## Plugins and lifecycle

Plugins are identified by their permanent manifest GUID. Unknown plugins require
approval **before import**, with decline as the default. The prompt shows name,
GUID, version, publisher metadata and manifest location. Approval survives routine
version updates; it records intent, not publisher authentication or code integrity.
Declines persist. Noninteractive discovery skips unknown plugins without prompting
or approving them.

Gerber keeps **approval**, **association**, **enabled state** and **loaded state**
distinct. First approval also associates and enables the plugin. Older approved
records gain association on rediscovery. Disabled plugins remain approved but are
not imported or registered. `/plugins enable` explicitly approves and activates a
selected inactive plugin without another approval prompt; enable/disable persist
and update commands immediately.

`/plugins list` and `info` are read-only: they do not import unknown, declined or
disabled modules for inspection. Declined and missing associated plugins remain
visible. Generated name/version are display fallback until installed metadata is
available. Duplicate module names require a GUID; conflicting active identities
are rejected. Plugins may extend Core or their own commands, not another plugin's
owned commands.

There are **no remove or revoke commands**. Disable inside Gerber with
`/plugins disable`; uninstall the PowerShell module outside Gerber to remove or
revoke it. A saved association may remain visible as missing.

`/plugins create` asks for a suffix behind the fixed `Gerber.` prefix,
description, unused namespace, repository and destination parent (cwd by default).
It never overwrites an existing destination. PSGallery is preselected; a custom
repository needs a name and URI. An unknown URI becomes
`REPLACE_WITH_REPOSITORY_URI`, which must be replaced in `project.json` and rebuilt
before remote publication or updates; local build/test/publication still work.

Creation validates staged source, builds/tests it and checks Core registration
before approving, associating and enabling the new GUID. It **does not install or
load** the plugin. Completion shows location, identity, repository and lifecycle
state. Generated projects include a working example, boundary-check script,
changelog and agent guidance. Invalid input can be corrected; Esc cancels without
approval. The handler's consent-based missing-Nova fallback does not make Nova
optional at module import.

See [Create a Gerber plugin](docs/plugins-create.md) for the generated tree,
local-publication workflow and recovery behavior, and
[Plugin API v1](docs/architecture/plugin-api-v1-capabilities.md) for author reference.

## Secrets

- `/secrets list` lists Gerber-managed identifiers without retrieving values.
- `/secrets test` checks existence without retrieving the value.
- `/secrets get` lists stored keys, copies a selected value when clipboard support
  exists, then asks before revealing it in the terminal.
- `/secrets set` uses non-echoing input and asks before overwriting.
- `/secrets remove` lists keys and asks before deleting.

Identifiers are case-insensitive `gerber:<scope>:<name>` values. Plugin credentials
use `gerber:plugin:<manifest-guid>:<path>`. Namespacing prevents accidental
collisions, not arbitrary access by code running in the same process.
Storage is OS-backed and fails with guidance when unavailable; there is no
plaintext, JSON or environment-variable fallback.

See [credential architecture](docs/architecture/credential-service.md) and
[manual native-store verification](docs/credential-store-verification.md).

## Tools

UUIDs are standard hyphenated values without braces. Base64 encoding reads one
line of UTF-8 text; decoding tolerates surrounding whitespace and line breaks.
Results are displayed and copied when a supported clipboard command is available.
Invalid Base64 produces a recoverable in-app error. These are text tools, not
file or arbitrary-binary conversion workflows.

## Configuration files

Core settings, plugin approvals/associations and `coreUpdates.channel` live in
`GerberCore.json`. Default locations are:

- Windows: `$env:APPDATA/Gerber/GerberCore.json`
- macOS/Linux: `$env:XDG_CONFIG_HOME/Gerber/GerberCore.json`, if set;
  otherwise `$HOME/.config/Gerber/GerberCore.json`

`GERBER_CONFIG_PATH` is an absolute **Core file** override. An override ending in
legacy `config.json` selects sibling `GerberCore.json`; other explicit filenames
are retained. Legacy-name matching is case-insensitive on Windows and
case-sensitive on Unix-like systems.

Each plugin can use `<ModuleName>.json` in the same directory through identity-bound
Configuration.Read/Save. Missing files return null; invalid JSON is reported, not
silently replaced, and writes are atomic. Plugins own their settings schema.
Secrets belong in native storage, never these JSON files. No setting changes
Core's fixed PSGallery source.

## Public PowerShell cmdlets

These run **at the PowerShell prompt**, outside the Gerber command palette:

- `Invoke-Gerber` (alias `gerber`) starts the interactive session.
- `Test-GerberPluginBoundary -Path <project>` statically checks authored plugin
  source without executing it. Results include `IsValid`, `FileCount`,
  deterministic `Diagnostics` and the installed Core's `PublicApi` inventory.
  This is a development check, not a sandbox; computed dependencies need review.

Use `Get-Help Invoke-Gerber -Full` or `Get-Help Test-GerberPluginBoundary -Full`.
PlatyPS sources in `docs/Gerber/en-US/` become external help during Nova builds.

## Contributor build and test strategy

Build and run this checkout:

```powershell
Invoke-NovaBuild
Import-Module ./dist/Gerber/Gerber.psd1 -Force
Invoke-Gerber
```

Source-mirrored Pester tests use `tests/TestHelpers/`. The PTY harness runs the
built app and the generic `Gerber.TerminalFixture` Plugin API contract with
sanitized failure artifacts. Plugins own their domain tests in their repositories.

```powershell
./scripts/build/Invoke-ScriptAnalyzerCI.ps1
Invoke-NovaBuild
Invoke-NovaTest
Test-NovaBuild
./scripts/build/Invoke-TerminalRegressionCI.ps1 -Category core
./scripts/build/Invoke-TerminalRegressionCI.ps1 -Category synthetic
```

The ordered full quality loop is:

```powershell
pwsh -NoLogo -NoProfile -File ./run.ps1
```

Run the tracked terminal suite separately with:

```powershell
pwsh -NoLogo -NoProfile -File ./scripts/build/Invoke-TerminalRegressionCI.ps1
```

See [Contributing](CONTRIBUTING.md) for test ownership and isolated native checks.

## Prompt tracing

```powershell
$env:GERBER_PROMPT_TRACE = '1'
Invoke-Gerber
```

JSON lines go to `.gerber/prompt-debug.log` under cwd, recording prompt/fallback
selection, keys, suggestion refreshes and completions. Trace files can contain
ordinary prompt input; review and redact them before sharing. Never enter secrets
in ordinary traced inputs.

```powershell
Remove-Item Env:GERBER_PROMPT_TRACE
```

## Known limitations

- Terminal rendering uses `Clear-Host`, not a full-screen TUI framework.
- Completion covers registered commands and known subcommands, not arbitrary
  PowerShell input.
- Base64 tools handle text only.
- Linux credentials need a graphical Secret Service environment; headless
  sessions without that backend cannot use native storage.
- Live update has been verified on macOS only.
- Plugin updates require a PSModuleUpdate release exporting
  `Get-PSModuleUpdateTargetManifest`; see [the requirement note](docs/core-updates.md#requirements).
