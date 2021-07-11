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
        [Parameter()]
        [array]$Audio,

        # Parameter help description
        [Parameter()]
        [array]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset,

        # Crop dimensions for the output file
        [Parameter(Mandatory = $true)]
        [int[]]$CropDimensions,

        # Parameter help description
        [Parameter()]
        [array]$RateControl,

        # Parameter help description
        [Parameter()]
        [hashtable]$PresetParams,

        # Adjusts the quantizer curve compression factor
        [Parameter(Mandatory = $false)]
        [double]$QComp,

        # Deblock filter setting
        [Parameter(Mandatory = $false)]
        [Alias("DBF")]
        [int[]]$Deblock,

        # aq-strength. Higher values equate to a lower QP, but can also increase bitrate significantly
        [Parameter(Mandatory = $false)]
        [double]$AqStrength,

        # Filter to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [int[]]$NoiseReduction,

        # Enable/disable strong-intra-smoothing
        [Parameter(Mandatory = $false)]
        [int]$IntraSmoothing,

        # Parameter help description
        [Parameter()]
        [hashtable]$HDR,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        [int]$TestFrames,

        [Parameter(Mandatory = $false)]
        [switch]$Deinterlace
    )

    #Split rate control array
    $twoPass = $RateControl[2]
    $RateControl = $RateControl[0..($RateControl.Length - 2)]

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
        'sao=0'
        'rc-lookahead=48'
        'open-gop=0'
        'frame-threads=2'
        "psy-rd=$PsyRd"
        "qcomp=$QComp"
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

    #Default args for pass 1 in 2-pass encoding
    $x265FirstPassArray = @(
        'pass=1'
        "stats='$($Paths.X265Log)'"
        'rect=0'
        'max-merge=2'
        'keyint=192'
        'sao=0'
        'rc-lookahead=48'
        'open-gop=0'
        "psy-rd=$PsyRd"
        "qcomp=$QComp"
        'subme=2'
        'b-intra=0'
        "bframes=$($PresetParams.BFrames)"
        "psy-rdoq=$($PresetParams.PsyRdoq)"
        "aq-mode=$($PresetParams.AqMode)"
        "nr-intra=$($NoiseReduction[0])"
        "nr-inter=$($NoiseReduction[1])"
        "aq-strength=$AqStrength"
        "strong-intra-smoothing=$IntraSmoothing"
        "deblock=$($Deblock[0]),$($Deblock[1])"
    )

    ## End global array declarations ##

    ## Build Argument Arrays ##

    #Test frames. Null if not passed by user
    $testArray = $PSBoundParameters['TestFrames'] ? 
    ( @('-ss', '00:01:30', '-frames:v', $TestFrames) ) : 
    $null
    
    #Video filter array
    $vfArray = $Deinterlace ?
    ( @('-vf', "`"yadif, crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])`"") ) :
    ( @('-vf', "`"crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])`"") )

    #Set arguments for UHD/FHD based on the presence of HDR metadata
    if ($HDR) {
        $pxFormatArray = @('-pix_fmt', $HDR.PixelFmt)
        #Arguments specific to 2160p HDR
        $resArray = @(
            "colorprim=$($HDR.ColorPrimaries)"
            "transfer=$($HDR.Transfer)"
            "colormatrix=$($HDR.ColorSpace)"
            "$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma))"
            "max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL)"
            'chromaloc=2'
            'level-idc=5.1'
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

    $ffmpegArgsAL += $vfArray
    if ($testArray) { $ffmpegArgsAL += $testArray }
    $ffmpegArgsAL += $pxFormatArray

    #Build x265 arguments for CRF/ 1-pass
    if (!$twoPass) {
        #Combine x265 args and join
        $tmpArray = $x265Array + $resArray 
        $x265String = $tmpArray -join ":"
        $ffmpegArgsAL += @('-x265-params', "`"$x265String`"")

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
        $x265String = $tmpArray -join ":"
        $ffmpegPassTwoArgsAL += @('-x265-params', "`"$x265String`"")

        return @($ffmpegArgsAL, $ffmpegPassTwoArgsAL)
    }
}







