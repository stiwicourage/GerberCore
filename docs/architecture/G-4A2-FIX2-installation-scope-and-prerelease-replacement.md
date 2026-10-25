# G-4A2-FIX2 — Installation scope and prerelease replacement qualification

Date: investigation run on macOS, PowerShell 7.6.6, `Microsoft.PowerShell.PSResourceGet` **1.2.0** (imported with `-RequiredVersion 1.2.0` and asserted in every test).

Status legend: **PASS**, **FAIL**, **BLOCKED**, **NOT TESTED**. *Executed* means run in this investigation. *Source analysis* means read from the PSResourceGet v1.2.0 source (`InstallHelper.cs`, `Utils.cs`) and is not executable qualification.

## 1. Executive summary

| Question | Result |
| --- | --- |
| CurrentUser installation | **PASS** on macOS / PowerShell 7.6 for the replacement behaviours below. Windows, Linux and PowerShell 7.4 are **NOT TESTED**. |
| AllUsers installation | **NOT TESTED** (real install). The permission-denied path was executed as a non-root user and failed cleanly without modification. A successful AllUsers install could not be isolated. |
| Same-base prerelease replacement (preview.1 → preview.2 → preview.3 → stable) | Plain `Install-PSResource` and `Update-PSResource` **silently do nothing**. `Install-PSResource -Reinstall` works, but is not crash-safe and does not check the GUID. |
| Recommended strategy | **Strategy C**: staged, locked, verified replacement that uses PSResourceGet (`Save-PSResource` and `Install-PSResource -Reinstall`) for acquisition and installation, plus a PMU-owned backup and restore. |
| Recovery | Pre-mutation abort, verification-failure rollback and exception rollback are demonstrated. A hard kill (SIGKILL, power loss) mid-replacement can leave a broken module. This is shown empirically, and PMU must detect it and repair it on the next run. No atomicity is claimed. |
| G-4A3 readiness | **Conditionally ready**, once the G-4A1 revisions in section 12 are approved. AllUsers success, Windows, Linux and PowerShell 7.4 stay as explicit gaps. |

The two mandatory requirements (both scopes, same-base prerelease progression) can both be met. No blanket rejection of same-base updates is needed.

## 2. Existing architectural requirements and conflicts

Sources read: `DECISIONS.md`, `PLAN.md`, G-4A1 (API, lifecycle, open decisions), G-4A2, G-4A2-FIX1; G-4A0 and `ARCHITECTURE.md` were searched, not read cover to cover. No existing Gerber update code exists to conflict with.

Conflicts with the new mandatory requirements (historical decisions are not edited here):

| G-4A1 / G-4A2 statement | Conflict |
| --- | --- |
| `Policy.Scope` is CurrentUser only; AllUsers, mixed and custom layouts are blocked (G-4A1 ~154, 521, 550, 600) | Both scopes are mandatory. |
| Same-numeric-base collisions are rejected; no `-Reinstall` / `Force` (G-4A1 ~212, 604; G-4A2 section 13) | Preview progression is a normal release flow. |
| "No automatic rollback" (G-4A1 ~604) | Recoverable replacement is feasible and recommended. |
| The Install lifecycle lock is a small coordination lock | It must be scope- and module-specific, with revalidation. |
| G-4A1 section 17 lists scope/provenance and recovery/preview policy as open | These are now resolved by this report (proposed, pending approval). |

## 3. CurrentUser qualification

Every scenario ran in a child `pwsh` with a disposable `HOME`. PSResourceGet's repository store lives in the real user's ApplicationData on macOS and is **not** isolated by `HOME`, so only uniquely named `g4a2fix2-*` repositories pointing at local file feeds were registered, and they were removed in `finally`. The store and the real module root were verified unchanged afterwards (section 13).

- CurrentUser root with the `HOME` override: `$HOME/.local/share/powershell/Modules`. The install destination follows `HOME`, but `PSModulePath` does not decide it.
- Stable → newer stable, stable → higher-base prerelease and exact repeat: **PASS** (higher base creates a separate directory and older stable versions coexist; a repeat plain install is a no-op with a warning).
- Same-base replacement: see sections 5 to 7.
- A module loaded in the session keeps running the old code after replacement (section 7, T10). A new session is required.

## 4. AllUsers qualification

| Item | Evidence | Result |
| --- | --- | --- |
| Destination (Unix) | Hardcoded `/usr/local/share/powershell/Modules`; `PSModulePath` and `HOME` do not redirect it (source analysis plus G-4A2 `-WhatIf`) | Source analysis |
| Path state on this host | `/usr/local/share/powershell` is `root:wheel 755`, contains only `Scripts`; no `Modules` directory; current uid 501 | Executed observation |
| Non-root `Install-PSResource -Scope AllUsers` | Failed with `InstallPackageFailed`: "Access to the path '/usr/local/share/powershell/Modules' is denied." No entries created (entry count unchanged, no module copy, nothing installed into CurrentUser) | **PASS** (failure detected, no side effects) |
| Successful AllUsers install and replacement | Cannot be isolated; elevation is forbidden | **NOT TESTED** |
| Windows AllUsers | Program Files path, requires elevation | **NOT TESTED** |

Conclusions:

- Insufficient permission is detectable. PMU should map `InstallPackageFailed` with an access-denied message (and a pre-check that the destination or its nearest existing parent is writable) to a stable `PMU.PermissionDenied` error. It must never fall back to CurrentUser.
- PMU must not self-elevate. It reports that elevation is required and what command to run elevated.
- Replacement behaviour is provider code shared by both scopes (source analysis), so the staged algorithm applies equally, but it is **not executed** against AllUsers.

### Scope precedence and cross-scope behaviour

Two `PSModulePath` roots simulate CurrentUser and AllUsers. This is a **simulation** (fixtures copied by hand), not a real AllUsers installation.

| Roots (in PSModulePath order) | `Import-Module` result |
| --- | --- |
| CU root first (preview.1), AU root second (stable) | 2.0.0-preview.1 (CU) |
| AU root first, CU root second | 2.0.0 (AU) |

- Resolution follows `PSModulePath` order, not version. A higher stable version in a later root can be shadowed by an earlier-root prerelease. PMU must therefore resolve the target by scope root explicitly, report `ActiveVersion` (what the session would load) separately from `InstalledVersion` (what is in the requested scope), and never touch the other scope.
- `Get-InstalledPSResource -Path <root>` found nothing for hand-copied fixtures because they lack `PSGetModuleInfo.xml`. This is a fixture limitation, not a provider finding.

## 5. Prerelease collision analysis

PSResourceGet installs under `<root>/<Name>/<NumericVersion>/` and stores the prerelease label only in the manifest. `2.0.0-preview.1`, `-preview.2`, `-preview.3` and `2.0.0` all share `<Name>/2.0.0/`.

Executed behaviour (macOS):

| Operation (same numeric base) | Observed |
| --- | --- |
| Plain `Install-PSResource` preview.2 over preview.1 | Exit "ok" with only a warning "already installed"; **nothing changes** (silent no-op). Warning text names the target version, which is misleading. |
| Plain install of stable 2.0.0 over preview.3 | Same silent no-op. |
| `Update-PSResource` (with `-Prerelease -Version`, a range, or `-Force`) | Never updates within the same base; silent no-op. Without `-Version` it picks the higher-base 2.1.0-preview.1. |
| `Install-PSResource -Reinstall` | Replaces the directory (inode changes: delete and recreate). Works for preview→preview, preview→stable and repeat. |
| `Uninstall-PSResource -Version <full version>` | Removes the whole numeric directory; matches the full version (uninstalling preview.2 while preview.1 is installed is a warning with exit "ok"). |

Consequence: PMU must never trust a "success" exit from the provider. It must read the installed manifest and compare it with the target.

## 6. Comparison of replacement strategies

| Strategy | Pre-mutation validation | GUID check | Rollback | Hard-kill safety | Verdict |
| --- | --- | --- | --- | --- | --- |
| A. `-Reinstall` only | Provider downloads and extracts to temp first; bad packages fail before modification (executed) | **None**: it silently swapped the GUID bbbb→aaaa | Provider restores only if the delete fails (executed; source analysis) | **None** (section 8) | Insufficient alone |
| B. Uninstall then install | Possible if target is saved first | Possible | None; if install fails the module is gone | None | Rejected: uninstalled window |
| C. Staged replacement | `Save-PSResource` to a staging directory, validate manifest name, numeric version, prerelease and GUID before touching anything | Yes | Backup copy outside the Modules tree; restore on any failure or verification mismatch | Detectable and repairable from the backup, not atomic | **Recommended** |
| D. Alternative provider mechanism | n/a | n/a | n/a | n/a | None exists for same-base replacement in 1.2.0 (`Update-PSResource` no-ops) |

### Provider mechanism (source analysis)

- In `MoveFilesIntoInstallPath`, if the final directory exists, the provider copies it to a temp directory, deletes it and restores it only if the delete fails. The temp copy is deleted in `finally`.
- `MoveDirectory` then **copies** temp to destination and deletes the source. It is not a rename and not atomic. A failure during the copy-in has no provider recovery.
- The "already installed" check is bypassed only by `-Reinstall`.

## 7. Executed test matrix

Fixtures: disposable local file feeds. `G4A2F2.Mod` 1.0.0, 1.1.0, 2.0.0-preview.1/2/3, 2.0.0, 2.1.0-preview.1 with GUID `aaaaaaaa-…`; a second feed with the same name and different GUID `bbbbbbbb-…`; deliberately broken packages; a large package (~1500 files, ~12 MB, 3.0.0-preview.1/2). No credentials were used (`ADO_PAT` blanked in children).

| # | Scenario | Result |
| --- | --- | --- |
| T1 | Stable → newer stable | **PASS** |
| T2 | Stable → prerelease with higher base | **PASS** (separate directory) |
| T3 | Same-base prerelease → newer prerelease, plain install | **FAIL** (silent no-op) |
| T4 | Same-base prerelease → prerelease → stable with `-Reinstall` | **PASS** (verified from the manifest after each step) |
| T5 | Repeat exact version, plain | No-op with warning (**PASS** as idempotent); `-Reinstall` re-creates the directory |
| T6 | Existing install with an unexpected GUID | Plain install: silent no-op. `-Reinstall`: silently swaps the GUID (**FAIL** for Strategy A; caught before mutation by Strategy C) |
| T7 | Missing target, truncated nupkg, corrupt manifest, manifest-less package | `InstallPackageFailure` / `GetMetadataFromNupkgFailure`; installed copy intact in every case (**PASS**) |
| T8 | Delete failure (read-only parent, mode 555) | `InstallPackageFailed`, "previous package contents have been restored", same inode (**PASS**) |
| T9 | Unreadable file in the old version directory | `-Reinstall` failed in the backup copy before deletion; old install intact (**PASS**) |
| T10 | Module loaded during replacement | Replacement succeeded on disk (preview.2); the loaded session still reported preview.1 (`ActiveVersion` ≠ `InstalledVersion`); a fresh import after `Remove-Module` loaded preview.2. Restart or re-import required (**PASS**) |
| T11 | Existing install in another scope | Simulated with two roots only (section 4); real cross-scope **NOT TESTED** |
| T12 | Strategy C prototype: C1 p1→p2, C2 p2→p3, C3 p3→stable, C4 stable repeat | **PASS** (each verified from the manifest) |
| T13 | Strategy C: wrong-GUID target (C5) | **PASS**: aborted before mutation, state unchanged |
| T14 | Strategy C: injected crash after install (C6) | **PASS**: old tree restored (verified) |
| T15 | Strategy C: missing target (C7) | **PASS**: aborted before mutation |
| T16 | Strategy C: fresh install with injected fault (C8) | **PASS**: new install cleaned, nothing left |
| T17 | Hard kill mid-`-Reinstall` | **FAIL**, see section 8 |
| T18 | Lock contention and stale lock | **PASS**, see section 9 |
| T19 | Two concurrent real replacements | **NOT TESTED** by direct execution (G-4A2 showed simultaneous installs interfering); only lock serialization was executed |
| T20 | Non-root AllUsers | **PASS** (clean failure) |
| T21 | Real AllUsers success | **NOT TESTED** |

The prototype's tree comparison excludes `PSGetModuleInfo.xml`, which the provider writes only at install time. Other provider-removed metadata files did not cause mismatches after that exclusion.

## 8. Recovery and rollback analysis

| Failure point | Evidence | Outcome |
| --- | --- | --- |
| Before the existing install is modified (bad target, download or extract failure, GUID mismatch) | Executed (T7, T13, T15) | Old install intact; error reported |
| Delete step fails | Executed (T8) | Provider restores; old install intact |
| After install, verification fails or exception | Executed (T14) | PMU backup restores the old tree |
| Hard kill during `-Reinstall` | Executed: ~10.7 s large install killed at 5 to 10.5 s, 12 runs | See below |

Hard-kill sweep (process killed with SIGKILL at the stated times):

| Kill time | Resulting state |
| --- | --- |
| 5.0 s | preview.1 intact (1503 files) |
| 6.0 s | preview.2 manifest present, **243 of 1503 files** |
| 7.0 s | **no version directory at all** (module absent) |
| 7.5 to 9.6 s, 10.2 s | preview.2 manifest present, 489 to 1360 files (**incomplete**) |
| 9.9 s, 10.5 s | complete preview.2 |

Findings:

- A killed `-Reinstall` can leave the module absent or half-copied, and a half-copy has a **valid manifest reporting the new version**. A version-only check would report success. Verification must compare the file tree (or a hash) with the staged package.
- Backup and restore only help if PMU survives. PMU must write a persistent recovery journal (module, scope, backup path, staged path, target identity) **before** the first mutation, and on the next run (under the lock) detect an unfinished journal and either restore the backup or complete the replacement.
- Guarantees that can be supported: no success reported unless the installed tree matches the staged package; automatic restore for exceptions and verification failures; detectable and repairable state after a hard kill, provided the backup survives.
- Not claimed: atomicity, protection against power loss, protection when the backup is itself lost, or protection from non-cooperating package managers.
- Manual recovery is needed when both the installed copy and the backup are damaged, or the journal is lost. PMU should then report the exact paths and the reinstall command.

## 9. Concurrency requirements

Executed with a `FileShare.None` lock file:

| Test | Result |
| --- | --- |
| Lock held by another process; acquire with 500 ms timeout | TIMEOUT after 530 ms (**PASS**) |
| Acquire after the holder releases | Acquired (**PASS**) |
| Holder killed with SIGKILL | Lock acquired immediately; the OS released it, no stale-lock cleanup needed; the lock file stays on disk (**PASS**, macOS) |

Design requirements:

- Lock identity: scope + module name + resolved module root, so CurrentUser and AllUsers (and different modules) are independent.
- Lock location: the scope's PMU data directory, kept outside the Modules tree. AllUsers needs a location writable by the elevated user.
- Use an OS-level exclusive open (`FileShare.None`), not the existence of a file, so a crashed holder never leaves a stale lock. Bounded timeout with a clear `PMU.LockTimeout` error.
- After acquiring the lock, revalidate: re-read the installed version and any recovery journal, because another process may already have performed the update.
- Only cooperating PMU processes are protected. `Install-PSResource` run by other tools is **not** covered.
- Windows lock semantics and a real two-process replacement are **NOT TESTED**.

## 10. Cross-platform considerations

| Platform | Status |
| --- | --- |
| macOS, PowerShell 7.6, PSResourceGet 1.2.0 | Executed |
| Linux | **NOT TESTED**. Source analysis suggests the same paths as macOS (`~/.local/share/powershell/Modules`, `/usr/local/share/powershell/Modules`). Needs: CurrentUser replacement chain, non-root AllUsers failure, lock behaviour, XDG handling. |
| Windows | **NOT TESTED**. AllUsers is under Program Files and requires elevation. Directory deletion fails when files are in use (an imported module), so the delete/restore path is the likeliest to differ. Mandatory: replacement while the module is loaded, long paths, antivirus interference, and lock semantics. |
| PowerShell 7.4 | **NOT TESTED**. Only 7.6.6 was available. |

None of the rows other than macOS counts as executable cross-platform qualification.

## 11. Recommended implementation strategy

Use Strategy C inside `Install-PSModuleUpdate`; keep `Get-PSModuleUpdate` read-only and unchanged.

1. Resolve the scope root explicitly; never switch scope. For AllUsers, check writability up front and return `PMU.PermissionDenied` without elevating.
2. Acquire the scope-and-module lock with a timeout; revalidate state; handle any unfinished recovery journal first.
3. `Save-PSResource` the exact target from the explicit repository into a private staging directory. Validate the manifest: name, numeric version, prerelease label, GUID (equal to the installed GUID when one exists), plus any source expectations. Abort with no mutation on failure.
4. If no installed copy shares the numeric directory, use a plain `Install-PSResource`. If one exists, take the replacement path.
5. Replacement path: write the recovery journal, copy the existing directory to a backup outside the Modules tree, run `Install-PSResource -Reinstall` (exact name, version, repository, scope).
6. Verify the installed manifest (name, numeric version, prerelease, GUID, path under the requested scope root) and compare the installed tree against the staged tree. On mismatch or exception, restore the backup and report failure.
7. On success remove the backup and journal; on failure keep the journal until the restore is confirmed.
8. Return `ActiveVersion`, `InstalledVersion`, `TargetVersion`, `RestartRequired` (true whenever the module is loaded at a different version). Do not import or hot-reload Gerber Core.

Staging copy plus tree hashing costs time and disk; the large package (12 MB, 1500 files) took about 10.7 s for an unkilled `-Reinstall` in this environment.

## 12. Required G-4A1 design revisions (proposed, not applied)

1. `Scope`: accept CurrentUser and AllUsers; no silent scope change; add `PMU.PermissionDenied` with elevation guidance; replace the "CurrentUser only / block AllUsers" policy.
2. Same-base collision: replace "reject" with the staged replacement of section 11. Do not expose raw `-Reinstall` or `-Force` to callers.
3. Replace "no automatic rollback" with best-effort recoverable replacement, recovery journal and repair on the next run; state the non-guarantees from section 8.
4. Result model: add `ActiveVersion`, `InstalledVersion`, `TargetVersion`, `RestartRequired`.
5. Lock: per scope and module, OS-level exclusive lock, timeout, revalidation after acquisition.
6. Verification: manifest identity plus tree comparison; a provider "ok" is never evidence of success.
7. Close the G-4A1 section 17 open items on scope/provenance and recovery/preview policy once approved.

`ARCHITECTURE.md`, `PLAN.md`, `DECISIONS.md` and G-4A1 were not edited.

## 13. Remaining risks and qualification gaps

- AllUsers successful install and replacement: **NOT TESTED** (needs an elevated or disposable machine).
- Windows, Linux, PowerShell 7.4: **NOT TESTED**.
- Real concurrent replacement by two processes: **NOT TESTED** (lock only).
- The Strategy C prototype was exercised only on a local file feed and a small package set; hard-kill recovery through the journal was **not** executed. Only the underlying risk was demonstrated.
- Provider behaviour may change in other PSResourceGet versions; the algorithm depends on 1.2.0 behaviour (silent no-op, `-Reinstall` semantics, `PSGetModuleInfo.xml`).
- Source analysis (delete-and-restore, copy-based move) was read from the v1.2.0 tags and not exercised line by line.
- Preservation: after the tests the PSResourceGet repository list was `LocalNexus, PSGallery` (no `g4a2fix2-*` left; one repository left by a killed test process was removed explicitly); the real CurrentUser module root contains no `G4A2F2*` entries; `/usr/local/share/powershell` still contains only `Scripts`. Existing registrations and modules were not modified.

## 14. G-4A3 implementation readiness

**Conditionally ready.** G-4A3 can start once the revisions in section 12 are approved, with these limits stated up front:

- CurrentUser replacement on macOS is qualified; AllUsers is implemented against a documented design but remains unqualified for success until tested elevated or in a disposable host.
- The implementation must include tests for the recovery journal and hard-kill repair, a real two-process concurrency test and the platform matrix in section 10 before any claim of full cross-platform support.
- No claim of atomic or guaranteed rollback may be made in documentation or help.
