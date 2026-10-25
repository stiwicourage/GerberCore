BeforeAll {
    . (Join-Path $PSScriptRoot 'GerberAdoRetentionLeaseTestSupport.ps1')
}

Describe 'Retention lease request assertions' {
    It 'accepts the complete expected query' {
        Test-GerberRetentionLeaseQuery -Query '?ownerId=Gerber.ProdRetention&definitionId=53&runId=9001&api-version=7.1' |
            Should -BeTrue
    }

    It 'rejects a query with an invalid <Field>' -TestCases @(
        @{ Field = 'owner'; Pattern = 'Gerber\.ProdRetention' }
        @{ Field = 'definition'; Pattern = '53' }
        @{ Field = 'run'; Pattern = '9001' }
        @{ Field = 'API version'; Pattern = '7\.1' }
    ) {
        param($Pattern)

        $query = '?ownerId=Gerber.ProdRetention&definitionId=53&runId=9001&api-version=7.1'
        Test-GerberRetentionLeaseQuery -Query ($query -replace $Pattern, 'invalid') |
            Should -BeFalse
    }

    It 'accepts the complete expected body' {
        Test-GerberRetentionLeaseBody -Body '[{"daysValid":36500,"definitionId":53,"ownerId":"Gerber.ProdRetention","runId":9001}]' |
            Should -BeTrue
    }

    It 'rejects a body with an invalid <Field>' -TestCases @(
        @{ Field = 'retention duration'; Pattern = '36500' }
        @{ Field = 'definition'; Pattern = '53' }
        @{ Field = 'owner'; Pattern = 'Gerber\.ProdRetention' }
        @{ Field = 'run'; Pattern = '9001' }
    ) {
        param($Pattern)

        $body = '[{"daysValid":36500,"definitionId":53,"ownerId":"Gerber.ProdRetention","runId":9001}]'
        Test-GerberRetentionLeaseBody -Body ($body -replace $Pattern, 'invalid') |
            Should -BeFalse
    }
}
