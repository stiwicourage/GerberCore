# Built-module contract spans PMU delegation, overview mapping and the terminal view.
# PMU's returned plan is controlled here; installed-layout and version-selection tests belong to PMU.
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    $script:gerber = Import-Module "$root/dist/Gerber/Gerber.psd1" -Force -PassThru
}

Describe 'Core equal-version update contract' -Tag 'GerberPmu011' {
    BeforeEach {
        Mock Get-PSModuleUpdate -ModuleName Gerber {
            [pscustomobject]@{
                InstalledVersion = '0.1.0'; TargetVersion = '0.1.0'; Disposition = 'UpToDate'
            }
        }
        Mock Install-PSModuleUpdate -ModuleName Gerber { throw 'An up-to-date plan cannot install.' }
        Mock Test-GerberUpdateInteractive -ModuleName Gerber { $true }
        Mock Start-GerberScreen -ModuleName Gerber {}
        Mock Write-GerberScreenLine -ModuleName Gerber {}
        Mock Write-GerberPromptTrace -ModuleName Gerber {}
        Mock Wait-GerberContinue -ModuleName Gerber {}
        Mock Read-GerberConfirmationPrompt -ModuleName Gerber { throw 'An up-to-date plan cannot offer installation.' }
    }

    It 'preserves PMU available 0.1.0 and UpToDate without offering installation' {
        & $script:gerber { Show-GerberUpdateView }
        Should -Invoke Write-GerberScreenLine -ModuleName Gerber -Times 1 -ParameterFilter {
            $Text -match 'Available' -and $Text -match '0\.1\.0\s+0\.1\.0\s+PSGallery\s+UpToDate'
        }
        Should -Invoke Get-PSModuleUpdate -ModuleName Gerber -Times 1 -ParameterFilter {
            $Repository -ceq 'PSGallery' -and $Policy.Channel -ceq 'Stable' -and
            $Policy.Scope -ceq 'CurrentUser' -and
            $Policy.ExpectedRepositoryUri.AbsoluteUri -ceq 'https://www.powershellgallery.com/api/v2'
        }
        Should -Invoke Read-GerberConfirmationPrompt -ModuleName Gerber -Times 0
        Should -Invoke Install-PSModuleUpdate -ModuleName Gerber -Times 0
    }
}
