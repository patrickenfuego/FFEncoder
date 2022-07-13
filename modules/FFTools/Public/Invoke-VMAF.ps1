using namespace System.IO

<#
    .SYNOPSIS
        Performs VMAF quality comparison on two video files
    .DESCRIPTION
        Accepts a reference (source) and distorted (encode) video file for VMAF comparison. Can also perform
        SSIM and PSNR evaluations in addition to VMAF using the relevant switch parameters. Default log format
        is json, but can also be output with csv, sub, or xml.
    .PARAMETER Source
        Reference file path used for comparison
    .PARAMETER Encode
        Distorted file path used for comparison
    .PARAMETER LogFormat
        Specify the output log format
    .PARAMETER SSIM
        Switch parameter that adds SSIM evaluation
    .PARAMETER PSNR
        Switch parameter that adds PSNR evaluation
#>
function Invoke-VMAF {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Encode,

        [Parameter(Mandatory = $false)]
        [ValidateSet('json', 'xml', 'csv', 'sub')]
        [string]$LogFormat = 'json',

        [Parameter(Mandatory = $false)]
        [switch]$SSIM,

        [Parameter(Mandatory = $false)]
        [switch]$PSNR
    )

    # Private internal function to parse dimensions from a string 
    function Get-Resolution ([string]$FilePath) {
        $resolution = ffprobe -v error -select_streams v:0 -show_entries stream=width, height -of csv=s=x:p=0 $FilePath

        if ($resolution -match "(?<w>\d+)x(?<h>\d+)") {
            [int]$width, [int]$height = $Matches.w, $Matches.h
        }
        else {
            Write-Error "VMAF: Regular expression failed to match dimensions. ffprobe may have returned a bad result" -ErrorAction Stop
        }

        return $width, $height
    }

    <#
        SETUP NAMES

        Title
        Current Directory
    #>

    if ($Encode -match "(?<oRoot>.*(?:\\|\/)+)(?<oTitle>.*)\..*") {
        $title = $Matches.oTitle -replace '\s', '_'
        $currDirectory = $Matches.oRoot
    }
    else {
        $title = 'title_vmaf'
        $currDirectory = Split-Path $Encode -Parent
    }

    <#
        GATHER VIDEO INFORMATION

        Resolution
        Scaling
        Frame rate (FPS)
    #>

    # Check if zscale is available with ffmpeg & set scaling args
    $scale, $set = ($(ffmpeg 2>&1) -join ' ' -notmatch 'libzimg') ? 'scale', 'flags' : 'zscale', 'f'

    # # Get the resolution of the encode (distorted) for cropping
    $w, $h = Get-Resolution -FilePath $Encode
    # Get the resolution of the source (reference) file to verify if scaling was used
    $sw, $sh = Get-Resolution -FilePath $Source
    # Check for downscale - upscale encode back using lanczos
    if (($sw - $w) -gt 200) {
        $referenceString = "[0:v]crop=$($sw):$($sh)[reference]"
        $distortedString = "[1:v]$scale=$($sw):$($sh):$set=lanczos[distorted]"
    }
    # Check for upscale - downscale encode back using bicubic
    elseif (($sw - $w) -lt 0) {
        $referenceString = "[0:v]crop=$($sw):$($sh)[reference]"
        $distortedString = "[1:v]$scale=$($sw):$($sh):$set=bicubic[distorted]"
    }
    # Both videos are the same base resolution - crop reference to source
    else {
        $referenceString = "[0:v]crop=$w`:$h`[reference]"
        $distortedString = "[1:v]crop=$w`:$h`[distorted]"
    }

    # Get framerate of Encode
    $fps = ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $Encode
    $framerate = [math]::Round($(Invoke-Expression $fps), 3)
    # Get framerate of source to ensure they match
    $fpsSrc = ffprobe -v error -select_streams v -of default=noprint_wrappers=1:nokey=1 -show_entries stream=r_frame_rate $Source
    $framerateSrc = [math]::Round($(Invoke-Expression $fpsSrc), 3)
    if ($framerate -ne $framerateSrc) {
        Write-Error "Source and encode have different frame rates. Ensure the proper files are being compared" -ErrorAction Stop
    }
    
    <#
        SET PATHS

        Log path
        model path
    #>

    # Get the parent directory of json model files
    $root = [Path]::Join((Get-item $PSModuleRoot).Parent.Parent, 'vmaf')

    $jsonFile = switch ($sw) {
        { $_ -gt 3000 } { [Path]::Join($root, 'vmaf_4k_v0.6.1.json') }
        default         { [Path]::Join($root, 'vmaf_v0.6.1.json') }
    }

    if (![File]::Exists($jsonFile)) {
        Write-Error "VMAF: Cannot locate json model file" -ErrorAction Stop
    }

    $jsonLeaf = Split-Path $jsonFile -Leaf

    # Perform all the path fuckery required by VMAF & ffmpeg on Windows
    if ($env:OS -like "*Windows*") {
        # Copy to temp for easier path manipulation
        Copy-Item -Path $jsonFile -Destination 'C:\Temp'
        # Set true paths in temp
        $jsonTmpPath = [Path]::Join('C:\Temp', $jsonLeaf)
        $logTmpPath = [Path]::Join('C:\Temp', "$title`_vmaf_log.json")
        # Escape path in the special way required by libvmaf: C\\:/Temp/file.json
        $tmpRoot = (Split-Path $jsonTmpPath -Qualifier) -replace ':', '\\:'
        $tmpPath = (Split-Path $jsonTmpPath -NoQualifier) -replace '\\', '/'
        $modelPath = "$tmpRoot$tmpPath"
        $logPath = "$tmpRoot/Temp/$title`_vmaf_log.json"
    }
    elseif ($IsLinux -or $isMacOS) {
        Copy-Item $jsonFile -Destination '/tmp'
        $modelPath = [Path]::Join('/tmp', $jsonLeaf)
        $logPath = [Path]::Join('/tmp', "$title`_vmaf_log.json")
    }
    else {
        Write-Error "Unknown Operating System detected. Exiting script" -ErrorAction Stop
    }

    <#
        Set VMAF string
        Add features
        Run libvmaf via ffmpeg
    #>

    # Set the VMAF string with options and paths
    $vmafStr = "log_fmt=json:log_path=$logPath`:model_path=$modelPath"
    if ($SSIM) {
        $vmafStr += ":feature=name=ssim"
    }
    if ($PSNR) {
        $vmafStr += ":feature=name=psnr"
    }

    # Run VMAF
    ffmpeg -hide_banner `
        -r $framerate -i $Source `
        -r $framerate -i $Encode `
        -filter_complex "$referenceString;`
                         $distortedString;`
                         [distorted][reference]libvmaf=$vmafStr" `
        -f null -

    Write-Verbose "Last Exit Code: $LASTEXITCODE"
    if ($LASTEXITCODE) {
        Write-Host "`nAnalysis complete! " -NoNewline @successColors
    }
    else {
        Write-Host "The exit code for ffmpeg indicates that a problem occurred. " @warnColors -NoNewline
    }
    # Copy log path back to main directory and remove temp paths
    Copy-Item $logTmpPath -Destination $currDirectory -ErrorAction SilentlyContinue
    $success = $?
    if ($psReq) {
        $success ? (Write-Host "VMAF log has been copied to $($italicOn+$aMagenta)`u{201C}$currDirectory`u{201D}$($reset)") :
                   (Write-Host "There was an issue copying the log file back from the temp directory" @warnColors)
    }
    else {
        $success ? (Write-Host "VMAF log has been copied to `u{201C}$currDirectory`u{201D}" @progressColors) :
                   (Write-Host "There was an issue copying the log file back from the temp directory" @warnColors)
    }
}