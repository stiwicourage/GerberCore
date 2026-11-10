BeforeAll {
    $root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $source = "$root/src/private/cli/Show-GerberUpdateBatchCompletion.ps1"
    if (Test-Path $source) {
        . $source
    }
    function Write-GerberScreenLine {
        param($Text)
        $null = $Text
    }
    function Write-GerberPromptTrace {
        param($EventName, $Data)
        $null = $EventName, $Data
    }
    function Wait-GerberContinue {
    }
    function Show-GerberUpdateBatchRestartChoice {
        param($Text)
        $null = $Text
    }
}

Describe 'Show-GerberUpdateBatchCompletion' -Tag 'G4A9UI' {
    BeforeEach {
        Mock Write-GerberScreenLine {
        }
        Mock Write-GerberPromptTrace {
        }
        Mock Wait-GerberContinue {
        }
        Mock Show-GerberUpdateBatchRestartChoice {
            $true
        }
    }

    It 'reports every actual outcome and keeps Installed truthful when activation fails' {
        $results = @(
            foreach ($outcome in @('Installed', 'Failed', 'Blocked', 'Cancelled')) {
                [pscustomobject]@{
                    Item = [pscustomobject]@{
                        State = [pscustomobject]@{
                            Name = $outcome
                        }
                    }
                    Outcome = $outcome; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'
                    ActivationStatus = 'Failed'; RestartRequired = $false; Message = 'Safe recovery advice.'
                }
            }
        )
        Show-GerberUpdateBatchCompletion -ResultList $results
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -match '^✔ Installed\s+installed' -and $Text -match 'Activation: Failed'
        }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -match '^✖ Failed\s+failed' -and $Text -match '(?m)^    Safe recovery advice\.$'
        }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -match '^✖ Blocked\s+blocked' -and $Text -match 'Safe recovery advice'
        }
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -match '^- Cancelled\s+cancelled' -and $Text -match 'Safe recovery advice'
        }
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'offers the existing restart choice only for verified installed results requesting restart' {
        $result = [pscustomobject]@{
            Item = [pscustomobject]@{
                State = [pscustomobject]@{
                    Name = 'ExamplePlugin'
                }
            }
            Outcome = 'Installed'; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'
            ActivationStatus = 'Verified'; RestartRequired = $true; Message = ''
        }
        Show-GerberUpdateBatchCompletion -ResultList @($result) | Should -BeTrue
        Should -Invoke Show-GerberUpdateBatchRestartChoice -Times 1 -ParameterFilter {
            $Text -match 'Restart PowerShell' -and $Text -match '✔ ExamplePlugin\s+installed' -and $Text -notmatch 'Activation:'
        }
        Should -Invoke Wait-GerberContinue -Times 0
    }

    It 'keeps a clean installed result to a single line' {
        $result = [pscustomobject]@{
            Item = [pscustomobject]@{ State = [pscustomobject]@{ Name = 'Gerber' } }
            Outcome = 'Installed'; VerificationStatus = 'Verified'; RecoveryStatus = 'NotRequired'
            ActivationStatus = 'Unverified'; RestartRequired = $false; Message = 'Restart PowerShell before using installed updates; this session has not reloaded modules.'
        }
        Show-GerberUpdateBatchCompletion -ResultList @($result)
        Should -Invoke Write-GerberScreenLine -Times 1 -ParameterFilter {
            $Text -ceq '✔ Gerber  installed'
        }
    }
}
