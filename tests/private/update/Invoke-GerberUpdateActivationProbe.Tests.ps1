BeforeAll {
    . (Join-Path $PSScriptRoot '../../TestHelpers/PluginUpdate.TestSupport.ps1')
    $probe = Join-Path $backendRoot 'update/Invoke-GerberUpdateActivationProbe.ps1'
    if (Test-Path $probe) {
        . $probe
    }
}

Describe 'Invoke-GerberUpdateActivationProbe' -Tag 'G4A9' {
    BeforeEach {
        $script:probeWorker = Join-Path $TestDrive 'worker.ps1'
        if (Get-Command Get-GerberUpdateActivationWorkerPath -ErrorAction SilentlyContinue) {
            Mock Get-GerberUpdateActivationWorkerPath {
                $script:probeWorker
            }
        }
        $script:probePayload = @{
            CoreVersion = '0.3.0'
        }
    }

    It 'returns only a validated structured response from the child' {
        Set-Content $script:probeWorker "param(`$Payload); '{`"Protocol`":1,`"Status`":`"Verified`",`"Version`":`"0.3.0`"}'"
        (Invoke-GerberUpdateActivationProbe $script:probePayload).Status | Should -Be 'Verified'
    }

    It 'reports nonzero exit and unexpected output as unverified' -ForEach @('exit 3', "'private-diagnostic'") {
        Set-Content $script:probeWorker "param(`$Payload); $_"
        $result = Invoke-GerberUpdateActivationProbe $script:probePayload
        $result.Status | Should -Be 'Unverified'
        ($result | ConvertTo-Json) | Should -Not -Match 'private-diagnostic'
    }

    It 'bounds a child that does not finish' {
        Set-Content $script:probeWorker 'param($Payload); Start-Sleep -Seconds 30'
        $watch = [Diagnostics.Stopwatch]::StartNew()
        (Invoke-GerberUpdateActivationProbe $script:probePayload -TimeoutMilliseconds 100).Status | Should -Be 'Unverified'
        $watch.Elapsed.TotalSeconds | Should -BeLessThan 10
    }
}
