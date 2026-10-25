# Credential service architecture

Gerber Core owns one internal credential service. Public slash commands, Azure DevOps integrations, and Plugin API v1 all use that service instead of calling an operating-system backend directly.

## Runtime dependency

Gerber packages these .NET Standard 2.0 assemblies under `resources/lib`:

| Package | Version | Purpose |
| --- | --- | --- |
| `Devlooped.CredentialManager` | `2.7.0` | Cross-platform API over native credential stores |
| `DotNetConfig` | `1.2.0` | Direct dependency used by CredentialManager |

PowerShell 7.4 supplies the required framework assemblies, including `System.Text.Json`, `System.Security.Cryptography.ProtectedData`, `System.Collections.Immutable`, and `System.Memory`. Gerber loads the packaged assemblies lazily on the first credential operation. Module import and `Invoke-Gerber` startup do not initialize native credential storage.

Nova copies `src/resources` into the built module, so loading the packaged credential assemblies needs neither a local NuGet cache nor a source checkout and does not invoke Nova build operations. This packaging boundary does not make Nova optional for Gerber: the owner's [D-017 / amended D-002](../../DECISIONS.md) requires both NovaModuleTools and PSModuleUpdate at runtime for their respective plugin-development and update roles. CredentialManager and DotNetConfig publish their source under the MIT License; the CredentialManager NuGet binary declares its Open Source Maintenance Fee Agreement as the package license.

## Internal operations

The private credential service supports:

- `Get-GerberCredential`
- `Set-GerberCredential`
- `Remove-GerberCredential`
- `Test-GerberCredential`
- `Get-GerberCredentialInfo`

The provider namespace is `Gerber`, and the provider account is the complete canonical Gerber identifier. The service is `gerber://credentials` on Windows because the native provider constructs targets from an absolute URI. macOS and Linux retain `credentials` so existing stored entries remain addressable. All five operations use the same platform-specific service resolver; this is an internal storage key, not a network endpoint or configuration setting.

Missing reads return no value, missing removals return `false`, and provider errors are replaced with redacted platform-specific guidance.

## Identifier rules

Credential identifiers are stable, case-insensitive, and canonicalized to lowercase. Each path segment is URI-escaped before it is joined.

| Consumer | Identifier |
| --- | --- |
| Azure DevOps profile | `gerber:ado:<profile>:pat` |
| Plugin credential | `gerber:plugin:<plugin-guid>:<path-segments>` |
| General Gerber credential | `gerber:<scope>:<name>` |

The Azure DevOps identifier is derived from the profile name and is not stored redundantly in `config.json`. Plugin identity continues to use the PowerShell module manifest GUID.

The namespace prevents Gerber from listing or modifying unrelated application credentials. It is not a security sandbox: plugins execute as PowerShell code in the user's process and can call other process-accessible APIs.

## Native backends

| Platform | Backend | Requirements |
| --- | --- | --- |
| macOS | Apple Keychain | Normal user Keychain access; macOS may display its own security prompt |
| Windows | Windows Credential Manager | Normal user Credential Manager access |
| Linux | Secret Service | A desktop Secret Service provider, D-Bus session, GLib/GObject, and `libsecret` |

Gerber explicitly selects CredentialManager's `secretservice` provider on Linux. If no supported native backend is available, the requested credential operation fails. Gerber does not use a plaintext fallback, a separate password database, configuration files, environment variables, or a Gerber master password for secret storage.

## Azure DevOps

An Azure DevOps operation resolves the configured profile, derives its credential identifier, and retrieves the PAT only when authentication is required. Gerber now handles first-use readiness inline: if no suitable profile exists, it can guide the user through minimal named-profile setup; if the profile exists but the PAT is missing, it can prompt only for the PAT; and unrelated commands still avoid touching the credential store.

Profile metadata and PAT storage remain separate systems:

- profile metadata stays in user configuration under `ado.defaultProfile` and `ado.profiles`
- the PAT stays only in native credential storage under `gerber:ado:<profile>:pat`
- there is no `AZURE_DEVOPS_PAT` fallback, plaintext storage, or PAT copy in `config.json`

Because those writes are separate, Gerber validates the inputs first, writes configuration before credential storage, and reports any partial failure explicitly so the user can retry safely without exposing the secret value.

## Core updates

G-4A7R permanently binds Core updates to public PSGallery. Core discovery and
installation do not retrieve native credentials, request credentials or consult
ADO profiles. The provisional G-4A7 Core credential references are superseded
and ignored together with its obsolete configurable repository binding.

Future plugin updates may use Gerber-owned repository/credential configuration
with PMU, independently of Core; that contract remains G-4A9. No plugin update
credential flow is implemented here. See [Core updates](../core-updates.md).

## Enumeration limits

CredentialManager can enumerate account identifiers for the Gerber provider service. Gerber therefore lists identifiers only. The provider does not expose portable creation or modification timestamps, so `/secrets list` does not invent them.
