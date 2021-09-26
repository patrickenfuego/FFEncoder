<#
    .SYNOPSIS   
        Function to build the arguments used by Invoke-FFMpeg
    .DESCRIPTION
        Dynamically generates an array list of arguments based on parameters passed by the user,
        the preset selected, and a few hard coded default arguments based on my personal preference.
        If custom preset arguments are passed, they will override the default values. 
        
        The hard coded defaults are as follows and should be changed in this function if new values are
        desired:

        1. rc-lookahead: 48
        2. subme: 4
        3. open-gop: 0
        4. sao: 0
        4. keyint: 192 (8 second GOP)
        5. frame-threads: 2
        6. merange: 44 (720p/1080p only)

        Two pass encoding, first pass (meant to balance speed and quality):

        1. rect: 0
        2. max-merge: 2
        3. bintra: 0
        4. subme: 2
    .OUTPUTS
        Array list of ffmpeg arguments
#>

function Set-FFMpegArgs {      
    [CmdletBinding()]
    param (
        # Parameter help description
        [Parameter(Mandatory = $true)]
        [array]$Audio,

        # Parameter help description
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
        [switch]$Deinterlace
    )

    #Split rate control array
    $twoPass = $RateControl[2]
    $passType = $RateControl[3]
    $RateControl = $RateControl[0..($RateControl.Length - 3)]

    ## Unpack extra parameters ##

    if ($PSBoundParameters['FFMpegExtra']) {
        [string[]]$ffmpegExtraArray = @()
        foreach ($arg in $FFMpegExtra) {
            if ($arg -is [hashtable]) {
                foreach ($entry in $arg.GetEnumerator()) {
                    #Skip crop args. Handled in Set-VideoFilter
                    if ($entry.Value -notmatch "crop") {
                        $ffmpegExtraArray += "$($entry.Name)"
                        $ffmpegExtraArray += "$($entry.Value)"
                    }
                }
            }
            else { $ffmpegExtraArray += $arg }
        }
    }

    if ($PSBoundParameters['x265Extra']) {
        [string[]]$x265ExtraArray = @()
        foreach ($arg in $x265Extra.GetEnumerator()) {
            $x265ExtraArray += "$($arg.Name)=$($arg.Value)"
        }
    }

    ## Base Array Declarations ##

    #Primary array list initialized with global values
    $ffmpegArgsAL = [System.Collections.ArrayList] @(
        '-probesize'
        '100MB'
        '-i'
        "`"$($Paths.InputFile)`""
        '-color_range'
        'tv'
        '-map'
        '0:v:0'
        '-c:v'
        'libx265'
        $Audio
        $Subtitles
        '-preset'
        $Preset
        $RateControl
    )
    [System.Collections.ArrayList]$ffmpegPassTwoArgsAL = $null

    #x265 args common to all CRF configurations
    $x265Array = @(
        'keyint=192'
        'min-keyint=24'
        'sao=0'
        'rc-lookahead=48'
        'open-gop=0'
        "psy-rd=$PsyRd"
        "qcomp=$QComp"
        "tu-intra-depth=$($TuDepth[0])"
        "tu-inter-depth=$($TuDepth[1])"
        "limit-tu=$LimitTu"
        "subme=$($PresetParams.Subme)"
        "b-intra=$($PresetParams.BIntra)"
        "bframes=$($PresetParams.BFrames)"
        "psy-rdoq=$($PresetParams.PsyRdoq)"
        "aq-mode=$($PresetParams.AqMode)"
        "nr-intra=$($NoiseReduction[0])"
        "nr-inter=$($NoiseReduction[1])"
        "aq-strength=$AqStrength"
        "strong-intra-smoothing=$IntraSmoothing"
        "deblock=$($Deblock[0]),$($Deblock[1])"
    )
    #Settings common to all first pass options
    $x265FirstPassCommonArray = @(
        'pass=1'
        "stats='$($Paths.X265Log)'"
        'keyint=192'
        'min-keyint=24'
        'sao=0'
        'rc-lookahead=48'
        'open-gop=0'
        "psy-rd=$PsyRd"
        "qcomp=$QComp"
        "tu-intra-depth=$($TuDepth[0])"
        "tu-inter-depth=$($TuDepth[1])"
        "limit-tu=$LimitTu"
        "b-intra=$($PresetParams.BIntra)"
        "bframes=$($PresetParams.BFrames)"
        "psy-rdoq=$($PresetParams.PsyRdoq)"
        "aq-mode=$($PresetParams.AqMode)"
        "nr-intra=$($NoiseReduction[0])"
        "nr-inter=$($NoiseReduction[1])"
        "aq-strength=$AqStrength"
        "strong-intra-smoothing=$IntraSmoothing"
        "deblock=$($Deblock[0]),$($Deblock[1])"
    )

    if ($passType) {
        $x265FirstPassArray = switch -Regex ($passType) {
            "^d[efault]*$" {
                @(
                    $x265FirstPassCommonArray
                    "subme=$($PresetParams.Subme)"
                )
                break
            }
            "^f[ast]*$" {
                @(
                    $x265FirstPassCommonArray
                    'rect=0'
                    'amp=0'
                    'max-merge=1'
                    'fast-intra=1'
                    'early-skip=1'
                    'rd=2'
                    'subme=2'
                    'me=0'
                    'ref=1'
                )
                break
            }
            "^c[ustom]*$" {
                @(
                    $x265FirstPassCommonArray
                    'rect=0'
                    'amp=0'
                    'max-merge=2'
                    'subme=2'
                )
                break
            }
        }
    }

    ## End base array declarations ##

    ## Build Argument Arrays ##

    #Add frame threads parameter if set by user
    if ($PSBoundParameters['FrameThreads']) {
        $x265Array += "frame-threads=$FrameThreads"
    }

    #Test frames. Null if not passed by user
    $testArray = $PSBoundParameters['TestFrames'] ? 
    ( @('-ss', '00:01:30', '-frames:v', $TestFrames) ) : 
    $null
    
    #Set video specific filter arguments
    $vfArray = Set-VideoFilter $CropDimensions $Scale $FFMpegExtra

    #Set arguments for UHD/FHD based on the presence of HDR metadata
    if ($HDR) {
        $pxFormatArray = @('-pix_fmt', $HDR.PixelFmt)
        if (@('1080p', '720p') -contains $Scale.Resolution) { $level = 4 }
        else { $level = 5.1 }
        #Arguments specific to 2160p HDR
        $resArray = @(
            "colorprim=$($HDR.ColorPrimaries)"
            "transfer=$($HDR.Transfer)"
            "colormatrix=$($HDR.ColorSpace)"
            "$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma))"
            "max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL)"
            'chromaloc=2'
            "level-idc=$level"
            'hdr10-opt=1'
            'aud=1'
            'hrd=1'
        )
    }
    else {
        $pxFormatArray = @('-pix_fmt', 'yuv420p10le')
        #Arguments specific to 1080p SDR
        $resArray = @(
            'merange=44'
            'colorprim=bt709'
            'transfer=bt709'
            'colormatrix=bt709'
        )
    }

    ## Combine Arrays ##

    if ($vfArray) { $ffmpegArgsAL += $vfArray }
    if ($testArray) { $ffmpegArgsAL += $testArray }
    if ($ffmpegExtraArray) { $ffmpegArgsAL += $ffmpegExtraArray }
    $ffmpegArgsAL += $pxFormatArray

    #Build x265 arguments for CRF/ 1-pass
    if (!$twoPass) {
        #Combine x265 args and join
        $tmpArray = $x265Array + $resArray
        if ($x265ExtraArray) { $tmpArray += $x265ExtraArray }
        $x265String = $tmpArray -join ":"
        $ffmpegArgsAL += @('-x265-params', "`"$x265String`"")

        Write-Verbose "ARGUMENT ARRAY IS:`n $($ffmpegArgsAL -join " ")`n"
        return $ffmpegArgsAL
    }
    #Build x265 arguments for 2-pass
    else {
        #Make a copy of the primary array for pass 2
        $ffmpegPassTwoArgsAL = $ffmpegArgsAL
        #First pass
        $tmpArray = $x265FirstPassArray + $resArray 
        $x265String = $tmpArray -join ":"
        $ffmpegArgsAL += @('-x265-params', "`"$x265String`"")
        #Second pass
        $tmpArray = @('pass=2', "stats='$($Paths.X265Log)'") + $x265Array + $resArray
        if ($x265ExtraArray) { $tmpArray += $x265ExtraArray }
        $x265String = $tmpArray -join ":"
        $ffmpegPassTwoArgsAL += @('-x265-params', "`"$x265String`"")

        Write-Verbose "FIRST PASS ARRAY IS:`n $($ffmpegArgsAL -join " ")`n"
        Write-Verbose "SECOND PASS ARRAY IS:`n $($ffmpegPassTwoArgsAL -join " ")`n" 
        return @($ffmpegArgsAL, $ffmpegPassTwoArgsAL)
    }
}
