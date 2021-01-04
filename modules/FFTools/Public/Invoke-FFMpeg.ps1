###################################################################
#
#   Written by: Patrick Kelly
#   Last Modified: 01/02/2021
#
###################################################################
<#
    .SYNOPSIS
        Function that calls ffmpeg to encode the input file using passed parameters
    .DESCRIPTION
        This function takes a series of input parameters and uses them to encode
        a 4K HDR file. It uses the module function Set-AudioPreference to build an 
        argument array that ffmpeg can parse based on the -Audio parameter. 
    .INPUTS
        Path of the source file to be encoded
        Path of the output file
        HDR metadata (as hashtable)
        Crop dimensions for the output file
        Optional x265 parameter values that differ from -Preset
    .OUTPUTS
        4K HDR encoded video file
    .NOTES
        HDR metadata can be collected using module function Get-HDRMetadata
        Get-AudioPreference is a private function that is not publicly loaded by the module
#>
function Invoke-FFMpeg {      
    [CmdletBinding()]
    param (
        # The input file to be encoded
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("InFile", "I")]
        [string]$InputFile,

        # Crop dimensions for the output file
        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Crop", "CropDim")]
        [int[]]$CropDimensions,

        # Audio preference for the output file
        [Parameter(Mandatory = $false)]
        [Alias("Audio", "A")]
        [string]$AudioInput = "none",

        [Parameter(Mandatory = $false)]
        [ValidateRange(32, 160)]
        [Alias("AQ", "AACQ")]
        [int]$AacBitrate,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset = "slow",

        # x265 CRF setting
        [Parameter(Mandatory = $false)]
        [double]$CRF = 17.0,

        # Deblock filter setting
        [Parameter(Mandatory = $false)]
        [Alias("DBF")]
        [int[]]$Deblock = @(-1, -1),

        # HDR metadata object
        [Parameter(Mandatory = $true, Position = 2)]
        [hashtable]$HDR,

        # Path to the output file
        [Parameter(Mandatory = $true)]
        [Alias("O")]
        [string]$OutputPath,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [Alias("L")]
        [string]$LogPath,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        [Alias("T")]
        [int]$TestFrames
    )
    #Builds the audio argument array based on user input (none, aac, or copy)
    $audio = Set-AudioPreference $InputFile $AudioInput $AacBitrate

    Write-Host "***** STARTING FFMPEG *****" @progressColors
    Write-Host "To view your progress, run " -NoNewline
    Write-Host "Get-Content path\to\cropFile.txt -Tail 10" @emphasisColors -NoNewline
    Write-Host " in a different PowerShell session`n`n"

    if ($PSBoundParameters['TestFrames']) {
        Write-Host "Test Run Enabled. Encoding $TestFrames frames`n" @warnColors
        ffmpeg -probesize 100MB -ss 00:01:00 -i $InputFile $audio -frames:v $TestFrames -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
            -color_range tv -c:v libx265 -preset $Preset -crf $CRF -pix_fmt $HDR.PixelFmt `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=$($HDR.ColorPrimaries):`
            transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr-opt=1" `
            $OutputPath 2>$logPath
    }
    else {
        ffmpeg -probesize 100MB -i $InputFile $audio -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
            -color_range tv -c:v libx265 -preset $Preset -crf $CRF -pix_fmt $HDR.PixelFmt `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=$($HDR.ColorPrimaries):`
            transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr-opt=1" `
            $OutputPath 2>$logPath
    }
}
