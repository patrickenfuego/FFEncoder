$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase



#region Load Public Functions
Try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}
#region Load Private Functions
Try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $Function = Split-Path $_ -Leaf
        . $_
    }
} Catch {
    Write-Warning ("{0}: {1}" -f $Function,$_.Exception.Message)
    Continue
}