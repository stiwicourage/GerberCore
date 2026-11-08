function Get-GerberModuleSemanticVersion {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [System.Management.Automation.PSModuleInfo]$Module
    )

    if ($null -eq $Module) {
        $Module = $MyInvocation.MyCommand.Module
    }
    if (-not (Test-GerberExecutingModule -Module $Module)) {
        throw [System.InvalidOperationException]::new('Unable to resolve the executing Gerber module version. The plugin MinimumGerberVersion cannot be generated; rebuild or reinstall Gerber and retry.')
    }

    $build = [Math]::Max($Module.Version.Build, 0)
    $core = '{0}.{1}.{2}' -f $Module.Version.Major, $Module.Version.Minor, $build
    $prerelease = Get-GerberModulePrereleaseLabel -Module $Module
    if ([string]::IsNullOrWhiteSpace($prerelease)) {
        return $core
    }

    return ('{0}-{1}' -f $core, $prerelease)
}

function Test-GerberExecutingModule {
    param([System.Management.Automation.PSModuleInfo]$Module)

    if ($null -eq $Module) {
        return $false
    }
    if ($Module.Name -ne 'Gerber') {
        return $false
    }

    return $null -ne $Module.Version
}

function Get-GerberModulePrereleaseLabel {
    param([System.Management.Automation.PSModuleInfo]$Module)

    if ($null -eq $Module.PrivateData) {
        return ''
    }
    $psData = $Module.PrivateData['PSData']
    if ($null -eq $psData) {
        return ''
    }

    return [string]$psData['Prerelease']
}
