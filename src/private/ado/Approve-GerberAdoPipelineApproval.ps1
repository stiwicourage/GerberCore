function Approve-GerberAdoPipelineApproval {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$ApprovalId,

        [Parameter(Mandatory)]
        [string]$Comment
    )

    $null = $PSCmdlet.ShouldProcess("approval $ApprovalId", 'approve Azure DevOps pipeline approval')
    $uri = Get-GerberAdoPipelineApprovalPatchUri -Configuration $Configuration
    $body = Get-GerberAdoPipelineApprovalPatchBody -ApprovalId $ApprovalId -Comment $Comment

    try {
        Invoke-GerberAdoPipelineApprovalPatchRequest -Uri $uri -Pat $Pat -Body $body
    } catch {
        throw [System.ArgumentException]::new(
            (Get-GerberAdoMutationFailureMessage `
                -Uri $uri `
                -RequestLabel "approve pipeline approval $ApprovalId" `
                -CredentialIdentifier $Configuration.CredentialIdentifier `
                -Exception $_.Exception),
            $_.Exception
        )
    }
}

function Invoke-GerberAdoPipelineApprovalPatchRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Body
    )

    if (Test-GerberAdoPipelineApprovalCurlAvailable) {
        Invoke-GerberAdoPipelineApprovalPatchWithCurl -Uri $Uri -Pat $Pat -Body $Body
        return
    }

    Invoke-GerberAdoPipelineApprovalPatchWithRestMethod -Uri $Uri -Pat $Pat -Body $Body
}

function Test-GerberAdoPipelineApprovalCurlAvailable {
    [OutputType([bool])]
    [CmdletBinding()]
    param()

    return -not [string]::IsNullOrWhiteSpace((Resolve-GerberAdoPipelineApprovalCurlCommand))
}

function Resolve-GerberAdoPipelineApprovalCurlCommand {
    [OutputType([string])]
    [CmdletBinding()]
    param()

    foreach ($commandName in @('curl.exe', 'curl')) {
        $command = Get-Command -Name $commandName -CommandType Application -ErrorAction SilentlyContinue
        if ($null -ne $command) {
            return $command.Source
        }
    }

    return ''
}

function Invoke-GerberAdoPipelineApprovalPatchWithCurl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Body
    )

    $curlCommand = Resolve-GerberAdoPipelineApprovalCurlCommand
    if ([string]::IsNullOrWhiteSpace($curlCommand)) {
        throw [System.InvalidOperationException]::new('curl is not available for Azure DevOps approval updates.')
    }

    $bodyFilePath = New-GerberAdoPipelineApprovalCurlBodyFile -Body $Body
    try {
        $configText = Get-GerberAdoPipelineApprovalCurlConfigText -Uri $Uri -Pat $Pat -BodyFilePath $bodyFilePath
        $result = Invoke-GerberAdoPipelineApprovalCurlConfigRequest -CurlCommand $curlCommand -ConfigText $configText
        if ($result.ExitCode -ne 0) {
            $message = Get-GerberAdoPipelineApprovalCurlFailureMessage -StandardError $result.StandardError -StandardOutput $result.StandardOutput
            throw [System.InvalidOperationException]::new($message)
        }
    } finally {
        Remove-GerberAdoPipelineApprovalCurlBodyFile -BodyFilePath $bodyFilePath
    }
}

function New-GerberAdoPipelineApprovalCurlBodyFile {
    [OutputType([string])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Body
    )

    $bodyFilePath = [System.IO.Path]::GetTempFileName()
    $null = $PSCmdlet.ShouldProcess($bodyFilePath, 'write temporary curl approval body file')
    [System.IO.File]::WriteAllText($bodyFilePath, $Body, [System.Text.UTF8Encoding]::new($false))
    return $bodyFilePath
}

function Remove-GerberAdoPipelineApprovalCurlBodyFile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$BodyFilePath
    )

    if (Test-Path -LiteralPath $BodyFilePath -PathType Leaf) {
        $null = $PSCmdlet.ShouldProcess($BodyFilePath, 'remove temporary curl approval body file')
        Remove-Item -LiteralPath $BodyFilePath -Force
    }
}

function Invoke-GerberAdoPipelineApprovalCurlConfigRequest {
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CurlCommand,

        [Parameter(Mandatory)]
        [string]$ConfigText
    )

    $processStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $processStartInfo.FileName = $CurlCommand
    $processStartInfo.ArgumentList.Add('--config')
    $processStartInfo.ArgumentList.Add('-')
    $processStartInfo.RedirectStandardInput = $true
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.UseShellExecute = $false

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $processStartInfo
    $null = $process.Start()

    $process.StandardInput.WriteLine($ConfigText)
    $process.StandardInput.Close()

    $standardOutput = $process.StandardOutput.ReadToEnd()
    $standardError = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    return [pscustomobject]@{
        ExitCode       = $process.ExitCode
        StandardOutput = $standardOutput
        StandardError  = $standardError
    }
}

function Get-GerberAdoPipelineApprovalCurlConfigText {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$BodyFilePath
    )

    $lineList = [System.Collections.Generic.List[string]]::new()
    $lineList.Add('silent')
    $lineList.Add('show-error')
    $lineList.Add('fail-with-body')
    $lineList.Add(("request = {0}" -f (ConvertTo-GerberAdoPipelineApprovalCurlConfigValue -Value 'PATCH')))
    $lineList.Add(("url = {0}" -f (ConvertTo-GerberAdoPipelineApprovalCurlConfigValue -Value $Uri.AbsoluteUri)))
    foreach ($headerLine in @(Get-GerberAdoPipelineApprovalCurlHeaderLineList -Pat $Pat)) {
        $lineList.Add(("header = {0}" -f (ConvertTo-GerberAdoPipelineApprovalCurlConfigValue -Value $headerLine)))
    }
    $lineList.Add(("data-binary = {0}" -f (ConvertTo-GerberAdoPipelineApprovalCurlConfigValue -Value "@$BodyFilePath")))
    return $lineList -join [Environment]::NewLine
}

function Get-GerberAdoPipelineApprovalCurlHeaderLineList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pat
    )

    $headerMap = Get-GerberAdoJsonRequestHeader -Pat $Pat
    return @(
        foreach ($headerName in @('Authorization', 'User-Agent', 'Accept', 'Content-Type')) {
            if ($headerMap.ContainsKey($headerName)) {
                '{0}: {1}' -f $headerName, $headerMap[$headerName]
            }
        }
    )
}

function ConvertTo-GerberAdoPipelineApprovalCurlConfigValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $escapedValue = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escapedValue + '"'
}

function Get-GerberAdoPipelineApprovalCurlFailureMessage {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$StandardError,

        [AllowEmptyString()]
        [string]$StandardOutput
    )

    $trimmedError = $StandardError.Trim()
    $trimmedOutput = $StandardOutput.Trim()
    if ((-not [string]::IsNullOrWhiteSpace($trimmedError)) -and (-not [string]::IsNullOrWhiteSpace($trimmedOutput))) {
        return $trimmedError + [Environment]::NewLine + $trimmedOutput
    }

    if (-not [string]::IsNullOrWhiteSpace($trimmedError)) {
        return $trimmedError
    }

    if (-not [string]::IsNullOrWhiteSpace($trimmedOutput)) {
        return $trimmedOutput
    }

    return 'curl failed to update the Azure DevOps approval.'
}

function Invoke-GerberAdoPipelineApprovalPatchWithRestMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Pat,

        [Parameter(Mandatory)]
        [string]$Body
    )

    $httpConfig = Get-GerberHttpConfiguration
    Invoke-RestMethod `
        -Method Patch `
        -Uri $Uri `
        -ConnectionTimeoutSeconds $httpConfig.ConnectionTimeoutSeconds `
        -OperationTimeoutSeconds $httpConfig.OperationTimeoutSeconds `
        -Headers (Get-GerberAdoJsonRequestHeader -Pat $Pat) `
        -Body $Body `
        -ErrorAction Stop | Out-Null
}

function Get-GerberAdoPipelineApprovalPatchBody {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ApprovalId,

        [Parameter(Mandatory)]
        [string]$Comment
    )

    $bodyObject = @{
        approvalId = $ApprovalId
        status     = 'approved'
        comment    = $Comment
    }

    return ConvertTo-Json -InputObject $bodyObject -Depth 10 -Compress -AsArray
}

function Get-GerberAdoPipelineApprovalPatchUri {
    [OutputType([uri])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Configuration
    )

    return Get-GerberAdoApiUri `
        -BaseUri ([System.Uri]::new($Configuration.CollectionUri, "$($Configuration.ProjectName)/_apis/pipelines/approvals")) `
        -QueryParameterMap @{ 'api-version' = '7.2-preview.2' }
}
