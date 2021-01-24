#Setting module run location
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase

## module variables ##

$progressColors = @{ForegroundColor = 'Green'; BackgroundColor = 'Black'}
$warnColors = @{ForegroundColor = 'Yellow'; BackgroundColor = 'Black'}
$emphasisColors = @{ForegroundColor = 'Cyan'; BackgroundColor = 'Black'}

## end module variables ##

## region Load Public Functions ##
try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}
## region Load Private Functions ##
try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}

## Setting function aliases ##
New-Alias -Name iffmpeg -Value Invoke-FFMpeg -Force
New-Alias -Name itpffmpeg -Value Invoke-TwoPassFFMpeg -Force
New-Alias -Name ncf -Value New-CropFile -Force
New-Alias -Name mcd -Value Measure-CropDimensions -Force


$ExportModule = @{
    Alias = @("iffmpeg", "itpffmpeg", "ncf", "mcd")
    Function = @("Invoke-FFmpeg", "Invoke-TwoPassFFmpeg","New-CropFile", 'Measure-CropDimensions')
    Variable = @("progressColors", "warnColors", "emphasisColors" )
}
Export-ModuleMember @ExportModule