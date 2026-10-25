function Get-GerberPluginUsingDiagnostic {
    param($Document)

    $statements = $Document.Tree.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.UsingStatementAst] -and $node.UsingStatementKind -eq 'Module'
    }, $true)
    foreach ($statement in $statements) {
        $value = Resolve-GerberStaticSourceValue -Node $statement.Name
        Get-GerberPluginImportDiagnostic -Command ([pscustomobject]@{
            CommandElements = @($statement.Name)
            InvocationOperator = 'Dot'
        }) -Document $Document -Name $value
    }
}
