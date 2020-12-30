function Invoke-FFMpeg  {      
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [Alias("InFile")]
        [string]$InputFile,

        # Parameter help description
        [Parameter(AttributeValues)]
        [Alias("Crop")]
        [int[]]$CropDimensions,

        # Parameter help description
        [Parameter(AttributeValues)]
        [Alias("Audio", "A")]
        [string]$AudioType,

        # Parameter help description
        [Parameter(AttributeValues)]
        [Alias("P")]
        [string]$Preset,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [int]$CRF = 17.0,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [int[]]$Deblock = @(-1, -1)

    )

    $audio = Set-AudioPreference $AudioType

    Write-Host "Starting ffmpeg...`nTo view your progress, run the command 'gc path\to\crop.txt -Tail 10' in a different PowerShell session"
    if ($Test) {
        ffmpeg -probesize 100MB -ss 00:01:00 -i $InputFile $audio -frames:v 1000 -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" `
            -color_range tv -color_primaries 9 -color_trc 16 -colorspace 9 -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($deblock[0]),$($deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=bt2020:`
            transfer=smpte2084:colormatrix=bt2020nc:chromaloc=2:$masterDisplay`L($MaxLuminance,$MinLuminance):max-cll=$MaxCLL,$MaxFAL`:hdr-opt=1" `
            $OutputPath 2>$logPath
    }
    else {
        ffmpeg -probesize 100MB -i $InputFile -c:a copy -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" `
            -color_range tv -color_primaries 9 -color_trc 16 -colorspace 9 -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
            -x265-params "level-idc=5.1:keyint=120:deblock=$($deblock[0]),$($deblock[1]):sao=0:rc-lookahead=48:subme=4:colorprim=bt2020:`
            transfer=smpte2084:colormatrix=bt2020nc:chromaloc=2:$masterDisplay`L($MaxLuminance,$MinLuminance):max-cll=$MaxCLL,$MaxFAL`:hdr-opt=1" `
            $OutputPath 2>$logPath
    }
}
