function Invoke-FFMpeg  {      
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [Alias("InFile")]
        [string]$InputFile,

        # Parameter help description
        [Parameter(AttributeValues)]
        [Alias("Crop", "CropDim")]
        [int[]]$CropDimensions,

        # Parameter help description
        [Parameter(AttributeValues)]
        [Alias("Audio", "A")]
        [string]$AudioInput,

        # Parameter help description
        [Parameter(AttributeValues)]
        [Alias("P")]
        [string]$Preset,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [int]$CRF = 17.0,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [int[]]$Deblock = @(-1, -1),

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [hashtable]$HDR

    )

    $audio = Set-AudioPreference $InputFile $AudioInput

    Write-Host "Starting ffmpeg...`nTo view your progress, run 'gc path\to\crop.txt -Tail 10' in a different PowerShell session"
    if ($Test) {
        ffmpeg -probesize 100MB -ss 00:01:00 -i $InputFile $audio -frames:v 1000 -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" `
            -color_range tv -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=$($HDR.ColorPrimaries):`
            transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr-opt=1" `
            $OutputPath 2>$logPath
    }
    else {
        ffmpeg -probesize 100MB -ss 00:01:00 -i $InputFile $audio -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" `
            -color_range tv -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=$($HDR.ColorPrimaries):`
            transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr-opt=1" `
            $OutputPath 2>$logPath
    }
}
