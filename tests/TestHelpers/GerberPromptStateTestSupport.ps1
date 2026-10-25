function Get-GerberRootPromptState {
    param(
        [Parameter(Mandatory)]
        [string]$PromptSymbol,

        [Parameter(Mandatory)]
        [object[]]$SuggestionList,

        [int]$SuggestionIndex = 0,

        [bool]$SuggestionNavigationUsed = $false
    )

    return @{
        Prompt = $PromptSymbol
        Buffer = '/'
        SuggestionIndex = $SuggestionIndex
        SuggestionList = @($SuggestionList)
        SuggestionNavigationUsed = $SuggestionNavigationUsed
    }
}

function Get-GerberRootSuggestionSelectionState {
    return @{
        Buffer = '/'
        CursorIndex = 1
        SuggestionIndex = 2
        SuggestionList = @(
            [pscustomobject]@{
                DisplayText = '/exit'
                CompletionText = '/exit'
                PreviewText = 'Exit the interactive Gerber session'
            }
            [pscustomobject]@{
                DisplayText = '/help'
                CompletionText = '/help'
                PreviewText = 'Show the built-in command help'
            }
            [pscustomobject]@{
                DisplayText = '/tools'
                CompletionText = '/tools'
                PreviewText = 'Open the interactive tools menu'
            }
        )
        SuggestionMode = 'Root'
        SuggestionNavigationUsed = $true
    }
}

function Get-GerberRootEmptyPromptLineList {
    param(
        [Parameter(Mandatory)]
        [string]$PromptSymbol,

        [Parameter(Mandatory)]
        [string]$EmptyStateHintText,

        [string]$Buffer = ''
    )

    return @(Get-GerberCommandPromptLineList -State @{
            Prompt = $PromptSymbol
            Buffer = $Buffer
            SuggestionMode = 'Root'
            SuggestionIndex = 0
            SuggestionList = @()
            SuggestionNavigationUsed = $false
            EmptyStateHintText = $EmptyStateHintText
        })
}
