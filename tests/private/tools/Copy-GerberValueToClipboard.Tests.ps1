BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

function script:Assert-GerberClipboardPipeFallback {
    param(
        [Parameter(Mandatory)]
        [string[]]$UnavailableCommandList,

        [Parameter(Mandatory)]
        [string]$AvailableCommand,

        [string[]]$ExpectedArgumentList = @()
    )

    $script:clipboardUnavailableCommandList = $UnavailableCommandList
    $script:clipboardAvailableCommand = $AvailableCommand
    $script:clipboardExpectedArgumentList = $ExpectedArgumentList

    Mock Get-Command { $null } -ParameterFilter { $Name -in $script:clipboardUnavailableCommandList }
    Mock Get-Command { [pscustomobject]@{ Name = $script:clipboardAvailableCommand } } -ParameterFilter { $Name -eq $script:clipboardAvailableCommand }
    Mock Invoke-GerberClipboardPipeCommand {}

    $result = Copy-GerberValueToClipboard -Value 'abc'

    $result.Success | Should -BeTrue
    Should -Invoke Invoke-GerberClipboardPipeCommand -Times 1 -ParameterFilter {
        $CommandName -eq $script:clipboardAvailableCommand -and
        ($ArgumentList -join ',') -eq ($script:clipboardExpectedArgumentList -join ',') -and
        $Value -eq 'abc'
    }
}

Describe 'Copy-GerberValueToClipboard' {
    It 'uses Set-Clipboard when it is available' {
        Mock Get-Command {
            [pscustomobject]@{ Name = 'Set-Clipboard' }
        } -ParameterFilter { $Name -eq 'Set-Clipboard' }
        Mock Set-Clipboard {}

        $result = Copy-GerberValueToClipboard -Value 'abc'

        $result.Success | Should -BeTrue
        $result.Message | Should -Be 'Copied the result to the clipboard.'
        Should -Invoke Set-Clipboard -Times 1 -ParameterFilter { $Value -eq 'abc' }
    }

    It 'returns a clear message when clipboard copy is not available' {
        Mock Get-Command { $null }
        Mock Set-Clipboard {}
        Mock Invoke-GerberClipboardPipeCommand {}

        $result = Copy-GerberValueToClipboard -Value 'abc'

        $result.Success | Should -BeFalse
        $result.Message | Should -Be 'Clipboard copy is not available in this shell.'
        Should -Invoke Set-Clipboard -Times 0
        Should -Invoke Invoke-GerberClipboardPipeCommand -Times 0
    }

    It 'uses the expected clipboard fallback command' -ForEach @(
        @{
            Name = 'pbcopy'
            UnavailableCommandList = @('Set-Clipboard')
            AvailableCommand = 'pbcopy'
            ExpectedArgumentList = @()
        }
        @{
            Name = 'wl-copy'
            UnavailableCommandList = @('Set-Clipboard', 'pbcopy')
            AvailableCommand = 'wl-copy'
            ExpectedArgumentList = @()
        }
        @{
            Name = 'xclip'
            UnavailableCommandList = @('Set-Clipboard', 'pbcopy', 'wl-copy')
            AvailableCommand = 'xclip'
            ExpectedArgumentList = @('-selection', 'clipboard')
        }
    ) {
        Assert-GerberClipboardPipeFallback `
            -UnavailableCommandList $UnavailableCommandList `
            -AvailableCommand $AvailableCommand `
            -ExpectedArgumentList $ExpectedArgumentList
    }

    It 'pipes the provided value into the requested clipboard command' {
        $script:clipboardCapture = @()
        function global:Test-GerberClipboardCapture {
            [CmdletBinding()]
            param(
                [Parameter(ValueFromPipeline = $true)]
                [string]$InputObject
            )

            process {
                $script:clipboardCapture += $InputObject
            }
        }

        try {
            Invoke-GerberClipboardPipeCommand -CommandName 'Test-GerberClipboardCapture' -Value 'abc'

            $script:clipboardCapture | Should -Be @('abc')
        } finally {
            Remove-Item function:global:Test-GerberClipboardCapture -ErrorAction SilentlyContinue
        }
    }
}
