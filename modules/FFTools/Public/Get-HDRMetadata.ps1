function Get-HDRMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$InputFile
    )
    #Constants for mastering display color primaries
    Set-Variable -Name Display_P3 -Value "master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)" -Option Constant
    $Display_P3
    Set-Variable -Name BT_2020 -Value "master-display=G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)" -Option Constant
    $BT_2020

    $probe = ffprobe -hide_banner -loglevel warning -select_streams v -print_format json `
        -show_frames -read_intervals "%+#1" -show_entries "frame=color_space,color_primaries,color_transfer,side_data_list,pix_fmt" `
        -i $InputFile

    $metadata = $probe | ConvertFrom-Json
    $colorSpace = $metadata.frames.color_space
    $colorPrimaries = $metadata.frames.color_primaries
    $colorTransfer = $metadata.frames.color_transfer
    if ($metadata.frames.side_data_list[0].red_x -match "35400/\d+" -and 
        $metadata.frames.side_data_list[0].red_y -match "14600/\d+") {
        $masterDisplayStr = $BT_2020
    }
    else { $masterDisplayStr = $Display_P3 }
    #HDR min and max luminance values
    [int]$minLuma = $metadata.frames.side_data_list[0].min_luminance -replace "/.*", ""
    [int]$maxLuma = $metadata.frames.side_data_list[0].max_luminance -replace "/.*", ""
    #MAx content light level and max frame average light level
    $maxCLL = $metadata.frames.side_data_list[1].max_content
    $maxFAL = $metadata.frames.side_data_list[1].max_average

    Write-Host "Master display is: " $masterDisplayStr

    $metadataObj = [PSCustomObject] @{
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

#$InputFile = "M:\Blu Ray Rips\Knives Out (2019) 2160p HDR\Knives Out_t04.mkv"