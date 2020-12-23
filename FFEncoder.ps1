<#
    .SYNOPSIS
        Script for encoding 4K HDR video content using ffmpeg and x265
    
    .DESCRIPTION
        This script is meant to make video encoding easier with ffmpeg. Instead of manually changing
        the script parameters for each encode, you can pass dynamic parameters to this script and it  
        will use the arguments as needed. Supports 2160p HDR encoding, and I plan to add 1080p soon.   

    .EXAMPLE
        ## Windows ##
        .\FFEncoder.ps1 -InputPath "Path\To\file" -CRF 16.5 -Preset medium -Deblock -2,-2 -MaxLuminance 1000 -MinLuminance 0.0050 -MaxCLL 1347 -MaxFAL 129 -OutputPath "Path\To\Encoded\File"
    .EXAMPLE
        ## MacOS or Linux ##
        ./FFEncoder.ps1 -InputPath "Path/To/file" -CRF 16.5 -Preset medium -Deblock -2,-2 -MaxLuminance 1000 -MinLuminance 0.0050 -MaxCLL 1347 -MaxFAL 129 -OutputPath "Path/To/Encoded/File"

    .INPUTS
        4K HDR video file 

    .OUTPUTS
        crop.txt - File used for auto-cropping
        4K HDR encoded video file

    .NOTES
        For FFEncoder to work, ffmpeg must be in your PATH (consult your OS documentation for info on how to verify this).

        Be sure to include ".mkv" or ".mp4" at the end of your output file, or you will be left with a file that will not play. 

        FFEncoder is designed to encode video ONLY. ffmpeg does not have great passthrough options for Atmos or DTS-X (yet), 
        so it is easier to mux the audio yourself using MKVToolNix. By default, ffmpeg will convert audio streams to Vorbis.
        When your video is done encoding, simply mux the Vorbis out and replace it with your audio stream of choice. I have a
        separate script for AAC audio encoding that I plan to merge into FFEncoder at some point. 

        FFEncoder will automatically convert HDR Content Light Level values for you. Input CLL values as you see them in
        MediaInfo (or similar software).

        .PARAMETER Help
            Displays help information for the script. Only required for the "Help" parameter set
        .PARAMETER Test
            Switch to enable a test run. Only encodes the first 1000 frames
        .PARAMETER 1080p
            Switch to enable 1080p encode. Removes HDR arguments (still testing). Only required for the "1080p" parameter set
        .PARAMETER InputPath
            Location of the file to be encoded
        .PARAMETER Preset
            The x265 preset to be used. Ranges from "placebo" (slowest) to "ultrafast" (fastest)
        .PARAMETER CRF
            Constant rate factor setting. Ranges from 0.0 to 51.0. Lower values equate to a higher bitrate
        .PARAMETER Deblock
            Deblock filter settings. The first value represents strength, and the second value represents frequency
        .PARAMETER MaxLuminance
            Maximum master display luminance for HDR. Only required for the "2160p" parameter set
        .PARAMETER MinLuminance
            Minimum master display luminance for HDR. Only required for the "2160p" parameter set
        .PARAMETER MaxCLL
            Maximum content light level for HDR. Only required for the "2160p" parameter set
        .PARAMETER MaxFAL
            Maximum frame average light level for HDR. Only required for the "2160p" parameter set
        .PARAMETER OutputPath
            Location of the encoded video file
        
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

    [Parameter(Mandatory = $true, ParameterSetName = "1080p")]
    [switch]$1080p,

    [Parameter(Mandatory = $true, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $true, ParameterSetName = "1080p")]
    [ValidateNotNullOrEmpty()]
    [Alias("I")]
    [string]$InputPath,

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
    [ValidateNotNullOrEmpty()]
    [Alias("MaxL")]
    [int]$MaxLuminance,

    [Parameter(Mandatory = $true, ParameterSetName = "2160p")]
    [ValidateNotNullOrEmpty()]
    [Alias("MinL")]
    [double]$MinLuminance,

    [Parameter(Mandatory = $true, ParameterSetName = "2160p")]
    [ValidateNotNullOrEmpty()]
    [Alias("CLL")]
    [int]$MaxCLL,

    [Parameter(Mandatory = $true, ParameterSetName = "2160p")]
    [ValidateNotNullOrEmpty()]
    [Alias("FAL")]
    [int]$MaxFAL,

    [Parameter(Mandatory = $true, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $true, ParameterSetName = "1080p")]
    [ValidateNotNullOrEmpty()]
    [Alias("O")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "2160p")]
    [Parameter(Mandatory = $false, ParameterSetName = "1080p")]
    [Alias("T")]
    [switch]$Test

)

## Global Variables ##

#Change these to modify the default path for crop files when a regex match cannot be made
$macDefaultPath = '~/Movies'
$linuxDefaultPath = '~/Videos'
$windowsDefaultPath = "C:\Users\$env:USERNAME\Videos"

#converting the luminance values for ffmpeg
$MaxLuminance = $MaxLuminance * 10000
[int]$MinLuminance = $MinLuminance * 10000
#Global variable that holds the crop file generated by New-CropFile function
$cropFilePath = ""

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

<#
    Generates a crop file which is used to calculate auto-cropping values for the video source

    .PARAMETER osType
            The current operating system.
#>
function New-CropFile ($osType) {
    if ($InputPath -match "(?<root>.*(?:\\|\/)+).*\.m[a-z 4]+") {
        $cropFileRoot = $Matches.root
        $cropFilePath = Join-Path -Path $cropFileRoot -ChildPath "crop.txt"
        Write-Host "Crop file path is " $cropFilePath "`n"
    }
    else {
        Write-Host "Could not match root folder pattern. Using OS default path instead..."
        $os = Get-OperatingSystem
        Write-Host $os.OperatingSystem " detected. Using path: $($os.DefaultPath)`n"
        $cropFileRoot = $os.DefaultPath
        $cropFilePath = Join-Path -Path $cropFileRoot -ChildPath "crop.txt"
        Write-Host "Crop file path is " $cropFilePath "`n"
    }
    #if the crop file already exists (from a test run for example) return the path. Else, use ffmpeg to create one
    if (Test-Path -Path $cropFilePath) { 
        Write-Host "Crop file already exists`n"
        return $cropFilePath 
    }
    else {
        switch ($osType) {
            "Windows" { 
                ffmpeg.exe -skip_frame nokey -y -hide_banner -loglevel 32 -stats -i $InputPath -vf cropdetect -an -f null - 2>$cropFilePath
            }
            { $_ -match "MacOS" -xor $_ -match "Linux" } {
                ffmpeg -skip_frame nokey -y -hide_banner -loglevel 32 -stats -i $InputPath -vf cropdetect -an -f null - 2>$cropFilePath
            }
            Default { Write-Host "OS could not be detected while generating the crop file. Exiting script..."; exit }
        }
        return $cropFilePath
    }
}

<#
    Enumerates the crop file to find the max crop width and height. This simulates auto-cropping from software like Handbrake

    .PARAMETER cropPath
        The path to the crop file
#>
function Measure-CropDimensions ($cropPath) {
    if (!$cropPath) { throw "There was an issue reading the crop file. Check that the file was properly created and try again." }
    $cropFile = Get-Content $cropPath
    $cropHeight = 0
    $cropWidth = 0
    foreach ($line in $cropFile) {
        if ($line -match "Parsed_cropdetect.*w:(?<width>\d+) h:(?<height>\d+).*") {
            [int]$height = $Matches.height
            [int]$width = $Matches.width
    
            if ($width -gt $cropWidth) { $cropWidth = $width }
            if ($height -gt $cropHeight) { $cropHeight = $height }
        }
    }
    Write-Host "Crop Dimensions: " $cropWidth "x" $cropHeight
    return @($cropWidth, $cropHeight)
}

<#
    Runs ffmpeg with operating system specific parameters 

    .PARAMETER osType
        The current operating system.
#>
function Invoke-FFMpeg ($osType) {
    switch ($osType) {
        { $_ -match "Windows" } { 
            if ($Test) {
                ffmpeg.exe -probesize 100MB -i $InputPath `
                    -frames:v 1000 -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" -color_range tv -color_primaries 9 -color_trc 16 -colorspace 9 -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
                    -x265-params "level-idc=5.1:keyint=120:deblock=$($deblock[0]),$($deblock[1]):sao=0:rc-lookahead=48:subme=4:chromaloc=2:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L($MaxLuminance,$MinLuminance):max-cll=$MaxCLL,$MaxFAL`:hdr-opt=1" `
                    $OutputPath 2>&1
            }
            else {
                ffmpeg.exe -probesize 100MB -i $InputPath `
                    -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" -color_range tv -color_primaries 9 -color_trc 16 -colorspace 9 -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
                    -x265-params "level-idc=5.1:keyint=120:deblock=$($deblock[0]),$($deblock[1]):sao=0:rc-lookahead=48:subme=4:chromaloc=2:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L($MaxLuminance,$MinLuminance):max-cll=$MaxCLL,$MaxFAL`:hdr-opt=1" `
                    $OutputPath 2>&1
            }
        }
        { $_ -match "MacOS" -xor $_ -match "Linux" } {
            if ($Test) {
                ffmpeg -probesize 100MB -i $InputPath `
                    -frames:v 1000 -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" -color_range tv -color_primaries 9 -color_trc 16 -colorspace 9 -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
                    -x265-params "level-idc=5.1:keyint=120:deblock=$($deblock[0]),$($deblock[1]):sao=0:rc-lookahead=48:subme=4:chromaloc=2:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L($MaxLuminance,$MinLuminance):max-cll=$MaxCLL,$MaxFAL`:hdr-opt=1" `
                    $OutputPath 2>&1
            }
            else {
                ffmpeg -probesize 100MB -i $InputPath `
                    -vf "crop=w=$($cropDim[0]):h=$($cropDim[1])" -color_range tv -color_primaries 9 -color_trc 16 -colorspace 9 -c:v libx265 -preset $Preset -crf $CRF -pix_fmt yuv420p10le `
                    -x265-params "level-idc=5.1:keyint=120:deblock=$($deblock[0]),$($deblock[1]):sao=0:rc-lookahead=48:subme=4:chromaloc=2:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L($MaxLuminance,$MinLuminance):max-cll=$MaxCLL,$MaxFAL`:hdr-opt=1" `
                    $OutputPath 2>&1
            }
        }
        default { Write-Host "`nAn OS could not be matched while invoking ffmpeg. Exiting script..."; exit }
    }
}


## End Functions ##

######################################## Main Script Logic ########################################

if ($Help) { Get-Help .\FFEncoder.ps1 -Full; exit }

Write-Host "`nStarting Script...`n`n"
$startTime = (Get-Date).ToLocalTime()
#if the output path already exists, delete the existing file or exit script
if (Test-Path -Path $OutputPath) {
    do {
        $response = Read-Host "The output path already exists. Would you like to delete it? (y/n)"
    } until ($response -eq "y" -or $response -eq "n")
    switch ($response) {
        "y" { 
            Remove-Item -Path $OutputPath -Include "*.mkv", "*.mp4" -Confirm 
            if ($?) { Write-Host "`nFile $OutputPath was successfully deleted" }
            else { Write-Host "$OutputPath could not be deleted. Make sure it is not in use by another program.`nExiting script..."; exit }
        }
        "n" { "Please choose a different file name, or delete the existing file. Exiting script..."; exit }
        default { Write-Host "You have somehow reached an unreachable block. Exiting script..."; exit }
    }
}

$checkOS = Get-OperatingSystem
$cropFilePath = New-CropFile $checkOS.OperatingSystem
Start-Sleep -Seconds 5
$cropDim = Measure-CropDimensions $cropFilePath
Invoke-FFMpeg $checkOS.OperatingSystem

$endTime = (Get-Date).ToLocalTime()
$totalTime = $endTime - $startTime
Write-Host "`nTotal Encoding Time: $($totalTime.Hours) Hours, $($totalTime.Minutes) Minutes" 

Read-Host -Prompt "Press enter to exit"

