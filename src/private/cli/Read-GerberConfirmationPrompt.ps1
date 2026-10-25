function Read-GerberConfirmationPrompt {
    [OutputType([bool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$ScreenTitle,

        [string]$ScreenText,

        [pscustomobject]$PromptOptionSet = (Get-GerberConfirmationPromptOptionSet)
    )

    $selection = Read-GerberNumberedMenuPrompt `
        -Prompt $Prompt `
        -ScreenTitle $ScreenTitle `
        -ScreenText $ScreenText `
        -MenuItemList (Get-GerberConfirmationMenuItemList -PromptOptionSet $PromptOptionSet)

    return $selection -eq 'action'
}

function Get-GerberConfirmationPromptOptionSet {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [string]$ActionLabel = 'Continue',

        [string]$CancelLabel = 'Cancel',

        [string]$ActionPreviewText = 'Continue with this action.',

        [string]$CancelPreviewText = 'Cancel and return to the current menu.',

        [ValidateSet('action', 'cancel')]
        [string]$DefaultOption = 'action'
    )

    return [pscustomobject]@{
        ActionLabel        = $ActionLabel
        CancelLabel        = $CancelLabel
        ActionPreviewText  = $ActionPreviewText
        CancelPreviewText = $CancelPreviewText
        DefaultOption      = $DefaultOption
    }
}

function Get-GerberConfirmationMenuItemList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PromptOptionSet
    )

    $actionMenuItem = [pscustomobject]@{
        Label       = $PromptOptionSet.ActionLabel
        Value       = 'action'
        PreviewText = $PromptOptionSet.ActionPreviewText
    }
    $cancelMenuItem = [pscustomobject]@{
        Label       = $PromptOptionSet.CancelLabel
        Value       = 'cancel'
        PreviewText = $PromptOptionSet.CancelPreviewText
    }
    $menuItemList = if ($PromptOptionSet.DefaultOption -eq 'cancel') {
        @($cancelMenuItem, $actionMenuItem)
    } else {
        @($actionMenuItem, $cancelMenuItem)
    }

    return @(
        for ($index = 0; $index -lt $menuItemList.Count; $index++) {
            [pscustomobject]@{
                Number      = $index + 1
                Label       = $menuItemList[$index].Label
                Value       = $menuItemList[$index].Value
                PreviewText = $menuItemList[$index].PreviewText
            }
        }
    )
}
