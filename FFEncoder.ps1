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
        ## Copy the primary audio stream and transcode a second audio stream to FDK AAC 2.0 using VBR 5 ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio c -Audio 2 faac -ABitrate2 5 -Stereo2 -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Convert primary audio stream to AAC at 112 kb/s per channel ##
        ./FFEncoder.ps1 -i "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -Audio aac -AacBitrate 112 -OutputPath "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Encode the video at 25 mb/s using the -VideoBitrate parameter ##
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
        Audio selection options. FFEncoder has 5 audio options:
            1. copy/c       - Pass through the primary audio stream without re-encoding
            2. copyall/ca   - Pass through all audio streams without re-encoding
            3. none/n       - No audio will be copied
            4. aac          - Convert primary audio stream to AAC. Default setting is 512 kb/s for multi-channel, and 128 kb/s for stereo
            5. fdkaac/faac  - Convert primary audio stream to AAC using FDK AAC. Default setting is -vbr 3
            6. dts          - Convert/copy DTS to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing DTS stream will be copied
            7. ac3          - Convert/copy AC3 to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing AC3 stream will be copied
            8. eac3         - Convert/copy E-AC3 to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing E-AC3 stream will be copied
            9. flac/f       - Convert the primary audio stream to FLAC lossless audio
            10. Stream #    - Copy an audio stream by its identifier in ffmpeg 
    .PARAMETER AudioBitrate
        Specifies the bitrate for the chosen codec (in kb/s). Values 1-5 are used to signal -vbr with libfdk_aac
    .PARAMETER Stereo
        Switch to downmix the paired audio stream to stereo
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
    .PARAMETER NoiseReduction
        Filter to help reduce high frequency noise (such as film grain). First value represents intra frames, and the second value represents inter frames
    .PARAMETER BFrames
        The number of consecutive B-Frames within a GOP. This is especially helpful for test encodes to determine the ideal number of B-Frames to use
    .PARAMETER BIntra 
        Enables the evaluation of intra modes in B slices. Accepted values are 0 (off) or 1 (on). Has a minor impact on performance 
    .PARAMETER Subme
        The amount of subpel motion refinement to perform. At values larger than 2, chroma residual cost is included. Has a large performance impact 
    .PARAMETER QComp
        Sets the quantizer curve compression factor, which effects the bitrate variance throughout the encode
    .PARAMETER OutputPath
        Location of the encoded output video file
    .PARAMETER RemoveFiles
        Switch to delete extraneous files generated by the script. The input, output, and report files will not be deleted
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
    [int]$BFrames,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 1)]
    [Alias("BINT")]
    [int]$BIntra,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 7)]
    [Alias("SM", "SPM")]
    [int]$Subme,

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $true, ParameterSetName = "Pass")]
    [ValidateNotNullOrEmpty()]
    [Alias("O")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("T", "Test")]
    [int]$TestFrames,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [alias("Del", "RM")]
    [switch]$RemoveFiles
)

## Global Variables ##

#Change these to modify the default path for generated files when a regex match cannot be made
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
function Set-ScriptPaths {
    if ($InputPath -match "(?<root>.*(?:\\|\/)+)(?<title>.*)\.(?<ext>[a-z 2 4]+)") {
        $root = $Matches.root
        $title = $Matches.title
        $ext = $Matches.ext
        if ($OutputPath -match "(?<oRoot>.*(?:\\|\/)+)(?<oTitle>.*)\.(?<oExt>[a-z 2 4]+)") {
            $oRoot = $Matches.oRoot
            $oTitle = $Matches.oTitle
            $oExt = $Matches.oExt
        }
        #If regex match can't be made on the output path, use input matches instead
        else {
            $oRoot = $root
            $oTitle = $title
            $oExt = $ext
        }
        #Creating path strings used throughout the script
        $cropPath = Join-Path -Path $root -ChildPath "$title`_crop.txt"
        $logPath = Join-Path -Path $root -ChildPath "$title`_encode.log"
        $x265Log = Join-Path -Path $root -ChildPath "x265_2pass.log"
        $stereoPath = Join-Path -Path $root -ChildPath "$oTitle`_stereo.$oExt"
        $remuxPath = Join-Path -Path $oRoot -ChildPath "$oTitle`_stereo-remux.$oExt"
        $reportPath = Join-Path -Path $root -ChildPath "$oTitle.rep"
    }
    #Regex match could not be made on the folder pattern
    else {
        Write-Host "Could not match root folder pattern. Using OS default path instead..."
        $os = Get-OperatingSystem
        Write-Host $os.OperatingSystem " detected. Using path: <$($os.DefaultPath)>"
        #Creating path strings used throughout the script
        $cropPath = Join-Path -Path $os.DefaultPath -ChildPath "crop.txt"
        $logPath = Join-Path -Path $os.DefaultPath -ChildPath "encode.log"
        $x265Log = Join-Path -Path $os.DefaultPath -ChildPath "x265_2pass.log"
        $stereoPath = Join-Path -Path $os.DefaultPath -ChildPath "stereo.mkv"
        $remuxPath = Join-Path -Path $os.DefaultPath -ChildPath "stereo-remux.mkv"
        $reportPath = Join-Path -Path $os.DefaultPath -ChildPath "report.rep"
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
        Title      = $oTitle
        ReportPath = $reportPath
    }
    return $pathObject
}

## End Functions ##

######################################## Main Script Logic ########################################

if ($Help) { Get-Help .\FFEncoder.ps1 -Full; exit }
if (!(Test-Path -Path $InputPath)) { throw "Input path does not exist. Check the path and try again" }

Import-Module -Name ".\modules\FFTools" -Force

$stopwatch = [System.Diagnostics.stopwatch]::StartNew()
$startTime = (Get-Date).ToLocalTime()

Write-Host
Write-Host "|<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" -ForegroundColor Magenta -BackgroundColor Black -NoNewline
Write-Host " Firing up FFEncoder " @emphasisColors -NoNewline
Write-Host ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>|" -ForegroundColor Magenta -BackgroundColor Black
Write-Host

Write-Host "Start Time: $startTime`n"
#Generating paths to various files
$paths = Set-ScriptPaths
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
    Write-Warning "There was an error verifying rate control. This statement should be unreachable. CRF 18.0 will be used"
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
    BIntra         = $BIntra
    Subme          = $Subme 
    Paths          = $paths
    TestFrames     = $TestFrames
}

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

#Display a quick view of the finished log file, the end time and total encoding time
Get-Content -Path $Paths.LogPath -Tail 8
$endTime = (Get-Date).ToLocalTime()
Write-Host "`nEnd time: $endTime"
$stopwatch.Stop()
"Encoding Time: {0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds`n" -f $stopwatch.Elapsed
#Generate the report file
Write-Report -DateTimes @($startTime, $endTime) -Duration $stopwatch -Paths $paths
#Delete extraneous files if switch is present
if ($PSBoundParameters['RemoveFiles']) {
    Write-Host "Removing extra files..." -NoNewline
    Write-Host "The input, output, and report files will not be deleted" @warnColors
    Get-ChildItem -Path $paths.Root | ForEach-Object { 
        Remove-Item -LiteralPath $_.Fullname -Include "*.txt", "*.log", "muxed.mkv", "*.cutree", "*_stereo.mkv"
    }
}
