# Credential service architecture

Gerber Core owns one internal credential service. Public slash commands and Plugin API v1 all use that service instead of calling an operating-system backend directly.

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
| Plugin credential | `gerber:plugin:<plugin-guid>:<path-segments>` |
| General Gerber credential | `gerber:<scope>:<name>` |

Plugins use the GUID-scoped Secrets API with a logical path segment list.
Identifiers are not stored redundantly in JSON.
Plugin identity continues to use the module manifest GUID.

The namespace prevents Gerber from listing or modifying unrelated application credentials. It is not a security sandbox: plugins execute as PowerShell code in the user's process and can call other process-accessible APIs.

## Native backends

| Platform | Backend | Requirements |
| --- | --- | --- |
| macOS | Apple Keychain | Normal user Keychain access; macOS may display its own security prompt |
| Windows | Windows Credential Manager | Normal user Credential Manager access |
| Linux | Secret Service | A desktop Secret Service provider, D-Bus session, GLib/GObject, and `libsecret` |

Gerber explicitly selects CredentialManager's `secretservice` provider on Linux. If no supported native backend is available, the requested credential operation fails. Gerber does not use a plaintext fallback, a separate password database, configuration files, environment variables, or a Gerber master password for secret storage.

## Plugin credentials

Plugins own their own first-use setup and lazy authenticated use through the
public Secrets API. Import and unrelated Core commands do not request
credentials. A missing plugin credential is entered again only during
interactive authenticated use; noninteractive calls fail without prompts.

Plugin settings and secrets remain separate systems:

- plugin settings stay in the plugin's own module-named JSON file
- secrets stay only in GUID-scoped native credential storage through Secrets
- there is no environment-variable fallback, plaintext storage or secret copy in JSON

Because those writes are separate, plugins should validate inputs first, write configuration before credential storage, and report any partial failure explicitly so the user can retry safely without exposing the secret value.

## Core updates

G-4A7R permanently binds Core updates to public PSGallery. Core discovery and
installation do not retrieve native credentials or request credentials.
The provisional G-4A7 Core credential references are superseded
and ignored together with its obsolete configurable repository binding.

Future plugin updates may use Gerber-owned repository/credential configuration
with PMU, independently of Core; that contract remains G-4A9. No plugin update
credential flow is implemented here. See [Core updates](../core-updates.md).

## Enumeration limits

CredentialManager can enumerate account identifiers for the Gerber provider service. Gerber therefore lists identifiers only. The provider does not expose portable creation or modification timestamps, so `/secrets list` does not invent them.
