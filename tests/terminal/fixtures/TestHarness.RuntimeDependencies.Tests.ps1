BeforeAll {
    . "$PSScriptRoot/TestHarness.RuntimeDependencies.ps1"
}

Describe 'Import-GerberTerminalRuntimeDependency' -Tag 'G4A7' {
    Context 'read-only dependency loading before fixture isolation' {
        It 'imports exactly the built manifest requirements without building or changing modules' {
            Mock Import-PowerShellDataFile {
                @{ RequiredModules = @(
                    @{ ModuleName = 'NovaModuleTools'; ModuleVersion = '3.4.2' }
                    @{ ModuleName = 'PSModuleUpdate'; ModuleVersion = '0.1.1' }
                ) }
            }
            Mock Import-Module {}
            Import-GerberTerminalRuntimeDependency -GerberRoot $TestDrive
            Should -Invoke Import-Module -Times 1 -ParameterFilter { $FullyQualifiedName[0].Name -eq 'NovaModuleTools' }
            Should -Invoke Import-Module -Times 1 -ParameterFilter { $FullyQualifiedName[0].Name -eq 'PSModuleUpdate' }
        }
    }
}
