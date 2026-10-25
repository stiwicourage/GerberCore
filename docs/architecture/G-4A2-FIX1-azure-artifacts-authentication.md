# G-4A2-FIX1 - Azure Artifacts authentication and endpoint qualification

> Organization, project, feed and resource identifiers have been replaced with illustrative examples for this snapshot. Recorded outcomes describe the historical investigation, not requests to the example endpoints.

**Investigation date:** 2026-10-22 UTC.
**Repository revision:** `232d9462a1d61a1ff5e1fd4c473c6ad2510cfcbc`; initially clean worktree.
**Disposition:** investigation complete with an external authentication blocker; private-feed qualification remains blocked.
**Scope:** read-only executable investigation and documentation, not PMU or Gerber implementation.

## 1. Executive summary

**The inherited `ADO_PAT` did not successfully authenticate to the authorized Azure DevOps organization independently of PSResourceGet.** Redirect-disabled, platform-TLS-validated HTTP requests returned **401**, `typeKey: AccessCheckException`, `errorCode: 0`, from the organization connection API, the SampleProject project API and the feed-metadata API. A single organization-API control using the previously used Basic username `token` also returned 401.

The actual feed scope, feed GUID and authoritative NuGet v3 endpoint remain **unverified**. The browser URL and documented endpoint formats identify the intended target but do not establish its scope or existence. No feed metadata or service index was retrieved.

The failure is reproducible without a package provider or NuGet endpoint. This narrows the blocker to **authentication/organization access for the environment-supplied credential**, not an established Packaging-permission deficit or PSResourceGet defect. The precise server-side reason remains unknown. The user's expectation of full access is preserved; no permissions, token settings or organization policy were changed.

PSResourceGet **1.2.0** was explicitly loaded and inspected. Pinned 1.2.0 source confirms that credential username `token` deliberately sends Basic authentication with an **empty username** and the PAT as password. That construction matches the direct request rejected here. Live provider/package authentication was not retried after the independent API-layer failure, as required by the stop condition. No private discovery, version query, download or installation passed.

**G-4A3 cannot proceed on the basis that Azure authentication is resolved.** First establish successful authentication to this organization using the credential actually inherited by the investigation process, then establish the feed's authoritative connection configuration and rerun private qualification. This report does not start G-4A3 or alter the G-4A1 design.

## 2. Environment and provider versions

| Component | Executable observation |
| --- | --- |
| PowerShell | 7.6.6, Core |
| Operating system | macOS 27.0.1 |
| Explicitly imported module | Microsoft.PowerShell.PSResourceGet **1.2.0** |
| Provider location | Bundled `Modules/Microsoft.PowerShell.PSResourceGet` under the PowerShell installation |
| `ADO_PAT` | Present; printable ASCII, no leading/trailing whitespace; value never emitted |
| Direct HTTP client | PowerShell-hosted .NET `HttpClient`, 35-second timeout, `AllowAutoRedirect = false`, default certificate validation |
| Proxy observations | No HTTP/HTTPS/ALL proxy environment variables in either casing; .NET default proxy reported bypass for the organization API |
| Existing Azure credential-provider discovery | No `CredentialProvider.Microsoft.*` files under the default user `.nuget/plugins` directory; no `NUGET_PLUGIN_PATHS`, `NUGET_NETCORE_PLUGIN_PATHS` or `NUGET_NETFX_PLUGIN_PATHS` configured |
| Other runtimes/platforms | Actual PowerShell 7.4, Windows and Linux **NOT TESTED** |

Provider assertions and command inspection ran in short-lived `pwsh -NoLogo -NoProfile -NonInteractive` processes. No downloaded package was imported or executed. No credential provider, dependency or replacement provider version was installed. The credential-provider inventory is limited to the locations/configuration above, not a machine-wide absence claim.

An initial Python standard-library HTTPS attempt failed certificate-chain validation with `SSLCertVerificationError`, verification code **20**, before an HTTP response. An unauthenticated transport check reproduced it. This is a local Python trust-store limitation, not a PAT rejection. The investigation switched to the existing PowerShell/.NET platform trust path; **TLS validation was not disabled**, certificates were not installed and trust settings were not changed.

## 3. Feed identity and endpoint verification

### Target and candidate endpoint catalog

All URLs below contain no credentials. **Only E1-E3 received authenticated HTTP requests in this follow-up.**

| ID | Purpose | Exact endpoint | Verification |
| --- | --- | --- | --- |
| E1 | Organization connection/identity API | `https://dev.azure.com/example-org/_apis/connectionData?connectOptions=0&api-version=7.1-preview.1` | HTTP 401; no authenticated identity established |
| E2 | Read the named project | `https://dev.azure.com/example-org/_apis/projects/SampleProject?api-version=7.1` | HTTP 401; project access not established |
| E3 | Read project-scoped candidate feed metadata | `https://feeds.dev.azure.com/example-org/SampleProject/_apis/packaging/feeds/ExampleModules?api-version=7.1` | HTTP 401; no feed metadata obtained |
| E4 | Organization-scoped metadata alternative | `https://feeds.dev.azure.com/example-org/_apis/packaging/feeds/ExampleModules?api-version=7.1` | NOT TESTED after API authentication failure |
| E5 | Project-scoped NuGet v3 candidate from G-4A2 | `https://pkgs.dev.azure.com/example-org/SampleProject/_packaging/ExampleModules/nuget/v3/index.json` | NOT TESTED in FIX1; historical G-4A2 HTTP 401 |
| E6 | Organization-scoped NuGet v3 alternative | `https://pkgs.dev.azure.com/example-org/_packaging/ExampleModules/nuget/v3/index.json` | Documented format only; NOT TESTED |

The authorized browser target remains:

```text
https://dev.azure.com/example-org/SampleProject/_artifacts/feed/ExampleModules
```

### What is and is not confirmed

| Item | Finding |
| --- | --- |
| Intended organization/project/feed | User-supplied `example-org` / `SampleProject` / `ExampleModules`; requests stayed within that target |
| Server-confirmed feed identity/GUID | **BLOCKED**; no successful feed response |
| Feed scope | **BLOCKED**; neither project-scoped nor organization-scoped is confirmed |
| Authoritative NuGet v3 endpoint | **BLOCKED / unverified**; neither E5 nor E6 is promoted to authoritative |
| Official connection configuration | **NOT TESTED**; no authenticated browser connection snippet or server-returned feed URL available |

Microsoft's Get Feed API requires the project parameter for a project-scoped feed and omits it for an organization-scoped feed. Its `project` reference is the relevant scope evidence; its `url` is a REST feed URL, not automatically the NuGet service index. Microsoft's **Connect to feed -> NuGet.exe** configuration provides the package source. [D2] [D3]

E3's 401 establishes neither that the feed exists there nor that E4 is correct. Probing E4/E6 after organization authentication failed would not establish scope reliably, so no additional endpoint guesses were attempted. Once authenticated, prefer returned feed identity/scope and the official connection snippet, then verify the service index and its resource URLs before sending credentials to package resources.

## 4. PAT authentication investigation

### Mechanism and construction

Microsoft documents PAT authentication as HTTP Basic with the PAT as password; the username may be empty. The canonical input to Base64 encoding is a colon followed by the PAT. [D1]

The .NET probes created that header in process memory using ASCII encoding and supplied it explicitly on each `HttpRequestMessage`. The PAT was not an argument value, URL component or persisted file. An offline encode/decode round-trip assertion passed for both the empty-username and `token`-username forms without printing either encoded or decoded material.

Relevant executed request-construction excerpts:

```powershell
$handler = [System.Net.Http.HttpClientHandler]::new()
$handler.AllowAutoRedirect = $false
$client = [System.Net.Http.HttpClient]::new($handler)
$client.Timeout = [TimeSpan]::FromSeconds(35)
$request = [System.Net.Http.HttpRequestMessage]::new(
    [System.Net.Http.HttpMethod]::Get, $uri)
$bytes = [Text.Encoding]::ASCII.GetBytes(":" + $env:ADO_PAT)
$request.Headers.Authorization =
    [System.Net.Http.Headers.AuthenticationHeaderValue]::new(
        "Basic", [Convert]::ToBase64String($bytes))
$request.Headers.Accept.ParseAdd("application/json")
$response = $client.SendAsync($request).GetAwaiter().GetResult()
```

`$uri` was exactly E1, E2 or E3. The separate E1 control changed only the credential input to `"token:" + $env:ADO_PAT`. All request/client/handler objects were disposed through `finally` cleanup; bodies were processed only in memory. Only allowlisted status/type/error fields and challenge scheme names were emitted, never headers, raw bodies or authenticated exception messages.

### Username comparison and limits

| Test | Authentication | Result | Interpretation |
| --- | --- | --- | --- |
| B01 | E1, Basic empty username / PAT password | **FAIL**, HTTP 401 | Canonical documented construction did not establish organization authentication |
| B01-control | E1, Basic username `token` / same PAT password | **FAIL**, HTTP 401 | Changing the Basic username did not repair API access |
| Encoding check | In-memory round-trip for both constructions | **PASS** | Encoding was internally consistent; does not prove credential validity or access |

Both E1 responses were JSON with `AccessCheckException`, error code 0 and a `Basic` challenge. No more specific allowlisted `TF...`, `VS...` or `AADSTS...` identifier was found in the canonical E1/E2/E3 JSON message fields. No 403 response was observed.

The `token` control is one bounded comparison against the original convention, not identity guessing. No Bearer-PAT substitution, alternate account, alternate credential, token trimming or permission escalation was attempted. Printable ASCII/no-edge-whitespace checks rule out those simple input-shape issues only; they do not prove that this process inherited the intended, current token.

## 5. Azure DevOps REST API results

These are **fresh executable observations**, independent of PSResourceGet. Each desired postcondition was a successful authenticated read. Authentication used the in-memory Basic header described above.

| ID / purpose | Endpoint | HTTP status / safe error | Result | Observation and remaining uncertainty |
| --- | --- | --- | --- | --- |
| B01: establish organization authentication | E1 | 401 / `AccessCheckException`, `errorCode: 0` | **FAIL** | No authenticated identity. Cannot distinguish token lifecycle, intended-value mismatch, organization eligibility or policy rejection |
| B01-control: compare original username | E1 | 401 / `AccessCheckException`, `errorCode: 0` | **FAIL** | No improvement with `token`; not a feed test |
| B02: access SampleProject | E2 | 401 / `AccessCheckException`, `errorCode: 0` | **FAIL** | No project metadata. Does not establish accepted identity followed by a project-only denial |
| A01: access named feed metadata | E3 | 401 / `AccessCheckException`, `errorCode: 0` | **FAIL** | No feed metadata. Does not establish accepted identity/project followed by a feed-only denial |
| A02: confirm scope/identity | E3/E4 metadata | No successful metadata response; E4 not requested | **BLOCKED** | Cannot choose project versus organization scope |

Python's initial E1/E2/E3 attempts each had **no HTTP status** because certificate validation failed. They are transport-blocked attempts, not additional Azure 401s. The authoritative HTTP observations above came from .NET with normal certificate validation.

After the independent API failure and single username control, package-authentication attempts stopped. The project/feed metadata requests supplied the bounded access-layer evidence; no broad project/feed listing or unrelated organization was probed.

## 6. NuGet v3 endpoint results

| Purpose | Endpoint/authentication | Execution and result | Interpretation |
| --- | --- | --- | --- |
| Retrieve authoritative service index | Not yet established | **BLOCKED** | No successful scope/connection metadata prerequisite |
| Retest original candidate | E5, direct PAT Basic | **NOT TESTED** in FIX1 | Historical G-4A2 returned 401; no repeat after API failure |
| Test organization alternative | E6, direct PAT Basic | **NOT TESTED** | Documented alternative is not a verified endpoint |
| Inspect downstream registration/content/search resources | Unknown until authenticated index | **NOT TESTED** | No redirects/resource URLs followed or credential forwarding attempted |

An API authentication failure does not establish that Azure DevOps APIs and NuGet endpoints have identical authorization conventions. Here, there is no accepted-API control with which to isolate that difference. It would be incorrect to describe this as "REST succeeds but NuGet fails" or "changing feed scope fixes authentication."

## 7. PSResourceGet authentication results

### Fresh local provider observations

Executed with `pwsh -NoLogo -NoProfile -NonInteractive`:

```powershell
Import-Module Microsoft.PowerShell.PSResourceGet -RequiredVersion 1.2.0
$m = Get-Module Microsoft.PowerShell.PSResourceGet
if ($m.Version.ToString() -ne "1.2.0") { throw "Provider version mismatch" }
Get-Command Find-PSResource
Get-PSResourceRepository
```

The version assertion passed; `Find-PSResource` exposes `Credential`. Command metadata inspected with `Get-Command Register-PSResourceRepository -ArgumentList @(<inspection-name>, <E5>)` confirmed the dynamic `CredentialProvider` parameter, whose underlying enum values are `None` and `AzArtifacts`. This does **not** invoke registration or contact E5. A static parameter lookup initially omitted that dynamic parameter; a subsequent enum-inspection attempt needed nullable-type unwrapping. Corrected metadata inspection passed. Neither harness correction was a provider-authentication failure.

### Comparison with pinned 1.2.0 source

Source evidence is pinned to release revision **`9289da13a78a05b08c53756194816cf79d4584c6`**, the G-4A1/G-4A2 1.2.0 baseline, not a newer branch. It is static evidence, not fresh private-feed execution.

| Mechanism / behavior | Pinned finding | Executable qualification status |
| --- | --- | --- |
| Direct `PSCredential` | Explicit credentials flow through `FindHelper` and take precedence over vault/provider lookup in `Utils` | Available parameter verified locally; new live feed access **BLOCKED** [P1] [P3] |
| Credential username `token` | `V3ServerAPICalls` explicitly emits preemptive Basic from empty username + PAT password, not `token:password` | Matches FIX1 canonical direct HTTP construction; historical provider result remains `UnauthorizedRequest` [P2] |
| Other credential username | Uses `HttpClientHandler.Credentials` rather than that special-case preemptive header | Different challenge behavior is possible; no live package comparison after API failure [P2] |
| `-CredentialProvider None` | Supported dynamic option; skips provider selection when registering without `CredentialInfo` | Metadata verified; new registration **NOT TESTED**, unnecessary while blocked [P4] [P5] |
| Unspecified Azure provider option | Recognized Azure URLs default to `AzArtifacts` in repository settings | G-4A2 explicitly used None, so default selection does not explain that historical probe [P5] |
| Existing Azure credential provider | 1.2.0 discovers configured/default locations and invokes noninteractively, including via `dotnet` for DLLs | Default inventory empty; integration **NOT TESTED**; no installation authorized [P6] |
| Redirects | V3 constructs a standard HTTP handler without overriding `AllowAutoRedirect` | Source behavior differs from the direct no-redirect probes; no redirect occurred in the direct HTTP results, and provider redirects were **NOT TESTED** [P2] |
| Authorization versus absent package | Separate unauthorized and missing-resource paths; a particular Azure upstream-cache 401 message is specially treated as missing resource | Source distinction only; live valid-auth/missing-package control **NOT TESTED** [P2] |

The Azure private-PowerShell tutorial still says the Azure credential provider is unsupported. That general page conflicts with the pinned 1.2.0 implementation and G-4A1 release evidence. It is not used to negate 1.2.0's implemented integration or to justify installing a vault/provider. [D4] [P6]

**No fresh `Find-PSResource` private-feed request was made.** G-4A2's original `UnauthorizedRequest,Microsoft.PowerShell.PSResourceGet.Cmdlets.FindPSResource` is historical evidence. The comparison here combines that recorded failure, fresh independent API failures and the pinned credential mechanism; it does not claim a new side-by-side authenticated service-index/provider test.

## 8. Safe package discovery, download and installation results

No package name was assumed. In particular, the earlier probe did not establish that `NovaModuleTools` exists in this feed.

| Operation / expected postcondition | Result | Reason and limit |
| --- | --- | --- |
| Discover actual private-feed inventory | **BLOCKED** | No authenticated metadata/index; no package inventory available |
| Query versions of a discovered package | **BLOCKED** | No verified package candidate |
| Query stable/prerelease metadata | **BLOCKED** | No verified package candidate; presence of prereleases unknown |
| Verify live explicit-repository selection | **BLOCKED** | No authenticated provider operation; historical local-feed results are not private-feed evidence |
| Distinguish authorization failure from absent package with a valid-auth control | **BLOCKED** | No accepted credential/feed control; source distinction alone is insufficient |
| `Save-PSResource` to isolated directory | **NOT TESTED** | Authentication and package-selection prerequisites blocked; no package downloaded |
| Inspect downloaded identity/metadata without executing package code | **NOT TESTED** | No archive |
| Isolated CurrentUser installation | **NOT TESTED** | No authenticated, inspected, dependency-free candidate; safe installation prerequisites not established |
| Private dependency resolution | **NOT TESTED** | No authenticated package operation |

For the eventual rerun, discover inventory through the authenticated official feed API or service-index search resource before selecting a real package. Pinned 1.2.0 V3 source does not support arbitrary Azure-feed `Find-PSResource -Name '*'` enumeration; that unsupported search would not be an authentication diagnosis. Then use an exact discovered name/version and an explicit unique repository. Saving is not installing, and metadata success cannot qualify installation. [P2]

## 9. Root-cause analysis of the original HTTP 401

| Candidate explanation | Evidence and conclusion |
| --- | --- |
| Wrong NuGet endpoint or feed scope | **Unresolved.** E5 was constructed from a documented project format, not server-confirmed. API authentication failure prevents obtaining authoritative scope. Endpoint correctness must still be verified |
| Incorrect Basic encoding | **Not supported by the new evidence.** The documented empty-username/PAT form was explicitly constructed, its encoding round-trip checked, and Azure returned 401 even at the organization API |
| Username `token` is incompatible | **Not established.** Both username forms failed at E1. More importantly, 1.2.0 maps credential username `token` to the canonical empty-username form; G-4A2 already tested equivalent direct HTTP |
| PAT accepted for Azure DevOps but denied only Packaging/feed access | **Not demonstrated.** No organization/project API acceptance was observed, so a feed-specific effective-permission boundary cannot be claimed |
| Wrong or unavailable environment credential / token lifecycle / organization eligibility or policy | **Plausible unresolved family.** A present, well-shaped secret is not proof it is the intended current token or accepted for this organization. The response provides no precise lifecycle/policy reason |
| PSResourceGet omits the direct credential | **Not supported as the sole cause.** Direct HTTP fails independently and pinned source sends the expected header for `token`. Actual provider wire behavior was not traced |
| Unexpected credential-provider configuration | **Not supported for G-4A2's explicit None/direct-credential probe.** No default plugin binary found in the current limited inventory; no new provider selected |
| Redirect/proxy interference | **No positive evidence in fresh direct HTTP.** Requests did not follow redirects; status was 401, not 3xx/407; organization default proxy bypass was true. Transparent intermediaries and historical/provider traffic were not traced |
| Nonexistent test package | **Not an explanation for the new organization/project API 401s.** No package is named there; historical package existence remains unknown |

**Most precise supported diagnosis:** an organization/API authentication or organization-access rejection is reproducible outside PSResourceGet with the inherited PAT and documented Basic construction. This is a sufficient blocker before private package qualification, but not proof of an expired PAT, missing Packaging scope, incorrect feed scope or provider incompatibility. FIX1 did not change the token or demonstrate that the same token value was present during G-4A2; it explains the failure class, not a proven historical server-side event.

## 10. Security and isolation verification

| Safeguard | Result / evidence |
| --- | --- |
| Credential destination | **PASS:** authenticated requests only to E1/E2 on `dev.azure.com/example-org` and E3 on its official `feeds.dev.azure.com/example-org` endpoint |
| Redirect/TLS safeguards | **PASS:** redirects disabled in authenticated direct clients; normal platform TLS validation retained; no credential sent to a redirect target |
| Credential output/persistence | **PASS within audited scope:** no token/header output, traces, transcripts, HTTP debug logs, URLs, saved credential object or credential-store write; literal/encoded-form audit described below |
| Repository mutation | **PASS:** none. No Register/Set/Reset/Unregister call executed; the inspection-only name was never registered |
| Existing repository inventory | **PASS:** `LocalNexus` (V3, priority 50, trusted) and `PSGallery` (V2, priority 50, untrusted), both provider None and no CredentialInfo; no HTTP call to either repository |
| Repository-store integrity | **PASS:** original macOS application-data XML preserved byte-for-byte; SHA-256 `b12778318cd9b1e85f398be2741bf9d3a142e039312c546be8e388297adb5f1c` before and after |
| Existing installed modules | **PASS within inventoried roots:** user Modules tree content digest unchanged (881 files); the inspected Documents/PowerShell and AllUsers roots remained absent; no save/install/update/uninstall command executed |
| Cleanup | **PASS:** HTTP objects disposed; child processes exited; no test registration, module installation, downloaded archive, temporary script or disposable package directory to remove |
| Remote mutation | **PASS:** GET only; no feed/package/permission/token/policy changes, publication or deletion |

The real repository store is under macOS `LocalApplicationData/PSResourceGet/PSResourceRepository.xml`, outside a hypothetical disposable HOME/XDG override. The existing store was hashed before reading it. No registration was attempted because the prerequisite failed, avoiding unnecessary real-user-store writes. No backup containing credential material was created, and no whole-file restoration could overwrite concurrent user changes.

An in-memory literal/Basic-encoded-form audit covered the two documentation deliverables, the repository XML and this session's existing `files/` artifacts. It found no credential material. This is a scoped check, not a universal forensic claim about OS memory, server logging or unrelated files. The parent environment and native credential store were not changed.

Repository changes are only this report and the appended G-4A2 follow-up. The original G-4A2 content remains an unchanged prefix. ARCHITECTURE, PLAN, DECISIONS, G-4A0/G-4A1, Gerber production code and NovaModuleTools were not modified. No commit, push, tag or publication occurred.

## 11. Remaining blockers

1. **External organization authentication:** the supplied environment credential receives 401 even before a package endpoint is involved. Its actual lifecycle/intended-value/organization-access/policy state cannot be determined from `AccessCheckException`, error code 0.
2. **Authoritative feed configuration:** feed identity, scope and connection URL cannot be retrieved until authentication succeeds or the owner supplies the non-secret Connect-to-feed configuration.
3. **Private provider qualification:** successful service index, real package metadata, download, isolated installation and valid-auth/missing-package controls remain unexecuted. No positive private-feed support claim is justified.

PowerShell 7.4, Windows/Linux and the other G-4A2 limitations are unchanged, not silently resolved by this follow-up. The missing indexed `.github/instructions/documentation.instructions.md` remains a guidance limitation; available shared documentation-separation instructions and the project Markdown skill were used.

## 12. Recommended next action

**Minimum external action:** the credential owner should privately verify that the value supplied as `ADO_PAT` to this process is the intended current credential for `example-org`, and establish a successful read of E1/E2 with documented Basic authentication. If it still fails, the organization owner should inspect the credential owner's organization eligibility, token status and applicable policy/server-side diagnostics. Do not paste the token into a discussion, log or document. A full-access expectation is not a reason to increase scopes blindly or weaken policy.

This is a verification request, not a recommendation to regenerate the token or grant feed permissions without evidence. If lifecycle/organization policy proves to be the cause, remediation belongs to the owner under separate authorization. The agent did not enumerate or mutate PATs; Microsoft's PAT-lifecycle APIs require a different delegated authentication context. [D1]

After organization authentication succeeds, separately:

1. Read the named feed metadata in the correct scope, confirm its identity/project reference and obtain the official non-secret **Connect to feed** NuGet v3 source. Verify that index and all intended resource destinations.
2. Repeat the 1.2.0 direct-credential qualification using a uniquely named temporary registration with explicit `-CredentialProvider None`, no CredentialInfo, preserved repository hashes and owned-name-only `finally` cleanup.
3. Discover real inventory; qualify exact stable/prerelease metadata, source selection, a missing-package control and isolated `Save-PSResource`. Test CurrentUser installation only after inspecting a suitable dependency-free package and proving destination isolation. Do not import its package code.

Do not introduce custom Azure authentication into PMU. G-4A3 remains on hold for Azure authentication qualification; any separately authorized public-only implementation would be a different scope decision, not a passed FIX1 authentication gate.

### Deliverable checks

| Check | Classification / evidence |
| --- | --- |
| Exact provider/version and Basic construction | **PASS:** local version assertion, dynamic parameter metadata and offline encoding assertions executed |
| Authenticated organization/project/feed reads | **FAIL:** the four .NET HTTP responses above were 401 |
| Feed scope/endpoint and private-provider operations | **BLOCKED** as detailed above; unexecuted individual operations explicitly marked NOT TESTED |
| Documentation links, Markdown, historical prefix, write scope and file endings | **PASS:** checked locally; repository formatting wrapper run for `docs/architecture` |
| ScriptAnalyzer/build/Pester/PTY/CodeScene code scoring | **NOT TESTED; not applicable to the documentation-only repository change.** No production/test/helper code or build-executed example changed; no code-quality success is claimed |
| README/CONTRIBUTING/CHANGELOG/RELEASE_NOTE review | **PASS:** reviewed; unchanged because no supported command, configuration, user workflow or release behavior changed |

Documentation commands executed successfully:

```text
git --no-pager diff --check
pwsh -NoLogo -NoProfile -File ./scripts/build/Test-TextFileFormatting.ps1 -ProjectRoot ./docs/architecture
```

Additional in-memory assertions passed for relative-link targets, balanced fences, exactly one trailing newline, the unchanged original G-4A2 prefix, repository XML/module-tree integrity, credential-free artifacts and the two-file repository write scope.

### Sources and evidence types

**Official documentation**, consulted 2026-10-22; describes mechanisms, not successful execution against this feed:

- **D1:** [Microsoft PAT authentication and lifecycle guidance](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops): Basic construction, token status and organization-policy considerations.
- **D2:** [Get Feed REST API 7.1](https://learn.microsoft.com/en-us/rest/api/azure/devops/artifacts/feed-management/get-feed?view=azure-devops-rest-7.1) and [Get Project REST API 7.1](https://learn.microsoft.com/en-us/rest/api/azure/devops/core/projects/get?view=azure-devops-rest-7.1): targeted read APIs and scope metadata.
- **D3:** [Azure Artifacts NuGet connection configuration](https://learn.microsoft.com/en-us/azure/devops/artifacts/nuget/nuget-exe?view=azure-devops): official connection snippet and project/organization URL formats.
- **D4:** [Private PowerShell repository tutorial](https://learn.microsoft.com/en-us/azure/devops/artifacts/tutorials/private-powershell-library?view=azure-devops): connection-source guidance; its credential-provider warning is not treated as authoritative for pinned 1.2.0 implementation behavior.

**Pinned source**, revision `9289da13a78a05b08c53756194816cf79d4584c6`; static implementation findings, not live compatibility proof:

- **P1:** [FindHelper.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/FindHelper.cs): explicit repository resolution and credential flow.
- **P2:** [V3ServerAPICalls.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/V3ServerAPICalls.cs): constructor's token special case, generic Azure V3 search limits, unauthorized/missing-package mapping and standard HTTP handler.
- **P3:** [Utils.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/Utils.cs) and [PSRepositoryInfo.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/PSRepositoryInfo.cs): credential precedence and selection.
- **P4:** [RegisterPSResourceRepository.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/RegisterPSResourceRepository.cs): dynamic CredentialProvider option and registration boundaries.
- **P5:** [RepositorySettings.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/RepositorySettings.cs): actual macOS special-folder store, optional credential persistence and Azure default selection.
- **P6:** [CredentialProvider.cs](https://github.com/PowerShell/PSResourceGet/blob/9289da13a78a05b08c53756194816cf79d4584c6/src/code/CredentialProvider.cs): plugin discovery and noninteractive invocation.

**Repository/historical evidence:** [G-4A2](G-4A2-psresourceget-provider-qualification.md) retains the original HTTP/provider failures; [G-4A1](G-4A1-psmoduleupdate-design.md) and [G-4A0](G-4A0-shared-self-update-analysis.md) remain unchanged. Current Gerber [Basic-header helper](../../src/private/ado/Get-GerberAdoRequestHeader.ps1), [REST adapter](../../src/private/ado/Invoke-GerberAdoRestRequest.ps1) and [credential abstraction](../../src/private/credentials/Get-GerberCredential.ps1) were inspected, not invoked for real credential-store access or changed. Gerber's native-secret architecture is not replaced by this explicitly authorized environment-PAT investigation.

## Authentication recovery and resumed qualification

**Resumed:** 2026-10-22 (later the same day). Sections 1-12 above are the unchanged historical record of the blocked run. Results below are new executable observations from a Copilot CLI process restarted from the PowerShell environment holding the working `ADO_PAT`. No credential, header, encoded credential or credential fingerprint is recorded.

### Process-environment finding

1. G-4A2 received HTTP 401 with its inherited PAT.
2. G-4A2-FIX1 reproduced HTTP 401 independently of PSResourceGet.
3. An interactive PowerShell session authenticated successfully to the SampleProject project.
4. Comparing fingerprints of `ADO_PAT` showed the interactive session and the earlier Copilot process held **different values**.
5. Copilot CLI was restarted from the working environment.
6. The new process authenticated successfully.

The process-environment credential mismatch is established. The server-side reason the earlier value was rejected was never established; it is **not** claimed to be expired, revoked or under-scoped.

### Results

| Phase | Result | Evidence |
| --- | --- | --- |
| A. Authentication | **PASS** | `GET https://dev.azure.com/example-org/_apis/projects/SampleProject?api-version=7.1` returned HTTP 200, project `SampleProject`; empty-username Basic, platform TLS validation, redirects disabled |
| B. Feed identity (E3) | **PASS** | Project-scoped metadata returned HTTP 200: name `ExampleModules`, ID `11111111-2222-4333-8444-555555555555`, project `SampleProject` (`66666666-7777-4888-8999-aaaaaaaaaaaa`), upstreams enabled |
| B. Organization-scoped alternative (E4) | **PASS (negative)** | HTTP 404 `FeedIdNotFoundException` for the name at organization scope. Combined with the 200 above, the feed is **project-scoped** |
| C. Verified v3 endpoint (E5) | **PASS** | HTTP 200, NuGet v3 index, version 3.0.0, 11 resources (PackagePublish, LegacyGallery, Registrations, SearchQueryService, PackageBaseAddress and Azure vendor resources). All resource URLs are on `pkgs.dev.azure.com` and embed the confirmed project and feed GUIDs; `VssFeedId` matches |
| C. Organization-scoped v3 (E6) | **FAIL (expected)** | HTTP 404; not the correct endpoint for this feed |
| D. PSResourceGet 1.2.0 | **PASS** | Explicit `-RequiredVersion 1.2.0` import, asserted loaded 1.2.0. Temporary uniquely named repository registered with `-ApiVersion V3 -CredentialProvider None`; in-memory credential only |
| E. Inventory | **PASS** | Feed packages REST API: 12 packages. 11 NuGet (`BizTalkVerification`, `DatabaseFunctions`, `HashUtil`, `LogUtil`, `ps.mgmt.APMessageMetrics`, `ps.mgmt.messageextract`, `ps.mgmt.platform`, `SQLVerification`, `TaskUtil`, `TestUtil`, `VerificationUtil`) plus one Universal Package (`modules`). **`NovaModuleTools` is not in the feed** |
| E. Exact discovery / versions | **PASS** | `Find-PSResource -Name HashUtil` returned 1.4.79; `-Version '*'` returned 10 versions 1.4.68-1.4.79 matching the REST inventory; exact `1.4.75` selected correctly; repository reported as the temporary registration |
| E. Prerelease metadata | **NOT TESTED (no data)** | `-Prerelease` query succeeded but the feed lists no prerelease versions, so prerelease semantics were not exercised |
| E. Missing vs. unauthorized | **PASS** | Missing `NovaModuleTools` with valid credential: `PackageNotFound`. Invalid credential and no credential: `UnauthorizedRequest` (401, "Re-run the command with -Credential"). The two failure classes are distinguishable |
| F. `Save-PSResource` | **PASS** | `HashUtil` 1.4.75 from the explicit repository with in-memory credential into an isolated temporary directory; `HashUtil.psd1`, `.psm1` and help file saved. Nothing imported or executed |
| F. Package verification | **PASS (integrity only)** | Manifest `ModuleVersion` 1.4.75, GUID `3f8e91c2-126b-4f32-9c13-7755ebfff635`, no `RequiredModules`. The `.nupkg` (4035 bytes, 7 entries) was fetched via the flat container; its credentialed request returned a 303 to an Azure blob host, which was checked against an allow-list and fetched **without** the Authorization header. All entries readable; nuspec id/version `HashUtil`/1.4.75, 0 dependencies; archive manifest GUID matches the saved one. This is not publisher/signature verification |
| G. Isolated installation | **NOT TESTED** | See below |

### Observations worth keeping

- `Find-PSResource` reported `Dependencies.Count` 0 and an empty `Guid` for `HashUtil`; the real GUID is only visible in the manifest. Do not rely on v3 search metadata for GUID identity.
- The feed's nuspec author differs from the manifest author; identity checks should use name, version and GUID from the manifest, not author text.
- Anonymous and invalid-credential reads both return 401, so the feed is not publicly readable.

### Installation (Phase G)

Not attempted. `Install-PSResource` 1.2.0 has no general `-Path`, `-TemporaryPath` is staging only and `PSModulePath` does not set the destination. No mechanism was demonstrated that guarantees a disposable CurrentUser destination, and the real CurrentUser module root (`~/.local/share/powershell/Modules`) contains installed modules. Install behavior against the private feed is therefore **NOT TESTED**. `HashUtil` is a suitable dependency-free candidate for a future isolated environment (for example a throwaway user account or container).

### Preservation

PSResourceGet's repository store hash was identical before and after; only the temporary registration was added and removed in `finally`. `LocalNexus` and `PSGallery` were unchanged, and the CurrentUser module directory listing was unchanged. Temporary download directories were deleted. No feed, permission or package was modified.

### Reassessment of the original HTTP 401

The original blocker is **resolved** for this environment: the failure was the inherited process credential, and with the working credential authentication, feed metadata, v3 index, PSResourceGet discovery and save all succeed. The historical 401 results above remain valid for the credential that produced them. PSResourceGet worked once authentication worked, so there was no provider-specific defect and no custom Azure authentication is needed in PMU.

### Updated qualification status

| Capability | Status |
| --- | --- |
| Azure DevOps authentication | **PASS** |
| Feed scope / NuGet v3 endpoint | **PASS** (project-scoped, E5) |
| PSResourceGet 1.2.0 authenticated discovery, versions, exact version | **PASS** |
| Missing-versus-unauthorized behavior | **PASS** |
| Save and archive integrity | **PASS** |
| Prerelease metadata | **NOT TESTED** (no prerelease versions in feed) |
| Isolated install, dependencies, upgrade/collision behavior | **NOT TESTED** |
| PowerShell 7.4, Windows, Linux | **NOT TESTED** |
| A real update target (`NovaModuleTools`/Gerber) in this feed | **NOT TESTED** (not present) |

### Recommendation for G-4A3

G-4A3 **may proceed** on the private-feed authentication and discovery contract: project-scoped endpoint E5, `-ApiVersion V3 -CredentialProvider None`, in-memory credential from the environment, exact name/version queries and save. Explicit limitations: installation, prerelease handling, dependency handling and non-macOS/PowerShell 7.4 platforms are unqualified; the target package is absent from the feed; and each consuming process must receive the correct `ADO_PAT` in its own environment. G-4A3 was not started.

## Follow-up: G-4A2-FIX2

Installation scope and prerelease replacement are covered in `G-4A2-FIX2-installation-scope-and-prerelease-replacement.md`. This report is otherwise unchanged.
