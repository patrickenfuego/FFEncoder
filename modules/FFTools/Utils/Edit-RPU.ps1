using namespace System.IO

<#
    .SYNOPSIS
        Edit Dolby Vision RPU metadata
    .DESCRIPTION
        Edits the extracted RPU file to ensure metadata properties are set correctly.
    .PARAMETER Paths
        <hashtable> Paths to files used throughout the script. Expected keys are:
           - DvPath
           - InputFile
        This is required for the default function parameter set.
    .PARAMETER RpuPath
        <string> Path to the RPU file to edit. Required for the standalone function parameter set.
    .PARAMETER InputFile
        <string> Path to the source file. Required for the standalone function parameter set.
    .PARAMETER CropDimensions
        <int[]> Cropping dimensions used to generate black bar offsets
    .PARAMETER HDRMetadata
        <hashtable> HDR metadata extracted from source file. Expected keys are:
           - MinLuma
           - MaxLuma
           - MaxCLL
           - MaxFALL
    .PARAMETER KeepRPU
        <switch> Keep the original RPU file. Default behavior deletes the original file.
#>
function Edit-RPU {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [hashtable]$Paths,

        [Parameter(Mandatory = $true, ParameterSetName = 'Standalone')]
        [Alias('RPU')]
        [string]$RpuPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Standalone')]
        [Alias('VideoFile')]
        [string]$InputFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Standalone')]
        [Alias('Crop')]
        [array]$CropDimensions,

        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, ParameterSetName = 'Standalone')]
        [ValidateScript(
            { 
                $_.Keys -contains 'MinLuma' -and
                $_.Keys -contains 'MaxLuma' -and
                $_.Keys -contains 'MaxCLL' -and
                $_.Keys -contains 'MaxFAL' 
            },
            ErrorMessage = 'HDR metadata must contain the following keys: MinLuma, MaxLuma, MaxCLL, MaxFAL'
        )]
        [Alias('HDR')]
        [hashtable]$HDRMetadata,

        [Parameter(Mandatory = $false, ParameterSetName = 'Standalone')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [ValidateSet('8.1', '8.2', '8.1m')]
        [Alias('DoViProfile')]
        [string]$DolbyVisionProfile = '8.1',

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $false, ParameterSetName = 'Standalone')]
        [Alias('SaveRPU')]
        [switch]$KeepRPU
    )

    # Configure hashtable if function is called outside of automation
    if ($PSCmdlet.ParameterSetName -eq 'Standalone') {
        $Paths = @{
            'DvPath'    = $RpuPath
            'InputFile' = $InputFile
        }
    }

    $edited = $Paths.DvPath.replace('.bin', '_edited.bin')
    if ([File]::Exists($edited)) {
        Write-Verbose "Existing edited RPU file found"
        $Paths.DvPath = $edited
        return
    }

    Write-Host "Editing RPU file..." @emphasisColors -NoNewline

    $outJson = Join-Path (Split-Path $Paths.InputFile -Parent) -ChildPath 'rpu_edit.json'

    $srcWidth, $srcHeight = Get-MediaInfo $Paths.InputFile | Select-Object Width, Height | 
        ForEach-Object { $_.Width, $_.Height }

    # Specify mode for dovi_tool
    $mode = switch ($DolbyVisionProfile) {
        '8.1'   { 2 }
        '8.4'   { 4 }
        '8.1m'  { 5 }
        default { Write-Error "Invalid Dolby Vision mode option '$DolbyVisionProfile'" -ErrorAction Stop }
    }

    $canvasTop = $canvasBottom = ($srcHeight - $CropDimensions[1]) / 2
    $canvasLeft = $CanvasRight = ($srcWidth - $CropDimensions[0]) / 2

    # Lookup table for common pq values
    $pqLookup = @{
        1         = 7
        50        = 62
        10000000  = 3079
        40000000  = 3696
    }

    # If no crop, set presets. Else, don't set
    if ($canvasTop -eq 0 -and $canvasLeft -eq 0) {
        $presets = [ordered]@{
            'id'     = 0
            'left'   = 0
            'right'  = 0
            'top'    = 0
            'bottom' = 0
        }

        $activeArea = [ordered]@{
            'crop'    = $true
            'presets' = @($presets)
        }

    }
    elseif ($canvasTop -eq 0) {
        $presets = [ordered]@{
            'id'     = 0
            'left'   = $canvasLeft
            'right'  = $CanvasRight
            'top'    = 0
            'bottom' = 0
        }

        $activeArea = [ordered]@{
            'crop'    = $true
            'presets' = @($presets)
        }
    }
    else {
        $activeArea = [ordered]@{
            'crop' = $true
        }
    }
    $activeArea['edits'] = @{ 'all' = 0 }

    Write-Verbose "Active area: $($activeArea | Out-String)"


    $minPq = $pqLookup[$HDRMetadata['MinLuma']]
    $maxPq = $pqLookup[$HDRMetadata['MaxLuma']]

    $level6 = [Ordered]@{
        'max_display_mastering_luminance' = $HDRMetadata['MaxLuma'] / 10000
        'min_display_mastering_luminance' = $HDRMetadata['MinLuma']
        'max_content_light_level'         = $HDRMetadata['MaxCLL']
        'max_frame_average_light_level'   = $HDRMetadata['MaxFAL']
    }

    $metadata = [pscustomobject]@{
        'mode'           = $mode
        'remove_mapping' = $true
        'min_pq'         = $minPq
        'max_pq'         = $maxPq
        'active_area'    = $activeArea
        'level6'         = $level6
    }

    ConvertTo-Json -InputObject $metadata -Depth 4 | Out-File $outJson

    if ($IsLinux -or $IsMacOS) {
        $parserPath = $IsLinux ?
            ([Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, "bin/linux/dovi_tool")) :
            ([Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, "bin/mac/dovi_tool"))

        $parserPath, $edited, $outJson, $dv = ($parserPath, $edited, $outJson, $Paths.DvPath).ForEach({ 
            [Regex]::Escape($_) 
        }) 
        $outEdit = bash -c "$parserPath editor -i $dv -j $outJson -o $edited"
    }
    else {
        $parserPath = [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, "bin\windows\dovi_tool.exe")
        $outEdit = cmd.exe /c "`"$parserPath`" editor -i `"$($Paths.DvPath)`" -j `"$outJson`" -o `"$edited`""
    }

    Write-Verbose "`n$($outEdit -join "`n")"

    if ([Path]::Exists($edited)) {
        $editLen = ([FileInfo]$edited).Length
        $srcLen = ([FileInfo]$Paths.DvPath).Length
        if ((($srcLen - $editLen) / 1MB ) -lt 10) {
            Write-Host "Great Success!`n" @progressColors
        }
        else {
            Write-Host "Edited RPU file was generated, but is smaller than expected. Investigate manually`n" @warnColors
        }
        
        if (!$KeepRPU) {
            Remove-Item $Paths.DvPath
        }
        $Paths.DvPath = $edited

        if ($PSCmdlet.ParameterSetName -eq 'Standalone') {
            Write-Host "Edited RPU file was generated at '$edited'" @progressColors
            Write-Host "JSON file was generated at '$outJson'`n" @emphasisColors
        }
    }
    else {
        Write-Host "Edited RPU file was not found and won't be used`n" @warnColors
    }
}
