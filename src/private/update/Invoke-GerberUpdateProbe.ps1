function Invoke-GerberUpdateProbe {
    param([object]$Request, [int]$TimeoutMilliseconds = 2000)
    $process = Initialize-GerberUpdateProbeProcess $Request
    try {
        $null = $process.Start()
        $output = $process.StandardOutput.ReadToEndAsync()
        $null = $process.StandardError.ReadToEndAsync()
        return Receive-GerberUpdateProbe -Process $process -Output $output -TimeoutMilliseconds $TimeoutMilliseconds
    } catch [System.Management.Automation.PipelineStoppedException] { throw
    } catch {
        return [pscustomobject]@{ Status = 'Unavailable' }
    } finally {
        Close-GerberUpdateProbe $process
    }
}

function Initialize-GerberUpdateProbeProcess {
    param([object]$Request)
    $scriptText = Get-GerberUpdateProbeCommand $Request
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new((Join-Path $PSHOME 'pwsh'))
    foreach ($argument in @('-NoLogo', '-NoProfile', '-NonInteractive', '-EncodedCommand',
        [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($scriptText)))) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    [System.Diagnostics.Process]::new() | ForEach-Object { $_.StartInfo = $startInfo; $_ }
}

function Get-GerberUpdateProbeCommand {
    param([object]$Request)
    $payload = @{
        Manifest = Join-Path $Request.Module.ModuleBase 'Gerber.psd1'
    } | ConvertTo-Json -Depth 8 -Compress
    $encodedPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload))
    "`$payload = '$encodedPayload';`n" + (Get-GerberUpdateProbeScript)
}

function Receive-GerberUpdateProbe {
    param([System.Diagnostics.Process]$Process, [System.Threading.Tasks.Task[string]]$Output, [int]$TimeoutMilliseconds)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $Process.WaitForExit($TimeoutMilliseconds)) { return [pscustomobject]@{ Status = 'TimedOut' } }
    $remaining = [Math]::Max(0, $TimeoutMilliseconds - [int]$watch.ElapsedMilliseconds)
    if (-not $Output.Wait($remaining)) { return [pscustomobject]@{ Status = 'TimedOut' } }
    if ($Process.ExitCode -ne 0) { return [pscustomobject]@{ Status = 'Unavailable' } }
    $summary = $Output.Result | ConvertFrom-Json -ErrorAction Stop
    if ($summary.Status -notin @('Available', 'UpToDate', 'RestartRequired', 'Unavailable', 'NoMatchingPackage')) {
        return [pscustomobject]@{ Status = 'Unavailable' }
    }
    $summary | Select-Object Status, Name, Installed, Available, Repository, Message
}

function Close-GerberUpdateProbe {
    param([System.Diagnostics.Process]$Process)
    try {
        if (-not $Process.HasExited) { $Process.Kill($true) }
    } catch [System.InvalidOperationException] {
        Write-Verbose 'Update probe already exited or could not start.'
    } finally {
        $Process.Dispose()
    }
}

function Get-GerberUpdateProbeScript {
    param()
    @'
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$data = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json -AsHashtable
$module = Import-Module $data.Manifest -PassThru -ErrorAction Stop
& $module {
    param($module)
    $request = [pscustomobject]@{ Module = $module }
    Get-GerberCoreUpdateState -Request $request | Select-Object Status, Name, Installed, Available, Repository, Message | ConvertTo-Json -Compress
} $module
'@
}
