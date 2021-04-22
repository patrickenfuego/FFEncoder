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
        [string]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$HDR10PlusPath
    )
    #Internal function that generates an HDR10+ metadata json file if the source is Profile A/B compliant
    function Confirm-HDR10Plus {
        $res = cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_parser --verify -"
        if ($res[1] -like "*HDR10+*") {
            Write-Host "HDR10+ SEI metadata found..." -NoNewline
            if (Test-Path -Path $HDR10PlusPath) { Write-Host "JSON file already exists" @warnColors }
            else {
                Write-Host "Generating JSON file" @emphasisColors
                cmd.exe /c "ffmpeg -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_parser -o `"$HDR10PlusPath`" -" 2>&1
            }
            return $true
        }
        else { return $false }
    }

    #Constants for mastering display color primaries
    Set-Variable -Name Display_P3 -Value "master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)" -Option Constant
    Set-Variable -Name BT_2020 -Value "master-display=G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)" -Option Constant

    Write-Host "Retrieving HDR Metadata..." 

    #Exit script if the input file is null or empty
    if (!(Test-Path -Path $InputFile)) {
        Write-Warning "<$InputFile> could not be found. Check the input path and try again."
        $ioError = New-Object System.IO.FileNotFoundException
        throw $ioError
    }
    #Gather HDR metadata using ffprobe
    $probe = ffprobe -hide_banner -loglevel error -select_streams V -print_format json `
        -show_frames -read_intervals "%+#5" -show_entries "frame=color_space,color_primaries,color_transfer,side_data_list,pix_fmt" `
        -i $InputFile

    $metadata = $probe | ConvertFrom-Json | Select-Object -ExpandProperty frames | Where-Object { $_.pix_fmt -like "yuv420p10le" } |
        Select-Object -First 1

    if (!$metadata) {
        throw "10-bit pixel format could not be found within the first 5 frames. Make sure the input file supports HDR."
    }

    [string]$pixelFmt = $metadata.pix_fmt
    [string]$colorSpace = $metadata.color_space
    [string]$colorPrimaries = $metadata.color_primaries
    [string]$colorTransfer = $metadata.color_transfer
    #Compares the red coordinates to determine the mastering display color primaries
    if ($metadata.side_data_list[0].red_x -match "35400/\d+" -and 
        $metadata.side_data_list[0].red_y -match "14600/\d+") {
        $masterDisplayStr = $BT_2020
    }
    elseif ($metadata.side_data_list[0].red_x -match "34000/\d+" -and
        $metadata.side_data_list[0].red_y -match "16000/\d+") {
        $masterDisplayStr = $Display_P3
    }
    else { throw "Unknown mastering display colors found. Only BT.2020 and Display P3 are supported." }
    #HDR min and max luminance values
    [int]$minLuma = $metadata.side_data_list[0].min_luminance -replace "/.*", ""
    [int]$maxLuma = $metadata.side_data_list[0].max_luminance -replace "/.*", ""
    #MAx content light level and max frame average light level
    $maxCLL = $metadata.side_data_list[1].max_content
    $maxFAL = $metadata.side_data_list[1].max_average
    #Check if input has HDR10+ metadata and append the generated json file if present
    $isHDR10Plus = Confirm-HDR10Plus
    if ($isHDR10Plus) {
        $colorTransfer = "$colorTransfer`:dhdr10-info='$HDR10PlusPath':"
    }
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
    if ($null -eq $metadataObj) {
        throw "HDR object is null. ffprobe may have failed to retrieve the data. Reload the module and try again, or run ffprobe manually to investigate."
    }
    else {
        Write-Host "** HDR METADATA SUCCESSFULLY RETRIEVED **`n" @progressColors
        return $metadataObj
    }
}


