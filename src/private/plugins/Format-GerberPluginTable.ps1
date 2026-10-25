function Format-GerberPluginTable {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$ColumnList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RowList
    )

    $resolvedColumnList = @(Get-GerberResolvedPluginTableColumnList -ColumnList $ColumnList -RowList $RowList)
    $lineList = @(
        (Format-GerberPluginTableColumnLine `
                -ColumnList $resolvedColumnList `
                -ValueResolver {
                    param([pscustomobject]$Column)
                    [string]$Column.Header
                })
        (Format-GerberPluginTableColumnLine `
                -ColumnList $resolvedColumnList `
                -ValueResolver {
                    param([pscustomobject]$Column)
                    ''.PadRight([int]$Column.Width, [char]0x2500)
                })
        (Format-GerberPluginTableBodyLineList -ColumnList $resolvedColumnList -RowList $RowList)
    )

    return ($lineList -join [Environment]::NewLine)
}

function Get-GerberResolvedPluginTableColumnList {
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [hashtable[]]$ColumnList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RowList
    )

    return @(
        foreach ($column in $ColumnList) {
            $valueList = @(
                foreach ($row in $RowList) {
                    Get-GerberPluginTableColumnValue -Row $row -PropertyName ([string]$column.PropertyName)
                }
            )
            $maxValueLength = Get-GerberPluginTableMaximumLength -ValueList $valueList
            [pscustomobject][ordered]@{
                Header = [string]$column.Header
                PropertyName = [string]$column.PropertyName
                Width = [Math]::Max([int]$column.Header.Length, $maxValueLength)
            }
        }
    )
}

function Get-GerberPluginTableMaximumLength {
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$ValueList
    )

    $maximumLength = 0
    foreach ($value in $ValueList) {
        $currentLength = [string]$value
        if ($currentLength.Length -gt $maximumLength) {
            $maximumLength = $currentLength.Length
        }
    }

    return $maximumLength
}

function Format-GerberPluginTableBodyLineList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ColumnList,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$RowList
    )

    return [string[]]@(
        foreach ($row in $RowList) {
            Format-GerberPluginTableColumnLine `
                -ColumnList $ColumnList `
                -ValueResolver {
                    param([pscustomobject]$Column)
                    Get-GerberPluginTableColumnValue -Row $row -PropertyName ([string]$Column.PropertyName)
                }
        }
    )
}

function Format-GerberPluginTableColumnLine {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$ColumnList,

        [Parameter(Mandatory)]
        [scriptblock]$ValueResolver
    )

    return @(
        foreach ($column in $ColumnList) {
            (& $ValueResolver $column).PadRight([int]$column.Width)
        }
    ) -join '  '
}

function Get-GerberPluginTableColumnValue {
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Row,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $value = $Row.$PropertyName
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        return [string][char]0x2014
    }

    return [string]$value
}
