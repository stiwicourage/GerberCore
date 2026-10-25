function Test-GerberUpdateInteractive {
    param()
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { return $false }
    if ([Environment]::GetEnvironmentVariable('CI')) { return $false }
    return @([Environment]::GetCommandLineArgs() -match '^-NonI').Count -eq 0
}
