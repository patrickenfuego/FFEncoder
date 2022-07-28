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
    function Get-Resolution ([string]$FilePath, [string]$Type) {
        $resolution = ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 $FilePath
        Write-Verbose "VMAF Resolution is: $resolution"
        $match = [regex]::Matches($resolution, "(?<w>\d+)x(?<h>\d+).*")
        if ($match) {
            [int]$width = $match.Groups[1].Value
            [int]$height = $match.Groups[2].Value

            Write-Verbose "VMAF Dimensions for $Type : $width`x$height"
        }
        else {
            Write-Error "VMAF: Regular expression failed to match dimensions. ffprobe may have returned a bad result" -ErrorAction Stop
        }

        return $width, $height
    }

    Write-Verbose "Source Path: $Source"
    Write-Verbose "Encode path: $Encode"
    
    <#
        SETUP

        Sanitize LogFormat if present
        Title
    #>

    $LogFormat = $LogFormat.ToLower()
    $title = Split-Path $Encode -LeafBase

    <#
        GATHER VIDEO INFORMATION

        Resolution
        Scaling
        Frame rate (FPS)
    #>

    # Check if zscale is available with ffmpeg & set scaling args
    $scale, $set = ($(ffmpeg 2>&1) -join ' ' -notmatch 'libzimg') ? 
        'scale', 'flags' :
        'zscale', 'f'

    # Get the resolution of the source (reference) file to verify if scaling was used
    $sw, $sh = Get-Resolution -FilePath $Source -Type 'Source'
    # # Get the resolution of the encode (distorted) for cropping
    $w, $h = Get-Resolution -FilePath $Encode -Type 'Encode'

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
        SET PATHS & CPU COUNT

        Log path
        Model path
        Collect number of CPUs to use as thread count (50% usage)
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

    # Perform all the path fuckery required by VMAF & ffmpeg on Windows
    if ($IsWindows) {
        # Set the model path and format for libvmaf
        $modelDrive = (Split-Path $jsonFile -Qualifier) -replace ':', '\\:'
        $modelPath = (Split-Path $jsonFile -NoQualifier) -replace '\\', '/'
        $modelPath = "$modelDrive$modelPath"
        
        $logDrive = (Split-Path $Encode -Qualifier) -replace ':', '\\:'
        $logPath = (Split-Path $Encode -Parent)
        $logPath = (Split-Path $logPath -NoQualifier) -replace '\\', '/'
        $logPath = "$logDrive$logPath/$title`_vmaf_log.json"

        # Get CPU count. Use ~ 50% of system capability
        $coreCount = Get-CimInstance Win32_Processor | Select-Object -ExpandProperty NumberOfCores
    }
    elseif ($IsLinux -or $IsMacOS) {
        $modelPath = $jsonFile
        $logPath = [Path]::Join($(Split-Path $Encode -Parent), "$title`_vmaf_log.json")

        # Get CPU count. Use ~ 50% of system capability
        $cpuStr = $IsLinux ? 
            (grep 'cpu cores' /proc/cpuinfo | uniq) :
            (sysctl -a | grep machdep.cpu.core_count)
        
        $countStr = [regex]::Match($cpuStr, '\d+') |
        if ($countStr) {
            if (($coreCount.Value -as [int]) -is [int]) {
                $coreCount = $countStr.Value
            }
            else {
                Write-Warning "CPU count did not return an integer. Defaulting to 4 threads"
                $coreCount = 4
            }
        }
        else {
            Write-Host "Could not detect the number of CPUs on the system. Defaulting to 4 threads"
            $coreCount = 4
        }
    }
    else {
        Write-Error "Unknown Operating System detected. Exiting script" -ErrorAction Stop
    }

    Write-Verbose "VMAF Model Path: $modelPath"
    Write-Verbose "VMAF Log Path: $logPath"

    <#
        Set VMAF string
        Add features
        Run libvmaf via ffmpeg
    #>

    # Set the VMAF string with options and paths
    $vmafStr = "log_fmt=$LogFormat`:log_path=$logPath`:model_path=$modelPath`:n_threads=$coreCount"
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
    if ($LASTEXITCODE -ne 1) {
        Write-Host "`nAnalysis complete!" -NoNewline @successColors
        Write-Host "The log file can be found at: $($ul)$($aMagenta)$logPath"
    }
    else {
        Write-Host "The exit code for ffmpeg indicates that a problem occurred. " @warnColors -NoNewline
    }
}