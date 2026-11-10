# Runtime dependency and generated-help reference

Audience: Core maintainers validating packaging and plugin authors understanding
the host's dependencies. This is not a platform qualification report.

## Authoritative inputs and generated outputs

`project.json` declares the project identity, version, runtime module requirements
and build/test configuration. Nova generates the module root and manifest under
`dist/Gerber/`; do not maintain a second handwritten manifest or patch installed
modules to match source.

Core requires NovaModuleTools and PSModuleUpdate only. Plugins are separate
modules, never Core dependencies. A missing or incompatible required module can
block import; an unreachable update repository does not block Gerber startup.
Numeric ModuleVersion requirements express minimum versions, not package/channel
pins.

Plugin updates additionally need PMU's public target-manifest inspection
capability. See [update requirements](../core-updates.md#requirements).
Building Core does not install or replace its dependencies.

## Command help

`docs/Gerber/en-US/` is the authoritative PlatyPS Markdown source. Nova imports
command-help Markdown and exports a shared `Gerber-Help.xml` MAML artifact.
The module overview is a different PlatyPS document type, not a third cmdlet.

Build and import the correct dist module before regenerating command syntax or
parameter metadata. Preserve Module Name, external help filename, locale and
schema. Use the configured PlatyPS updater, then validate command-help structure,
import diagnostics and MAML export. Narrative corrections must remain consistent
with the actual public functions.

## Validation boundaries

Use the repository's documented Nova build/test flow and isolated module paths
for implementation validation; see [Contributing](../../CONTRIBUTING.md).
Do not silently install or publish dependencies, change repository registrations,
touch a workstation vault or run a live update as a documentation check.

Generated artifacts, mocked tests and provider-only checks do not prove a
particular installed launcher resolves the same module. Record actual module
paths and execution evidence in the work register, separately from user help.
