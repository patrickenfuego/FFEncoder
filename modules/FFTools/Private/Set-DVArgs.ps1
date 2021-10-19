<#
    .SYNOPSIS
        Private function that sets encoding array arguments for Dolby Vision
    .DESCRIPTION
        This function translates ffmpeg type syntax to x265 syntax to keep a consistent feel throughout the script.
        This function is a proxy function for Set-FFMpegArgs
    .NOTES
        This function is needed because ffmpeg does not currently support RPU files for DV encoding
#>

function Set-DVArgs {
    [CmdletBinding()]
    param (
        # Audo parameters
        [Parameter(Mandatory = $true)]
        [array]$Audio,

        # subtitle
        [Parameter(Mandatory = $true)]
        [array]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset,

        # Crop dimensions for the output file
        [Parameter(Mandatory = $true)]
        [int[]]$CropDimensions,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [array]$RateControl,

        # Parameter help description
        [Parameter(Mandatory = $true)]
        [hashtable]$PresetParams,

        # Adjusts the quantizer curve compression factor
        [Parameter(Mandatory = $false)]
        [double]$QComp,

        # Deblock filter setting
        [Parameter(Mandatory = $false)]
        [int[]]$Deblock,

        # aq-strength. Higher values equate to a lower QP, but can also increase bitrate significantly
        [Parameter(Mandatory = $false)]
        [double]$AqStrength,

        # psy-rd setting
        [Parameter(Mandatory = $false)]
        [double]$PsyRd,

        # Filter to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [int[]]$NoiseReduction,

        #Transform unit recursion depth (intra, inter)
        [Parameter(Mandatory = $false)]
        [int[]]$TuDepth,
 
        #Early exit setting for tu recursion depth
        [Parameter(Mandatory = $false)]
        [int]$LimitTu,

        # Enable/disable strong-intra-smoothing
        [Parameter(Mandatory = $false)]
        [int]$IntraSmoothing,

        # Number of frame threads the encoder should use
        [Parameter(Mandatory = $false)]
        [int]$FrameThreads,

        [Parameter(Mandatory = $false)]
        [array]$FFMpegExtra,

        [Parameter(Mandatory = $false)]
        [hashtable]$x265Extra,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [hashtable]$HDR,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        # Scale settings
        [Parameter(Mandatory = $false)]
        [hashtable]$Scale,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        [int]$TestFrames,

        # Switch to enable deinterlacing with yadif
        [Parameter(Mandatory = $false)]
        [switch]$Deinterlace,

        [Parameter(Mandatory = $false)]
        [string]$Verbosity
    )

    if ($PSBoundParameters['Verbosity']) {
        $VerbosePreference = 'Continue'
    }
    else {
        $VerbosePreference = 'SilentlyContinue'
    }

    #Split rate control array
    $twoPass = $RateControl[2]
    $passType = $RateControl[3]
    $RateControl = $RateControl[0..($RateControl.Length - 3)]

    ## Unpack extra parameters ##

    if ($PSBoundParameters['FFMpegExtra']) {
        [string[]]$ffmpegExtraArray = [System.Collections.ArrayList]@()
        foreach ($arg in $FFMpegExtra) {
            if ($arg -is [hashtable]) {
                foreach ($entry in $arg.GetEnumerator()) {
                    #Skip crop args. Handled in Set-VideoFilter
                    if ($entry.Value -notmatch "crop") {
                        $ffmpegExtraArray += @("$($entry.Name)", "$($entry.Value)")
                    }
                }
            }
            else { $ffmpegExtraArray += $arg }
        }
    }

    if ($PSBoundParameters['x265Extra']) {
        [string[]]$x265ExtraArray = [System.Collections.ArrayList]@()
        foreach ($arg in $x265Extra.GetEnumerator()) {
            #Convert extra args from ffmpeg format to x265 no-arg format
            #Looking for a better way to do this...setting these values
            #based only on (1, 0) causes false positives for some options
            if ($arg.Name -eq 'limit-modes') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--limit-modes' }
                    0 { $x265ExtraArray += '--no-limit-modes' }
                }
            }
            elseif ($arg.Name -eq 'rect') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--rect' }
                    0 { $x265ExtraArray += '--no-rect' }
                }
            }
            elseif ($arg.Name -eq 'amp') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--amp' }
                    0 { $x265ExtraArray += '--no-amp' }
                }
            }
            elseif ($arg.Name -eq 'early-skip') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--early-skip' }
                    0 { $x265ExtraArray += '--no-early-skip' }
                }
            }
            elseif ($arg.Name -eq 'splitrd-skip') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--splitrd-skip' }
                    0 { $x265ExtraArray += '--no-splitrd-skip' }
                }
            }
            elseif ($arg.Name -eq 'fast-intra') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--fast-intra' }
                    0 { $x265ExtraArray += '--no-fast-intra' }
                }
            }
            elseif ($arg.Name -eq 'cu-lossless') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--cu-lossless' }
                    0 { $x265ExtraArray += '--no-cu-lossless' }
                }
            }
            elseif ($arg.Name -eq 'tskip-fast') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--tskip-fast' }
                    0 { $x265ExtraArray += '--no-tskip-fast' }
                }
            }
            elseif ($arg.Name -eq 'rd-refine') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--rd-refine' }
                    0 { $x265ExtraArray += '--no-rd-refine' }
                }
            }
            elseif ($arg.Name -eq 'dynamic-refine') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--dynamic-refine' }
                    0 { $x265ExtraArray += '--no-dynamic-refine' }
                }
            }
            elseif ($arg.Name -eq 'tskip') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--tskip' }
                    0 { $x265ExtraArray += '--no-tskip' }
                }
            }
            elseif ($arg.Name -eq 'temporal-mvp') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--temporal-mvp' }
                    0 { $x265ExtraArray += '--no-temporal-mvp' }
                }
            }
            elseif ($arg.Name -eq 'weightp' -or $arg.Name -eq 'w') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--weightp' }
                    0 { $x265ExtraArray += '--no-weightp' }
                }
            }
            elseif ($arg.Name -eq 'weightb') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--weightb' }
                    0 { $x265ExtraArray += '--no-weightb' }
                }
            }
            elseif ($arg.Name -eq 'analyze-src-pics') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--analyze-src-pics' }
                    0 { $x265ExtraArray += '--no-analyze-src-pics' }
                }
            }
            elseif ($arg.Name -eq 'hme') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--hme' }
                    0 { $x265ExtraArray += '--no-hme' }
                }
            }
            elseif ($arg.Name -eq 'constrained-intra') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--constrained-intra' }
                    0 { $x265ExtraArray += '--no-constrained-intra' }
                }
            }
            elseif ($arg.Name -eq 'open-gop') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--open-gop' }
                    0 { $x265ExtraArray += '--no-open-gop' }
                }
            }
            elseif ($arg.Name -eq 'scenecut') {
                switch ($arg.Value) {
                    0 { $x265ExtraArray += '--no-scenecut' }
                    default { $x265ExtraArray += @('--scenecut', "$($arg.Value)") }
                }
            }
            elseif ($arg.Name -eq 'hist-scenecut') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--hist-scenecut' }
                    0 { $x265ExtraArray += '--no-hist-scenecut' }
                }
            }
            elseif ($arg.Name -eq 'b-pyramid') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--b-pyramid' }
                    0 { $x265ExtraArray += '--no-b-pyramid' }
                }
            }
            elseif ($arg.Name -eq 'lossless') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--lossless' }
                    0 { $x265ExtraArray += '--no-lossless' }
                }
            }
            elseif ($arg.Name -eq 'aq-motion') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--aq-motion' }
                    0 { $x265ExtraArray += '--no-aq-motion' }
                }
            }
            elseif ($arg.Name -eq 'cutree') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--cutree' }
                    0 { $x265ExtraArray += '--no-cutree' }
                }
            }
            elseif ($arg.Name -eq 'lossless') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--lossless' }
                    0 { $x265ExtraArray += '--no-lossless' }
                }
            }
            elseif ($arg.Name -eq 'rc-grain') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray += '--rc-grain' }
                    0 { $x265ExtraArray += '--no-rc-grain' }
                }
            }
            elseif ($arg.Name -eq 'aq-motion' -and $arg.Value -eq 1) {
                $x265BaseArray += '--aq-motion'
            }
            elseif ($arg.Name -eq 'hevc-aq' -and $arg.Value -eq 1) {
                $x265ExtraArray += '--hevc-aq'
            }
            elseif ($arg.Name -eq 'sao' -and $arg.Value -eq 1) {
                $x265ExtraArray += '--sao'
            }
            else {
                $x265ExtraArray += @("--$($arg.Name)", "$($arg.Value)")
            }
        }
    }

    ## Set base argument arrays ##

    if ($IsLinux -or $IsMacOS) {
        $inputPath = [regex]::Escape($Paths.InputFile)
        $dvPath = [regex]::Escape($Paths.dvPath)
    }
    else {
        $inputPath = "`"$($Paths.InputFile)`""
        $dvPath = "`"$($Paths.dvPath)`""
    }

    $ffmpegBaseVideoArray = @(
        '-i'
        $inputPath
        '-f'
        'yuv4mpegpipe'
        '-strict'
        '-1'
        '-pix_fmt'
        'yuv420p10le'
    )
    
    $ffmpegOtherArray = @(
        '-probesize'
        '100MB'
        '-i'
        $inputPath
        '-map_chapters'
        '0'
        '-vn'
        $Audio
        $Subtitles
    )

    $x265BaseArray = @(
        '--input'
        '-'
        '--output-depth'
        10
        '--y4m'
        '--profile'
        'main10'
        '--preset'
        $Preset
        '--level-idc'
        5.1
        '--vbv-bufsize'
        '160000'
        '--vbv-maxrate'
        '160000'
        '--master-display'
        "$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma))"
        '--max-cll'
        "`"$($HDR.MaxCLL),$($HDR.MaxFAL)`""
        '--colormatrix'
        "$($HDR.ColorSpace)"
        '--colorprim'
        "$($HDR.ColorPrimaries)"
        '--transfer'
        "$($HDR.Transfer)"
        '--range'
        'limited'
        '--hdr10'
        '--hdr10-opt'
        '--dolby-vision-rpu'
        $dvPath
        '--dolby-vision-profile'
        '8.1'
        '--aud'
        '--hrd'
        '--repeat-headers'
        '--chromaloc'
        '2'
        '--bframes'
        "$($PresetParams.BFrames)"
        '--psy-rdoq'
        "$($PresetParams.PsyRdoq)"
        '--aq-mode'
        "$($PresetParams.AqMode)"
        '--aq-strength'
        $AqStrength
        '--rc-lookahead'
        '48'
        '--keyint'
        '192'
        '--min-keyint'
        '24'
        '--psy-rd'
        $PsyRd
        '--tu-intra-depth'
        "$($TuDepth[0])"
        '--tu-inter-depth'
        "$($TuDepth[1])"
        '--limit-tu'
        "$LimitTu"
        '--qcomp'
        $Qcomp
        '--nr-intra'
        "$($NoiseReduction[0])"
        '--nr-inter'
        "$($NoiseReduction[1])"
        '--deblock'
        "$($Deblock[0]):$($Deblock[1])"
    )

    ## Set additional ffmpeg arguments ##

    #Set video specific filter arguments
    $vfArray = Set-VideoFilter $CropDimensions $Scale $FFMpegExtra $Deinterlace $Verbosity
    if ($vfArray) { $ffmpegBaseVideoArray += $vfArray }

    if ($ffmpegExtraArray) { $ffmpegBaseVideoArray += $ffmpegExtraArray }
    #Set test frames if passed
    if ($PSBoundParameters['TestFrames']) {
        $ffmpegBaseVideoArray += @('-ss', '00:01:30', '-frames:v', $TestFrames)
        $x265BaseArray += @('-f', $TestFrames)
    }
    
    #Add final argument for piping
    $ffmpegBaseVideoArray += '- '

    ## Set extra x265 arguments ##

    if ($x265ExtraArray) { $x265BaseArray += $x265ExtraArray }
    if ($x265ExtraArray -notcontains '--sao') {
        $x265BaseArray += @('--no-sao')
    }
    if ($x265ExtraArray -notcontains '--open-gop') {
        $x265BaseArray += @('--no-open-gop')
    }
    if ($PSBoundParameters['FrameThreads']) { $x265BaseArray += @('-F', "$FrameThreads") }
    ($PresetParams.BIntra -eq 1) ? ($x265BaseArray += @('--b-intra')) : ($x265BaseArray += @('--no-b-intra'))

    ($IntraSmoothing -eq 0) ?
    ($x265BaseArray += @('--no-strong-intra-smoothing')) : 
    ($x265BaseArray += @('--strong-intra-smoothing'))

    ## Set rate control ##

    if ($RateControl[0] -like '-crf') {
        $x265BaseArray += @('--crf', $RateControl[1])
    }
    elseif ($RateControl[0] -like '-b:v') {
        $val = switch -Wildcard ($RateControl[1]) {
            '*M' {
                ([int]( $_ -replace 'M', '') * 1000)
            }
            '*k' {
                [int]( $_ -replace 'k', '') 
            }
            default { throw "Unknown bitrate suffix"; exit 2 }
        }
        $x265BaseArray += @('--bitrate', $val)
    }

    Write-Verbose "FFMPEG VIDEO ARGS ARE: `n $($ffmpegBaseVideoArray -join " ")`n"
    Write-Verbose "FFMPEG SUB/AUDIO ARGS ARE: `n $($ffmpegOtherArray -join " ")`n"

    #Set remaining two pass arguments
    if ($twoPass) {
        $x265FirstPassArray = switch -Regex ($passType) {
            "^d[efault]*$" {
                @(
                    $x265BaseArray
                    '--subme'
                    "$($PresetParams.Subme)"
                )
                break
            }
            "^f[ast]*$" {
                @(
                    $x265BaseArray
                    '--no-rect'
                    '--no-amp'
                    '--max-merge'
                    '1'
                    '--fast-intra'
                    '--early-skip'
                    '--rd'
                    '2'
                    '--subme'
                    '2'
                    '--me'
                    '0'
                    '--ref'
                    '1'
                )
                break
            }
            "^c[ustom]*$" {
                @(
                    $x265BaseArray
                    '--no-rect'
                    '--no-amp'
                    '--max-merge'
                    '2'
                    '--subme'
                    '2'
                )
                break
            }
        }

        $x265FirstPassArray += @('--stats', "`"$($Paths.X265Log)`"", '--pass', '1')
        $x265SecondPassArray = $x265BaseArray + @('--stats', "`"$($Paths.X265Log)`"", '--pass', '2', '--subme', "$($PresetParams.Subme)")

        Write-Verbose "FIRST PASS ARRAY IS:`n $($x265FirstPassArray -join " ")`n"
        Write-Verbose "SECOND PASS ARRAY IS:`n $($x265SecondPassArray -join " ")`n"
        
        $dvHash = @{
            FFMpegVideo = $ffmpegBaseVideoArray
            FFMpegOther = $ffmpegOtherArray
            x265Args1   = $x265FirstPassArray
            x265Args2   = $x265SecondPassArray
        }
    }
    #Set remaining one pass / crf argument
    else {
        $x265BaseArray += @('--subme', "$($PresetParams.Subme)")

        Write-Verbose "x265 ARRAY IS:`n $($x265BaseArray -join " ")`n"
        
        $dvHash = @{
            FFMpegVideo = $ffmpegBaseVideoArray
            FFMpegOther = $ffmpegOtherArray
            x265Args1   = $x265BaseArray
            x265Args2   = $null
        }
    }

    return $dvHash
}