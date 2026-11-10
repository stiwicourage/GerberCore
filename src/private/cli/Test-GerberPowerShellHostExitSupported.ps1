function Test-GerberPowerShellHostExitSupported {
    [OutputType([bool])]
    param([string]$HostName = $Host.Name)
    $HostName -ceq 'ConsoleHost'
}
