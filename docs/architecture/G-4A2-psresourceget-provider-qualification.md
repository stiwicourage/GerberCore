# G-4A2 - PSResourceGet provider qualification

> Organization, project and feed identifiers are illustrative replacements. Recorded private-feed outcomes describe the historical investigation, not requests to the example endpoints.

**Qualification date:** 2026-10-22 UTC.
**Architecture baseline:** [G-4A1 - PSModuleUpdate design](G-4A1-psmoduleupdate-design.md).
**Disposition:** useful foundation confirmed; not an unconditional provider qualification.

> **Historical qualification - see [G-4A5](G-4A5-update-architecture.md) for the current architecture.** The macOS / PowerShell 7.6.6 / PSResourceGet 1.2.0 evidence stands as recorded. Its design adjustments build on the G-4A1 baseline, whose lazy-dependency and Core-only recommendations are superseded; the same-base prerelease and scope constraints were later superseded by PSModuleUpdate's G-4A3 decisions (see [G-4A2-FIX2](G-4A2-FIX2-installation-scope-and-prerelease-replacement.md)). The text below is preserved unchanged.

> **Runtime dependency clarification (2026-10-24):** the current [D-017](../../DECISIONS.md) requires **both NovaModuleTools and PSModuleUpdate** in Gerber's `RequiredModules`. This report's retained lazy-PMU recommendation is not current policy; Nova supports Gerber plugin development, while independent PMU supplies updates. `/update` covers Core and later plugins, with notification-only Core checks at startup; provider qualification does not implement those Gerber workflows.

PSResourceGet **1.2.0** successfully performed public discovery/download and isolated local-fixture installation, exact version selection, dependency resolution and source selection. It did not transparently replace an installed prerelease with another release sharing the same numeric version directory. A prerelease-to-stable transition with that same base also left the prerelease installed. Concurrent installation attempts were not transparently serialized. A successful install did not establish the expected module manifest or preserve an earlier version's manifest GUID.

The authorized Azure Artifacts feed could not be qualified: `ADO_PAT` was present, but authenticated HTTP requests returned **401**, and PSResourceGet returned `UnauthorizedRequest`. No private package metadata, download or installation succeeded. This is an access blocker, not evidence that PSResourceGet cannot support Azure Artifacts.

The recommendation remains a thin PMU orchestration layer over standard package management, not a custom installer. A public-feed/CurrentUser implementation can be considered after approving the collision policy below. Private-feed support and the complete PowerShell 7.4/Windows/macOS/Linux contract remain unqualified. This task does not authorize implementation.

## 1. Environment and tool versions

| Component | Observed environment |
| --- | --- |
| PowerShell used for every provider test | **7.6.6**, Core, Unix |
| Operating system | **macOS 27.0.1** |
| PSResourceGet installed and explicitly loaded | **1.2.0** |
| PowerShellGet installed | **2.2.5** |
| PackageManagement installed | **1.4.8.1** |
| Separately installed .NET SDKs | 8.0.425 and 10.0.401 |
| Separately installed .NET runtimes | Microsoft.NETCore.App and Microsoft.AspNetCore.App 8.0.31 and 10.0.12 |
| Azure Artifacts credential-provider inventory | No binaries found under the default user NuGet plugin directory; no custom NuGet plugin-path variables configured; no Azure credential-provider global dotnet tool listed |
| Execution account | Non-root; no elevation requested |
| `ADO_PAT` | Present; value never displayed or written to artifacts |

PSResourceGet was loaded from the PowerShell installation's bundled module directory with `Import-Module ... -RequiredVersion 1.2.0`; each qualification process asserted that the loaded version was exactly 1.2.0. No newer provider was substituted. PowerShellGet was inventoried, not used for the installations.

The .NET inventory describes the separately invocable `dotnet` installation, not a claim that every listed runtime hosted the PowerShell tests. Credential-provider discovery was limited to the locations/configuration above; it is not a machine-wide assertion that no provider binary exists anywhere. No provider, module dependency or SDK was installed to complete qualification.

PowerShell **7.4 itself**, Windows and Linux were **NOT TESTED**. Running successfully on 7.6.6 does not verify the minimum runtime.

## 2. Test methodology and isolation

Tests used disposable child PowerShell processes and the temporary workspace `/private/tmp/gerber-g4a2-gd7vqw2b`. Each process received a disposable `HOME`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, staging directory and explicit `PSModulePath`. `ADO_PAT` was removed from local, public, permission and concurrent test-process environments. Only the approved Azure probes received it.

CurrentUser installations were confined to:

```text
<workspace>/home/.local/share/powershell/Modules
```

The controlled permission-denial test used a separate disposable HOME and a read-only Modules directory. No existing user or AllUsers installation was changed.

**Repository isolation required a different safeguard.** On this macOS host, changing HOME/XDG variables did not change .NET's `LocalApplicationData` location. PSResourceGet's repository XML therefore remained in the real user application-data directory. Its stable implementation uses that special folder, not the test module path. Only four uniquely named, owned registrations were added and subsequently removed: suffixes `-A`, `-B`, `-Network` and `-ADO`, under prefix `G4A2-gd7vqw2b`. Existing registrations were not repointed, reprioritized or trusted. The final repository XML matched its original SHA-256 exactly.

Twenty local ZIP-format NuGet fixture archives were created directly, without any `Publish-*` command or remote package write:

| Fixture | Purpose |
| --- | --- |
| `G4A2.Sample` in A | Stable 1.0.0, 1.1.0, 2.0.0; previews 2.0.0-beta.1 and beta.2; harmless function returning its version |
| Same name in B | 9.9.0 with higher repository priority, to detect unintended source selection |
| `G4A2.Channels` | Stable 1.0.0 and previews 2.0.0-beta.2/beta.10 |
| `G4A2.Dependency` | 1.0.0 and 1.1.0, distinguishing exact dependency selection from latest |
| `G4A2.WithDependencyV2` | Requires exactly Dependency 1.0.0 |
| `G4A2.CrossFeedV2`, `G4A2.OnlyB` | A dependency available only in B, while the parent is installed explicitly from A |
| `G4A2.Identity` | Two releases with different manifest GUIDs |
| `G4A2.Broken` | Archive with module script but without the expected module manifest |
| `G4A2.Concurrent` | Shared target for simultaneous install and controlled permission tests |

Two initial dependency fixtures were superseded by the V2 fixtures because the originals declared dependencies in the nuspec but omitted manifest `RequiredModules`. Discovery exposed no dependencies for those originals. The corrected fixtures declared both; only their results qualify dependency behavior.

Other harness corrections were a filesystem-path/file-URI comparison and an attempted use of a non-publicly available `NuGet.Versioning.NuGetVersion` type. Their aborted runs were not classified as provider defects. The actual failed prerelease assertions were retained, not changed to expected successes. An explicit `-Reinstall` probe was a separate experiment, not a repair silently applied to the normal-install result.

The test harness and packages were disposable investigation artifacts, not a delivered regression suite or PMU implementation. Commands below are historical excerpts; their fixture paths were removed after qualification.

## 3. Azure Artifacts endpoint and authentication

Authorized browser feed:

```text
https://dev.azure.com/example-org/SampleProject/_artifacts/feed/ExampleModules
```

The project-scoped NuGet v3 candidate derived from Microsoft's documented endpoint format was:

```text
https://pkgs.dev.azure.com/example-org/SampleProject/_packaging/ExampleModules/nuget/v3/index.json
```

**Endpoint-format derivation is not authenticated endpoint verification.** Azure has both project-scoped and organization-scoped feeds, and the browser project context alone does not prove the feed's scope. HTTP 401 prevented inspecting the service index or confirming the feed's authoritative scope. The feed owner must confirm the endpoint from **Connect to feed** before the blocked integration is rerun. No other organization or alternative feed was probed.

Authentication used an in-memory `PSCredential` with username `token` and the environment PAT as its secure password. A temporary registration explicitly selected `-ApiVersion V3 -CredentialProvider None`; `CredentialInfo` remained absent. This qualified registration without persisting credentials or attempting to install/use an unavailable credential provider.

The first HTTP probe used PowerShell's Basic authentication support, prohibited redirects and returned **401**. A second in-memory Basic probe matching the provider's token-style request also returned **401**. PSResourceGet 1.2.0 itself was then called with the credential and returned:

```text
UnauthorizedRequest,Microsoft.PowerShell.PSResourceGet.Cmdlets.FindPSResource
```

No successful service-index response was available to enumerate or validate downstream package-resource endpoints, so package operations were not attempted. The status does not establish whether the PAT was expired, revoked, insufficiently scoped, associated with a different identity, or blocked by feed/organization policy. No secret value was requested from the user.

## 4. Result matrix

**PASS** means the stated observation/assertion succeeded, not that every related scenario is supported. **FAIL** means an executed desired postcondition was not met. **BLOCKED** means a prerequisite prevented qualification. **NOT TESTED** means no corresponding execution occurred.

| Evidence | Capability or assertion | Result | Observed result and limit |
| --- | --- | --- | --- |
| L00 | Exact provider baseline and owned installation destination | PASS | Loaded 1.2.0; CurrentUser root inside disposable HOME |
| P01 | Public PSGallery exact discovery | PASS | PSResourceGet 1.2.0 returned from explicit PSGallery |
| P02 | Public archive download without installation | PASS | Saved one 1.2.0 nupkg |
| Public archive inspection | Archive/package metadata checks | PASS | ZIP CRC passed; nuspec ID/version matched; signature entry present, not cryptographically verified |
| P03 | Zero fourth-component normalization | PASS | Exact request `[1.2.0.0]` returned 1.2.0 |
| P04 | Public prerelease metadata | PASS | Exact 1.3.0-rc1 returned Version 1.3.0 and Prerelease rc1; not imported |
| L01-L03 | Stable/all-version/exact local discovery and named source | PASS | Stable latest 2.0.0; all five versions returned; exact A/1.1.0 selected despite B/9.9.0 having higher priority |
| L04 | Exact CurrentUser install and installed-version query | PASS | 1.0.0 installed and verified under disposable HOME |
| L05 | Imported version during side-by-side numeric-version update | PASS | Installing 1.1.0 left loaded 1.0.0/function active |
| L06-L07 | Ordinary beta.1 to beta.2 install with same numeric base | FAIL | No terminating install error; disk remained beta.1; exact installed beta.2 query failed |
| L06-REINSTALL, V01 | Separate explicit reinstall and fresh-process verification | PASS | `-Reinstall` placed beta.2 on disk; old process still ran beta.1; new process ran beta.2 and exact installed lookup succeeded |
| V02 | Ordinary beta.2 to stable 2.0.0 installation | FAIL | Warning said numeric version was already installed; disk remained beta.2 |
| L08 | Repeated installation of already matching exact preview | PASS | Manifest timestamp unchanged |
| L09 | Declared exact dependency | PASS | Corrected fixture installed Dependency 1.0.0, not available 1.1.0 |
| L10 | Dependency source isolation, local A/B | PASS | Dependency present only in B was not fetched; operation failed and parent/dependency destinations were absent |
| L11 | Manifest GUID continuity provided by installer | PASS, observation only | Both releases installed despite different GUIDs; continuity is not enforced |
| L12, V03 | Install success establishes expected versioned manifest | FAIL | Install returned without error; expected manifest absent; `Get-Module -ListAvailable` discovered no module |
| L13 | AllUsers parameter/WhatIf feasibility | PASS | WhatIf accepted explicit scope without installation |
| Filesystem check | Real AllUsers install/permission failure | NOT TESTED | Nearest existing ancestor was not writable; no real global write or elevation attempted |
| S01 | Controlled non-writable CurrentUser destination | PASS | Terminating install failure; no target package directory remained |
| L14, L18 | Semantic prerelease ordering and channel discovery | PASS | beta.2 < beta.10 < stable; stable search returned 1.0.0, inclusion of previews returned 2.0.0-beta.10 |
| L19 | Four-part nonzero revision comparison | PASS, limitation observed | `[version]'1.2.3.4'` valid; direct `[semver]` conversion failed; provider install of such a version NOT TESTED |
| L15 | Unreachable repository | PASS | Closed loopback endpoint produced `HttpRequestCallFailure`, not an up-to-date result |
| L16 | Arbitrary save path versus install path | PASS | Save extracted to chosen path; Install had no `Path` parameter |
| L17 | Per-call trust override versus persisted trust | PASS | Using `-TrustRepository` did not mark A trusted |
| C01 and second process | Transparent concurrent-install success | FAIL | One process verified success; the other terminated with `InstallPackageFailed`; final package/manifest verified intact |
| A00 | PAT presence | PASS | Present; no value output |
| A01, A09 | Successful Azure authentication | FAIL | Both authenticated HTTP probes returned 401 |
| A10 | Temporary v3 registration without stored credentials | PASS | V3/None registration; no `CredentialInfo` |
| A11 | Authorized private package discovery | BLOCKED | Real provider request returned `UnauthorizedRequest` |
| Private follow-on | Metadata enumeration, versions, previews, save, isolated install, dependencies | BLOCKED | No authenticated service index/package candidate |
| Other auth profiles | Invalid synthetic PAT against a working feed, credential provider, vault, cached Entra identity | NOT TESTED | No successful private-authentication control; no provider installation authorized |
| Other platforms/runtime | Windows, Linux, PowerShell 7.4 | NOT TESTED | Only macOS/7.6.6 executed |
| Fault injection | Interrupted process, disk-full, corrupt transfer, crash recovery | NOT TESTED | No destructive/large-resource fault injection |
| Z01 and store hash | Registration cleanup and settings preservation | PASS | All four owned names absent; original repository XML byte-identical |

L12 originally recorded successful *execution of the probe*. It is classified **FAIL** here against the meaningful PMU postcondition, not presented as successful module validation. Similarly, L13's dry run is not a passed real AllUsers installation.

## 5. Actual command excerpts

These are the actual provider operations used, grouped for readability. Variables denote the disposable workspace, its Modules root and the uniquely named A/B/ADO repositories described above. Credentials are referenced through the environment/in-memory object, never literal values. Do not run the fixture commands against a real user HOME.

### Baseline and isolation

Child processes were launched with the following environment values; local/public/concurrent/permission children additionally had `ADO_PAT` removed:

```text
HOME=<workspace>/home
XDG_DATA_HOME=<workspace>/data
XDG_CONFIG_HOME=<workspace>/config
PSModulePath=<workspace>/home/.local/share/powershell/Modules:<PSHOME>/Modules
TMPDIR=<workspace>/stage
```

```powershell
Import-Module Microsoft.PowerShell.PSResourceGet -RequiredVersion 1.2.0
Get-Module -ListAvailable Microsoft.PowerShell.PSResourceGet, PowerShellGet, PackageManagement
$PSVersionTable
Get-Command Install-PSResource
Get-PSResourceRepository

Register-PSResourceRepository -Name $repoA -Uri (Join-Path $root 'feed-a') -ApiVersion Local -Priority 50
Register-PSResourceRepository -Name $repoB -Uri (Join-Path $root 'feed-b') -ApiVersion Local -Priority 0
Find-PSResource -Name G4A2.Sample -Repository $repoA
Find-PSResource -Name G4A2.Sample -Version '*' -Prerelease -Repository $repoA
Find-PSResource -Name G4A2.Sample -Version '1.1.0' -Repository $repoA
```

### Public discovery and download

```powershell
Find-PSResource -Name Microsoft.PowerShell.PSResourceGet -Version '1.2.0' -Repository PSGallery -ErrorAction Stop
Save-PSResource -Name Microsoft.PowerShell.PSResourceGet -Version '1.2.0' -Repository PSGallery -Path $publicDirectory -AsNupkg -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop
Find-PSResource -Name Microsoft.PowerShell.PSResourceGet -Version '[1.2.0.0]' -Repository PSGallery
Find-PSResource -Name Microsoft.PowerShell.PSResourceGet -Version '1.3.0-rc1' -Prerelease -Repository PSGallery
```

The saved nupkg was inspected with Python `zipfile.ZipFile.testzip()` and `xml.etree.ElementTree` to check its nuspec ID/version. No code from that download was imported.

### Installation, loaded state and verification

```powershell
Install-PSResource -Name G4A2.Sample -Version '1.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -TemporaryPath (Join-Path $root 'stage') -ErrorAction Stop
Get-InstalledPSResource -Name G4A2.Sample -Path $moduleRoot
$active = Import-Module $manifest -PassThru
Get-G4A2FixtureVersion
Install-PSResource -Name G4A2.Sample -Version '1.1.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop

Install-PSResource -Name G4A2.Sample -Version '2.0.0-beta.1' -Prerelease -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop
$previewActive = Import-Module (Join-Path $previewPath 'G4A2.Sample.psd1') -PassThru -Force
Install-PSResource -Name G4A2.Sample -Version '2.0.0-beta.2' -Prerelease -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop
Get-InstalledPSResource -Name G4A2.Sample -Version '2.0.0-beta.2' -Path $moduleRoot
```

That final query failed with `InstalledPackageNotFound`; inspecting the manifest showed beta.1. The separate experiment was:

```powershell
Install-PSResource -Name G4A2.Sample -Version '2.0.0-beta.2' -Prerelease -Repository $repoA -Scope CurrentUser -TrustRepository -Reinstall -Confirm:$false -Quiet -ErrorAction Stop
Import-PowerShellDataFile (Join-Path $previewPath 'G4A2.Sample.psd1')
Get-G4A2FixtureVersion
```

After it, the manifest said beta.2 but the already imported function still returned beta.1. A fresh child imported that same manifest, returned beta.2 and successfully queried exact installed beta.2. In that fresh child, the subsequent stable-transition probe was:

```powershell
Install-PSResource -Name G4A2.Sample -Version '2.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -WarningVariable providerWarnings -WarningAction SilentlyContinue -ErrorAction Stop
Import-PowerShellDataFile (Join-Path $moduleRoot 'G4A2.Sample/2.0.0/G4A2.Sample.psd1')
```

The manifest still said beta.2. For comparison, timestamp checks surrounded a repeat install of the already matching beta.2. Reinstall was not enabled for that idempotency probe.

### Dependencies, paths, permission, failures and concurrency

```powershell
Install-PSResource -Name G4A2.WithDependencyV2 -Version '1.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop
Get-InstalledPSResource -Name G4A2.Dependency -Path $moduleRoot
Install-PSResource -Name G4A2.CrossFeedV2 -Version '1.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop

Install-PSResource -Name G4A2.Identity -Version '1.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet
Install-PSResource -Name G4A2.Identity -Version '2.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet
Install-PSResource -Name G4A2.Broken -Version '1.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop
Get-Module -ListAvailable -Name G4A2.Broken

Install-PSResource -Name G4A2.Concurrent -Version '1.0.0' -Repository $repoA -Scope AllUsers -TrustRepository -WhatIf -Confirm:$false -Quiet -ErrorAction Stop
Install-PSResource -Name G4A2.Concurrent -Version '1.0.0' -Repository $repoA -Scope CurrentUser -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop

Register-PSResourceRepository -Name $repoOffline -Uri 'http://127.0.0.1:1/v3/index.json' -ApiVersion V3 -Priority 50
Find-PSResource -Name G4A2.Sample -Repository $repoOffline -ErrorAction Stop
Save-PSResource -Name G4A2.Sample -Version '1.0.0' -Repository $repoA -Path (Join-Path $root 'downloads') -TrustRepository -Confirm:$false -Quiet -ErrorAction Stop
(Get-PSResourceRepository -Name $repoA).Trusted
Find-PSResource -Name G4A2.Channels -Repository $repoA
Find-PSResource -Name G4A2.Channels -Repository $repoA -Prerelease
[semver]'2.0.0-beta.10' -gt [semver]'2.0.0-beta.2'
[semver]'2.0.0' -gt [semver]'2.0.0-beta.10'
[semver]'1.2.3.4'
```

The CurrentUser Concurrent command was executed in two child processes launched together against one initially absent target. The same command was separately run under the read-only disposable destination. No AllUsers command without WhatIf was executed.

### Approved private authentication and cleanup

```powershell
[string]::IsNullOrWhiteSpace($env:ADO_PAT)
$endpoint = 'https://pkgs.dev.azure.com/example-org/SampleProject/_packaging/ExampleModules/nuget/v3/index.json'
$credential = [pscredential]::new('token', (ConvertTo-SecureString $env:ADO_PAT -AsPlainText -Force))
Invoke-WebRequest -Uri $endpoint -Authentication Basic -Credential $credential -MaximumRedirection 0 -SkipHttpErrorCheck -TimeoutSec 30
Register-PSResourceRepository -Name $repoAdo -Uri $endpoint -ApiVersion V3 -CredentialProvider None -ErrorAction Stop
Find-PSResource -Name NovaModuleTools -Repository $repoAdo -Credential $credential -ErrorAction Stop

foreach ($name in @($repoA, $repoB, $repoAdo, $repoOffline)) {
    Unregister-PSResourceRepository -Name $name -Confirm:$false
}
```

The first expression established presence only; no secret was output. The second HTTP probe used an in-memory Basic request equivalent to the provider's token authentication; its authentication headers are deliberately not reproduced. The exact-name discovery probe does not establish that NovaModuleTools exists in this feed, because authorization failed first. Cleanup unregistered only owned names found to exist.

## 6. Public PSGallery findings

Explicit PSGallery discovery returned the requested stable 1.2.0 and prerelease 1.3.0-rc1. The prerelease was returned as numeric `Version` plus separate `Prerelease` metadata. The downloaded stable archive was not installed over the existing provider.

Archive CRC and nuspec identity checks passed. A NuGet signature entry existed, but no signature-chain, publisher or revocation verification was performed. Download success/CRC is not proof of publisher authenticity. Public remote **installation** was not executed; its discovery/download and the provider's local installation backend were exercised separately.

The zero fourth-component exact request normalized successfully. This does not qualify every four-part version/range combination or make a plain `[semver]` cast appropriate for all PowerShell manifest versions.

## 7. Private Azure Artifacts findings

Registration with direct-credential authentication configuration succeeded without saving credentials. Authentication did not. Consequently the following remain **BLOCKED**:

- Confirmation of feed scope and authoritative v3 service-index/resource endpoints.
- Available package inventory, exact versions and prerelease metadata.
- Safe archive download and selection of a dependency-free install candidate.
- Isolated private installation, installed-version/source verification and dependency resolution.

No real private package was downloaded, installed or imported. Generic private NuGet v3 compatibility was not established by the local-file fixtures. Azure credential-provider, SecretManagement, cached/unattended identity and successful-versus-invalid-credential controls remain **NOT TESTED**.

PSResourceGet's stable source supports a direct credential and token-style Basic requests; that source evidence explains the mechanism, not a successful feed qualification. Future testing should reuse supported authentication with a valid Packaging Read identity and the feed owner's endpoint. It must not introduce custom PMU Azure authentication.

## 8. Stable/prerelease behavior

Local discovery ordered stable 2.0.0 above previews of the same base. A separate fixture established numeric prerelease ordering: beta.10 above beta.2. Stable-only discovery excluded a higher-base preview; allowing prereleases selected it. Inclusion of prereleases is not a promise to select only prereleases.

Installation is the important exception. The previews occupied:

```text
Modules/G4A2.Sample/2.0.0/
```

The full preview label was in manifest `PrivateData.PSData.Prerelease`, not in the directory name. Ordinary exact installation of beta.2 over beta.1 did not change that manifest. Likewise, requesting stable 2.0.0 over beta.2 warned that the resource/version was already installed and left beta.2 on disk. `-ErrorAction Stop` did not turn this warning/no-op into installation success or an error.

The stable source corroborates the behavior: `Utils.GetInstalledPackages` constructs its installed name/version key from `PSResourceInfo.Version` without adding `Prerelease`. Numeric directory layout and numeric installed-version checks therefore cannot prove a full target-version match. Exact discovery alone does not eliminate this installation limitation.

Explicit `-Reinstall` replaced beta.1 with beta.2 in the disposable test, but that is **not** approved default PMU behavior. It overwrites the same directory rather than preserving both previews side by side. No guarantee is established for locked assemblies, Windows, an interrupted overwrite, or rollback. PMU must either reject such collisions actionably or obtain approval for a separately qualified repair/replacement flow.

## 9. CurrentUser, AllUsers and installation paths

CurrentUser installation and `Get-InstalledPSResource -Path` verification worked in the disposable HOME. On this Unix provider version, the install root was `$HOME/.local/share/powershell/Modules`, despite a different `XDG_DATA_HOME`. Explicitly adding this root to `PSModulePath` made the fixtures discoverable.

`Install-PSResource` 1.2.0 has **no `-Path` parameter**. `-TemporaryPath` controls staging, not final destination. `Save-PSResource -Path` successfully extracted to an arbitrary disposable destination, but saving a package is not equivalent to installing/registering it in the module search path. Merely altering `PSModulePath` does not select an arbitrary install destination.

AllUsers WhatIf was accepted and made no installation. The provider's Unix AllUsers Modules path was `/usr/local/share/powershell/Modules`; it did not exist. Its nearest existing ancestor had mode 0755 and was not writable by the non-root account. Real AllUsers installation and its actual permission exception are **NOT TESTED**.

The controlled CurrentUser permission test did execute a write-denied installation. It terminated with `InstallPackageFailed` and left no target directory. This validates a permission-failure observation, not a promise that every AllUsers failure has that identifier or cleanup behavior.

The macOS repository-store exception also matters to test design: disposable module paths do not imply disposable repository registrations. Windows path derivation differs in stable source; it was not executed here.

## 10. Imported modules and installed identity

Installing numeric 1.1.0 alongside imported 1.0.0 preserved the loaded function/version. The old and new numeric-version manifests coexisted. An explicit same-base preview reinstall changed the disk manifest but not the imported script function or existing module metadata object. A fresh process loaded the changed version successfully.

PMU should continue to report **active version**, **verified installed target** and **restart required** separately. It should not force-remove/reimport Gerber Core. Same-process file reads after replacement cannot reconstruct the identity of code already loaded from the overwritten path; capture active `PSModuleInfo` identity before mutation.

The observed `PSResourceInfo.InstalledLocation` was the **Modules root**, not the complete module/version directory. Verification must resolve the actual target manifest within the expected destination and compare its numeric version, prerelease and GUID. Do not return the root as a verified `InstalledPath`.

The installer accepted releases with different manifest GUIDs. It also installed the manifest-less fixture without a terminating error, leaving a directory that `Get-Module -ListAvailable` did not discover. This is a failure of the proposed *PMU verified-module postcondition*, not a claim that PSResourceGet promises manifest continuity or rejects every nonstandard package layout.

## 11. Dependencies and repository isolation

Corrected local fixtures demonstrated that the provider installed a manifest-declared exact dependency at 1.0.0 even though 1.1.0 was available. When A's declared dependency existed only in B, an explicit A install failed with `InstallPackageFailure`; neither the parent nor that dependency was installed. The higher-priority B also did not override explicit A discovery.

These are **local backend** results. They do not verify authenticated v3 dependency requests, transitive graphs, upstream Azure sources, conflicting dependencies, or source-binding behavior across every repository backend. Existing stable v3 test/source evidence in G-4A1 is not substituted for the blocked live private test.

PMU should retain standard dependency resolution, a single explicit approved repository, exact target version and expected endpoint. Repository-name selection does not by itself bind a plan to an unchanged URI: PMU must re-resolve/revalidate the registration at apply time. No live registration-repoint race was injected.

`-TrustRepository` allowed these test operations without permanently trusting the registration. It is a per-call permission, not cryptographic package approval. The behavior of untrusted/license/vault prompts **without** the explicit overrides was not tested; noninteractive prompt-safety promises remain to be verified.

## 12. Security, failures, recovery and cleanup

The credential remained in the inherited private-test environment and short-lived process memory. It was not put in a URL, credential configuration, transcript, plan, report, package or repository XML. Redirects were disabled in direct HTTP probes; credentials were sent only to the approved organization's explicit feed endpoint. No downstream package endpoints were contacted after authorization failed.

An in-memory audit of temporary files and repository settings found zero occurrences of the literal PAT or the tested Basic-encoded forms. This is a scoped artifact check, not a universal forensic guarantee about OS process memory or server-side logging. Raw credential headers and verbose HTTP diagnostics were never displayed.

Failure observations support these boundaries:

| Area | Evidence and implication |
| --- | --- |
| Network/offline | Closed loopback discovery terminated with `HttpRequestCallFailure`; no alternate repository or stale success was used. Full DNS/TLS/proxy/timeout/cache behavior remains untested |
| Authentication | Provider surfaced `UnauthorizedRequest`; classify safely without exposing raw authenticated request diagnostics |
| Permissions | Controlled write denial surfaced `InstallPackageFailed`; do not automatically elevate or change scope |
| Validation | A returned install is insufficient: verify full module identity and actual target before reporting success |
| Concurrency | Two starts against one absent target produced one successful install and one `InstallPackageFailed`; final target metadata/manifest were intact |
| Existing versions | Numeric 1.0.0/1.1.0 coexisted; same-base preview replacement used one shared directory |
| Interruption/rollback | No process-kill, disk-full, damaged transfer or automated rollback test; do not advertise transactionality |

The concurrency result supports PMU's planned cooperating-process lock; it does not prove provider atomicity, a specific race cause, or serialization against external package commands. Preserve failure details and re-inspect installed state rather than retrying destructive replacement automatically.

A malformed/missing target after an install should produce a verification failure and safe recovery guidance, not an automatic delete/rollback transaction. Ordinary PowerShell package commands in a fresh session remain the recovery route independent of PMU. Recovery must account for same-base directories that cannot retain two preview copies. None of these experiments justifies silently enabling `-Reinstall`, deleting old versions, weakening identity checks or broadening trust.

Cleanup removed all four owned registrations; the original repository XML matched byte-for-byte. Disposable archives, scripts, modules, staging/download directories and results were removed after recording this report. No private package/feed permission was changed, and no package was published.

## 13. Required G-4A1 design adjustments

The architecture report remains unchanged; these are proposed corrections/clarifications for the next approved design revision.

| Priority | Design consequence |
| --- | --- |
| Required before implementation | Define a distinct **same-numeric-base/full-version collision** outcome. Preflight it for preview-to-preview and preview-to-stable transitions, including an installed but inactive conflicting preview. Exact install alone is insufficient |
| Recommended initial policy | Reject a different full version already occupying that directory with actionable manual recovery guidance. Keep no implicit `-Reinstall` or force override in the initial API. A replacement workflow needs separate approval and cross-platform/recovery qualification |
| Required | Verify after every mutation even when the provider reports no error. Preserve `PMU.VerificationFailed` rather than converting a warning/no-op into `Installed` |
| Required | Resolve actual installed manifest path; do not assume `InstalledLocation` is that path. Compare name, numeric version, prerelease, expected GUID, source and destination as observable |
| Required | Keep active metadata captured before mutation, installed target and restart reporting separate. Never hot-reload Core to make verification appear successful |
| Clarification | Support provider-standard CurrentUser destination initially. Do not promise arbitrary `Install-PSResource -Path`; custom/development deployments require a separate supported strategy |
| Clarification | Scope/path calculation must follow the pinned provider, not assume XDG or the host's default `PSModulePath` selects the install root. Keep special-folder repository state separate from module state |
| Required validation | Retain the PMU cooperating-process lock and stale-plan/source checks. Qualify failure/recheck behavior; do not rely on provider concurrency serialization |
| Required validation | Treat private Azure/NuGet v3, authentication profiles and private dependency routing as **blocked/unverified**, not supported because registration succeeded |
| Required validation | Define four-part version normalization/comparison explicitly. A zero fourth component worked; a nonzero revision cannot be blindly cast to PowerShell SemanticVersion |
| Required validation | Test 7.4, Windows and Linux before making the complete compatibility claim; test noninteractive trust/license/authentication prompts separately |
| Unchanged recommendation | Independent, lazily loaded PMU runtime dependency; ordinary Gerber operation unaffected by missing/broken PMU; no automatic PMU self-update or custom package manager |

The two-command proposal remains appropriate: `Get-PSModuleUpdate` receives explicit consumer identity/repository/policy and returns a full-version-bound plan; `Install-PSModuleUpdate -Update` revalidates it, obtains native approval where applicable, installs through the provider and verifies. Qualification does not call for registration, callback frameworks, a dependency resolver or a transaction engine.

Gerber remains the first consumer and must update Core only, without forced reload or plugin/Nova updates. NovaModuleTools should retain its current updater until Gerber has validated PMU, including the failure paths above.

## 14. Recommendation and remaining qualification gates

**Do not declare PSResourceGet 1.2.0 fully qualified for the complete G-4A1 promise.** Keep it as the proposed baseline; the executed results justify focused orchestration rather than replacement package-management infrastructure.

Subject to a separate implementation approval, work can proceed on a **public PSGallery, standard CurrentUser, fail-closed collision policy** subset after that policy is accepted. Even this subset must detect an existing preview directory when targeting a stable release; calling it stable-only does not remove the collision.

Before claiming the broader supported product contract:

1. Approve collision handling and implement permanent behavior tests in the future PMU project, including beta.1 to beta.2, preview to stable, already-correct target, GUID mismatch, missing manifest and concurrent attempts.
2. Confirm the approved feed's Connect-to-feed endpoint and provide a usable Packaging Read authentication environment without sending/persisting secrets through this report. Rerun discovery, full-version metadata, safe archive download, suitable isolated installation, dependencies and valid/invalid credential controls.
3. Execute the PowerShell 7.4 minimum-runtime and Windows/macOS/Linux matrix, particularly imported assemblies and same-base replacement restrictions.
4. Qualify noninteractive trust/license/vault/provider behavior and proportionate isolated interruption/recovery scenarios. Real AllUsers mutation stays outside the initial scope unless separately approved.

Private-feed support is **BLOCKED**, not rejected. AllUsers and unexecuted platform/fault profiles remain **NOT TESTED**. No automatic credential-provider installation, elevation or custom Azure login is recommended to bypass those limits.

This deliverable is provider qualification and documentation only. No PMU project/repository, Gerber `/update`, runtime dependency, production code, pipeline or NovaModuleTools change was made. G-4A0/G-4A1 reports and pre-existing worktree changes were preserved. Nothing was committed, pushed, tagged or published.

### Sources and evidence boundaries

- [G-4A1 design](G-4A1-psmoduleupdate-design.md): architecture/API/distribution baseline and earlier consumer-source findings, not a substitute for executed provider results.
- [PSResourceGet stable `Utils.cs`](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/Utils.cs): `GetStandardPlatformPaths`, `GetHomeOrCreateTempHome`, `GetInstalledPackages`; corroborates Unix destinations and numeric installed-version keys.
- [Stable `RepositorySettings.cs`](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/RepositorySettings.cs): application-data repository store and registration configuration.
- [Stable `V3ServerAPICalls.cs`](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/V3ServerAPICalls.cs): v3 and token-style direct authentication implementation; not proof of successful private access.
- [Microsoft Install-PSResource reference](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.psresourceget/install-psresource?view=powershellget-3.x): installation versus import semantics. This live reference contains newer-version features and a v3-dependency warning; installed 1.2.0 commands, pinned source and explicit backend tests take precedence for this qualification. In particular, newer `$PSUserContentPath` behavior was not attributed to 1.2.0.
- [Microsoft Azure Artifacts NuGet connection guidance](https://learn.microsoft.com/en-us/azure/devops/artifacts/nuget/nuget-exe?view=azure-devops): project-scoped versus organization-scoped endpoint formats; no credential-provider installation instructions were executed.

Result IDs refer to the disposable run records summarized here. Those records were removed with the fixtures rather than committed as another deliverable. This is point-in-time executable evidence, not a maintained multi-platform test suite or a claim that documentation-based capabilities passed live tests.

## 15. G-4A2-FIX1 follow-up - Azure authentication investigation

**2026-10-22:** [G-4A2-FIX1 - Azure Artifacts authentication and endpoint qualification](G-4A2-FIX1-azure-artifacts-authentication.md) tested the inherited `ADO_PAT` independently of PSResourceGet. Documented empty-username/PAT Basic requests to the `example-org` organization connection API, SampleProject project API and named feed-metadata API all returned **401**, `AccessCheckException`, error code 0. A single organization-API control with Basic username `token` also returned 401.

This narrows the unresolved blocker to authentication/organization access before private package qualification. It does **not** establish missing PAT Packaging permissions, an incorrect feed endpoint or PSResourceGet incompatibility. Pinned 1.2.0 source confirms that credential username `token` intentionally sends the canonical empty-username/PAT Basic form. The historical failures and results above are unchanged.

The feed scope and authoritative NuGet v3 endpoint remain **unverified**. No further package-authentication request was made after the independent API failure; private inventory, versions, stable/prerelease metadata, download and installation remain blocked or not tested, not newly qualified. Existing repository settings and inventoried module roots were preserved. The credential owner must first establish successful authentication to the authorized organization with the actual inherited credential, then confirm the official feed connection configuration and rerun the private tests. G-4A3 was not started.

### G-4A2-FIX1 resumed qualification (2026-10-22)

After the process-environment credential mismatch was corrected, [G-4A2-FIX1](G-4A2-FIX1-azure-artifacts-authentication.md#authentication-recovery-and-resumed-qualification) executed the previously blocked private-feed tests. **New executable result:** the feed is project-scoped; the E5 project-scoped v3 endpoint is verified; PSResourceGet 1.2.0 authenticated and passed exact discovery, version listing, exact-version selection, missing-versus-unauthorized distinction and `Save-PSResource` with archive integrity. Prerelease handling and isolated installation remain **NOT TESTED**. The historical HTTP 401 results in this report are unchanged and describe the earlier credential. Current private-feed status moves from **BLOCKED** to **partially qualified** (see FIX1 status table).

## Follow-up: G-4A2-FIX2

Installation scope and same-base prerelease replacement were qualified in `G-4A2-FIX2-installation-scope-and-prerelease-replacement.md`. The silent same-base no-op documented above is confirmed, and `-Reinstall` plus staged verification is the recommended replacement path. Historical results above are unchanged.
