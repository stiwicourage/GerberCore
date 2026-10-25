function Invoke-GerberStartupUpdateCheck {
    param()
    try {
        $request = Resolve-GerberCoreUpdateRequest
        return Invoke-GerberUpdateProbe -Request $request -TimeoutMilliseconds 2000
    } catch [System.Management.Automation.PipelineStoppedException] { throw
    } catch [System.OperationCanceledException] { throw
    } catch {
        return [pscustomobject]@{ Status = 'Unavailable'; Repository = 'PSGallery'; Message = 'Core update discovery is unavailable. Run /update list to retry PSGallery.' }
    }
}
