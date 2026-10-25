function Get-GerberTerminalCredentialStoreState {
    [OutputType([hashtable])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    return (Read-GerberTerminalJsonFile -Path $Path -DefaultValue (Get-GerberTerminalDefaultCredentialStoreState))
}

function Add-GerberTerminalCredentialOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [hashtable]$Operation
    )

    $State.operations = @($State.operations + @($Operation))
}

function Assert-GerberTerminalCredentialOperationAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$State,

        [Parameter(Mandatory)]
        [string]$Operation
    )

    if ($State.failures.ContainsKey($Operation)) {
        throw [System.InvalidOperationException]::new([string]$State.failures[$Operation])
    }
}

function Get-GerberTerminalCredentialStoreAddOrUpdateMethod {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param()

    return {
        param(
            [string]$Service,
            [string]$Account,
            [string]$Secret
        )

        $state = Get-GerberTerminalCredentialStoreState -Path $this.Path
        Assert-GerberTerminalCredentialOperationAvailable -State $state -Operation 'AddOrUpdate'
        $state.credentials[$Account] = $Secret
        Add-GerberTerminalCredentialOperation -State $state -Operation @{
            operation = 'AddOrUpdate'
            service = $Service
            account = $Account
            secretLength = $Secret.Length
        }
        Write-GerberTerminalJsonFile -Path $this.Path -Value $state
    }
}

function Get-GerberTerminalCredentialStoreGetMethod {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param()

    return {
        param(
            [string]$Service,
            [string]$Account
        )

        $state = Get-GerberTerminalCredentialStoreState -Path $this.Path
        Assert-GerberTerminalCredentialOperationAvailable -State $state -Operation 'Get'
        Add-GerberTerminalCredentialOperation -State $state -Operation @{
            operation = 'Get'
            service = $Service
            account = $Account
        }
        Write-GerberTerminalJsonFile -Path $this.Path -Value $state
        if (-not $state.credentials.ContainsKey($Account)) {
            return $null
        }

        return [pscustomobject]@{
            Password = [string]$state.credentials[$Account]
        }
    }
}

function Get-GerberTerminalCredentialStoreGetAccountsMethod {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param()

    return {
        param(
            [string]$Service
        )

        $state = Get-GerberTerminalCredentialStoreState -Path $this.Path
        Assert-GerberTerminalCredentialOperationAvailable -State $state -Operation 'GetAccounts'
        Add-GerberTerminalCredentialOperation -State $state -Operation @{
            operation = 'GetAccounts'
            service = $Service
        }
        Write-GerberTerminalJsonFile -Path $this.Path -Value $state
        return @($state.credentials.Keys)
    }
}

function Get-GerberTerminalCredentialStoreRemoveMethod {
    [OutputType([scriptblock])]
    [CmdletBinding()]
    param()

    return {
        param(
            [string]$Service,
            [string]$Account
        )

        $state = Get-GerberTerminalCredentialStoreState -Path $this.Path
        Assert-GerberTerminalCredentialOperationAvailable -State $state -Operation 'Remove'
        $removed = $state.credentials.ContainsKey($Account)
        if ($removed) {
            $null = $state.credentials.Remove($Account)
        }

        Add-GerberTerminalCredentialOperation -State $state -Operation @{
            operation = 'Remove'
            service = $Service
            account = $Account
        }
        Write-GerberTerminalJsonFile -Path $this.Path -Value $state
        return $removed
    }
}

function Get-GerberTerminalCredentialStore {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $store = [pscustomobject]@{
        Path = $Path
    }
    $store | Add-Member -MemberType ScriptMethod -Name AddOrUpdate -Value (Get-GerberTerminalCredentialStoreAddOrUpdateMethod)
    $store | Add-Member -MemberType ScriptMethod -Name Get -Value (Get-GerberTerminalCredentialStoreGetMethod)
    $store | Add-Member -MemberType ScriptMethod -Name GetAccounts -Value (Get-GerberTerminalCredentialStoreGetAccountsMethod)
    $store | Add-Member -MemberType ScriptMethod -Name Remove -Value (Get-GerberTerminalCredentialStoreRemoveMethod)

    return $store
}
