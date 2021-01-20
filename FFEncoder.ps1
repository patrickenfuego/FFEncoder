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
    .INPUTS
        4K HDR video file 

    .OUTPUTS
        crop.txt - File used for auto-cropping
        4K HDR encoded video file

    .NOTES
        For FFEncoder to work, ffmpeg must be in your PATH (consult your OS documentation for info on how to verify this).

        Be sure to include an extension at the end of your output file (.mkv, .mp4, .ts, etc.), or you may be left with a file that will not play. 
 
        ffmpeg cannot decode Dolby Atmos streams, nor can they be easily identified using ffprobe. If you try and copy
        a Dolby Atmos track, the script will fail.

    .PARAMETER Help
        Displays help information for the script
    .PARAMETER TestFrames
        Performs a test encode with the number of frames provided
    .PARAMETER 1080p
        Switch to enable 1080p downsampling while retaining HDR metadata. Still testing
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
        Constant bitrate value for supported codec streams. It is advised that you consult the chosen codec's documentation for recommended bitrate per channel before setting this parameter.
        Codecs that support the use of this parameter (so far) are AAC and EAC3
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
        The x265 preset to be used. Ranges from "placebo" (slowest) to "ultrafast" (fastest)
    .PARAMETER CRF
        Constant rate factor setting for video rate control. This setting attempts to keep quality consistent throughout the encode. Ranges from 0.0 to 51.0. Lower values equate to a    
        higher bitrate (better quality). Recommended: 14.0 - 24.0. At very low values, the output file may actually grow larger than the source. CRF 0.0 is considered lossless.
    .PARAMETER VideoBitrate
        Constant bitrate setting for video rate control. This can be used as an alternative to CRF rate control. Use the 'K' suffix to denote kb/s, or the 'M' suffix for mb/s:
          ex: 10000k (10,000 kb/s)
          ex: 10m (10 mb/s) | 10.5M (10.5 mb/s)
    .PARAMETER Deblock
        Deblock filter settings. The first value represents strength, and the second value represents frequency.
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
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "ConstantBitrate")]
    [ValidateNotNullOrEmpty()]
    [Alias("I")]
    [string]$InputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "ConstantBitrate")]
    [ValidateSet("copy", "c", "copyall", "ca", "aac", "none", "n", "ac3", "dd", "dts", "flac", "f", "eac3")]
    [Alias("A")]
    [string]$Audio = "none",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "ConstantBitrate")]
    [ValidateRange(32, 3000)]
    [Alias("AB", "ABitrate")]
    [int]$AudioBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "ConstantBitrate")]
    [ValidateSet("all", "a", "none", "default", "d", "n", "eng", "fre", "ger", "spa", "dut", "dan", "fin", "nor", "cze", "pol", 
        "chi", "kor", "gre", "rum")]
    [Alias("S")]
    [string]$Subtitles = "default",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "ConstantBitrate")]
    [ValidateSet("placebo", "veryslow", "slower", "slow", "medium", "fast", "faster", "veryfast", "superfast", "ultrafast")]
    [Alias("P")]
    [string]$Preset = "slow",

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [ValidateRange(0.0, 51.0)]
    [Alias("C")]
    [double]$CRF,

    [Parameter(Mandatory = $true, ParameterSetName = "ConstantBitrate")]
    [Alias("VBitrate")]
    [ValidateScript(
        {
            $_ -cmatch "(?<num>\d+\.?\d{0,2})(?<suffix>[K M]+)"
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
                    default { throw "Invalid Suffix. Suffix must be 'K' (kb/s) or 'M' (mb/s)" }
                }
            }
            else { throw "Invalid bitrate value. Example formats: 10000K (10,000 kb/s) | 10M (10 mb/s). Suffixes must be CAPITALIZED" }
        }
    )]
    [string]$VideoBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "ConstantBitrate")]
    [ValidateRange(-6, 6)]
    [Alias("DBF")]
    [int[]]$Deblock = @(-1, -1),

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $true, ParameterSetName = "ConstantBitrate")]
    [ValidateNotNullOrEmpty()]
    [Alias("O")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "ConstantBitrate")]
    [Alias("T", "Test")]
    [int]$TestFrames

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
    if ($InputPath -match "(?<root>.*(?:\\|\/)+)(?<title>.*)\.[a-z 2 4]+") {
        $root = $Matches.root
        $title = $Matches.title
        $cropPath = Join-Path -Path $root -ChildPath "$title`_crop.txt"
        $logPath = Join-Path -Path $root -ChildPath "$title`_encode.log"
    }
    else {
        Write-Host "Could not match root folder pattern. Using OS default path instead..."
        $os = Get-OperatingSystem
        Write-Host $os.OperatingSystem " detected. Using path: <$($os.DefaultPath)>"
        $cropPath = Join-Path -Path $os.DefaultPath -ChildPath "crop.txt"
        $logPath = Join-Path -Path $os.DefaultPath -ChildPath "encode.log"
    }

    Write-Host "Crop file path is: " -NoNewline 
    Write-Host "<$cropPath>" @emphasisColors

    $pathObject = @{
        CropPath = $cropPath
        LogPath  = $logPath
    }
    return $pathObject
}

## End Functions ##

######################################## Main Script Logic ########################################

if ($Help) { Get-Help .\FFEncoder.ps1 -Full; exit }

Import-Module -Name ".\modules\FFTools" -Force

Write-Host
Write-Host "|<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" -ForegroundColor Magenta -BackgroundColor Black -NoNewline
Write-Host " Firing up FFEncoder " @emphasisColors -NoNewline
Write-Host ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>|" -ForegroundColor Magenta -BackgroundColor Black
Write-Host

$startTime = (Get-Date).ToLocalTime()
Write-Host "Start Time: $startTime`n"
#if the output path already exists, prompt to delete the existing file or exit script
if (Test-Path -Path $OutputPath) {
    $title = "Output Path Already Exists"
    $prompt = "Would you like to delete it?"
    $yesPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", 
    "Delete the existing file. you will be asked to confirm again before deletion"
    $noPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&No", 
    "Do not delete the existing file and exit the script. The file must be renamed or deleted before continuing"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yesPrompt, $noPrompt)
    $response = $host.ui.PromptForChoice($title, $prompt, $options, 1)

    switch ($response) {
        0 { 
            Remove-Item -Path $OutputPath -Include "*.mkv", "*.mp4", "*.ts", "*.m2ts", "*.avi" -Confirm 
            if ($?) { Write-Host "`nFile <$OutputPath> was successfully deleted`n" }
            else { Write-Host "<$OutputPath> could not be deleted. Make sure it is not in use by another process.`nExiting script..." @warnColors; exit }
        }
        1 { Write-Host "Please choose a different file name, or delete the existing file. Exiting script..."; exit }
        default { Write-Host "You have somehow reached an unreachable block. Exiting script..." @warnColors; exit }
    }
}
#Generating paths to the crop and log files relative to the input path
$paths = Set-RootPath
$cropFilePath = $paths.CropPath
$logPath = $paths.LogPath
#Creating the crop file
New-CropFile -InputPath $InputPath -CropFilePath $cropFilePath
#Calculating the crop values
$cropDim = Measure-CropDimensions $cropFilePath

#Setting the rate control argument array
if ($PSBoundParameters['CRF']) {
    $rateControl = @('-crf', $CRF)
}
elseif ($PSBoundParameters['VideoBitrate']) {
    $rateControl = @('-b:v', $VideoBitrate)
}
else {
    Write-Warning "There was an error verifying the video quality parameter. This statement should be unreachable. CRF 17.0 will be used"
    $rateControl = @('-crf', 17.0) 
}

#Building parameters for Invoke-FFMpeg function
$ffmpegParams = @{
    InputFile      = $InputPath
    CropDimensions = $cropDim
    AudioInput     = $Audio
    AudioBitrate   = $AudioBitrate
    Subtitles      = $Subtitles
    Preset         = $Preset
    RateControl    = $rateControl
    Deblock        = $Deblock
    OutputPath     = $OutputPath
    LogPath        = $logPath
    TestFrames     = $TestFrames
}
Invoke-FFMpeg @ffmpegParams

$endTime = (Get-Date).ToLocalTime()
$totalTime = $endTime - $startTime
#Display a quick view of the finished log file, the end time and total encoding time
Get-Content -Path $logPath -Tail 8
Write-Host "`nEnd time: " $endTime
Write-Host "Total Encoding Time: $($totalTime.Hours) Hours, $($totalTime.Minutes) Minutes, $($totalTime.Seconds) Seconds`n" 