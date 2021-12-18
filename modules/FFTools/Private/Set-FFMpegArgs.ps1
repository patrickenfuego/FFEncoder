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

        # Encoder level to use. Default is unset (encoder decision)
        [Parameter(Mandatory = $false)]
        [string]$LevelIDC,

        # Video buffering verifier: (bufsize, maxrate)
        [Parameter(Mandatory = $false)]
        [int[]]$VBV,

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

        #Starting Point for test encodes. Integers are treated as a frame #
        [Parameter(Mandatory = $false)]
        [string]$TestStart,

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
                        $ffmpegExtraArray.AddRange(@("$($entry.Name)", "$($entry.Value)"))
                    }
                }
            }
            else { $ffmpegExtraArray.Add($arg) > $null }
        }
    }

    $skip = @{}
    @('OpenGop', 'RCL', 'Keyint', 'MinKeyInt', 'Merange', 'Sao').ForEach({ $skip.$_ = $false })
    if ($PSBoundParameters['x265Extra']) {
        $x265ExtraArray = [System.Collections.ArrayList]@()
        foreach ($arg in $x265Extra.GetEnumerator()) {
            if ($arg.Name -eq 'sao') { $skip.Sao = $true } 
            elseif ($arg.Name -eq 'open-gop')     { $skip.OpenGOP = $true } 
            elseif ($arg.Name -eq 'rc-lookahead') { $skip.RCL = $true } 
            elseif ($arg.Name -eq 'keyint')       { $skip.Keyint = $true } 
            elseif ($arg.Name -eq 'min-keyint')   { $skip.MinKeyint = $true } 
            elseif ($arg.Name -eq 'merange')      { $skip.Merange = $true } 
        
            $x265ExtraArray.Add("$($arg.Name)=$($arg.Value)") > $null
        }
    }

    ## Base Array Declarations ##

    #Primary array list initialized with global values
    $ffmpegArgsAL = [System.Collections.ArrayList]@(
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

    $x265BaseArray = [System.Collections.ArrayList]@(
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

    ## Build Argument Array Lists ##

    #Set test encode arguments

    if ($PSBoundParameters['TestFrames']) {
        $tParams = @{
            InputFile        = $Paths.InputFile
            TestFrames       = $TestFrames
            TestStart        = $TestStart
            PrimaryArguments = $ffmpegArgsAL
            ExtraArguments   = $ffmpegExtraArray
        }
        Set-TestParameters @tParams
    }
    #If TestFrames is not used but a start code is passed
    elseif (!$PSBoundParameters['TestFrames'] -and $ffmpegExtraArray -contains '-ss') {
        $i = $ffmpegExtraArray.IndexOf('-ss')
        $ffmpegArgsAL.InsertRange($ffmpegArgsAL.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1]))
        $ffmpegExtraArray.RemoveRange($i, 2)
    }
    
    #Set additional x265 arguments and override arguments

    if ($PSBoundParameters['FrameThreads']) {
        $x265BaseArray.Add("frame-threads=$FrameThreads") > $null
    }

    if ($PSBoundParameters['LevelIDC']) {
        $x265BaseArray.Add("level-idc=$LevelIDC") > $null
    }

    if ($PSBoundParameters['VBV']) {
        $x265BaseArray.AddRange(@("vbv-bufsize=$($VBV[0])", "vbv-maxrate=$($VBV[1])"))
    }

    switch ($skip) {
        { $skip.OpenGOP -eq $false }   { $x265BaseArray.Add('open-gop=0') > $null }
        { $skip.RCL -eq $false }       { $x265BaseArray.Add('rc-lookahead=48') > $null }
        { $skip.KeyInt -eq $false }    { $x265BaseArray.Add('keyint=192') > $null }
        { $skip.MinKeyInt -eq $false } { $x265BaseArray.Add('min-keyint=24') > $null }
        { $skip.Sao -eq $false }       { $x265BaseArray.Add('sao=0') > $null }
    }
    
    #Set video specific filter arguments

    $vfHash = @{
        CropDimensions = $CropDimensions
        Scale          = $Scale
        FFMpegExtra    = $FFMpegExtra
        Deinterlace    = $Deinterlace
        Verbosity      = $Verbosity
    }
    $vfArray = Set-VideoFilter @vfHash
    if ($vfArray) { $ffmpegArgsAL.AddRange($vfArray) }

    #Set res and bit depth related arguments for x265

    if ($HDR) {
        $ffmpegArgsAL.AddRange(@('-pix_fmt', $HDR.PixelFmt))
        #Arguments specific to 2160p HDR
        $resArray = @(
            "colorprim=$($HDR.ColorPrimaries)"
            "transfer=$($HDR.Transfer)"
            "colormatrix=$($HDR.ColorSpace)"
            "master-display=$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma))"
            "max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL)"
            'chromaloc=2'
            'hdr10-opt=1'
            'aud=1'
            'hrd=1'
            if ($HDR.HDR10Plus -eq $true) { 
                "dhdr10-info='$($Paths.HDR10Plus)'"
            }
        )
    }
    else {
        $ffmpegArgsAL.AddRange(@('-pix_fmt', 'yuv420p10le'))
        #Arguments specific to 1080p SDR
        $resArray = @(
            'colorprim=bt709'
            'transfer=bt709'
            'colormatrix=bt709'
        )
        if ($skip.Merange -eq $false) { $resArray += 'merange=44' }
    }
    $x265BaseArray.AddRange($resArray)

    #Set ffmpeg extra arguments if passed
    if ($ffmpegExtraArray) {
        Write-Verbose "FFMPEG EXTRA ARGS ARE: `n $($ffmpegExtraArray -join ' ')`n"
        Write-Verbose "NOTE: If -ss was passed, it was moved before the file input and deleted from the above array"
        $ffmpegArgsAL.AddRange($ffmpegExtraArray) 
    }
    #Add x265 extra arguments if passed
    if ($x265ExtraArray) {
        $x265BaseArray.AddRange($x265ExtraArray)
    }

    if ($twoPass) {
        [System.Collections.ArrayList]$x265FirstPassArray = switch -Regex ($passType) {
            "^d[efault]*$" {
                @(
                    $x265BaseArray
                    "subme=$($PresetParams.Subme)"
                )
                break
            }
            "^f[ast]*$" {
                @(
                    $x265BaseArray
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
                    $x265BaseArray
                    'rect=0'
                    'amp=0'
                    'max-merge=2'
                    'subme=2'
                )
                break
            }
        }

        #Add remaining parameters for first/second pass
        $x265FirstPassArray.AddRange(@('pass=1', "stats='$($Paths.X265Log)'"))
        $x265SecondPassArray = $x265BaseArray.Clone()
        $x265SecondPassArray.AddRange(@('pass=2', "stats='$($Paths.X265Log)'", "subme=$($PresetParams.Subme)"))
        #Create copy for 2nd pass and join with ffmpeg arrays
        $ffmpegPassTwoArgsAL = $ffmpegArgsAL.Clone()
        $ffmpegArgsAL.AddRange(@('-x265-params', "`"$($x265FirstPassArray -join ':')`"")) 
        $ffmpegPassTwoArgsAL.AddRange(@('-x265-params', "`"$($x265SecondPassArray -join ':')`""))

        Write-Verbose "FFMPEG FIRST PASS ARRAY IS: `n $($ffmpegArgsAL -join " ")`n"
        Write-Verbose "FFMPEG SECOND PASS ARRAY IS: `n $($ffmpegPassTwoArgsAL -join " ")`n"

        return @($ffmpegArgsAL, $ffmpegPassTwoArgsAL)
    }
    #CRF/1-Pass
    else {
        #Add remaining argument and join with ffmpeg array
        $x265BaseArray.Add("subme=$($PresetParams.Subme)") > $null
        $ffmpegArgsAL.AddRange(@('-x265-params', "`"$($x265BaseArray -join ':')`""))

        Write-Verbose "FFMPEG ARGUMENT ARRAY IS:`n $($ffmpegArgsAL -join " ")`n"

        return $ffmpegArgsAL
    }
}
