<#

#>

function Set-TestParameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [int]$TestFrames,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$TestStart,

        [Parameter(Mandatory = $true, Position = 3)]
        [System.Collections.ArrayList]$PrimaryArguments,

        [Parameter(Mandatory = $false, Position = 4)]
        [System.Collections.ArrayList]$ExtraArguments
    )

    $a = @('-frames:v', $TestFrames, '-shortest')

    if ($ExtraArguments -contains '-ss' -and $TestStart -match '^\d+f') {
        throw "Test encode start cannot include both a time (-ss) and a frame number"
        exit 2
    }
    elseif ($ExtraArguments -contains '-ss') {
        $i = $ExtraArguments.IndexOf('-ss')
        $PrimaryArguments.InsertRange($PrimaryArguments.IndexOf('-i'), @($ExtraArguments[$i], $ExtraArguments[$i + 1]))
        $ExtraArguments.RemoveRange($i, 2)
    }
    #Check for 00:00:00 time format
    elseif ($TestStart -match "^\d+\:") {
        $PrimaryArguments.InsertRange($PrimaryArguments.IndexOf('-i'), @('-ss', $TestStart))
    }
    #check for 1 or 1.11 time format from the t modifier, convert
    elseif ($TestStart -match "^(\d+)(\.?)(\d*)t") {
        $TestStart = $Matches[2] ? [double]($TestStart -replace 't', '') : [int]($TestStart -replace 't', '')
        $PrimaryArguments.InsertRange($PrimaryArguments.IndexOf('-i'), @('-ss', $TestStart))
    }
    #Check if frame start was specified through the f modifier and calculate starting position
    elseif ($TestStart -match "^\d+f") {
        $TestStart = [int]($TestStart -replace 'f', '')
        #Calculate input FPS
        $fpsStr = $(ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $InputFile)
        $fpsStr = ($fpsStr -is [array]) ? $fpsStr[0] : $fpsStr
        #Calculate starting timestamp: Frame number / FPS
        $timestamp = $TestStart / $(Invoke-Expression $fpsStr)
        $PrimaryArguments.InsertRange($PrimaryArguments.IndexOf('-i'), @('-ss', $timestamp))
    }
    #Default: Start encode at 00:01:30
    else {
        $PrimaryArguments.InsertRange($PrimaryArguments.IndexOf('-i'), @('-ss', '00:01:30'))
    }
    $PrimaryArguments.AddRange($a)
}
