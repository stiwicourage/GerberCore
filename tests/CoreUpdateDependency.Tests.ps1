# Cross-cutting dependency contract: project metadata and the native CI entrypoint must agree.
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    $script:project = Get-Content -LiteralPath "$root/project.json" -Raw | ConvertFrom-Json
    $script:nativeCi = Get-Content -LiteralPath "$root/scripts/build/ci/Invoke-NativeCredentialPlatformCI.ps1" -Raw
}

Describe 'Core update dependency minimum' -Tag 'GerberPmu011' {
    It 'requires numeric PMU 0.1.1 for the corrected installed-copy discovery' {
        $requirement = $script:project.Manifest.RequiredModules | Where-Object ModuleName -EQ 'PSModuleUpdate'
        $requirement.ModuleVersion | Should -BeExactly '0.1.1'
    }

    It 'uses the same minimum at the directly dependent native CI import' {
        $script:nativeCi | Should -Match 'Import-Module PSModuleUpdate -MinimumVersion 0\.1\.1 -ErrorAction Stop'
    }
}
