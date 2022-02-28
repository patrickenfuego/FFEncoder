#Setting Module Run Location
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase

## Module Variables ##

$progressColors = @{ForegroundColor = 'Green'; BackgroundColor = 'Black'}
$warnColors = @{ForegroundColor = 'Yellow'; BackgroundColor = 'Black'}
$emphasisColors = @{ForegroundColor = 'Cyan'; BackgroundColor = 'Black'}
$errColors = @{ ForegroundColor = 'Red'; BackgroundColor = 'Black'}

# Track titles for muxing files with mkvmerge
$Script:trackTitle = @{
    AudioTitle1 = $null
    AudioTitle2 = $null
    StereoTitle = $null
    DeeTitle    = $null
    VideoTitle  = $null
}

# Arguments for dee encoders and audio
$Script:dee = @{
    DeeArgs = @('dee_ddp', 'dee_eac3', 'dee_dd', 'dee_ac3', 'dee_thd')
    DeeUsed = $false
}

## End module variables ##

## region Load Public Functions ##
try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} 
catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}
## region Load Private Functions ##
try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} 
catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}
## Region Load Util Functions ##
try {
    Get-ChildItem "$ScriptPath\Utils" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
}
catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}

## Setting Function Aliases ##
New-Alias -Name iffmpeg -Value Invoke-FFMpeg -Force
New-Alias -Name cropfile -Value New-CropFile -Force
New-Alias -Name cropdim -Value Measure-CropDimensions -Force


$ExportModule = @{
    Alias    = @('iffmpeg', 'cropfile', 'cropdim')
    Function = @('Invoke-FFmpeg', 'Invoke-TwoPassFFmpeg', 'New-CropFile', 'Measure-CropDimensions', 'Remove-FilePrompt', 'Write-Report', 'Confirm-HDR10Plus',
                    'Confirm-DolbyVision', 'Confirm-ScaleFilter', 'Invoke-MkvMerge')
    Variable = @('progressColors', 'warnColors', 'emphasisColors' )
}
Export-ModuleMember @ExportModule