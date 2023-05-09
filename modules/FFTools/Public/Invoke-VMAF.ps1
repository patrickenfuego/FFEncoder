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
        [ValidateSet('point', 'spline16', 'spline36', 'bilinear', 'bicubic', 'lanczos',
            'fast_bilinear', 'neighbor', 'area', 'gauss', 'sinc', 'spline', 'bicublin')]
        [string]$ResizeKernel = 'bicubic',

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

    # Format and output assessment scores. Backward compatible with older pwsh versions
    function Write-Score {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromPipeline = $true)]
            [hashtable]$ScoreData
        )
    
        begin {
            $blinkify = $boldOn + $blinkOn
        }
        process {
            $style =
    
            # Pwsh 7.2+
            if ($psReq) {
                switch ($ScoreData.Type) {
                    'vmaf' {
                        if ($ScoreData.Score -ge 90) {
                            $PSStyle.Foreground.FromRgb('#2bf502') + $blinkify
                        }
                        elseif ($ScoreData.Score -gt 70 -and $ScoreData.Score -lt 90) {
                            $PSStyle.Foreground.FromRgb('#f5a802') + $blinkify
                        }
                        else {
                            $PSStyle.Foreground.FromRgb('#f51a02') + $blinkify
                        }
                    }
                    'ms-ssim' {
                        if ($ScoreData.Score -ge 0.97) {
                            $PSStyle.Foreground.FromRgb('#2bf502') + $blinkify
                        }
                        elseif ($ScoreData.Score -ge 0.95 -and $ScoreData.Score -lt 0.97) {
                            $PSStyle.Foreground.FromRgb('#f5a802') + $blinkify
                        }
                        else {
                            $PSStyle.Foreground.FromRgb('#f51a02') + $blinkify
                        }
                    }
                    'psnr' {
                        if ($ScoreData.Score -ge 38) {
                            $PSStyle.Foreground.FromRgb('#2bf502') + $blinkify
                        }
                        elseif ($ScoreData.Score -ge 33 -and $ScoreData.Score -lt 38) {
                            $PSStyle.Foreground.FromRgb('#f5a802') + $blinkify
                        }
                        else {
                            $PSStyle.Foreground.FromRgb('#f51a02') + $blinkify
                        }
                    }
                }
            }
            # Pwsh 7, 7.1
            else {
                switch ($ScoreData.Type) {
                    'vmaf' {
                        if ($ScoreData.Score -ge 90) {
                            'Green'
                        }
                        elseif ($ScoreData.Score -gt 70 -and $ScoreData.Score -lt 90) {
                            'Yellow'
                        }
                        else {
                            'Red'
                        }
                    }
                    'ms-ssim' {
                        if ($ScoreData.Score -ge 0.97) {
                            'Green'
                        }
                        elseif ($ScoreData.Score -ge 0.95 -and $ScoreData.Score -lt 0.97) {
                            'Yellow'
                        }
                        else {
                            'Red'
                        }
                    }
                    'psnr' {
                        if ($ScoreData.Score -ge 38) {
                            'Green'
                        }
                        elseif ($ScoreData.Score -ge 33 -and $ScoreData.Score -lt 38) {
                            'Yellow'
                        }
                        else {
                            'Red'
                        }
                    }
                }
            }
    
            $psReq ? 
                (Write-Host "$($ScoreData.Type.ToUpper()) Score:`t$($style)$($ScoreData.Score)$($reset)") : 
                (Write-Host "$($ScoreData.Type.ToUpper()) Score:`t$($ScoreData.Score)" -ForegroundColor $style -BackgroundColor Black)
        }
    }

    <#
        SETUP

        Configure display & formatting variables
        Set temp log path for score parsing
        Sanitize LogFormat if present
        Set title
    #>

    # Display stuff
    $refInfo = [FileInfo]$Source
    $distInfo = [FileInfo]$Encode

    $refName = $refInfo.BaseName
    $refExt = $refInfo.Extension.Replace('.', '')
    $distName = $distInfo.BaseName
    $distExt = $distInfo.Extension.Replace('.', '')

    if ($psReq) {
        $c1 = $PSStyle.Foreground.FromRgb('#8507ed')
        $c2 = $PSStyle.Foreground.FromRgb('#027cf5') # #0255fa
        $c3 = $PSStyle.Foreground.FromRgb('#02fa86')

        Write-Host "$ul`Reference$ulOff`: $c1$refName$reset.$c2$refExt"
        Write-Host "$ul`Distorted$ulOff`: $c3$distName$reset.$c2$distExt`n"
    }
    else {
        Write-Host "Reference: " -NoNewline
        Write-Host "$refName.$refExt" @progressColors
        Write-Host "Distorted: " -NoNewline
        Write-Host "$distName.$distExt`n" @emphasisColors
    }

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

    # Check for downscale/upscale
    if ($sw -ne $w) {
        $referenceString = "[0:v]crop=$($sw):$($sh)[reference]"
        $distortedString = "[1:v]$scale=$($sw):$($sh):$set=$ResizeKernel[distorted]"
    }
    # Both videos are the same base resolution - crop source to reference
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

    # Set paths and calculate system resources
    if ($IsWindows) {
        # Perform all the path fuckery required by VMAF & ffmpeg on Windows
        $modelDrive = (Split-Path $jsonFile -Qualifier) -replace ':', '\\:'
        $modelPath = (Split-Path $jsonFile -NoQualifier) -replace '\\', '/'
        $modelPath = "$modelDrive$modelPath"
        
        $logDrive = (Split-Path $Encode -Qualifier) -replace ':', '\\:'
        $logPath = (Split-Path $Encode -Parent)
        $logPath = (Split-Path $logPath -NoQualifier) -replace '\\', '/'
        $logPath = "$logDrive$logPath/$title`_vmaf_log.json"

        # Get CPU count. Use ~ 50% of system capability
        $coreCount = (Get-CimInstance Win32_Processor).NumberOfCores
    }
    elseif ($IsLinux -or $IsMacOS) {
        $modelPath = $jsonFile
        $logPath = [Path]::Join($(Split-Path $Encode -Parent), "$title`_vmaf_log.json")
        $logPath = [Regex]::Escape($logPath)

        # Get CPU count. Use ~ 50% of system capability
        $cpuStr = $IsLinux ? 
            (grep 'cpu cores' /proc/cpuinfo | uniq) :
            (sysctl -a | grep machdep.cpu.core_count)
        
        $countStr = [regex]::Match($cpuStr, '\d+')
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
        $vmafStr += ":feature=name=float_ms_ssim"
    }
    if ($PSNR) {
        $vmafStr += ":feature=name=float_psnr"
    }

    # Run VMAF
    ffmpeg -hide_banner `
        -r $framerate -i $Source `
        -r $framerate -i $Encode `
        -filter_complex "$referenceString;`
                         $distortedString;`
                         [distorted][reference]libvmaf=$vmafStr" `
        -f null - 2>$null

    Write-Verbose "Last Exit Code: $LASTEXITCODE"
    if ($LASTEXITCODE -ne 1) {
        Write-Host "Analysis Complete! " -NoNewline

        # Unfuck the log escaping to make it parsable
        if ($isWindows) {
            $logPath = [Regex]::Unescape($logPath).Replace('\:', ':') | 
                Resolve-Path | 
                    Select-Object -ExpandProperty Path
        }
        else {
            $logPath = [Regex]::Unescape($logPath)
        }

        [File]::Exists($logPath) ? 
            (Write-Host "Scores:`n") : 
            (Write-Host "Unfortunately, the log file doesn't exist and scores couldn't be extracted" @warnColors)

        # Get score from log for processing
        $scoreData = [File]::ReadAllLines($logPath) | 
            ConvertFrom-Json | 
                Select-Object -ExpandProperty pooled_metrics

        $scores = @(
            @{ Type = 'vmaf'; Score = $scoreData.vmaf.harmonic_mean }
            if ($SSIM) {
                @{ Type = 'ms-ssim'; Score = $scoreData.float_ms_ssim.harmonic_mean }
            }
            if ($PSNR) {
                @{ Type = 'psnr'; Score = $scoreData.float_psnr.harmonic_mean }
            }
        )
        $scores | Write-Score

        Write-Host "`nThe full log file can be found at: $($ul)$($aMagenta)$logPath`n"
    }
    else {
        Write-Host "The exit code for ffmpeg indicates that a problem occurred.`n" @warnColors
    }
}