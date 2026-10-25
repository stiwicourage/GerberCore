function global:Get-GerberFakeCurlCommandPath {
    param(
        [int]$ExitCode = 0,
        [string]$StandardOutput = '',
        [string]$StandardError = ''
    )

    $extension = if ($IsWindows) { '.cmd' } else { '.sh' }
    $scriptPath = Join-Path ([System.IO.Path]::GetTempPath()) ("gerber-fake-curl-{0}{1}" -f ([guid]::NewGuid().ToString('N')), $extension)

    if ($IsWindows) {
        $content = @(
            '@echo off'
            'more >nul'
            'if not "%~1"=="--config" exit /b 99'
            'if not "%~2"=="-" exit /b 98'
        )
        if (-not [string]::IsNullOrWhiteSpace($StandardOutput)) {
            $content += ('echo {0}' -f $StandardOutput)
        }
        if (-not [string]::IsNullOrWhiteSpace($StandardError)) {
            $content += ('echo {0} 1>&2' -f $StandardError)
        }
        $content += ('exit /b {0}' -f $ExitCode)
        [System.IO.File]::WriteAllLines($scriptPath, $content)
        return $scriptPath
    }

    $content = @(
        '#!/bin/sh'
        'cat >/dev/null'
        'if [ "$1" != "--config" ]; then exit 99; fi'
        'if [ "$2" != "-" ]; then exit 98; fi'
    )
    if (-not [string]::IsNullOrWhiteSpace($StandardOutput)) {
        $content += ("printf '%s\n' '{0}'" -f $StandardOutput.Replace("'", "'\\''"))
    }
    if (-not [string]::IsNullOrWhiteSpace($StandardError)) {
        $content += ("printf '%s\n' '{0}' 1>&2" -f $StandardError.Replace("'", "'\\''"))
    }
    $content += ('exit {0}' -f $ExitCode)
    [System.IO.File]::WriteAllLines($scriptPath, $content)
    & /bin/chmod '+x' $scriptPath | Out-Null
    return $scriptPath
}

BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Approve-GerberAdoPipelineApproval' {
    It 'routes approval updates through the expected transport' -ForEach @(
        @{
            CurlAvailable            = $true
            ExpectedMock             = 'Invoke-GerberAdoPipelineApprovalPatchWithCurl'
            UnexpectedMock           = 'Invoke-RestMethod'
            ConfigureFallbackHeaders = $false
        }
        @{
            CurlAvailable            = $false
            ExpectedMock             = 'Invoke-RestMethod'
            UnexpectedMock           = 'Invoke-GerberAdoPipelineApprovalPatchWithCurl'
            ConfigureFallbackHeaders = $true
        }
    ) {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Test-GerberAdoPipelineApprovalCurlAvailable { $CurlAvailable }
        Mock Invoke-GerberAdoPipelineApprovalPatchWithCurl {}
        if ($ConfigureFallbackHeaders) {
            Mock Get-GerberHttpConfiguration { [pscustomobject]@{ ConnectionTimeoutSeconds = 5; OperationTimeoutSeconds = 15 } }
        }
        Mock Invoke-RestMethod {}

        Approve-GerberAdoPipelineApproval -Configuration $configuration -Pat 'pat' -ApprovalId 'approval-1' -Comment '21279'

        Should -Invoke $ExpectedMock -Times 1 -ParameterFilter {
            $Uri.AbsoluteUri -eq 'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/approvals?api-version=7.2-preview.2' -and
            $Body -match 'approval-1' -and
            $Body -match '21279'
        }
        Should -Invoke $UnexpectedMock -Times 0
    }

    It 'wraps request failures in a Gerber-owned error' {
        $configuration = [pscustomobject]@{
            CollectionUri          = [uri]'https://ado.example.test/ExampleProject/'
            ProjectName            = 'ExampleProject'
            CredentialIdentifier = 'gerber:ado:example:pat'
        }
        Mock Test-GerberAdoPipelineApprovalCurlAvailable { $true }
        Mock Invoke-GerberAdoPipelineApprovalPatchWithCurl { throw [System.InvalidOperationException]::new('curl failed') }
        Mock Get-GerberAdoMutationFailureMessage { 'Wrapped approval error.' }

        {
            Approve-GerberAdoPipelineApproval -Configuration $configuration -Pat 'pat' -ApprovalId 'approval-1' -Comment '21279'
        } | Should -Throw '*Wrapped approval error.*'
    }
}

Describe 'Approve-GerberAdoPipelineApproval helpers' {
    It 'builds the expected approval patch body' {
        $body = Get-GerberAdoPipelineApprovalPatchBody -ApprovalId 'approval-1' -Comment '21279'

        $body | Should -Match '^\s*\['
        $body | Should -Match 'approval-1'
        $body | Should -Match '"status":\s*"approved"'
        $body | Should -Match '"comment":\s*"21279"'
    }

    It 'creates curl config text with headers and the body file reference' {
        $configText = Get-GerberAdoPipelineApprovalCurlConfigText `
            -Uri ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/approvals?api-version=7.2-preview.2') `
            -Pat 'pat' `
            -BodyFilePath '/tmp/body.json'

        $configText | Should -Match 'request = "PATCH"'
        $configText | Should -Match 'Authorization: Basic'
        $configText | Should -Match 'Content-Type: application/json'
        $configText | Should -Match 'data-binary = "@/tmp/body\.json"'
    }

    It 'prefers stderr when building the curl failure message' {
        $expectedMessage = 'boom' + [Environment]::NewLine + '{"message":"bad"}'

        (Get-GerberAdoPipelineApprovalCurlFailureMessage -StandardError 'boom' -StandardOutput '{"message":"bad"}') | Should -Be $expectedMessage
        (Get-GerberAdoPipelineApprovalCurlFailureMessage -StandardError '' -StandardOutput 'body') | Should -Be 'body'
        (Get-GerberAdoPipelineApprovalCurlFailureMessage -StandardError '' -StandardOutput '') | Should -Be 'curl failed to update the Azure DevOps approval.'
    }

    It 'returns false when curl cannot be resolved' {
        Mock Resolve-GerberAdoPipelineApprovalCurlCommand { '' }

        Test-GerberAdoPipelineApprovalCurlAvailable | Should -BeFalse
    }

    It 'returns true when curl can be resolved' {
        Mock Resolve-GerberAdoPipelineApprovalCurlCommand { '/usr/bin/curl' }

        Test-GerberAdoPipelineApprovalCurlAvailable | Should -BeTrue
    }

    It 'prefers curl.exe when both curl commands are available' {
        Mock Get-Command {
            if ($Name -eq 'curl.exe') {
                return [pscustomobject]@{ Source = 'C:\Windows\System32\curl.exe' }
            }

            return [pscustomobject]@{ Source = '/usr/bin/curl' }
        }

        Resolve-GerberAdoPipelineApprovalCurlCommand | Should -Be 'C:\Windows\System32\curl.exe'
    }

    It 'returns an empty string when no curl command is available' {
        Mock Get-Command { $null }

        Resolve-GerberAdoPipelineApprovalCurlCommand | Should -Be ''
    }

    It 'falls back to the secondary curl command when curl.exe is unavailable' {
        Mock Get-Command {
            if ($Name -eq 'curl.exe') {
                return $null
            }

            return [pscustomobject]@{ Source = '/usr/bin/curl' }
        }

        Resolve-GerberAdoPipelineApprovalCurlCommand | Should -Be '/usr/bin/curl'
    }

    It 'writes and removes the temporary curl body file' {
        $bodyFilePath = New-GerberAdoPipelineApprovalCurlBodyFile -Body '{"approvalId":"approval-1"}'

        try {
            (Test-Path -LiteralPath $bodyFilePath -PathType Leaf) | Should -BeTrue
            (Get-Content -LiteralPath $bodyFilePath -Raw) | Should -Match 'approval-1'
        } finally {
            Remove-GerberAdoPipelineApprovalCurlBodyFile -BodyFilePath $bodyFilePath
        }

        (Test-Path -LiteralPath $bodyFilePath -PathType Leaf) | Should -BeFalse
    }

    It 'throws when curl transport is requested but curl is unavailable' {
        Mock Resolve-GerberAdoPipelineApprovalCurlCommand { '' }

        {
            Invoke-GerberAdoPipelineApprovalPatchWithCurl `
                -Uri ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/approvals?api-version=7.2-preview.2') `
                -Pat 'pat' `
                -Body '[]'
        } | Should -Throw '*curl is not available*'
    }

    It 'sends the generated curl config request and removes the body file after success' {
        Mock Resolve-GerberAdoPipelineApprovalCurlCommand { '/usr/bin/curl' }
        Mock New-GerberAdoPipelineApprovalCurlBodyFile { '/tmp/body.json' }
        Mock Invoke-GerberAdoPipelineApprovalCurlConfigRequest {
            [pscustomobject]@{
                ExitCode       = 0
                StandardOutput = ''
                StandardError  = ''
            }
        }
        Mock Remove-GerberAdoPipelineApprovalCurlBodyFile {}

        Invoke-GerberAdoPipelineApprovalPatchWithCurl `
            -Uri ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/approvals?api-version=7.2-preview.2') `
            -Pat 'pat' `
            -Body '[]'

        Should -Invoke Invoke-GerberAdoPipelineApprovalCurlConfigRequest -Times 1 -ParameterFilter {
            $CurlCommand -eq '/usr/bin/curl' -and
            $ConfigText -match 'data-binary = "@/tmp/body\.json"'
        }
        Should -Invoke Remove-GerberAdoPipelineApprovalCurlBodyFile -Times 1 -ParameterFilter {
            $BodyFilePath -eq '/tmp/body.json'
        }
    }

    It 'surfaces curl transport failures and still removes the body file' {
        Mock Resolve-GerberAdoPipelineApprovalCurlCommand { '/usr/bin/curl' }
        Mock New-GerberAdoPipelineApprovalCurlBodyFile { '/tmp/body.json' }
        Mock Invoke-GerberAdoPipelineApprovalCurlConfigRequest {
            [pscustomobject]@{
                ExitCode       = 22
                StandardOutput = '{"message":"bad"}'
                StandardError  = 'curl: (22) bad request'
            }
        }
        Mock Remove-GerberAdoPipelineApprovalCurlBodyFile {}

        $expectedPattern = '*curl: (22) bad request*' + [Environment]::NewLine + '{"message":"bad"}*'

        {
            Invoke-GerberAdoPipelineApprovalPatchWithCurl `
                -Uri ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_apis/pipelines/approvals?api-version=7.2-preview.2') `
                -Pat 'pat' `
                -Body '[]'
        } | Should -Throw $expectedPattern

        Should -Invoke Remove-GerberAdoPipelineApprovalCurlBodyFile -Times 1 -ParameterFilter {
            $BodyFilePath -eq '/tmp/body.json'
        }
    }

    It 'returns the expected result from the curl config process helper (<CaseExitCode>)' -ForEach @(
        @{ CaseExitCode = 0; CaseStandardOutput = 'curl-ok'; CaseStandardError = 'curl-warn' }
        @{ CaseExitCode = 22; CaseStandardOutput = 'curl-body'; CaseStandardError = 'curl-error' }
    ) {
        $curlCommand = Get-GerberFakeCurlCommandPath `
            -ExitCode $CaseExitCode `
            -StandardOutput $CaseStandardOutput `
            -StandardError $CaseStandardError

        try {
            $result = Invoke-GerberAdoPipelineApprovalCurlConfigRequest -CurlCommand $curlCommand -ConfigText 'request = "PATCH"'

            $result.ExitCode | Should -Be $CaseExitCode
            $result.StandardOutput | Should -Match $CaseStandardOutput
            $result.StandardError | Should -Match $CaseStandardError
        } finally {
            Remove-Item -LiteralPath $curlCommand -Force
        }
    }

}
