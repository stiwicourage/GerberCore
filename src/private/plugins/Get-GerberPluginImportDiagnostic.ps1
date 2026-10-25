function Get-GerberPluginImportDiagnostic {
    param($Command, $Document, [string]$Name)

    $commandName = $Name -replace '^Microsoft.PowerShell.Core\\', ''
    if ($commandName -in @('Import-Module', 'ipmo') -or $Command.InvocationOperator -eq 'Dot') {
        foreach ($element in $Command.CommandElements) {
            $value = Resolve-GerberStaticSourceValue -Node $element
            Write-GerberCoreImportDiagnostic -Value $value -Document $Document -Extent $element.Extent
        }
    }
    if ($commandName -eq 'Get-Module') {
        Get-GerberCoreScopeDiagnostic -Command $Command -Document $Document
    }
}

function Get-GerberCoreScopeDiagnostic {
    param($Command, $Document)

    if (-not (Test-GerberCoreScopeAccess -Command $Command)) {
        return
    }
    Get-GerberBoundaryDiagnostic -Document $Document -Extent $Command.Extent -Finding @{
        Dependency = 'Gerber'; Reason = 'CoreModuleScope'
        Resolution = 'Use the supplied public API v1 context; request a public capability instead of accessing Core module scope or session state.'
    }
}

function Write-GerberCoreImportDiagnostic {
    param([string]$Value, $Document, $Extent)

    $normalized = $Value.Replace('\', '/')
    if ($normalized -notmatch '(?i)(^|/)Gerber/(src/)?(private|internal)(/|$)|(^|/)Gerber/Gerber\.psm1$') {
        return
    }
    Get-GerberBoundaryDiagnostic -Document $Document -Extent $Extent -Finding @{
        Dependency = $Value; Reason = 'CoreImplementationImport'
        Resolution = 'Import only the public Gerber module manifest and use the supplied Plugin API v1 context. Request a public capability if none fits.'
    }
}

function Test-GerberCoreScopeAccess {
    param($Command)

    $values = @($Command.CommandElements | Select-Object -Skip 1 | ForEach-Object { Resolve-GerberStaticSourceValue -Node $_ })
    if ('Gerber' -notin $values) {
        return $false
    }
    $parent = $Command.Parent
    while ($parent -isnot [System.Management.Automation.Language.ScriptBlockAst]) {
        if (Test-GerberCoreScopeParent -Parent $parent -Command $Command) {
            return $true
        }
        $parent = $parent.Parent
    }
    return $false
}

function Test-GerberCoreScopeParent {
    param($Parent, $Command)

    if ($Parent -is [System.Management.Automation.Language.MemberExpressionAst]) {
        return $Parent.Member.Value -eq 'SessionState'
    }
    if ($Parent -is [System.Management.Automation.Language.CommandAst]) {
        return Test-GerberModuleInvocationTarget -Parent $Parent -Command $Command
    }

    return $false
}

function Test-GerberModuleInvocationTarget {
    param($Parent, $Command)

    $target = $Parent.CommandElements[0].Extent
    return $Parent.InvocationOperator -eq 'Ampersand' -and
        $target.StartOffset -le $Command.Extent.StartOffset -and
        $target.EndOffset -ge $Command.Extent.EndOffset
}
