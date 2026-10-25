BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot
}

Describe 'Get-GerberMenuSubcommand' {
    It 'uses the shared inline submenu prompt when no subcommand argument was provided' {
        Mock Read-GerberSubcommandPrompt { '/tools create-uuid' }

        $result = Get-GerberMenuSubcommand -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @() })

        $result | Should -Be 'create-uuid'
        Should -Invoke Read-GerberSubcommandPrompt -Times 1 -ParameterFilter {
            $CommandName -eq 'tools' -and
            $SubcommandTable.Keys -join ',' -eq 'create-uuid,base-64'
        }
    }

    It 'reuses the first explicit command argument without reopening the submenu prompt' {
        Mock Read-GerberSubcommandPrompt {}

        $result = Get-GerberMenuSubcommand `
            -CommandName 'tools base-64' `
            -Command ([pscustomobject]@{ Arguments = @('/tools base-64 decode') }) `
            -SubcommandTable ([ordered]@{
                encode = 'Encode UTF-8 text as Base64'
                decode = 'Decode Base64 text into UTF-8 text'
            })

        $result | Should -Be 'decode'
        Should -Invoke Read-GerberSubcommandPrompt -Times 0
    }

    It 'uses an explicit nested submenu table when one is provided' {
        $subcommandTable = [ordered]@{
            encode = 'Encode UTF-8 text as Base64'
            decode = 'Decode Base64 text into UTF-8 text'
        }
        Mock Read-GerberSubcommandPrompt { '/tools base-64 decode' }

        $result = Get-GerberMenuSubcommand -CommandName 'tools base-64' -Command ([pscustomobject]@{ Arguments = @() }) -SubcommandTable $subcommandTable

        $result | Should -Be 'decode'
        Should -Invoke Read-GerberSubcommandPrompt -Times 1 -ParameterFilter {
            $CommandName -eq 'tools base-64' -and
            $SubcommandTable.Keys -join ',' -eq 'encode,decode'
        }
    }

    It 'passes through opt-in first-suggestion submit behavior for top-level submenu prompts' {
        Mock Read-GerberSubcommandPrompt { '/secrets list' }

        $result = Get-GerberMenuSubcommand `
            -CommandName 'secrets' `
            -Command ([pscustomobject]@{ Arguments = @() }) `
            -SubcommandTable ([ordered]@{
                list = 'Show the stored Gerber keys'
                get = 'Reveal a stored Gerber secret after confirmation'
            }) `
            -AutoSelectFirstSuggestionOnSubmit

        $result | Should -Be 'list'
        Should -Invoke Read-GerberSubcommandPrompt -Times 1 -ParameterFilter {
            $CommandName -eq 'secrets' -and
            $AutoSelectFirstSuggestionOnSubmit
        }
    }

    It 'requests the visible root chooser when Escape leaves a top-level submenu prompt' {
        Mock Read-GerberSubcommandPrompt { throw (Get-GerberMenuEscapeException) }
        Mock Request-GerberVisibleRootPrompt {}

        {
            Get-GerberMenuSubcommand -CommandName 'tools' -Command ([pscustomobject]@{ Arguments = @() })
        } | Should -Throw 'Go back to the previous Gerber menu.'

        Should -Invoke Request-GerberVisibleRootPrompt -Times 1
    }

    It 'does not request the visible root chooser when Escape leaves a nested submenu prompt' {
        Mock Read-GerberSubcommandPrompt { throw (Get-GerberMenuEscapeException) }
        Mock Request-GerberVisibleRootPrompt {}

        {
            Get-GerberMenuSubcommand `
                -CommandName 'tools base-64' `
                -Command ([pscustomobject]@{ Arguments = @() }) `
                -SubcommandTable ([ordered]@{
                    encode = 'Encode UTF-8 text as Base64'
                    decode = 'Decode Base64 text into UTF-8 text'
                })
        } | Should -Throw 'Go back to the previous Gerber menu.'

        Should -Invoke Request-GerberVisibleRootPrompt -Times 0
    }

    It 'reuses a scalar explicit command argument without assuming a Count property on the raw input' {
        Mock Read-GerberSubcommandPrompt {}

        $result = Get-GerberMenuSubcommand `
            -CommandName 'repository' `
            -Command ([pscustomobject]@{ Arguments = ([uri]'https://ado.example.test/ExampleProject/ExampleProject/_git/Repo/pullrequest/18075') }) `
            -SubcommandTable ([ordered]@{
                review = 'Review an Azure DevOps pull request'
                create = 'Create repository artifacts'
            })

        $result | Should -Be 'https://ado.example.test/exampleproject/exampleproject/_git/repo/pullrequest/18075'
        Should -Invoke Read-GerberSubcommandPrompt -Times 0
    }

    It 'treats a null command-argument list as an empty submenu selection source' {
        Mock Read-GerberSubcommandPrompt { '/tools create-uuid' }

        $result = Get-GerberMenuSubcommand `
            -CommandName 'tools' `
            -Command ([pscustomobject]@{ Arguments = $null }) `
            -SubcommandTable ([ordered]@{
                'create-uuid' = 'Generate a UUID and copy it to the clipboard when possible'
            })

        $result | Should -Be 'create-uuid'
        Should -Invoke Read-GerberSubcommandPrompt -Times 1
    }
}

Describe 'Resolve-GerberMenuSubcommandInput' {
    It 'normalizes slash-prefixed submenu input to the selected action' {
        $result = Resolve-GerberMenuSubcommandInput -CommandName 'tools base-64' -InputText '/tools base-64 decode'

        $result | Should -Be 'decode'
    }

    It 'keeps an empty result when the user stays at the bare submenu command' {
        $result = Resolve-GerberMenuSubcommandInput -CommandName 'tools' -InputText '/tools'

        $result | Should -Be ''
    }

    It 'strips a generic leading slash from direct submenu input' {
        $result = Resolve-GerberMenuSubcommandInput -CommandName 'tools base-64' -InputText '/decode'

        $result | Should -Be 'decode'
    }

    It 'passes through plain text without modification' {
        $result = Resolve-GerberMenuSubcommandInput -CommandName 'tools' -InputText 'decode'

        $result | Should -Be 'decode'
    }
}

Describe 'Test-GerberTopLevelMenuEscapeRequest' {
    It 'returns true only for top-level submenu Escape requests' {
        (Test-GerberTopLevelMenuEscapeRequest -CommandName 'tools' -Exception (Get-GerberMenuEscapeException)) | Should -BeTrue
        (Test-GerberTopLevelMenuEscapeRequest -CommandName 'tools base-64' -Exception (Get-GerberMenuEscapeException)) | Should -BeFalse
        (Test-GerberTopLevelMenuEscapeRequest -CommandName 'tools' -Exception ([System.InvalidOperationException]::new('other'))) | Should -BeFalse
    }
}
