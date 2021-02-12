<#
    .SYNOPSIS
        Script for encoding 4K HDR video content using ffmpeg and x265
    .DESCRIPTION
        This script is meant to make video encoding easier with ffmpeg. Instead of manually changing
        the script parameters for each encode, you can pass dynamic parameters to this script and it  
        will use the arguments as needed. Supports 2160p HDR encoding with automatic fetching of HDR 
        metadata, automatic cropping, and multiple audio & subtitle options.   
    .EXAMPLE
        ## Windows ##
        .\FFEncoder.ps1 -InputPath "Path\To\file.mkv" -CRF 16.5 -Preset medium -Deblock -3,-3 -Audio copy -OutputPath "Path\To\Encoded\File.mkv"
    .EXAMPLE
        ## MacOS or Linux ##
        ./FFEncoder.ps1 -InputPath "Path/To/file.mp4" -CRF 16.5 -Preset medium -Deblock -2,-2 -Audio none -OutputPath "Path/To/Encoded/File.mp4"
    .EXAMPLE 
        ## Test run. Encode only 10 frames ##
        ./FFEncoder.ps1 "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -CRF 20.0 -Audio copy -Subtitles none -TestFrames 10 -OutputPath "~/Movies/Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE
        ## Using shorthand parameter aliases ##
        .\FFEncoder.ps1 "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -c 20.5 -a c -dbf -3,-3 -a copyall -s d -o "C:\Users\user\Videos\Ex Machina Test.mkv" -t 500
    .EXAMPLE
        ## Copy English subtitles and all audio streams ##
        ./FFEncoder.ps1 -i "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -CRF 22.0 -Subtitles eng -Audio copyall -o "~/Movies/Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Copy existing AC3 stream, or transcode to AC3 if no existing streams are found ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio ac3 -Subtitles default -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Copy existing DTS stream, or transcode to DTS if no existing streams are found ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio dts -Subtitles default -OutputPath "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Convert primary audio stream to AAC at 112 kb/s per channel ##
        ./FFEncoder.ps1 -i "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -Audio aac -AacBitrate 112 -OutputPath "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Encode the video to 25 mb/s using the -VideoBitrate parameter ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio copy -VideoBitrate 25M -OutputPath "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv" 
    .EXAMPLE 
        ## Adjust psycho visual settings and aq-mode level/strength ##
        ./FFEncoder.ps1 "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -PsyRd 4.0 -PsyRdoq 1.50 -AqMode 1 -AqStrength 0.90 -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .INPUTS
        4K HDR video file 
    .OUTPUTS
        crop.txt - File used for auto-cropping
        4K HDR encoded video file
    .NOTES
        For FFEncoder to work, ffmpeg must be in your system PATH (consult your OS documentation for info on how to verify this)

        Be sure to include an extension at the end of your output file (.mkv, .mp4, .ts, etc.), or you may be left with a file that will not play
 
        ffmpeg cannot decode Dolby Atmos streams, nor can the metadata be identified using ffprobe. If you try and copy a Dolby Atmos track, THE SCRIPT WILL FAIL.
        This is not a flaw in the script, but rather a limitation of ffmpeg
    .PARAMETER Help
        Displays help information for the script
    .PARAMETER TestFrames
        Performs a test encode with the number of frames provided
    .PARAMETER InputPath
        Location of the file to be encoded
    .PARAMETER Audio
        Audio encoding option. FFEncoder has 5 audio options:
            1. copy/c       - Pass through the primary audio stream without re-encoding
            2. copyall/ca   - Pass through all audio streams without re-encoding
            2. none/n       - No audio will be copied. This is useful for Dolby Atmos tracks
            3. aac          - Convert primary audio stream to AAC. Default setting is 64 kb/s per channel. Use the -AacBitrate parameter to specify a custom value
            4. dts          - If there is an existing DTS Audio stream, it will be copied instead of the primary stream. Otherwise, the primary stream will be transcoded to DTS 
                              (This feature is EXPERIMENTAL. Only transcode to DTS for compatibility purposes)
            5. ac3          - Dolby Digital. If there is an existing AC3 audio stream, it will be copied instead of the primary stream. Otherwise, the primary stream will be transcoded to AC3
            6. flac/f       - Convert the primary audio stream to FLAC lossless audio 
    .PARAMETER AudioBitrate
        Constant bitrate value for supported codec streams. It is advised that you consult the chosen codec's documentation for the recommended bitrate per channel before setting this parameter.
        Codecs that support the use of this parameter (so far) are AAC, EAC3, DTS, and AAC. Unit is always kb/s, and the 'k' should be excluded from the passed value 
    .PARAMETER Subtitles
        Supports passthrough of embedded subtitles with the following options and languages:

        - All               - "all"  / "a"
        - None              - "none" / "n"
        - Default (first)   - "default" / "d"
        - English           - "eng"
        - French            - "fra"
        - German            - "ger"
        - Spanish           - "spa"
        - Dutch             - "dut"
        - Danish            - "dan"
        - Finnish           - "fin"
        - Norwegian         - "nor"
        - Czech             - "cze"
        - Polish            - "pol"
        - Chinese           - "chi"
        - Korean            - "kor"
        - Greek             - "gre"
        - Romanian          - "rum"
    .PARAMETER Preset
        The x265 preset to be used. Ranges from "placebo" (slowest) to "ultrafast" (fastest). Slower presets improve quality by enabling additional, more expensive, x265 parameters at the expensive of encoding time.
        Recommended presets (depending on source and purpose) are slow, medium, or fast. 
    .PARAMETER CRF
        Constant rate factor setting for video rate control. This setting attempts to keep quality consistent from frame to frame, and is most useful for targeting a specific quality level.    
        Ranges from 0.0 to 51.0. Lower values equate to a higher bitrate (better quality). Recommended: 14.0 - 24.0. At very low values, the output file may actually grow larger than the source.
        CRF 4.0 is considered mathematically lossless in x265 (vs. CRF 0.0 in x264)
    .PARAMETER VideoBitrate
        Average bitrate (ABR) setting for video rate control. This can be used as an alternative to CRF rate control, and is most useful for targeting a specific file size (bitrate / duration).
        Use the 'K' suffix to denote kb/s, or the 'M' suffix for mb/s:
            ex: 10000k (10,000 kb/s)
            ex: 10m (10 mb/s) | 10.5M (10.5 mb/s)
    .PARAMETER Deblock
        Deblock filter settings. The first value represents strength, and the second value represents frequency
    .PARAMETER AqMode
        x265 AQ mode setting. Ranges from 0 (disabled) - 4. See x265 documentation for more info on AQ Modes and how they work
    .PARAMETER AqStrength
        Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates
    .PARAMETER PsyRd
        Psycho-visual enhancement. Higher values of PsyRd strongly favor similar energy over blur. See x265 documentation for more info
    .PARAMETER PsyRdoq
        Psycho-visual enhancement. Favors high AC energy in the reconstructed image, but it less efficient than PsyRd. See x265 documentation for more info
    .PARAMETER NrInter
        Filter to help reduce high frequency noise (such as film grain) throughout a GOP, and can be useful for controlling the bitrate of grainy sources. Default disabled. 
    .PARAMETER OutputPath
        Location of the encoded output video file
    .lINK
        GitHub Page - https://github.com/patrickenfuego/FFEncoder
    .LINK
        FFMpeg documentation - https://ffmpeg.org
    .LINK
        x265 HEVC Documentation - https://x265.readthedocs.io/en/master/introduction.html

#>

[CmdletBinding(DefaultParameterSetName = "CRF")]
param (
    [Parameter(Mandatory = $true, ParameterSetName = "Help")]
    [Alias("H", "/?", "?")]
    [switch]$Help,

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Pass")]
    [ValidateNotNullOrEmpty()]
    [Alias("I")]
    [string]$InputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("copy", "c", "copyall", "ca", "aac", "none", "n", "ac3", "dd", "dts", "flac", "f", "eac3", 
        "fdkaac", "faac", 1, 2, 3, 4, 5)]
    [Alias("A")]
    [string]$Audio = "copy",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 3000)]
    [Alias("AB", "ABitrate")]
    [int]$AudioBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("2CH", "ST")]
    [switch]$Stereo,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("copy", "c", "copyall", "ca", "aac", "none", "n", "ac3", "dd", "dts", "flac", "f", "eac3", 
        "fdkaac", "faac", 1, 2, 3, 4, 5)]
    [Alias("A2")]
    [string]$Audio2 = "none",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 3000)]
    [Alias("AB2", "ABitrate2")]
    [int]$AudioBitrate2,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("2CH2", "ST2")]
    [switch]$Stereo2,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("all", "a", "none", "default", "d", "n", "eng", "fre", "ger", "spa", "dut", "dan", "fin", "nor", "cze", "pol", 
        "chi", "kor", "gre", "rum")]
    [Alias("S")]
    [string]$Subtitles = "default",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("placebo", "veryslow", "slower", "slow", "medium", "fast", "faster", "veryfast", "superfast", "ultrafast")]
    [Alias("P")]
    [string]$Preset = "slow",

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [ValidateRange(0.0, 51.0)]
    [Alias("C")]
    [double]$CRF,

    [Parameter(Mandatory = $true, ParameterSetName = "Pass")]
    [Alias("VBitrate")]
    [ValidateScript(
        {
            $_ -cmatch "(?<num>\d+\.?\d{0,2})(?<suffix>[K k M]+)"
            if ($Matches) {
                switch ($Matches.suffix) {
                    "K" { 
                        if ($Matches.num -gt 99000 -or $Matches.num -lt 1000) {
                            throw "Bitrate out of range. Must be between 1,000-99,000 kb/s"
                        }
                        else { $true }
                    }
                    "M" {
                        if ($Matches.num -gt 99 -or $Matches.num -le 1) {
                            throw "Bitrate out of range. Must be between 1-99 mb/s"
                        }
                        else { $true }
                    }
                    default { throw "Invalid Suffix. Suffix must be 'K/k' (kb/s) or 'M' (mb/s)" }
                }
            }
            else { throw "Invalid bitrate input. Example formats: 10000k (10,000 kb/s) | 10M (10 mb/s)" }
        }
    )]
    [string]$VideoBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 2)]
    [int]$Pass = 2,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(-6, 6)]
    [Alias("DBF")]
    [int[]]$Deblock = @(-2, -2),

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 4)]
    [Alias("AQM")]
    [int]$AqMode = 2,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.0, 3.0)]
    [Alias("AQS")]
    [double]$AqStrength = 1.00,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.0, 5.0)]
    [Alias("PRD")]
    [double]$PsyRd = 2.00,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.0, 50.0)]
    [Alias("PRDQ")]
    [double]$PsyRdoq = 1.00,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 2000)]
    [Alias("NR")]
    [int[]]$NoiseReduction = @(0, 0),

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.5, 1.0)]
    [Alias("Q")]
    [double]$QComp = 0.60,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 16)]
    [Alias("B")]
    [int]$BFrames = 4,

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $true, ParameterSetName = "Pass")]
    [ValidateNotNullOrEmpty()]
    [Alias("O")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("T", "Test")]
    [int]$TestFrames

    # [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    # [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    # [alias("Del", "RMFiles")]
    # [switch]$RemoveFiles

)

## Global Variables ##

#Change these to modify the default path for crop files when a regex match cannot be made
$macDefaultPath = '~/Movies'
$linuxDefaultPath = '~/Videos'
$windowsDefaultPath = "C:\Users\$env:USERNAME\Videos"

## End Global Variables ##

## Functions ##

#Returns an object with OS related information
function Get-OperatingSystem {
    if ($isMacOs) {
        $osInfo = @{
            OperatingSystem = "MacOS"
            DefaultPath     = $macDefaultPath
        } 
    }
    elseif ($isLinux) {
        $osInfo = @{
            OperatingSystem = "Linux"
            DefaultPath     = $linuxDefaultPath
        }
    }
    elseif ($env:OS -match "Windows") {
        $osInfo = @{
            OperatingSystem = "Windows"
            DefaultPath     = $windowsDefaultPath
        }
    }
    else { throw "Fatal error...could not detect operating system." }

    return $osInfo
}

#Returns an object containing the paths to the crop file and log file relative to the input path
function Set-RootPath {
    if ($InputPath -match "(?<root>.*(?:\\|\/)+)(?<title>.*)\.(?<ext>[a-z 2 4]+)") {
        $root = $Matches.root
        $title = $Matches.title
        $ext = $Matches.ext
        $cropPath = Join-Path -Path $root -ChildPath "$title`_crop.txt"
        $logPath = Join-Path -Path $root -ChildPath "$title`_encode.log"
        $x265Log = Join-Path -Path $root -ChildPath "x265_2pass.log"
        $stereoPath = Join-Path -Path $root -ChildPath "$title`_stereo.$ext"
        if ($OutputPath -match "(?<oRoot>.*(?:\\|\/)+)(?<oTitle>.*)\.(?<oExt>[a-z 2 4]+)") {
            $remuxPath = Join-Path -Path $Matches.oRoot -ChildPath "$($Matches.oTitle)`_stereo-remux.$($Matches.oExt)"
        }
        else { $remuxPath = Join-Path -Path $root -ChildPath "$title`_stereo-remux.$ext" }
    }
    else {
        Write-Host "Could not match root folder pattern. Using OS default path instead..."
        $os = Get-OperatingSystem
        Write-Host $os.OperatingSystem " detected. Using path: <$($os.DefaultPath)>"
        $cropPath = Join-Path -Path $os.DefaultPath -ChildPath "crop.txt"
        $logPath = Join-Path -Path $os.DefaultPath -ChildPath "encode.log"
        $x265Log = Join-Path -Path $os.DefaultPath -ChildPath "x265_2pass.log"
        $stereoPath = Join-Path -Path $os.DefaultPath -ChildPath "stereo.mkv"
        $RemuxPath = Join-Path -Path $os.DefaultPath -ChildPath "$title`_stereo-remux.mkv"
    }

    Write-Host "Crop file path is: " -NoNewline 
    Write-Host "<$cropPath>" @emphasisColors

    $pathObject = @{
        InputFile  = $InputPath
        Root       = $root
        RemuxPath  = $remuxPath
        StereoPath = $stereoPath
        CropPath   = $cropPath
        LogPath    = $logPath
        X265Log    = $x265Log
        OutputFile = $OutputPath
    }
    return $pathObject
}

## End Functions ##

######################################## Main Script Logic ########################################

if ($Help) { Get-Help .\FFEncoder.ps1 -Full; exit }
if (!(Test-Path -Path $InputPath)) { throw "Input path does not exist. Check the path and try again" }

Import-Module -Name ".\modules\FFTools" -Force

Write-Host
Write-Host "|<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" -ForegroundColor Magenta -BackgroundColor Black -NoNewline
Write-Host " Firing up FFEncoder " @emphasisColors -NoNewline
Write-Host ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>|" -ForegroundColor Magenta -BackgroundColor Black
Write-Host

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Host "Start Time: $((Get-Date).ToLocalTime())`n"
#Generating paths to various files
$paths = Set-RootPath
#if the output path already exists, prompt to delete the existing file or exit script
if (Test-Path -Path $paths.OutputFile) { Remove-FilePrompt -Path $paths.OutputFile -Type "Primary" }
elseif (Test-Path -Path $paths.RemuxPath) { Remove-FilePrompt -Path $paths.RemuxPath -Type "Primary" }
if ($paths.InputFile) { 
    #Creating the crop file
    New-CropFile -InputPath $paths.InputFile -CropFilePath $paths.CropPath -Count 1
 }
 else { throw "Input path could not be found" }

#Calculating the crop values
$cropDim = Measure-CropDimensions $paths.CropPath

#Setting the rate control argument array
$rcTwoPass = $false
if ($PSBoundParameters['CRF']) {
    $rateControl = @('-crf', $CRF)
}
elseif ($PSBoundParameters['VideoBitrate']) {
    $rateControl = @('-b:v', $VideoBitrate)
    if ($Pass -eq 2) { $rcTwoPass = $true }
}
else {
    Write-Warning "There was an error verifying the video quality parameter. This statement should be unreachable. CRF 18.0 will be used"
    $rateControl = @('-crf', 18.0) 
}
#Condensing audio parameters
$audioHash1 = @{
    Audio   = $Audio
    Bitrate = $AudioBitrate
    Stereo  = $Stereo
}
if ($PSBoundParameters['Audio2']) {
    $audioHash2 = @{
        Audio   = $Audio2
        Bitrate = $AudioBitrate2
        Stereo  = $Stereo2
    }
}
else { $audioHash2 = $null }
$audioArray = @($audioHash1, $audioHash2)

#Building parameters for ffmpeg functions
$ffmpegParams = @{
    CropDimensions = $cropDim
    AudioInput     = $audioArray
    Subtitles      = $Subtitles
    Preset         = $Preset
    RateControl    = $rateControl
    Deblock        = $Deblock
    AqMode         = $AqMode
    AqStrength     = $AqStrength
    PsyRd          = $PsyRd
    PsyRdoq        = $PsyRdoq
    NoiseReduction = $NoiseReduction
    Qcomp          = $QComp
    BFrames        = $BFrames
    Paths          = $paths
    TestFrames     = $TestFrames
}

#Setting which FFMpeg function to call
if ($rcTwoPass) { Invoke-TwoPassFFMpeg @ffmpegParams }
else { Invoke-FFMpeg @ffmpegParams }

if (@('copy', 'c', 'copyall', 'ca') -contains $Audio -and $Stereo2) {
    Write-Host "`nMultiplexing stereo track back into the output file..." @progressColors
    ffmpeg -i $OutputPath -i $paths.StereoPath -loglevel error -map 0 -map 1:a -c copy -y $paths.RemuxPath
    Write-Host "Cleaning up..." -NoNewline
    Remove-Item -Path $paths.OutputFile
    if ($?) { Write-Host "done!" @progressColors; Write-Host "`n" }
    else { Write-Host ""; Write-Host "Could not delete the original output file. It may be in use by another process" @warnColors } 
}
# if ($PSBoundParameters['RemoveFiles']) {
#     Write-Host "`nDeleting generated files..."
#     Get-Content -Path $Paths.LogPath -Tail 8
# }

#Display a quick view of the finished log file, the end time and total encoding time
Get-Content -Path $Paths.LogPath -Tail 8
Write-Host "`nEnd time: $((Get-Date).ToLocalTime())"
$Stopwatch.Stop()
"Encoding Time: {0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds" -f $Stopwatch.Elapsed
Write-Host ""