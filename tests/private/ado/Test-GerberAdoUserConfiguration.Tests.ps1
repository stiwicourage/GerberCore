BeforeAll {
    . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'TestHelpers/GerberTestSupport.ps1')
    Import-GerberSource -StartPath $PSScriptRoot

    function ConvertTo-TestGerberConfiguration {
        param(
            [Parameter(Mandatory)]
            [string]$Json
        )

        return ($Json | ConvertFrom-Json -AsHashtable -Depth 100)
    }
}

Describe 'Test-GerberAdoUserConfiguration' {
    It 'accepts configuration without an ado section' {
        {
            Test-GerberAdoUserConfiguration `
                -Configuration @{ schemaVersion = 1 } `
                -Path '/tmp/config.json'
        } | Should -Not -Throw
    }

    It 'accepts an empty profile collection' {
        $configuration = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "profiles": {}
  }
}
'@

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } | Should -Not -Throw
    }

    It 'accepts one valid profile and preserves unknown metadata' {
        $configuration = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "defaultProfile": "example",
    "profiles": {
      "example": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject",
        "note": "keep-me"
      }
    }
  }
}
'@

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } | Should -Not -Throw
        $configuration.ado.profiles.example.note | Should -Be 'keep-me'
    }

    It 'accepts multiple valid profiles for services and server deployments' {
        $configuration = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "defaultProfile": "example",
    "profiles": {
      "example": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject"
      },
      "internal": {
        "projectUrl": "https://ado.example.com/azuredevops/DefaultCollection/MyProject",
        "deploymentType": "Server",
        "serverUrl": "https://ado.example.com/azuredevops"
      }
    }
  }
}
'@

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } | Should -Not -Throw
    }

    It 'rejects invalid ado section and profile shapes' -ForEach @(
        @{
            Scenario = 'a non-object ado section'
            Json = '{"schemaVersion":1,"ado":"invalid"}'
            ErrorMessage = "*property 'ado' must be a JSON object*"
        }
        @{
            Scenario = 'a non-object profiles section'
            Json = '{"schemaVersion":1,"ado":{"profiles":"invalid"}}'
            ErrorMessage = "*property 'ado.profiles' must be a JSON object*"
        }
        @{
            Scenario = 'a non-object profile entry'
            Json = '{"schemaVersion":1,"ado":{"profiles":{"example":"invalid"}}}'
            ErrorMessage = "*profile 'example' must be a JSON object*"
        }
        @{
            Scenario = 'a profile without projectUrl'
            Json = '{"schemaVersion":1,"ado":{"profiles":{"example":{}}}}'
            ErrorMessage = "*profile 'example' must define string property 'projectUrl'*"
        }
        @{
            Scenario = 'a profile with invalid projectUrl'
            Json = '{"schemaVersion":1,"ado":{"profiles":{"example":{"projectUrl":"relative/path"}}}}'
            ErrorMessage = '*has invalid Azure DevOps profile*'
        }
        @{
            Scenario = 'an invalid default profile reference'
            Json = '{"schemaVersion":1,"ado":{"defaultProfile":"missing","profiles":{"example":{"projectUrl":"https://dev.azure.com/example-org/SampleProject"}}}}'
            ErrorMessage = "*references unknown profile 'missing'*"
        }
    ) {
        $configuration = ConvertTo-TestGerberConfiguration -Json $Json

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } |
            Should -Throw $ErrorMessage
    }

    It 'rejects invalid profile names' -ForEach @(
        @{
            Json = '{"schemaVersion":1,"ado":{"profiles":{"":"value"}}}'
            ErrorMessage = '*empty name*'
        }
        @{
            Json = '{"schemaVersion":1,"ado":{"profiles":{"   ":{"projectUrl":"https://dev.azure.com/example-org/SampleProject"}}}}'
            ErrorMessage = '*whitespace-only name*'
        }
        @{
            Json = '{"schemaVersion":1,"ado":{"profiles":{" example":{"projectUrl":"https://dev.azure.com/example-org/SampleProject"}}}}'
            ErrorMessage = '*leading or trailing whitespace*'
        }
        @{
            Json = '{"schemaVersion":1,"ado":{"profiles":{"example ":{"projectUrl":"https://dev.azure.com/example-org/SampleProject"}}}}'
            ErrorMessage = '*leading or trailing whitespace*'
        }
    ) {
        $configuration = ConvertTo-TestGerberConfiguration -Json $Json

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } |
            Should -Throw $ErrorMessage
    }

    It 'accepts valid JSON-compatible profile names' {
        $configuration = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "profiles": {
      "team/devops:prod": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject"
      }
    }
  }
}
'@

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } | Should -Not -Throw
    }

    It 'rejects profile names that differ only by case' {
        $configuration = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "profiles": {
      "example": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject"
      },
      "EXAMPLE": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject"
      }
    }
  }
}
'@

        { Test-GerberAdoUserConfiguration -Configuration $configuration -Path '/tmp/config.json' } |
            Should -Throw '*must be unique ignoring case*'
    }

    It 'rejects known credential-value fields without rejecting unrelated metadata' {
        $withCredential = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "profiles": {
      "example": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject",
        "token": "super-secret"
      }
    }
  }
}
'@
        $withoutCredential = ConvertTo-TestGerberConfiguration -Json @'
{
  "schemaVersion": 1,
  "ado": {
    "profiles": {
      "example": {
        "projectUrl": "https://dev.azure.com/example-org/SampleProject",
        "tokenHint": "metadata"
      }
    }
  }
}
'@

        { Test-GerberAdoUserConfiguration -Configuration $withCredential -Path '/tmp/config.json' } |
            Should -Throw "*must not contain credential field 'token'*"
        { Test-GerberAdoUserConfiguration -Configuration $withoutCredential -Path '/tmp/config.json' } |
            Should -Not -Throw
    }
}
