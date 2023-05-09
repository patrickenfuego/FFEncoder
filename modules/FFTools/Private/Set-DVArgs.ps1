using namespace System.Collections

<#
    .SYNOPSIS
        Private function that sets encoding array arguments for Dolby Vision
    .DESCRIPTION
        This function translates ffmpeg type syntax to x265 syntax to keep a consistent feel throughout the script.
        This function is a proxy function for Set-FFMpegArgs
    .NOTES
        This function is needed because ffmpeg still does not fully support DV encoding.
        Requires x265 executable
#>

function Set-DVArgs {
    [CmdletBinding()]
    param (
        # Audio parameters
        [Parameter(Mandatory = $true)]
        [array]$Audio,

        # Subtitle settings
        [Parameter(Mandatory = $true)]
        [array]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset,

        # Crop dimensions for the output file
        [Parameter(Mandatory = $true)]
        [int[]]$CropDimensions,

        # Rate control options
        [Parameter(Mandatory = $true)]
        [array]$RateControl,

        # Preset Parameter options
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

        # Transform unit recursion depth (intra, inter)
        [Parameter(Mandatory = $false)]
        [int[]]$TuDepth,
 
        # Early exit setting for tu recursion depth
        [Parameter(Mandatory = $false)]
        [int]$LimitTu,

        # Enable/disable strong-intra-smoothing
        [Parameter(Mandatory = $false)]
        [int]$IntraSmoothing,

        # Enable tree algorithm
        [Parameter(Mandatory = $false)]
        [int]$Tree,

        # Enable NLMeans denoising filter
        [Parameter(Mandatory = $false)]
        [hashtable]$NLMeans,

        # Sharpen/blur filter
        [Parameter(Mandatory = $false)]
        [hashtable]$Unsharp,

        # Number of frame threads the encoder should use
        [Parameter(Mandatory = $false)]
        [int]$Threads,

        # Encoder level to use. Default is 5.1 for DV only
        [Parameter(Mandatory = $false)]
        [string]$Level,

        # Video buffering verifier: (bufsize, maxrate)
        [Parameter(Mandatory = $false)]
        [int[]]$VBV,

        [Parameter(Mandatory = $false)]
        [Generic.List[object]]$FFMpegExtra,

        [Parameter(Mandatory = $false)]
        [hashtable]$EncoderExtra,

        # HDR properties
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

        # Starting Point for test encodes. Integers are treated as a frame #
        [Parameter(Mandatory = $false)]
        [string]$TestStart,

        # Switch to enable deinterlacing with yadif
        [Parameter(Mandatory = $false)]
        [switch]$Deinterlace
    )

    # Currently broken with x265 piping - need to figure out how to fix this
    if ($PSBoundParameters['Scale']) {
        $Scale = $null
    }

    # Split rate control array
    $twoPass = $RateControl[2]
    $passType = $RateControl[3]
    $RateControl = $RateControl[0..($RateControl.Length - 3)]

    # Keys for x265 parameters that take no value & not available as a parameter. 
    # Might be some missing
    $noArgKeys = @(
        'rect'
        'amp'
        'sao'
        'b-intra'
        'strong-intra-smoothing'
        'early-skip'
        'splitrd-skip'
        'fast-intra'
        'tskip-fast'
        'rd-refine'
        'dynamic-refine'
        'tskip'
        'temporal-mvp'
        'weightp'
        'w'
        'hme'
        'weightb'
        'constrained-intra'
        'hist-scenecut'
        'b-pyramid'
        'open-gop'
        'lossless'
        'cu-lossless'
        'sao-non-deblock'
        'limit-sao'
        'limit-modes'
        'rc-grain'
        'hevc-aq'
        'aq-motion'
        'analyze-src-pics'
        'ssim'
        'psnr'
        'wpp'
        'pmode'
        'pme'
        'frame-dup'
        'field'
        'allow-non-conformance'
        'ssim-rd'
        'fades'
        'svt'
        'svt-hme'
        'svt-compressed-ten-bit-format'
        'svt-speed-control'
        'multi-pass-opt-analysis'
        'multi-pass-opt-distortion'
        'strict-cbr'
        'const-vbv'
        'signhide'
        'cll'
        'dhdr10-opt'
        'annexb'
        'repeat-headers'
        'aud'
        'eob'
        'hrd'
        'hrd-concat'
        'info'
        'temporal-layers'
        'vui-timing-info'
        'opt-qp-pps'
        'opt-ref-list-length-pps'
        'multi-pass-opt-rps'
        'opt-cu-delta-qp'
        'idr-recovery-sei'
        'single-sei'
        'svt-fps-in-vps'
    )

    <#
        UNPACK EXTRA PARAMETERS

        ffmpeg extra arguments
        x265 extra arguments
    #>

    # Add parameters passed via -FFMpegExtra
    if ($PSBoundParameters['FFMpegExtra']) {
        $ffmpegExtraArray = [ArrayList]@()
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

    # Add parameters passed via -EncoderExtra
    if ($PSBoundParameters['EncoderExtra']) {
        $x265ExtraArray = [ArrayList]@()
        foreach ($arg in $EncoderExtra.GetEnumerator()) {
            # Check if arg is in the no arg array. Must be exact match
            if ($arg.Name -in $noArgKeys) {
                switch ($arg.Value) {
                    1 { $x265ExtraArray.Add("--$($arg.Name)") > $null }
                    0 { $x265ExtraArray.Add("--no-$($arg.Name)") > $null }
                }
            }
            elseif ($arg.Name -eq 'copy-pic' -and $arg.Value -eq 0) {
                $x265ExtraArray.Add('--no-copy-pic') > $null
            }
            elseif ($arg.Name -eq 'scenecut') {
                switch ($arg.Value) {
                    0 { $x265ExtraArray.Add('--no-scenecut') > $null }
                    default { $x265ExtraArray.AddRange(@('--scenecut', "$($arg.Value)")) }
                }
            }
            else {
                $x265ExtraArray.AddRange(@("--$($arg.Name)", "$($arg.Value)"))
            }
        }
    }

    # Escape paths for *NIX, add escape quotes for Windows
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

    <#
        SET BASE ARGUMENT ARRAYS

        vapoursynth vspipe array (if used)
        ffmpeg base array for video
        ffmpeg base array for audio/subs
        x265 base array
    #>

    if (![string]::IsNullOrEmpty($Paths.VPY)) {
        $vapoursynthBaseArray = [ArrayList]@(
            'vspipe'
            '--y4m'
            "`"$($Paths.VPY)`""
            '- '
        )
    }

    $ffmpegBaseVideoArray = [ArrayList]@(
        '-i'
        $inputPath
        '-f'
        'yuv4mpegpipe'
        '-strict'
        '-1'
        '-pix_fmt'
        'yuv420p10le'
    )
    
    $ffmpegOtherArray = [ArrayList]@(
        '-probesize'
        '100MB'
        '-i'
        if ($PSVersionTable.PSVersion -ge [version]'7.3') {
            $Paths.InputFile
        }
        else {
           "`"$($Paths.InputFile)`"" 
        }
        '-map_chapters'
        '0'
        '-vn'
        $Audio
        $Subtitles
    )

    $x265BaseArray = [ArrayList]@(
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
        $PSBoundParameters['Level'] ? $Level : 5.1
        '--vbv-bufsize'
        $PSBoundParameters['VBV'] ? $VBV[0] : 160000
        '--vbv-maxrate'
        $PSBoundParameters['VBV'] ? $VBV[1] : 160000
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
        if ($HDR.HDR10Plus -eq $true) {
            "--dhdr10-info"
            "`"$($Paths.HDR10Plus)`""
        }
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
        '--ref'
        "$($PresetParams.Ref)"
        '--merange'
        "$($PresetParams.Merange)"
        '--rc-lookahead'
        "$($PresetParams.RCLookahead)"
        '--aq-strength'
        $AqStrength
        '--psy-rd'
        $PSBoundParameters['PsyRd'] ? $PsyRd : '2.00'
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
        if ($PSBoundParameters['Tree'] -eq 0) {
            '--no-cutree'
        }
        if ($PSBoundParameters['Threads']) { 
            '-F'
            $Threads
        }
        if (![string]::IsNullOrEmpty($Paths.VPY) -and $TestFrames) {
            '--frames'
            $TestFrames
        }
    )

    <#
        SET ADDITIONAL ARGUMENTS

        Video filter array
        Set situational arguments based on parameters
    #>

    # Set video specific filter arguments unless VS is used
    if ([string]::IsNullOrEmpty($Paths.VPY)) {
        $vfHash = @{
            CropDimensions = $CropDimensions
            Scale          = $Scale
            FFMpegExtra    = $FFMpegExtra
            Deinterlace    = $Deinterlace
            Unsharp        = $Unsharp
            Verbose        = $setVerbose
        }
        try {
            $vfArray = Set-VideoFilter @vfHash
        }
        catch {
            Write-Error "Video filter exception: $($_.Exception)" -ErrorAction Stop
        }

        if ($vfArray) { $ffmpegBaseVideoArray.AddRange($vfArray) }
    }

    # Set test frames if passed. Insert start time before input
    if ($PSBoundParameters['TestFrames']) {
        $tParams = @{
            InputFile        = $Paths.InputFile
            TestFrames       = $TestFrames
            TestStart        = $TestStart
            PrimaryArguments = $ffmpegBaseVideoArray
            ExtraArguments   = $ffmpegExtraArray
        }
        Set-TestParameters @tParams
    }
    elseif (!$PSBoundParameters['TestFrames'] -and $ffmpegExtraArray -contains '-ss') {
        $i = $ffmpegExtraArray.IndexOf('-ss')
        $ffmpegBaseVideoArray.InsertRange(
            $ffmpegBaseVideoArray.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1])
        )
        $ffmpegOtherArray.InsertRange(
            $ffmpegOtherArray.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1])
        )
        $ffmpegExtraArray.RemoveRange($i, 2)
    }

    if ($ffmpegExtraArray) { 
        Write-Verbose "FFMPEG EXTRA ARGS ARE: `n $($ffmpegExtraArray -join ' ')`n"
        $ffmpegBaseVideoArray.AddRange($ffmpegExtraArray) 
    }
    
    # Add final argument for piping
    $ffmpegBaseVideoArray.Add('- ')

    <#
        SET ADDITIONAL X265 ARGUMENTS
    #>

    if ($x265ExtraArray) { $x265BaseArray.AddRange($x265ExtraArray) }

    ($PresetParams.BIntra -eq 1) ? 
        ($x265BaseArray.Add('--b-intra') > $null) : 
        ($x265BaseArray.Add('--no-b-intra') > $null)

    ($IntraSmoothing -eq 0) ?
        ($x265BaseArray.Add('--no-strong-intra-smoothing') > $null) : 
        ($x265BaseArray.Add('--strong-intra-smoothing') > $null)

    <#
        SET RATE CONTROL
    #>

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
            default { Write-Error "Unknown bitrate suffix for two pass encode" -ErrorAction Stop }
        }
        $x265BaseArray.AddRange(@('--bitrate', $val))
    }

    ($null -ne $Paths.VPY) ?
        (Write-Verbose "VAPOURSYNTH ARGS ARE :`n  $($vapoursynthBaseArray -join " ")`n") :
        (Write-Verbose "FFMPEG VIDEO ARGS ARE:`n  $($ffmpegBaseVideoArray -join " ")`n")

    Write-Verbose "FFMPEG SUB/AUDIO ARGS ARE:`n  $($ffmpegOtherArray -join " ")`n"

    <#
        TWO PASS SETTINGS

        Add params based two pass type (if passed)
        Set remaining two pass arguments
    #>

    if ($twoPass) {
        [ArrayList]$x265FirstPassArray = switch -Regex ($passType) {
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
        $x265SecondPassArray.AddRange(
            @('--stats', "`"$($Paths.X265Log)`"", '--pass', 2, '--subme', "$($PresetParams.Subme)")
        )

        Write-Verbose "DV FIRST PASS ARRAY IS:`n $($x265FirstPassArray -join " ")`n"
        Write-Verbose "DV SECOND PASS ARRAY IS:`n $($x265SecondPassArray -join " ")`n"
        
        $dvHash = @{
            FFMpegOther = $ffmpegOtherArray
            x265Args1   = $x265FirstPassArray
            x265Args2   = $x265SecondPassArray
        }
    }
    # Set remaining one pass / crf argument
    else {
        $x265BaseArray.AddRange(@('--subme', "$($PresetParams.Subme)"))

        Write-Verbose "x265 ARRAY IS:`n $($x265BaseArray -join " ")`n"
        
        $dvHash = @{
            FFMpegOther = $ffmpegOtherArray
            x265Args1   = $x265BaseArray
            x265Args2   = $null
        }
    }

    if (![string]::IsNullOrEmpty($Paths.VPY)) {
        $dvHash['Vapoursynth'] = $vapoursynthBaseArray
        $dvHash['FFMpegVideo'] = $null
    }
    else {
        $dvHash['FFMpegVideo'] = $ffmpegBaseVideoArray
        $dvHash['Vapoursynth'] = $null
    }

    return $dvHash
}

