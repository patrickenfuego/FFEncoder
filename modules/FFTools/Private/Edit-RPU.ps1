using namespace System.IO

<#
    .SYNOPSIS
        Edit Dolby Vision RPU metadata
    .DESCRIPTION
        Edits the extracted RPU file to ensure metadata properties are set correctly.
    .PARAMETER Paths
        <hashtable> Paths to files used throughout the script
    .PARAMETER CropDimensions
        <int[]> Cropping dimensions used to generate black bar offsets
    .PARAMETER HDRMetadata
        <hashtable> HDR metadata extracted from source file
#>
function Edit-RPU {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        [Parameter(Mandatory = $true)]
        [array]$CropDimensions,

        [Parameter(Mandatory = $true)]
        [hashtable]$HDRMetadata
    )

    $edited = $Paths.DvPath.replace('.bin', '_edited.bin')
    if ([File]::Exists($edited)) {
        Write-Verbose "Existing edited RPU file found"
        $Paths.DvPath = $edited
        return
    }

    Write-Host "Editing RPU file..." @emphasisColors -NoNewline

    $outJson = Join-Path (Split-Path $Paths.InputFile -Parent) -ChildPath 'rpu_edit.json'

    $srcWidth, $srcHeight = switch ($CropDimensions[0]) {
        { $_ -gt 1920 }                   { 3840, 2160 }
        { $_ -gt 1280 -and $_ -lt 3000 }  { 1920, 1080 }
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

    $presets = @(
        [ordered]@{
            'id'     = 0
            'left'   = $canvasLeft
            'right'  = $CanvasRight
            'top'    = $canvasTop
            'bottom' = $canvasBottom
        }
    )


    $minPq = $pqLookup[$HDRMetadata['MinLuma']]
    $maxPq = $pqLookup[$HDRMetadata['MaxLuma']]

    $level6 = [Ordered]@{
        'max_display_mastering_luminance' = $HDRMetadata['MaxLuma'] / 10000
        'min_display_mastering_luminance' = $HDRMetadata['MinLuma']
        'max_content_light_level'         = $HDRMetadata['MaxCLL']
        'max_frame_average_light_level'   = $HDRMetadata['MaxFAL']
    }

    $metadata = [pscustomobject]@{
        'mode'        = 2
        'min_pq'      = $minPq
        'max_pq'      = $maxPq
        'active_area' = [Ordered]@{
            'crop'    = $true
            'presets' = $presets
        }
        'level6'      = $level6
    }

    ConvertTo-Json -InputObject $metadata -Depth 4 |
        Out-File $outJson

    if ($IsLinux -or $IsMacOS) {
        $parserPath = $IsLinux ?
            ([Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, "bin/linux/dovi_tool")) :
            ([Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, "bin/mac/dovi_tool"))

        $parserPath, $edited, $outJson, $dv = ($parserPath, $edited, $outJson, $Paths.DvPath).ForEach({ [regex]::Escape($_) }) 
        $outEdit = bash -c "$parserPath editor -i $dv -j $outJson -o $edited"
    }
    else {
        $parserPath = [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, "bin\windows\dovi_tool.exe")
        $outEdit = cmd.exe /c "`"$parserPath`" editor -i `"$($Paths.DvPath)`" -j `"$outJson`" -o `"$edited`""
    }

    Write-Verbose "`n$($outEdit -join "`n")"

    if ((Test-Path $edited)) {
        $editLen = (Get-Item $edited).Length
        $srcLen = (Get-Item $Paths.DvPath).Length
        if ((($srcLen - $editLen) / 1MB ) -lt 2) {
            Write-Host "Great Success!`n" @progressColors
            Remove-Item $Paths.DvPath
            $Paths.DvPath = $edited
        }
        else {
            Write-Host "Edited RPU file was generated, but is smaller than expected. Investigate manually`n" @warnColors
        }  
    }
    else {
        Write-Host "Edited RPU file was not found and won't be used`n" @warnColors
    }
}
