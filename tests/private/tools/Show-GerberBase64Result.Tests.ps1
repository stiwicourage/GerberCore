BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Show-GerberBase64Result' {
    It 'shows the conversion result and clipboard status' {
        Mock Show-GerberTextBlock {}

        Show-GerberBase64Result -Action 'encode' -Result ([pscustomobject]@{
                Value = 'R2VyYmVy'
                ClipboardResult = [pscustomobject]@{
                    Success = $true
                    Message = 'Copied the result to the clipboard.'
                }
            })

        Should -Invoke Show-GerberTextBlock -Times 1 -ParameterFilter {
            $Title -eq '/tools base-64 encode' -and
            $Text -match 'R2VyYmVy' -and
            $Text -match 'Copied the result to the clipboard.'
        }
    }

    It 'renders an empty result explicitly' {
        $text = Format-GerberBase64ResultText -Result ([pscustomobject]@{
                Value = ''
                ClipboardResult = [pscustomobject]@{
                    Success = $false
                    Message = 'Clipboard copy is not available in this shell.'
                }
            })

        $text | Should -Match '\(empty string\)'
    }
}
