###################################################################
#
#   Written by: Patrick Kelly
#   Last Modified: 12/31/2020
#
###################################################################
<#
    Function that gathers HDR metadata automatically using ffprobe

    .PARAMETER InputFile
        Path to source file. This is the file to be encoded
    .Outputs
        PowerShell object containing relevant HDR metadata
#>
function Get-HDRMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile
    )
    #Constants for mastering display color primaries
    Set-Variable -Name Display_P3 -Value "master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)" -Option Constant
    Set-Variable -Name BT_2020 -Value "master-display=G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)" -Option Constant
    #Gather HDR metadata using ffprobe
    $probe = ffprobe -hide_banner -loglevel warning -select_streams v -print_format json `
        -show_frames -read_intervals "%+#1" -show_entries "frame=color_space,color_primaries,color_transfer,side_data_list,pix_fmt" `
        -i $InputFile

    $metadata = $probe | ConvertFrom-Json
    [string]$pixelFmt = $metadata.frames.pix_fmt
    [string]$colorSpace = $metadata.frames.color_space
    [string]$colorPrimaries = $metadata.frames.color_primaries
    [string]$colorTransfer = $metadata.frames.color_transfer
    #Compares the red coordinates to determine the mastering display color primaries
    if ($metadata.frames.side_data_list[0].red_x -match "35400/\d+" -and 
        $metadata.frames.side_data_list[0].red_y -match "14600/\d+") {
        $masterDisplayStr = $BT_2020
    }
    elseif ($metadata.frames.side_data_list[0].red_x -match "34000/\d+" -and
        $metadata.frames.side_data_list[0].red_y -match "16000/\d+") {
        $masterDisplayStr = $Display_P3
    }
    else { throw "Unknown mastering display colors found. Only BT.2020 and Display P3 are supported." }
    #HDR min and max luminance values
    [int]$minLuma = $metadata.frames.side_data_list[0].min_luminance -replace "/.*", ""
    [int]$maxLuma = $metadata.frames.side_data_list[0].max_luminance -replace "/.*", ""
    #MAx content light level and max frame average light level
    $maxCLL = $metadata.frames.side_data_list[1].max_content
    $maxFAL = $metadata.frames.side_data_list[1].max_average

    $metadataObj = @{
        PixelFmt       = $pixelFmt
        ColorSpace     = $colorSpace
        ColorPrimaries = $colorPrimaries
        Transfer       = $colorTransfer
        MasterDisplay  = $masterDisplayStr
        MaxLuma        = $maxLuma
        MinLuma        = $minLuma
        MaxCLL         = $maxCLL
        MaxFAL         = $maxFAL
    }
    return $metadataObj
}


