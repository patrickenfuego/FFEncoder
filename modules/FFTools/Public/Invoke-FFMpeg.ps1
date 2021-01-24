<#
    .SYNOPSIS
        Calls ffmpeg to encode the input file using CRF or 1 Pass ABR rate control
    .DESCRIPTION
        This function takes the input parameters and uses them to encode a 4K HDR file.
        It uses module functions from FFTools to set video metadata, audio, and
        subtitle preferences
    .INPUTS
        Path of the source file to be encoded
        Path of the output file
        Crop dimensions for the output file
        Audio preference
        Subtitle preference
        Rate Control method
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
        [Alias("AB", "AQ")]
        [int]$AudioBitrate,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [Alias("S")]
        [string]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset,

        # x265 CRF / 1 pass ABR array of arguments
        [Parameter(Mandatory = $true)]
        [array]$RateControl,

        # Deblock filter setting
        [Parameter(Mandatory = $false)]
        [Alias("DBF")]
        [int[]]$Deblock,

        # aq-mode setting. Default is 2
        [Parameter(Mandatory = $false)]
        [Alias("AQM")]
        [int]$AqMode,

        # aq-strength. Higher values equate to a lower QP, but can also increase bitrate significantly
        [Parameter(Mandatory = $false)]
        [Alias("AQS")]
        [double]$AqStrength,

        # psy-rd. Psycho visual setting
        [Parameter(Mandatory = $false)]
        [double]$PsyRd,

        # psy-rdoq (trellis). Psycho visual setting
        [Parameter(Mandatory = $false)]
        [Alias("PRDQ")]
        [double]$PsyRdoq,

        # Filter to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [Alias("NRTR")]
        [int]$NrInter,

        # Adjusts the quantizer curve compression factor
        [Parameter(Mandatory = $false)]
        [Alias("Q")]
        [double]$QComp,

        # Path to the output file
        [Parameter(Mandatory = $true)]
        [Alias("O")]
        [string]$OutputPath,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [Alias("L")]
        [hashtable]$Paths,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        [Alias("T")]
        [int]$TestFrames
    )

    #Gathering HDR metadata
    $HDR = Get-HDRMetadata $InputFile
    #Builds the audio argument array based on user input
    $audio = Set-AudioPreference -InputFile $InputFile -UserChoice $AudioInput -Bitrate $AudioBitrate
    #Builds the subtitle argument array based on user input
    $subs = Set-SubtitlePreference -InputFile $InputFile -UserChoice $Subtitles

    Write-Host "***** STARTING FFMPEG *****" @progressColors
    Write-Host "To view your progress, run " -NoNewline
    Write-Host "Get-Content '$LogPath' -Tail 10" @emphasisColors -NoNewline
    Write-Host " in a different PowerShell session`n`n"

    if ($PSBoundParameters['TestFrames']) {
        Write-Host "Test Run Enabled. Encoding $TestFrames frames`n" @warnColors
        ffmpeg -probesize 100MB -ss 00:01:30 -i $InputFile -frames:v $TestFrames -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
            -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -pix_fmt $HDR.PixelFmt `
            -x265-params "nr-inter=$NrInter`:aq-mode=$AqMode`:aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:level-idc=5.1:open-gop=0:`
            keyint=120:qcomp=$QComp`:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:`
            colorprim=$($HDR.ColorPrimaries):transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):`
            chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr10-opt=1" `
            $OutputPath 2>$Paths.LogPath
    }
    else {
        ffmpeg -probesize 100MB -i $InputFile -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
            -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -pix_fmt $HDR.PixelFmt `
            -x265-params "nr-inter=$NrInter`:aq-mode=$AqMode`:aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:level-idc=5.1:open-gop=0:`
            keyint=120:qcomp=$QComp`:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:`
            colorprim=$($HDR.ColorPrimaries):transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):`
            chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr10-opt=1" `
            $OutputPath 2>$Paths.LogPath
    }
}
