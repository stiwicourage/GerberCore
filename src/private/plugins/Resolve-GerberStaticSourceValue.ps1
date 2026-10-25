function Resolve-GerberStaticSourceValue {
    param([System.Management.Automation.Language.Ast]$Node)

    if ($Node -is [System.Management.Automation.Language.VariableExpressionAst]) {
        return Resolve-GerberStaticVariable -Node $Node
    }
    $folded = Resolve-GerberStaticCompoundValue -Node $Node
    if ($null -ne $folded) {
        return $folded
    }
    return Get-GerberSafeLiteralValue -Node $Node
}

function Get-GerberSafeLiteralValue {
    param($Node)

    if ($null -eq $Node) {
        return
    }
    try {
        $value = $Node.SafeGetValue()
        if ($value -is [string]) {
            return $value
        }
    } catch [System.InvalidOperationException] {
        return $null
    }
}

function Resolve-GerberStaticCompoundValue {
    param($Node)

    if ($Node -is [System.Management.Automation.Language.ParenExpressionAst]) {
        return Resolve-GerberStaticPipelineValue -Pipeline $Node.Pipeline
    }
    if ($Node -is [System.Management.Automation.Language.BinaryExpressionAst] -and $Node.Operator -eq 'Plus') {
        return Join-GerberStaticSourceValue -Left $Node.Left -Right $Node.Right
    }
}

function Join-GerberStaticSourceValue {
    param($Left, $Right)

    $leftValue = Resolve-GerberStaticSourceValue -Node $Left
    $rightValue = Resolve-GerberStaticSourceValue -Node $Right
    if ($null -ne $leftValue -and $null -ne $rightValue) {
        return $leftValue + $rightValue
    }
}

function Resolve-GerberStaticPipelineValue {
    param($Pipeline)

    $elements = @($Pipeline.PipelineElements)
    if ($elements.Count -eq 1 -and $elements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) {
        return Resolve-GerberStaticSourceValue -Node $elements[0].Expression
    }
}

function Resolve-GerberStaticVariable {
    param($Node)

    $scope = $Node.Parent
    while ($scope -isnot [System.Management.Automation.Language.ScriptBlockAst]) {
        $scope = $scope.Parent
    }
    $name = $Node.VariablePath.UserPath
    $assignments = @($scope.FindAll({
        param($item)
        $item -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $item.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
        $item.Left.VariablePath.UserPath -eq $name
    }, $false))
    return Get-GerberSingleAssignmentValue -Assignments $assignments -Node $Node
}

function Get-GerberSingleAssignmentValue {
    param([object[]]$Assignments, $Node)

    if ($Assignments.Count -ne 1) {
        return $null
    }
    $assignment = $Assignments[0]
    if ($assignment.Extent.EndOffset -ge $Node.Extent.StartOffset -or
        $assignment.Parent -isnot [System.Management.Automation.Language.NamedBlockAst]) {
        return $null
    }
    if ($assignment.Right -is [System.Management.Automation.Language.CommandExpressionAst]) {
        return Resolve-GerberStaticSourceValue -Node $assignment.Right.Expression
    }
}
