# The real multi-field input, defaults, recovery and shared Escape contract are
# exercised by Invoke-GerberPluginsCreateCommand.Tests.ps1 across the UI helpers.
BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function Initialize-TestPluginProjectAnswer {
        param([string[]]$Tail, [string]$Choice = 'PSGallery')

        [string[]]$answers = @('Example', 'Tools', 'example') + $Tail
        $script:values = [System.Collections.Generic.Queue[string]]::new($answers)
        $script:repositoryChoice = $Choice
    }
}

Describe 'Read-GerberPluginProjectRequest' -Tag 'PluginCreate' {
    BeforeEach {
        Mock Read-GerberCommand {
            $script:values.Dequeue()
        }
        Mock Read-GerberNumberedMenuPrompt {
            'PSGallery'
        }
    }

    It 'returns validated input from shared prompts' {
        $script:values = [System.Collections.Generic.Queue[string]]::new([string[]]@('Example', 'Tools', 'example', $TestDrive))
        Mock Read-GerberCommand { $script:values.Dequeue() }
        $request = Read-GerberPluginProjectRequest
        $request.Name | Should -Be 'Gerber.Example'
        $request.Destination | Should -Be (Join-Path $TestDrive 'Gerber.Example')
    }

    It 'renders the first field under built-module StrictMode before the suffix exists' -Tag 'PluginCreateStrict' {
        $script:values = [System.Collections.Generic.Queue[string]]::new([string[]]@('Example', 'Tools', 'example', $TestDrive))
        Mock Read-GerberCommand { $script:values.Dequeue() }
        Mock Write-GerberScreenLine {}
        $request = & {
            Set-StrictMode -Version Latest
            Read-GerberPluginProjectRequest
        }
        $request.Name | Should -Be 'Gerber.Example'
    }

    Context 'repository selection' -Tag 'PluginCreateRepository' {
        BeforeEach {
            Mock Read-GerberNumberedMenuPrompt {
                $script:remainingAtRepository = $script:values.Count
                $script:repositoryChoice
            }
            Mock Write-GerberScreenLine {
            }
            Mock Write-GerberPromptTrace {
            }
        }

        It 'defaults the shared chooser to PSGallery before destination and omits the override' {
            Initialize-TestPluginProjectAnswer -Tail @($TestDrive)
            $request = Read-GerberPluginProjectRequest
            $request.PSObject.Properties.Name | Should -Not -Contain 'RepositoryUri'
            $script:remainingAtRepository | Should -Be 1
            Should -Invoke Read-GerberNumberedMenuPrompt -Times 1 -ParameterFilter {
                $MenuItemList[0].Value -eq 'PSGallery' -and $MenuItemList[0].Number -eq 1 -and
                $MenuItemList[0].Label -match 'PSGallery' -and $MenuItemList[0].PreviewText -match 'omit'
            }
            Should -Invoke Read-GerberCommand -Times 0 -ParameterFilter {
                $Prompt -like '*Repository URI*'
            }
        }

        It 'keeps a known custom URI directly on the request' {
            Initialize-TestPluginProjectAnswer -Tail @('https://packages.example.org/feed', $TestDrive) -Choice Other
            $request = Read-GerberPluginProjectRequest
            $request.RepositoryUri | Should -BeExactly 'https://packages.example.org/feed'
            Should -Invoke Read-GerberCommand -Times 1 -ParameterFilter {
                $Prompt -like '*Repository URI*' -and $SuggestionMode -eq 'None' -and $TrimResult
            }
        }

        It 'records an explicit replacement placeholder when another source is not yet known' {
            Initialize-TestPluginProjectAnswer -Tail @('', $TestDrive) -Choice Other
            (Read-GerberPluginProjectRequest).RepositoryUri | Should -BeExactly 'REPLACE_WITH_REPOSITORY_URI'
        }

        It 'rejects unsafe URI input in place without tracing its sensitive value' {
            Initialize-TestPluginProjectAnswer -Tail @('https://example.org/feed?token=secret', 'https://example.org/feed', $TestDrive) -Choice Other
            (Read-GerberPluginProjectRequest).RepositoryUri | Should -BeExactly 'https://example.org/feed'
            Should -Invoke Write-GerberPromptTrace -Times 1 -ParameterFilter {
                $EventName -eq 'plugin-create-input-rejected' -and $Data.Field -eq 'RepositoryUri' -and $Data.Count -eq 1
            }
            Should -Invoke Write-GerberScreenLine -ParameterFilter {
                $Text -match 'absolute repository URI' -and $Text -match 'Enter' -and $Text -notmatch 'secret'
            }
        }

        It 'propagates shared navigation when the repository chooser is escaped' {
            Initialize-TestPluginProjectAnswer -Tail @()
            Mock Read-GerberNumberedMenuPrompt {
                throw (Get-GerberMenuEscapeException)
            }
            {
                Read-GerberPluginProjectRequest
            } | Should -Throw
            Should -Invoke Read-GerberCommand -Times 0 -ParameterFilter {
                $Prompt -like '*Destination*'
            }
        }
    }
}
