# G-4A6 - Runtime dependency and generated manifest qualification

**Date:** 2026-10-24.
**Disposition:** Investigation complete; local build/import qualification passed, retained checkout manifest remains stale, wider delivery qualification is limited as stated below.
**Authority:** [G-4A5](G-4A5-update-architecture.md) and [D-017](../../DECISIONS.md) remain the architecture contract. This report supplies execution evidence, not a different dependency architecture.
**Scope:** Documentation and disposable investigation artifacts only. No production source, tests, project configuration, original generated artifacts, normal module installations, Nova source, commits, pushes, publication or release were changed.

**Subsequent policy clarification (G-4A7R):** the independent repository-selection
wording in this historical report applies to plugins only. Core permanently
uses PSGallery with no configuration/environment/plugin override; Core has not
yet been published there. See current [G-4A5 section 9](G-4A5-update-architecture.md#9-core-and-plugin-repository-policies-decided-clarified-g-4a7r).

The owner's G-4A6 assignment now identifies this qualification. [PLAN.md](../../PLAN.md) previously used G-4A6 provisionally for plugin updates; that future phase remains planned after Core integration, without assigning it another implementation ID here.

## 1. Executive summary

- **PASS:** NovaModuleTools **3.4.2** generated both required dependency declarations from unchanged `project.json`. Two ordinary builds in the same disposable checkout produced byte-identical sets of **23 output files**.
- **PASS:** Fresh Gerber imports succeeded on macOS with PowerShell **7.4.21** and **7.6.6**, exact Nova **3.4.2**, and the installed PMU **0.1.0-preview** artifact, copied into an isolated module root.
- **PASS:** Each engine rejected a missing dependency and each separately tested too-old dependency. These expected import failures demonstrate enforcement, not failed qualification assertions.
- **PASS:** All fourteen matrix imports ran with OS-enforced network denial. No monitored Nova lifecycle, PMU update or package acquisition commands ran during import; PSResourceGet was not loaded by the successful baseline import.
- **FAIL, retained artifact:** The original ignored `dist/Gerber/Gerber.psd1` still omits both dependencies. It predates the dependency edit and was deliberately not regenerated in this investigation. No manifest-generator defect was reproduced.
- **Important limit:** `ModuleVersion` is a numeric minimum, not an exact package/channel pin. PMU's numeric manifest version `0.1.0` satisfies the current requirement even though its package identity includes `-preview`.

Startup update checks, `/update`, installation updates and plugin updates remain **unimplemented in Gerber**. Import success does not qualify those future workflows.

## 2. Environment, artifacts and isolation

| Item | Actual qualification input |
| --- | --- |
| Gerber checkout | `c57e4a8`, clean at investigation start; Gerber project version `0.1.0-preview` |
| Platform | macOS 27.0.1 |
| Engines | `/opt/homebrew/bin/pwsh`: 7.6.6; `/tmp/pwsh74/pwsh`: 7.4.21 |
| Build engine | PowerShell 7.6.6, NovaModuleTools 3.4.2 |
| Exact Nova baseline | Public 3.4.2 nupkg downloaded into disposable storage, extracted without installation; numeric manifest version 3.4.2, no prerelease label |
| Additional Nova input | Copy of existing installation: numeric 3.4.3, prerelease `preview`; tested separately, not substituted for the 3.4.2 baseline |
| PMU input | Copy of existing installation: numeric 0.1.0, `PrivateData.PSData.Prerelease = 'preview'` |
| Copied Nova dependencies | Pester 5.9.1, Microsoft.PowerShell.PlatyPS 1.0.3, PSScriptAnalyzer 1.25.0 |
| Copied provider | Microsoft.PowerShell.PSResourceGet 1.2.0; available, but not loaded during baseline Gerber import |

Nova 3.4.2 itself declares Pester `>= 5.7.1, <= 5.10.0`, PlatyPS `>= 1.0.1`, and PSScriptAnalyzer `>= 1.25.0`. Those transitive import requirements were supplied; this is not evidence that installing only two top-level module directories is sufficient.

The exact Nova archive was obtained with:

```sh
curl --location --fail --silent --show-error --max-time 60 \
  -o "$W/downloads/NovaModuleTools.3.4.2.nupkg" \
  https://www.powershellgallery.com/api/v2/package/NovaModuleTools/3.4.2
```

Archive SHA-256: `2153fe5bf6f9f282f7ccf068c91128ef53eaf3b1f1d4ec09d427b91740cb6d8c`. This identifies the tested bytes; package-signature authenticity was **NOT TESTED**.

`$W` abbreviates the session-owned `files/g4a6-qualification` directory under session `6069f3a5-34fc-4b46-9dd1-06eb4a80eed0`. Gerber was copied without `.git`, original `dist`, artifacts or `.gerber`. All builds targeted that copy. Each import used a fresh `-NoLogo -NoProfile -NonInteractive` process, a private module root, and only the selected engine's built-in modules appended to `PSModulePath`. HOME, XDG directories, temporary files and the module-analysis cache were redirected to owned paths; process environments contained no inherited credentials.

**HOME alone is not isolation on this host:** .NET still reported the real user's `Library/Application Support` as `LocalApplicationData`. Accordingly, the test processes also ran under this macOS sandbox profile, with `$W` expanded to its absolute path:

```scheme
(version 1)
(allow default)
(deny network*)
(deny file-write*)
(allow file-write*
  (subpath "<absolute qualification workspace>")
  (literal "/dev/null")
  (literal "/dev/tty"))
```

This is write/network confinement, not a claim of filesystem read isolation. No test repositories were registered, no normal module was installed/uninstalled, and no real application-data write was permitted. Original installed-module hashes were checked afterward.

## 3. Current declarations and initialization

[project.json](../../project.json) currently declares these `Manifest` entries (excerpt):

```json
{
  "RequiredModules": [
    { "ModuleName": "NovaModuleTools", "ModuleVersion": "3.4.2" },
    { "ModuleName": "PSModuleUpdate", "ModuleVersion": "0.1.0" }
  ]
}
```

Both remain mandatory. PowerShell, not a Gerber bootstrap installer, resolves the generated manifest's requirements through `PSModulePath`, imports available matching dependencies and rejects unavailable/incompatible ones.

The disposable build emitted the equivalent valid PowerShell manifest declarations:

```powershell
RequiredModules = @(
    @{ ModuleName = 'NovaModuleTools'; ModuleVersion = '3.4.2' }
    @{ ModuleName = 'PSModuleUpdate'; ModuleVersion = '0.1.0' }
)
```

Gerber's own manifest is numeric `ModuleVersion = '0.1.0'` with its `preview` label under `PrivateData.PSData.Prerelease`. That is separate from its two dependency specifications.

AST inspection of the generated Gerber module, exact Nova 3.4.2 module and copied PMU module found only function declarations and these top-level statements:

```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```

None of the three manifests specifies `ScriptsToProcess`. Import does not invoke [Invoke-Gerber](../../src/public/Invoke-Gerber.ps1), start the interactive host, create a plugin, build/package/publish, or check/install an update.

The existing [creation-tool check](../../src/private/plugins/Confirm-GerberPluginDevelopmentTool.ps1) checks Nova availability and offers `Install-Module` with consent when invoked. It is not an import-time resolver or a waiver of RequiredModules. The actual route is `/plugins create`; its [child validation script](../../src/resources/Test-GerberGeneratedProject.ps1) explicitly imports Nova and runs build/unit/integration validation on demand. Packaging and local publication remain separate lifecycle actions. They were source-inspected, **not requalified as complete plugin workflows here**.

The inspected PMU manifest has no declared RequiredModules. Its `Get-ProviderContext` instead imports **exact PSResourceGet 1.2.0 on operation**, rejecting incompatible providers and never installing one. This operational prerequisite is not an additional automatic Gerber-import action. Future update provisioning must account for it; successful import does not prove provider availability.

## 4. Generated manifest lifecycle and staleness

### Generation path

The normal entry point is `Invoke-NovaBuild`, also called by [run.ps1](../../run.ps1). In Nova 3.4.2:

1. Project resolution retains `Manifest.RequiredModules` from `project.json`.
2. `Invoke-NovaBuildWorkflow` resets the selected project's `dist`, builds the root module, validates functions, calls `Build-Manifest`, builds help and copies resources.
3. `Build-Manifest` validates allowed manifest keys and passes nonempty `RequiredModules` through to `New-ModuleManifest`.
4. Gerber's project semantic version is separated into a numeric module version and prerelease metadata; this does not rewrite dependency versions.

Inspected Nova paths: `src/private/shared/GetNovaProjectInfoResult.ps1`, `GetNovaResolvedProjectManifestSettings.ps1`, `src/private/build/BuildManifest.ps1` and `InvokeNovaBuildWorkflow.ps1`. The manifest-builder and workflow source sections were identical in the downloaded 3.4.2 package, installed 3.4.3-preview and sibling checkout. Nova's existing manifest-test source was inspected, not executed; the disposable builds provide the generation evidence here.

Normal builds also explicitly call Nova's own safe update-notification helper. That build-time behavior is distinct from module import and from planned Gerber startup checks. Builds here ran network-denied; no claim is made that Nova's build workflow never attempts a network operation.

### Why the retained artifact is stale

| Original checkout evidence | Observation |
| --- | --- |
| Manifest header | `Generated on: 22.10.2026` |
| Manifest file timestamp, UTC | 2026-10-22 09:23:40 |
| `project.json` file timestamp, UTC | 2026-10-23 19:00:34 |
| Manifest dependency field | Only `# RequiredModules = @()` |
| Git ownership | `dist/` ignored by `.gitignore:5`; manifest absent from `git ls-files` |

The artifact predates the current dependency edit. Editing `project.json` does not rewrite an already-generated file; regeneration requires a build. This chronology and successful regeneration explain the observed mismatch without inventing a failed-build history or blaming the generator.

The actual disposable build commands were:

```powershell
Set-Location (Join-Path $WorkRoot 'project')
Import-Module NovaModuleTools -RequiredVersion 3.4.2 -ErrorAction Stop
Invoke-NovaBuild
Invoke-NovaBuild
```

Both returned successfully and emitted both declarations. All 23 `dist` files had identical relative-path/hash inventories across the two builds. The manifest SHA-256 was `b43d7a5f496a39d1e0bbe7315e3e1fa3d1a48691dce95a521b5d2c750d08d71f`; the root module SHA-256 was `34cc687e682ddb86f32706acbd46f3291ce9f9b6df0cf82dfcde4409e0c1fd8f`.

**Determinism: PASS within the measured same-root, same-day, same-toolchain scope.** Unrestricted byte reproducibility across dates, platforms, locales or tool versions is **NOT TESTED** and must not be inferred: `New-ModuleManifest` includes a generated-date comment. Nova's source markers use relative paths, not assumed absolute-path differences.

The original manifest and root module were never overwritten. The retained artifact still needs an ordinary authorized build before anyone relies on it as dependency-compliant output.

## 5. Version, prerelease and package-resolution findings

PowerShell's [manifest requirements](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_module_manifests?view=powershell-7.4) and [prerelease packaging model](https://learn.microsoft.com/en-us/powershell/gallery/concepts/module-prerelease-support?view=powershellget-3.x) describe different layers:

| Surface | Meaning and finding |
| --- | --- |
| Module manifest `ModuleVersion` | Numeric `System.Version`; a module's own version, without `-preview` |
| RequiredModules `ModuleVersion` | Minimum numeric version, not exact pin; real Nova 3.4.3-preview satisfied `3.4.2` on both engines |
| RequiredModules `RequiredVersion` | Exact numeric version; cannot combine with ModuleVersion/MaximumVersion in the same specification |
| `PrivateData.PSData.Prerelease` | Label metadata, e.g. `preview`; does not add a prerelease constraint to RequiredModules |
| PMU package version | Semantic package identity `0.1.0-preview`, combining numeric version and label |
| PSResourceGet package selection | Prerelease-aware package identity/ranges, not PowerShell's numeric dependency matching |

**Executed result:** the real installed PMU preview copy satisfied `ModuleVersion = '0.1.0'` on both engines. A separate Gerber-manifest fixture using `RequiredVersion = '0.1.0'` also imported that preview on both engines. Numeric exactness therefore does **not** guarantee the stable channel.

Two `New-ModuleManifest` experiments on 7.6.6 rejected `0.1.0-preview` in either dependency `ModuleVersion` or `RequiredVersion`, before a valid manifest could be generated:

```powershell
New-ModuleManifest -Path $OwnedFixturePath -ModuleVersion 1.0.0 `
    -RequiredModules @(@{
        ModuleName = 'PSModuleUpdate'
        ModuleVersion = '0.1.0-preview'
    })
```

Observed error included `Cannot convert value "0.1.0-preview" to type "System.Version"`. Repeating with `RequiredVersion` produced the same conversion rejection. This is an invalid proposed representation, **not a defect in the current numeric project declaration**.

### Supported declaration and acquisition approach

Keep both existing numeric RequiredModules entries unchanged. Provision the intended packages separately using an explicit approved repository and prerelease-aware package selection, then let PowerShell enforce numeric import requirements.

[Save-PSResource](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/save-psresource?view=powershellget-3.x) accepts an exact prerelease package version and `-Prerelease`; an illustrative provisioning request is:

```powershell
Save-PSResource -Name PSModuleUpdate -Version '0.1.0-preview' -Prerelease `
    -Repository $ApprovedRepository -Path $OwnedDestination
```

This is **documented syntax, NOT an executed PMU acquisition result**. `-Path` belongs to Save-PSResource; do not substitute it into Install-PSResource. Numeric package selection such as `-Version '0.1.0'` denotes that exact package identity, not a promise to accept `0.1.0-preview`. `-Prerelease` enables preview candidates; it does not erase their labels. A minimum package range must be expressed as a range, rather than inferred from manifest `ModuleVersion` semantics.

No PMU package was downloaded, installed or published here, and no dependency version was changed. Availability of the intended PMU package in its future approved repository is **NOT TESTED**. Earlier [G-4A2](G-4A2-psresourceget-provider-qualification.md) provider tests are historical evidence, not a new provider run in this task.

## 6. Runtime import matrix

Every row was executed in a fresh process on **both 7.4.21 and 7.6.6**, using the newly generated disposable Gerber manifest. Network denial was active in every row; the successful baseline therefore also covers dependencies already installed with no network access.

| Case | Inputs differing from baseline | Expected observation | 7.4.21 | 7.6.6 |
| --- | --- | --- | --- | --- |
| Both present / offline | Nova 3.4.2 stable; PMU numeric 0.1.0 with preview metadata | Import succeeds; both dependencies loaded | PASS | PASS |
| Nova missing | Private search root excludes Nova | Import rejects missing Nova | PASS | PASS |
| PMU missing | Private search root excludes PMU | Import rejects missing PMU | PASS | PASS |
| Nova too old | Owned Nova copy's numeric manifest changed to 3.4.1 | Import rejects incompatible Nova | PASS | PASS |
| PMU too old | Owned PMU copy's numeric manifest changed to 0.0.9 | Import rejects incompatible PMU | PASS | PASS |
| Nova above minimum | Real installed Nova 3.4.3-preview copy | Import succeeds under numeric minimum semantics | PASS | PASS |
| Exact numeric PMU fixture | Gerber fixture uses PMU RequiredVersion 0.1.0 | Preview copy still satisfies exact numeric version | PASS | PASS |

The two too-old inputs are **synthetic manifest-version fixtures**, not claims about the behavior of actual released Nova 3.4.1 or PMU 0.0.9 packages. Real module implementation files were otherwise retained.

Missing/too-old cases returned `Modules_InvalidManifest,Microsoft.PowerShell.Commands.ImportModuleCommand`, naming the offending module:

```text
The required module 'PSModuleUpdate' is not loaded. Load the module or remove
the module from 'RequiredModules' in the file '<owned Gerber manifest>'.
```

Nova failures named `NovaModuleTools` instead. The native message identifies the failed dependency but omits its required version and includes generic removal advice. **Do not follow that removal advice:** the approved recovery is to provision the required dependency/version, not weaken RequiredModules. These failures occur before Gerber can provide its own CLI error presentation.

## 7. Network and operational-side-effect observations

Before each matrix import, a socket connection to `127.0.0.1:9` failed with socket error **AccessDenied** under the sandbox. This distinguishes enforced denial from an ordinary closed-port refusal. All fourteen probes confirmed denial; successful imports therefore did not depend on DNS, an accessible repository, a cached online response or network transport.

Command-breakpoint observers were installed **before import** for Nova build/package/publish and notification commands, PMU discovery/install, and Find/Install/Save-PSResource plus Find/Install/Update-Module. They recorded **zero import-time calls in every row**. AST inspection in section 3 independently confirms the three main modules do not invoke those workflows at top level.

On successful rows, counters were captured before separate positive controls deliberately invoked Nova build with `-WhatIf`, PMU discovery against a nonexistent test repository, and PMU installation with an invalid plan and `-WhatIf`. All three controls triggered the observers on both engines. PMU's controls returned expected provider/invalid-plan failures; they were not successful update operations and were not counted as import activity.

The instrumentation observes calls; it is **not** a blocking guard. Initial debugger-action experiments showed that throwing inside breakpoint actions was not a reliable prevention mechanism. Actual network/write prevention came from the OS sandbox. No real update plan, installation, package publication or release was performed.

Baseline imports on both engines left PSResourceGet **unloaded**, measured before the positive controls. Starting `Invoke-Gerber` interactively, startup notifications, `/update`, and complete creation/publication workflows were **NOT TESTED** in this matrix.

### Recorded launch commands and evidence

The import runner was invoked with:

```sh
python3 "$W/Run-Probes.py" /opt/homebrew/bin/pwsh \
  prepare both missing-nova missing-pmu old-nova old-pmu newer-nova exact-pmu
python3 "$W/Run-Probes.py" /tmp/pwsh74/pwsh \
  both missing-nova missing-pmu old-nova old-pmu newer-nova exact-pmu
```

It supplied the isolated environment and launched each case with the equivalent subprocess argument vector:

```sh
/usr/bin/sandbox-exec -p "$PROFILE" "$ENGINE" \
  -NoLogo -NoProfile -NonInteractive -File "$W/Import-Probe.ps1" \
  -ManifestPath "$OWNED_MANIFEST" -ResultPath "$CASE_RESULT"
```

The probe's import operation was `Import-Module -Name $ManifestPath -Force -ErrorAction Stop`. Case JSON records contain engine, loaded module versions/bases, restricted search path, socket-denial result, import outcome/error and observer/control counts. Local session evidence is retained in `results/build.json`, `build.log`, `version-fields.json`, `source-structure.json` and the seven `*-74.json` / seven `*-76.json` matrix records and logs. The baseline was rerun after adding the explicit provider-loaded measurement.

## 8. Defects, limitations and recommended remediation

| Finding | Result | Required disposition |
| --- | --- | --- |
| Retained original manifest does not enforce approved dependencies | FAIL | Run the normal build in an authorized artifact-refresh task; inspect its generated declarations before import/use |
| Nova preserves RequiredModules | PASS | No Nova modification or generator-remediation task justified by this evidence |
| Current numeric PMU requirement accepts its installed preview | PASS | Keep valid numeric declaration; qualify package identity/channel separately during acquisition |
| Invalid prerelease suffix inside dependency version fields is rejected | PASS | Do not use that syntax; leave current project declaration unchanged |
| Windows/Linux Gerber import matrix | NOT TESTED | Add the same dependency/import scenarios to a future cross-platform qualification; PMU's own CI does not substitute |
| PMU package acquisition from the intended repository | NOT TESTED | Confirm explicit repository, package availability and prerelease-aware provisioning without changing normal installations during this task |
| PMU provider availability during actual updates | NOT TESTED here; source requires exact 1.2.0 | Provision/qualify PSResourceGet for operational calls; do not infer it from import success |
| Full byte reproducibility across dates/platforms/toolchains | NOT TESTED | Treat the measured repeatability as bounded, not universal |
| Gerber startup check, `/update`, plugin updates | NOT TESTED / not implemented | Separate approved implementation work; no functionality added here |

No generator defect was found. The unresolved technical questions concern delivery/package-source and platform qualification, provider provisioning, and the existing G-4A5 configuration/repository/timeout questions, not whether either mandatory module should be removed.

## 9. Documentation and write-scope validation

The report and directly related status references were reviewed together. Formatting checks passed for all five documentation files, including **47 local links/anchors**, balanced typed fences, trailing whitespace and exactly one final newline. `git diff --check` passed. The full documentation diff was reviewed for contradictory dependency/version statements and for accidental claims of implemented update behavior.

A pre-investigation SHA-256 snapshot covered **640 Gerber files**, including ignored generated artifacts. A separate snapshot covered **200 existing installed-module files** used as qualification inputs. Final comparison found no changes to those original files except the explicitly edited documentation; source, tests, `project.json`, original `dist` and normal module copies were unchanged.

Disposable copied projects, modules, package downloads, fixtures and caches were removed after qualification. Probe scripts and JSON/log evidence remain in session storage, not in the repository.

README, contribution guidance, changelog and release notes were reviewed. Only the README's outstanding-qualification status needed updating; no product behavior or release version changed, so no new changelog/release announcement was added. Repository ScriptAnalyzer, Pester, PTY and full quality-loop execution were **not applicable to the documentation diff**; the isolated build/import commands above were investigation evidence, not claims that those broader gates passed. Code Health scoring is not applicable to prose.

## 10. Proposed next implementation step

First refresh and inspect Gerber's normal generated output in an authorized build/delivery task, preserving both numeric dependency entries. Carry this matrix into cross-platform qualification and confirm provisioning of the selected PMU package and its operational provider.

Then implement the separately approved **Core-first** Gerber integration from G-4A5: startup discovery only notifies and refers to `/update`; `/update` owns fresh checks, the tabular overview and explicit confirmation, with independent repository selection and the shared PMU engine. Plugin updates remain a later incremental phase. Configuration, credentials and presentation stay in Gerber; generic update mechanics stay in PMU. This report implements none of those steps.
