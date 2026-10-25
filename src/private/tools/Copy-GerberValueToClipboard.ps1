function Copy-GerberValueToClipboard {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Value
    )

    if ($null -ne (Get-Command -Name 'Set-Clipboard' -ErrorAction SilentlyContinue)) {
        Set-Clipboard -Value $Value
        return ConvertTo-GerberClipboardResult -Success $true -Message 'Copied the result to the clipboard.'
    }

    if ($null -ne (Get-Command -Name 'pbcopy' -ErrorAction SilentlyContinue)) {
        Invoke-GerberClipboardPipeCommand -CommandName 'pbcopy' -ArgumentList @() -Value $Value
        return ConvertTo-GerberClipboardResult -Success $true -Message 'Copied the result to the clipboard.'
    }

    if ($null -ne (Get-Command -Name 'wl-copy' -ErrorAction SilentlyContinue)) {
        Invoke-GerberClipboardPipeCommand -CommandName 'wl-copy' -ArgumentList @() -Value $Value
        return ConvertTo-GerberClipboardResult -Success $true -Message 'Copied the result to the clipboard.'
    }

    if ($null -ne (Get-Command -Name 'xclip' -ErrorAction SilentlyContinue)) {
        Invoke-GerberClipboardPipeCommand -CommandName 'xclip' -ArgumentList @('-selection', 'clipboard') -Value $Value
        return ConvertTo-GerberClipboardResult -Success $true -Message 'Copied the result to the clipboard.'
    }

    return ConvertTo-GerberClipboardResult -Success $false -Message 'Clipboard copy is not available in this shell.'
}

function Invoke-GerberClipboardPipeCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CommandName,

        [AllowEmptyCollection()]
        [string[]]$ArgumentList = @(),

        [AllowEmptyString()]
        [string]$Value
    )

    $Value | & $CommandName @ArgumentList | Out-Null
}

function ConvertTo-GerberClipboardResult {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$Success,

        [Parameter(Mandatory)]
        [string]$Message
    )

    return [pscustomobject]@{
        Success = $Success
        Message = $Message
    }
}
