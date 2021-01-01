$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase



#region Load Public Functions
try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} catch {
    Write-Warning ("{0}: {1}" -f $function,$_.Exception.Message)
    continue
}
#region Load Private Functions
try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} catch {
    Write-Warning ("{0}: {1}" -f $function,$_.Exception.Message)
    continue
}

New-Alias -Name iffmpeg -Value Invoke-FFMpeg -Force
New-Alias -Name ncf -Value New-CropFile1 -Force
New-Alias -Name ghdr -Value Get-HDRMetadata -Force


$ExportModule = @{
    Alias = @("iffmpeg", "ncf", "ghdr")
    Function = @("Invoke-FFmpeg", "New-CropFile", "Get-HDRMetadata")
}
Export-ModuleMember @ExportModule