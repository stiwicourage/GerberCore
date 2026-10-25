BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberBase64Tool' {
    It 'encodes and then returns to the Base64 action prompt' {
        Mock Get-GerberMenuSubcommand {
            @('encode', 'encode', '')[$script:base64MenuCall++]
        }
        Mock Read-GerberCommand { @('hello', 'again')[$script:base64ReadCall++] }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }
        Mock Show-GerberBase64Result {}
        Mock Wait-GerberContinue {}
        $script:base64MenuCall = 0
        $script:base64ReadCall = 0

        Show-GerberBase64Tool -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $CommandName -eq 'tools base-64' -and
            $Command.Arguments.Count -eq 0 -and
            $SubcommandTable.Keys -join ',' -eq 'encode,decode'
        }
        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $CommandName -eq 'tools base-64' -and
            $Command.Arguments -eq @('encode')
        }
        Should -Invoke Get-GerberMenuSubcommand -Times 1 -ParameterFilter {
            $CommandName -eq 'tools base-64' -and
            $Command.Arguments.Count -eq 0
        }
        Should -Invoke Read-GerberCommand -Times 2 -ParameterFilter { $Prompt -eq 'Text to encode' }
        Should -Invoke Show-GerberBase64Result -Times 1 -ParameterFilter {
            $Action -eq 'encode' -and
            $Result.Value -eq 'aGVsbG8='
        }
        Should -Invoke Show-GerberBase64Result -Times 1 -ParameterFilter {
            $Action -eq 'encode' -and
            $Result.Value -eq 'YWdhaW4='
        }
        Should -Invoke Wait-GerberContinue -Times 2
    }

    It 'goes back to the Base64 action chooser when Escape is pressed during continue' {
        Mock Get-GerberMenuSubcommand { @('encode', '')[$script:base64EscapeMenuCall++] }
        Mock Read-GerberCommand { 'hello' }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }
        Mock Show-GerberBase64Result {}
        Mock Wait-GerberContinue { throw (Get-GerberMenuEscapeException) }
        $script:base64EscapeMenuCall = 0

        Show-GerberBase64Tool -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Get-GerberMenuSubcommand -Times 2 -ParameterFilter {
            $CommandName -eq 'tools base-64' -and
            $Command.Arguments.Count -eq 0
        }
    }

    It 'shows a Gerber-owned error and stays in the loop for invalid decode input' {
        Mock Get-GerberMenuSubcommand { @('decode', '')[$script:base64DecodeCall++] }
        Mock Read-GerberCommand { '$$$' }
        Mock Show-GerberTextBlock {}
        Mock Show-GerberBase64Result {}
        Mock Wait-GerberContinue {}
        $script:base64DecodeCall = 0

        Show-GerberBase64Tool -Command ([pscustomobject]@{ Arguments = @() })

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq 'Error' -and
            $Text -eq 'That value is not valid Base64. Remove extra characters and try again.'
        }
        Should -Invoke Show-GerberBase64Result -Times 0
        Should -Invoke Wait-GerberContinue -Times 1
    }

    It 'shows a dedicated action screen before reading the action input' {
        Mock Show-GerberBase64ActionScreen {}
        Mock Read-GerberCommand { 'hello' }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }

        $result = Invoke-GerberBase64Action -Action 'encode'

        $result.Value | Should -Be 'aGVsbG8='
        Should -Invoke Show-GerberBase64ActionScreen -Times 1 -ParameterFilter { $Action -eq 'encode' }
        Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter { $Prompt -eq 'Text to encode' -and $TrimResult -eq $false }
    }

    It 'treats Escape at the Base64 action prompt as back navigation' {
        Mock Get-GerberMenuSubcommand { throw (Get-GerberMenuEscapeException) }

        $result = Read-GerberBase64Action -Command ([pscustomobject]@{ Arguments = @() }) -ActionTable (Get-GerberBase64ActionTable)

        $result | Should -Be ''
    }

    It 'returns to the Base64 chooser when the action raises Escape' {
        Mock Invoke-GerberBase64Action { throw (Get-GerberMenuEscapeException) }

        $result = Invoke-GerberBase64ActionFlow -Action 'encode' -ActionTable (Get-GerberBase64ActionTable)

        $result.Arguments | Should -Be @()
    }

    It 'rejects unknown Base64 actions' {
        { Invoke-GerberBase64Action -Action 'oops' } | Should -Throw "Unknown Base64 action 'oops'. Use encode or decode."
    }

    It 'decodes Base64 text and copies the decoded value to the clipboard' {
        Mock Read-GerberCommand { 'R2VyYmVy' }
        Mock Copy-GerberValueToClipboard { [pscustomobject]@{ Success = $true; Message = 'Copied the result to the clipboard.' } }

        $result = Invoke-GerberBase64Decode

        $result.Value | Should -Be 'Gerber'
        $result.ClipboardResult.Success | Should -BeTrue
        Should -Invoke Copy-GerberValueToClipboard -Times 1 -ParameterFilter { $Value -eq 'Gerber' }
    }

    It 'returns to the root Base64 prompt when the next action is unknown' {
        $result = Get-GerberBase64NextCommand -Action 'oops' -ActionTable (Get-GerberBase64ActionTable)

        $result.Arguments | Should -Be @()
    }
}
