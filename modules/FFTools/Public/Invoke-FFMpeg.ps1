function Invoke-FFMpeg  {      
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias("InFile", "I")]
        [string]$InputFile,

        # Parameter help description
        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Crop", "CropDim")]
        [int[]]$CropDimensions,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [Alias("Audio", "A")]
        [string]$AudioInput = "none",

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset = "slow",

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [int]$CRF = 17.0,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [Alias("DBF")]
        [int[]]$Deblock = @(-1, -1),

        # Parameter help description
        [Parameter(Mandatory = $true, Position = 2)]
        [hashtable]$HDR,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [Alias("O")]
        [string]$OutputPath,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [Alias("L")]
        [string]$LogPath,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [switch]$Test

    )

    $audio = Set-AudioPreference $InputFile $AudioInput

    Write-Host "Starting ffmpeg...`nTo view your progress, run 'gc path\to\crop.txt -Tail 10' in a different PowerShell session"
    if ($Test) {
        ffmpeg -probesize 100MB -ss 00:01:00 -i $InputFile $audio -frames:v 1000 -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
            -color_range tv -c:v libx265 -preset $Preset -crf $CRF -pix_fmt $HDR.PixelFmt `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=$($HDR.ColorPrimaries):`
            transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr-opt=1" `
            $OutputPath 2>$logPath
    }
    else {
        ffmpeg -probesize 100MB -ss 00:01:00 -i $InputFile $audio -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
            -color_range tv -c:v libx265 -preset $Preset -crf $CRF -pix_fmt $HDR.PixelFmt `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=$($HDR.ColorPrimaries):`
            transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr-opt=1" `
            $OutputPath 2>$logPath
    }
}
