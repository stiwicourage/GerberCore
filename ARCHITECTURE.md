# Gerber — Architecture Baseline (Reconstructed)

> 2026-10-10. Source of intended architecture: product-owner decisions and G-1A architecture materials. **Not a claim that all features below are implemented.** Current code must be checked before changing it.

## Product boundaries

```text
Gerber Core (standalone PowerShell module)
  ├─ interactive slash CLI, registry, help, rendering, PTY
  ├─ configuration (persistent user-owned data)
  ├─ /secrets → Core Secrets API → credential abstraction → OS credential store
  ├─ Azure DevOps generic connection / operations
  ├─ Plugin API v1 + discovery/registration/lifecycle
  └─ /plugins inspection, enable/disable and transactional creation
          │ public Plugin API only
          └─ Gerber.ExampleOrg / other independently installed plugins

RequiredModules:
  NovaModuleTools → plugin development/build/test/package/local publication
                    used by Gerber's creation workflow
  PSModuleUpdate  → generic update discovery/install/verification/recovery
                    for Core startup notification and /update
```

## Initialization
`Install-Module Gerber`, `Import-Module Gerber`, `Invoke-Gerber` should work without Azure DevOps, a PAT or plugins, with **both NovaModuleTools and PSModuleUpdate available as required modules**. The owner decision recorded in D-017 supersedes this baseline's former "NOT mandatory" Nova wording and the Nova exclusion in D-002; other Core/plugin boundaries remain. Required-module resolution is not execution of Nova build/package/publish operations at every startup. Missing/incompatible dependencies may prevent import; an unreachable update repository must not block startup. ADO configuration is lazy, triggered only by a command that needs it. Configuration and approvals survive module updates and reinstallations; do not write user settings into installed module files.

## Interactive navigation
- Root commands that expose registered subcommands use Gerber's shared submenu prompt/navigation infrastructure rather than bespoke parent-menu loops.
- A command may provide submenu-specific overview text for that shared prompt, but single-`Esc` back navigation and double-`Esc` root navigation remain centralized in the shared prompt/menu helpers.
- `/plugins` follows the same submenu contract as the other nested Core command groups; direct `/plugins list` or `/plugins info` execution still uses ordinary command resolution and does not create synthetic navigation history.

## Updates (Core implemented in G-4A7; plugins planned)
Authoritative contract: [G-4A5](docs/architecture/G-4A5-update-architecture.md); decision D-017. Both required modules remain declared in `project.json` and Nova regenerates both manifest requirements. `Invoke-Gerber`, not module import, attempts a notification-only Core check; repository failure never blocks startup. `/update` performs fresh discovery, shows the Core overview, defaults to Cancel and delegates confirmed installation to PSModuleUpdate without hot reload. Plugin updates remain a separate phase through this same command and engine.

**G-4A7R repository decision:** PSGallery is the permanent, sole official Core
repository, explicitly passed to PMU and not a configurable default. The Core
resolver does not read user, environment or plugin settings. Core pins the
official PSGallery endpoint, uses PMU Stable/CurrentUser policy and never falls
back, chooses a repository interactively or requests credentials. Gerber Core
has not yet been published to PSGallery; no matching package is a legitimate
discovery outcome, not a configuration error or proof of currency.

Plugins retain independent Gerber-owned repository configuration; different
plugins may use different repositories. Their implementation remains G-4A9
and cannot supply Core's binding. Both use PSModuleUpdate for discovery,
semantic-version eligibility, exact installation, verification, locking and
rollback/recovery. Gerber owns presentation, confirmation, coordination,
configuration and plugin approval. Do not duplicate PMU mechanics or confuse
them with Nova build/package/publication. PMU CI qualification is not Gerber integration.

**Historical G-4A7 choice, superseded:** `updates.modules.Gerber.repository`,
optional `policy` and `credential` were provisional. G-4A7R ignores that entire
Core binding without migrating or rewriting unrelated configuration. The
2,000 ms child-process startup probe and session-only notification state remain;
no persistent cache exists. Only eligible updates notify; failure does not block
startup or imply currency. Noninteractive update views neither prompt nor install.
See [Core updates](docs/core-updates.md) for prerelease and failure semantics.

## Plugin identity and lifecycle
- Permanent identity: manifest GUID. Display name, module name and slash namespace are separate concepts.
- Core enumerates module manifests and reads them with `Import-PowerShellDataFile`; plugin code is not imported or invoked during identity discovery.
- A candidate must have a valid manifest GUID plus the required `PrivateData.Gerber` metadata. Manifests that cannot be inspected safely or contain an invalid GUID are skipped with a controlled warning.
- User configuration stores normalized approved GUIDs under `plugins.approved` and normalized declined GUIDs under `plugins.declined`. The existing atomic configuration writer preserves unrelated settings and keeps these decisions outside installed module directories.
- User configuration also stores associated plugins under `plugins.associated`, keyed by normalized GUID. Each record persists `enabled: true|false`; generated plugins additionally retain optional `name` and `version` display metadata in the same approval save. Metadata is not identity, approval, installation or load state. No migration is needed for older records.
- Unknown GUIDs require a Gerber-owned confirmation before import. Decline skips the plugin, persists the declined GUID, and avoids re-prompting on the next startup; noninteractive startup loads approved plugins and skips unknown plugins without prompting.
- Approved GUIDs persist through ordinary plugin updates; no content hash or per-version reapproval is used.
- First approval now persists three distinct states in one flow: approve the GUID, associate that GUID with the user's Gerber environment, and mark it enabled. Existing approved plugins without an explicit association record stay usable and acquire an associated+enabled record lazily when discovered again.
- GUID approval identifies the plugin selected by the user. It is not a certificate, signature, publisher trust chain, or proof that the current plugin code is authentic.
- Disabled plugins remain associated and approved, but Core must not import their module, execute `Get-GerberPlugin`, or register their commands. Missing modules do not remove existing association records.
- Core now exposes a read-only management surface through `/plugins`, `/plugins list`, and `/plugins info <plugin>`. Those commands merge discovered manifest metadata, persisted approval/decline decisions, persisted association state, and current session loaded-state without importing additional plugin code.
- Declined plugins stay visible in management even when they were never associated. Missing generated plugins use cached name/version; records without these fields keep the GUID-only fallback. Discovered manifest metadata always wins, with current loaded-state metadata retained by the existing inventory path. Read-only inspection never writes, installs, imports or requests approval.
- `create` → read suffix/description/namespace/parent → stage Gerber-owned templates with one new GUID → AST Plugin API boundary check → Nova build/unit/integration checks → register against a copied Core registry → move to parent/Gerber.Suffix without overwrite → existing explicit approval/association/enabling lifecycle.
- `Gerber.` is immutable; namespace is a separately validated, unused root. The destination parent defaults to cwd, never the final child itself. Failed validation removes only owned staging data; configuration-write failure after finalization preserves and identifies the recoverable unapproved project.
- Creation uses shared UI with an introductory heading, separated explained fields, dynamic cwd/child hints and actual completion name/version/path/state. The project keeps only `Manifest.GUID`; `PrivateData.Gerber` holds the plugin marker/API/minimum version, not another GUID. The public definition still matches manifest identity.
- Creation does not install or load the plugin. Nova `Publish-NovaModule -Local` followed by Core startup discovery loads the same approved GUID without another prompt. The generated `/mycompany hello` example uses public Plugin API v1 UI operations only.
- `enable`/`disable` control availability without uninstalling the module.
- `remove`, explicit decline and revocation management are outside Core 1. Future intent is recorded in DECISIONS.md; no runtime capability is claimed.
- Existing Core command roots can be extended by plugins; conflicting full paths must be resolved deterministically, never last-loaded-wins.
- Future: trusted publisher certificates and compromised GUID notifications; not required for the first management implementation.

## Secrets and ADO
Current chosen backend: Devlooped CredentialManager, via a Gerber-owned Secrets abstraction; macOS Keychain works in the user's environment. No backend marketing text in runtime UI. Namespace plugin secrets by plugin GUID. Raw PAT is never stored in JSON or passed to plugins. Generic ADO functionality belongs in Core; plugin access uses opaque connection handles. Tests isolate credentials and HTTP, not real endpoints.

## Development and quality
NovaModuleTools is a runtime dependency for Gerber's plugin-development functionality as well as repository development/release tooling. The implemented `/plugins create` handler retains an invocation-time availability check and consent-based installation fallback; this is not a promise that Gerber imports without Nova. Decline leaves files and approvals unchanged. Gerber owns deterministic plugin-specific source/test/docs/agent templates under `src/resources/plugin-template`; Nova provides build/test/package/local publication and generates `dist/<Name>`, `docs/schema` and lifecycle artifacts. Creation builds/tests before approval but does not package, publish or install the plugin; its completion guidance offers `Publish-NovaModule -Local` separately. G-3E1 adds canonical self-contained AGENTS.md, thin tool bridges, scoped instructions, a plugin developer role and three workflow skills. Templates use constrained identity/namespace substitutions; descriptions are JSON-serialized after substitution, never injected into code/Markdown. The full six-category Unreleased changelog contains no fictional stable release. No separate templating framework or CI infrastructure is introduced. Core quality gates run without Gerber.ExampleOrg.

### Plugin API v1 development boundary (G-3F1)

`Test-GerberPluginBoundary -Path <project>` is a read-only exported command.
It parses authored PowerShell beneath `src/` and `scripts/` recursively, plus
root PowerShell entrypoints/manifests, without importing or executing plugin
source. Tests and generated output outside those authored roots are excluded.
It returns `IsValid`, `FileCount`, `PublicApi` and sorted structured diagnostics.
Generated `scripts/Test-PluginBoundary.ps1` converts invalid results to a
terminating development failure before the normal Nova build/test workflow.

Ownership is derived from actual function definitions in installed Core's
generated module and its exports, including same-file private siblings.
Source-mode tests derive the same information from authored Core files.
The public capability inventory and known direct equivalents come from the
existing API v1 context's scriptblocks; no duplicate denylist, prefix ban,
invented internal module names or independently maintained API manifest is used.
Reading the installed module artifact is not a requirement for a private source
checkout and does not start the application or inspect user configuration.

Diagnostics identify known private commands, explicit Core implementation imports
and identifiable module-scope/session-state access. ASTs avoid comments and
ordinary-string matches; plugin-owned and lexically local same-name functions
are allowed, while explicit `Gerber\PrivateCommand` retains Core ownership.
Literal dynamic invocation/lookup and conservative literal assignments are
recognized, but arbitrary computation, aliases, external code and dataflow are
not proven safe. See the [detection contract](docs/architecture/plugin-api-v1-capabilities.md#development-time-boundary-validation).

Invalid staged source fails before Nova or registration, so existing transaction
cleanup leaves no final project or approved GUID. No runtime permissions,
sandbox, discovery rejection or new approval mechanism is introduced.

## Implementation status (limited evidence)
- Historical G-4A5 source inspection 2026-10-24 found the ignored manifest stale and Core updates absent. [G-4A6](docs/architecture/G-4A6-runtime-dependency-qualification.md) subsequently qualified disposable generation/import. G-4A7 adds Core startup discovery and `/update`, and normal Nova builds refresh the local artifact. Neither dependency declaration changed. Focused mocked/disposable behavior and terminal scenarios are exercised; full quality readiness and remaining provider/platform limits are recorded in [PLAN.md](PLAN.md). This is not live repository installation qualification.
- Reported after G-PTY3: Core default `run.ps1` independent of Gerber.ExampleOrg; 26 Core commands; 54 PTY scenarios passed in an archived run; 1,366 Pester tests passed and 96.88% coverage reported. These are **historical run results**, not a fresh validation.
- User manually verified `/repository create` with real ADO; its full simulated provisioning chain remains a deferred PTY test gap.
- G-2A/G-2B were worked on before PTY, but exact completion of every acceptance criterion requires code inspection.
- G-3A1 persistent GUID approval, read-only `/plugins list`/`info`, enable/disable and G-3D1 create are implemented. A separate approve command is unnecessary because enable handles declined plugins. Remove/decline/revoke management is outside Core 1.
- G-3A2 persistent plugin association and enabled/disabled lifecycle state is implemented in Core. Read-only management now surfaces approved, declined, associated, enabled/disabled, loaded, and missing states without importing unknown, declined, or disabled plugins.

## References
- `G-1A.md`: initial product architecture analysis instructions.
- `G-1A_response.md`: resulting roadmap, superseded where subsequent user decisions differ.
- `DECISIONS.md`: authoritative reconstructed decisions, with explicit unresolved implementation details.
