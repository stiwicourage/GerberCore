function Invoke-GerberPipelineTagDelete {
    [CmdletBinding()]
    param()

    Invoke-GerberPipelineTagMutation -Operation ([pscustomobject]@{
            Mode         = 'delete'
            CommandLabel = '/pipelines tags delete'
            TracePrefix  = 'pipelines-tags-delete'
        })
}
