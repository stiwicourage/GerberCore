Describe 'Get-GerberHttpTransportFailureHint' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/private/http/Get-GerberHttpTransportFailureHint.ps1"
    }

    It 'returns DNS hint when DNS resolution fails' {
        $exception = [System.Exception]::new('nodename nor servname provided, or not known')
        $hint = Get-GerberHttpTransportFailureHint -Exception $exception

        $hint | Should -Be 'Verify DNS/VPN/network access and try again.'
    }

    It 'returns timeout hint when TaskCanceledException is thrown' {
        $exception = [System.Threading.Tasks.TaskCanceledException]::new('The request was canceled due to the configured timeout.')
        $hint = Get-GerberHttpTransportFailureHint -Exception $exception

        $hint | Should -Be 'Try again in a moment.'
    }

    It 'returns empty string for other exceptions' {
        $exception = [System.InvalidOperationException]::new('Something else went wrong')
        $hint = Get-GerberHttpTransportFailureHint -Exception $exception

        $hint | Should -BeNullOrEmpty
    }

    It 'returns empty string for null exception' {
        $hint = Get-GerberHttpTransportFailureHint -Exception $null

        $hint | Should -BeNullOrEmpty
    }

    It 'checks inner exceptions for DNS failure' {
        $inner = [System.Exception]::new('Name or service not known')
        $outer = [System.Exception]::new('Outer exception', $inner)
        $hint = Get-GerberHttpTransportFailureHint -Exception $outer

        $hint | Should -Be 'Verify DNS/VPN/network access and try again.'
    }

    It 'checks inner exceptions for timeout failure' {
        $inner = [System.Threading.Tasks.TaskCanceledException]::new()
        $outer = [System.Exception]::new('Outer exception', $inner)
        $hint = Get-GerberHttpTransportFailureHint -Exception $outer

        $hint | Should -Be 'Try again in a moment.'
    }
}

Describe 'Test-GerberHttpNameResolutionFailure' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/private/http/Get-GerberHttpTransportFailureHint.ps1"
    }

    It 'detects DNS failure from nodename message' {
        $exception = [System.Exception]::new('nodename nor servname provided, or not known')
        $result = Test-GerberHttpNameResolutionFailure -Exception $exception

        $result | Should -BeTrue
    }

    It 'detects DNS failure from Name or service message' {
        $exception = [System.Exception]::new('Name or service not known')
        $result = Test-GerberHttpNameResolutionFailure -Exception $exception

        $result | Should -BeTrue
    }

    It 'detects DNS failure from No such host message' {
        $exception = [System.Exception]::new('No such host is known')
        $result = Test-GerberHttpNameResolutionFailure -Exception $exception

        $result | Should -BeTrue
    }

    It 'returns false for other exceptions' {
        $exception = [System.Exception]::new('Something else')
        $result = Test-GerberHttpNameResolutionFailure -Exception $exception

        $result | Should -BeFalse
    }

    It 'returns false for null exception' {
        $result = Test-GerberHttpNameResolutionFailure -Exception $null

        $result | Should -BeFalse
    }
}

Describe 'Test-GerberHttpTimeoutFailure' {
    BeforeAll {
        . "$PSScriptRoot/../../../src/private/http/Get-GerberHttpTransportFailureHint.ps1"
    }

    It 'detects TaskCanceledException' {
        $exception = [System.Threading.Tasks.TaskCanceledException]::new()
        $result = Test-GerberHttpTimeoutFailure -Exception $exception

        $result | Should -BeTrue
    }

    It 'returns false for other exceptions' {
        $exception = [System.Exception]::new('Something else')
        $result = Test-GerberHttpTimeoutFailure -Exception $exception

        $result | Should -BeFalse
    }

    It 'returns false for null exception' {
        $result = Test-GerberHttpTimeoutFailure -Exception $null

        $result | Should -BeFalse
    }

    It 'checks inner exceptions for timeout' {
        $inner = [System.Threading.Tasks.TaskCanceledException]::new()
        $outer = [System.Exception]::new('Outer', $inner)
        $result = Test-GerberHttpTimeoutFailure -Exception $outer

        $result | Should -BeTrue
    }
}
