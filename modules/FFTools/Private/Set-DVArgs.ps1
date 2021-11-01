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
        $ffmpegExtraArray = [System.Collections.ArrayList]@()
        foreach ($arg in $FFMpegExtra) {
            if ($arg -is [hashtable]) {
                foreach ($entry in $arg.GetEnumerator()) {
                    #Skip crop args. Handled in Set-VideoFilter
                    if ($entry.Value -notmatch "crop") {
                        $ffmpegExtraArray.Add("$($entry.Name)") > $null
                        $ffmpegExtraArray.Add("$($entry.Value)") > $null
                    }
                }
            }
            else { $ffmpegExtraArray.Add($arg) > $null }
        }
    }

    if ($PSBoundParameters['x265Extra']) {
        $x265ExtraArray = [System.Collections.ArrayList]@()
        foreach ($arg in $x265Extra.GetEnumerator()) {
            #Convert extra args from ffmpeg format to x265 no-arg format
            #Looking for a better way to do this...setting these values
            #based only on (1, 0) causes false positives for some options
            if ($arg.Name -eq 'limit-modes') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--limit-modes') > $null }
                    0 { $x265ExtraArray.Add('--no-limit-modes') > $null }
                }
            }
            elseif ($arg.Name -eq 'rect') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--rect') > $null }
                    0 { $x265ExtraArray.Add('--no-rect') > $null }
                }
            }
            elseif ($arg.Name -eq 'amp') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--amp') > $null }
                    0 { $x265ExtraArray.Add('--no-amp') > $null }
                }
            }
            elseif ($arg.Name -eq 'early-skip') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--early-skip') > $null }
                    0 { $x265ExtraArray.Add('--no-early-skip') > $null }
                }
            }
            elseif ($arg.Name -eq 'splitrd-skip') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--splitrd-skip') > $null }
                    0 { $x265ExtraArray.Add('--no-splitrd-skip') > $null }
                }
            }
            elseif ($arg.Name -eq 'fast-intra') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--fast-intra') > $null }
                    0 { $x265ExtraArray.Add('--no-fast-intra') > $null }
                }
            }
            elseif ($arg.Name -eq 'cu-lossless') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--cu-lossless') > $null }
                    0 { $x265ExtraArray.Add('--no-cu-lossless') > $null }
                }
            }
            elseif ($arg.Name -eq 'tskip-fast') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--tskip-fast') > $null }
                    0 { $x265ExtraArray.Add('--no-tskip-fast') > $null }
                }
            }
            elseif ($arg.Name -eq 'rd-refine') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--rd-refine') > $null }
                    0 { $x265ExtraArray.Add('--no-rd-refine') > $null }
                }
            }
            elseif ($arg.Name -eq 'dynamic-refine') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--dynamic-refine') > $null }
                    0 { $x265ExtraArray.Add('--no-dynamic-refine') > $null }
                }
            }
            elseif ($arg.Name -eq 'tskip') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--tskip') > $null }
                    0 { $x265ExtraArray.Add('--no-tskip') > $null }
                }
            }
            elseif ($arg.Name -eq 'temporal-mvp') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--temporal-mvp') > $null }
                    0 { $x265ExtraArray.Add('--no-temporal-mvp') > $null }
                }
            }
            elseif ($arg.Name -eq 'weightp' -or $arg.Name -eq 'w') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--weightp') > $null }
                    0 { $x265ExtraArray.Add('--no-weightp') > $null }
                }
            }
            elseif ($arg.Name -eq 'weightb') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--weightb') > $null }
                    0 { $x265ExtraArray.Add('--no-weightb') > $null }
                }
            }
            elseif ($arg.Name -eq 'analyze-src-pics') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--analyze-src-pics') > $null }
                    0 { $x265ExtraArray.Add('--no-analyze-src-pics') > $null }
                }
            }
            elseif ($arg.Name -eq 'hme') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--hme') > $null }
                    0 { $x265ExtraArray.Add('--no-hme') > $null }
                }
            }
            elseif ($arg.Name -eq 'constrained-intra') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--constrained-intra') > $null }
                    0 { $x265ExtraArray.Add('--no-constrained-intra') > $null }
                }
            }
            elseif ($arg.Name -eq 'open-gop') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--open-gop') > $null }
                    0 { $x265ExtraArray.Add('--no-open-gop') > $null }
                }
            }
            elseif ($arg.Name -eq 'scenecut') {
                switch ($arg.Value) {
                    0 { $x265ExtraArray.Add('--no-scenecut') > $null }
                    default { $x265ExtraArray.AddRange(@('--scenecut', "$($arg.Value)")) }
                }
            }
            elseif ($arg.Name -eq 'hist-scenecut') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--hist-scenecut') > $null }
                    0 { $x265ExtraArray.Add('--no-hist-scenecut') > $null }
                }
            }
            elseif ($arg.Name -eq 'b-pyramid') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--b-pyramid') > $null }
                    0 { $x265ExtraArray.Add('--no-b-pyramid') > $null }
                }
            }
            elseif ($arg.Name -eq 'lossless') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--lossless') > $null }
                    0 { $x265ExtraArray.Add('--no-lossless') > $null }
                }
            }
            elseif ($arg.Name -eq 'aq-motion') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--aq-motion') > $null }
                    0 { $x265ExtraArray.Add('--no-aq-motion') > $null }
                }
            }
            elseif ($arg.Name -eq 'cutree') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--cutree') > $null }
                    0 { $x265ExtraArray.Add('--no-cutree') > $null }
                }
            }
            elseif ($arg.Name -eq 'lossless') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--lossless') > $null }
                    0 { $x265ExtraArray.Add('--no-lossless') > $null }
                }
            }
            elseif ($arg.Name -eq 'rc-grain') {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add('--rc-grain') > $null }
                    0 { $x265ExtraArray.Add('--no-rc-grain') > $null }
                }
            }
            elseif ($arg.Name -eq 'aq-motion' -and $arg.Value -eq 1) {
                $x265BaseArray.Add('--aq-motion') > $null
            }
            elseif ($arg.Name -eq 'hevc-aq' -and $arg.Value -eq 1) {
                $x265ExtraArray.Add('--hevc-aq') > $null
            }
            elseif ($arg.Name -eq 'sao' -and $arg.Value -eq 1) {
                $x265ExtraArray.Add('--sao') > $null
            }
            else {
                $x265ExtraArray.AddRange(@("--$($arg.Name)", "$($arg.Value)"))
            }
        }
    }

    ## Set base argument arrays ##

    if ($IsLinux -or $IsMacOS) {
        $inputPath = [regex]::Escape($Paths.InputFile)
        $dvPath = [regex]::Escape($Paths.dvPath)
        $masterDisplay = [regex]::Escape("$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma))")
    }
    else {
        $inputPath = "`"$($Paths.InputFile)`""
        $dvPath = "`"$($Paths.dvPath)`""
        $masterDisplay = "`"$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma))`""
    }

    $ffmpegBaseVideoArray = [System.Collections.ArrayList]@(
        '-i'
        $inputPath
        '-f'
        'yuv4mpegpipe'
        '-strict'
        '-1'
        '-pix_fmt'
        'yuv420p10le'
    )
    
    $ffmpegOtherArray = [System.Collections.ArrayList]@(
        '-probesize'
        '100MB'
        '-i'
        "`"$($Paths.InputFile)`""
        '-map_chapters'
        '0'
        '-vn'
        $Audio
        $Subtitles
    )

    $x265BaseArray = [System.Collections.ArrayList]@(
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
        160000
        '--vbv-maxrate'
        160000
        '--master-display'
        $masterDisplay
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
        2
        '--bframes'
        "$($PresetParams.BFrames)"
        '--psy-rdoq'
        "$($PresetParams.PsyRdoq)"
        '--aq-mode'
        "$($PresetParams.AqMode)"
        '--aq-strength'
        $AqStrength
        '--min-keyint'
        24
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
    if ($vfArray) { $ffmpegBaseVideoArray.AddRange($vfArray) }

    #Set test frames if passed. Insert start time before input
    if ($PSBoundParameters['TestFrames']) {
        $a = @('-frames:v', $TestFrames)
        if ($ffmpegExtraArray -contains '-ss') {
            $i = $ffmpegExtraArray.IndexOf('-ss')
            $ffmpegBaseVideoArray.InsertRange($ffmpegBaseVideoArray.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1]))
            $ffmpegOtherArray.InsertRange($ffmpegOtherArray.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1]))
            $ffmpegExtraArray.RemoveRange($i, 2)
        }
        else {
            $ffmpegBaseVideoArray.InsertRange($ffmpegBaseVideoArray.IndexOf('-i'), @('-ss', '00:01:30'))
            $ffmpegOtherArray.InsertRange($ffmpegBaseVideoArray.IndexOf('-i'), @('-ss', '00:01:30'))
        }
        $ffmpegBaseVideoArray.AddRange($a)
        $x265BaseArray.AddRange(@('-f', $TestFrames))
    }
    elseif (!$PSBoundParameters['TestFrames'] -and $ffmpegExtraArray -contains '-ss') {
        $i = $ffmpegExtraArray.IndexOf('-ss')
        $ffmpegBaseVideoArray.InsertRange($ffmpegBaseVideoArray.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1]))
        $ffmpegOtherArray.InsertRange($ffmpegOtherArray.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1]))
        $ffmpegExtraArray.RemoveRange($i, 2)
    }

    if ($ffmpegExtraArray) { 
        Write-Verbose "FFMPEG EXTRA ARGS ARE: `n $($ffmpegExtraArray -join ' ')`n"
        $ffmpegBaseVideoArray.AddRange($ffmpegExtraArray) 
    }
    
    #Add final argument for piping
    $ffmpegBaseVideoArray.Add('- ')

    ## Set additional x265 arguments ##

    if ($x265ExtraArray) { $x265BaseArray.AddRange($x265ExtraArray) }
    if ($x265ExtraArray -notcontains '--sao') {
        $x265BaseArray.Add('--no-sao') > $null
    }
    if ($x265ExtraArray -notcontains '--open-gop') {
        $x265BaseArray.Add('--no-open-gop') > $null
    }
    if ($x265ExtraArray -notcontains '--rc-lookahead') {
        $x265BaseArray.AddRange(@('--rc-lookahead', 48))
    }
    if ($x265ExtraArray -notcontains '--keyint') {
        $x265BaseArray.AddRange(@('--keyint', 192))
    }
    if ($x265ExtraArray -notcontains '--min-keyint') {
        $x265BaseArray.AddRange(@('--min-keyint', 24))
    }
    if ($PSBoundParameters['FrameThreads']) { 
        $x265BaseArray.AddRange(@('-F', $FrameThreads))
    }

    ($PresetParams.BIntra -eq 1) ? 
    ($x265BaseArray.Add('--b-intra') > $null) : 
    ($x265BaseArray.Add('--no-b-intra') > $null)

    ($IntraSmoothing -eq 0) ?
    ($x265BaseArray.Add('--no-strong-intra-smoothing') > $null) : 
    ($x265BaseArray.Add('--strong-intra-smoothing') > $null)

    ## Set rate control ##

    if ($RateControl[0] -like '-crf') {
        $x265BaseArray.AddRange(@('--crf', $RateControl[1]))
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
        $x265BaseArray.AddRange(@('--bitrate', $val))
    }

    Write-Verbose "FFMPEG VIDEO ARGS ARE: `n $($ffmpegBaseVideoArray -join " ")`n"
    Write-Verbose "FFMPEG SUB/AUDIO ARGS ARE: `n $($ffmpegOtherArray -join " ")`n"

    #Set remaining two pass arguments
    if ($twoPass) {
        [System.Collections.ArrayList]$x265FirstPassArray = switch -Regex ($passType) {
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

        $x265FirstPassArray.AddRange(@('--stats', "`"$($Paths.X265Log)`"", '--pass', 1))
        $x265SecondPassArray = $x265BaseArray.Clone()
        $x265SecondPassArray.AddRange(@('--stats', "`"$($Paths.X265Log)`"", '--pass', 2, '--subme', "$($PresetParams.Subme)"))

        Write-Verbose "DV FIRST PASS ARRAY IS:`n $($x265FirstPassArray -join " ")`n"
        Write-Verbose "DV SECOND PASS ARRAY IS:`n $($x265SecondPassArray -join " ")`n"
        
        $dvHash = @{
            FFMpegVideo = $ffmpegBaseVideoArray
            FFMpegOther = $ffmpegOtherArray
            x265Args1   = $x265FirstPassArray
            x265Args2   = $x265SecondPassArray
        }
    }
    #Set remaining one pass / crf argument
    else {
        $x265BaseArray.AddRange(@('--subme', "$($PresetParams.Subme)"))

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