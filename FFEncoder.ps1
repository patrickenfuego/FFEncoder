<#
    .SYNOPSIS
        Script for encoding 4K HDR video content using ffmpeg and x265
    
    .DESCRIPTION
        This script is meant to make video encoding easier with ffmpeg. Instead of manually changing
        the script parameters for each encode, you can pass dynamic parameters to this script and it  
        will use the arguments as needed. Supports 2160p HDR encoding with automatic fetching ofHDR 
        metadata. I plan to add 1080p soon.   

    .EXAMPLE
        ## Windows ##
        .\FFEncoder.ps1 -InputPath "Path\To\file.mkv" -CRF 16.5 -Preset medium -Deblock -3,-3 -Audio aac -AacBitrate 112 -OutputPath "Path\To\Encoded\File.mkv"
    .EXAMPLE
        ## MacOS or Linux ##
        ./FFEncoder.ps1 -InputPath "Path/To/file.mp4" -CRF 16.5 -Preset medium -Deblock -2,-2 -Audio none -OutputPath "Path/To/Encoded/File.mp4"
    .EXAMPLE
        .\FFEncoder "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -CRF 20 -a copy -dbf -3,-3 -o "C:\Users\user\Videos\Ex Machina Test.mkv" -t 500
    .EXAMPLE
        ./FFEncoder -Help

    .INPUTS
        4K HDR video file 

    .OUTPUTS
        crop.txt - File used for auto-cropping
        4K HDR encoded video file

    .NOTES
        For FFEncoder to work, ffmpeg must be in your PATH (consult your OS documentation for info on how to verify this).

        Be sure to include ".mkv" or ".mp4" at the end of your output file, or you will be left with a file that will not play. 

        FFEncoder will automatically retrieve HDR metadata for you using the Get-HDRMetadata function from FFTools module. 

    .PARAMETER Help
        Displays help information for the script. Only required for the "Help" parameter set
    .PARAMETER TestFrames
        Performs a test encode with the number of frames provided. Default is 1000 frames
    .PARAMETER 1080p
        Switch to enable 1080p encode. Removes HDR arguments (still testing, don't use)
    .PARAMETER InputPath
        Location of the file to be encoded
    .PARAMETER Audio
        Audio encoding option. FFEncoder has 3 audio options:
            1. copy/c - Pass through the primary audio stream without encoding
            2. none/n - Excludes the audio stream entirely
            3. aac    - Convert primary audio stream to AAC. Choosing this option will display a console prompt asking you to select the quality level (1-5)
    .PARAMETER AacBitrate
        The constant bitrate for each audio channel (in kb/s). If the audio stream is 7.1 (8 CH), the total bitrate will be 8 * AacBitrate. Default is 64 kb/s per channel. 
    .PARAMETER Preset
        The x265 preset to be used. Ranges from "placebo" (slowest) to "ultrafast" (fastest)
    .PARAMETER CRF
        Constant rate factor setting. Ranges from 0.0 to 51.0. Lower values equate to a higher bitrate
    .PARAMETER Deblock
        Deblock filter settings. The first value represents strength, and the second value represents frequency
    .PARAMETER OutputPath
        Location of the encoded output video file
    
    .lINK
        GitHub Page - https://github.com/patrickenfuego/FFEncoder
    .LINK
        FFMpeg documentation - https://ffmpeg.org
    .LINK
        x265 HEVC Documentation - https://x265.readthedocs.io/en/master/introduction.html

#>

[CmdletBinding(DefaultParameterSetName = "2160p")]
param (
    [Parameter(Mandatory = $true, ParameterSetName = "Help")]
    [Alias("H", "/?", "?")]
    [switch]$Help,

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "1080p")]
    [ValidateNotNullOrEmpty()]
    [Alias("I")]
    [string]$InputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
    [ValidateSet("copy", "aac", "none", "c", "n")]
    [Alias("A")]
    [string]$Audio = "none",

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
    [ValidateRange(32, 160)]
    [Alias("AQ", "AACQ")]
    [int]$AacBitrate = 64,

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
    [ValidateSet("placebo", "veryslow", "slower", "slow", "medium", "fast", "faster", "veryfast", "superfast", "ultrafast")]
    [Alias("P")]
    [string]$Preset = "slow",

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
    [ValidateRange(0.0, 51.0)]
    [double]$CRF = 16.0,

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
    [ValidateRange(-6, 6)]
    [Alias("DBF")]
    [int[]]$Deblock = @(-1, -1),

    [Parameter(Mandatory = $true, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $true, ParameterSetName = "1080p")]
    [ValidateNotNullOrEmpty()]
    [Alias("O")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
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
    if ($InputPath -match "(?<root>.*(?:\\|\/)+)(?<title>.*)\.m[a-z 4]+") {
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

Import-Module -Name ".\modules\FFTools"

Write-Host "`nFiring up FFEncoder...`n`n" @emphasisColors
$startTime = (Get-Date).ToLocalTime()
#if the output path already exists, prompt to delete the existing file or exit script
if (Test-Path -Path $OutputPath) {
    $title = "Output Path Already Exists"
    $prompt = "Would you like to delete it?"
    $yesPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&yes", "Delete the existing file. you will be asked to confirm again before deletion"
    $noPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&no", "Do not delete the existing file and exit the script. The file must be renamed or deleted before continuing"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yesPrompt, $noPrompt)
    $response = $host.ui.PromptForChoice($title, $prompt, $options, 1)

    switch ($response) {
        0 { 
            Remove-Item -Path $OutputPath -Include "*.mkv", "*.mp4" -Confirm 
            if ($?) { Write-Host "`nFile <$OutputPath> was successfully deleted`n" }
            else { Write-Host "<$OutputPath> could not be deleted. Make sure it is not in use by another program.`nExiting script..."; exit }
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
#Gathering HDR metadata
$hdrData = Get-HDRMetadata $InputPath
#Calculating the crop values
$cropDim = Measure-CropDimensions $cropFilePath
#Building parameters for Invoke-FFMpeg function
$ffmpegParams = @{
    InputFile      = $InputPath
    CropDimensions = $cropDim
    AudioInput     = $Audio
    AacBitrate     = $AacBitrate
    Preset         = $Preset
    CRF            = $CRF
    Deblock        = $Deblock
    HDR            = $hdrData
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