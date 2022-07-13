using namespace System.Collections

<#
    .SYNOPSIS   
        Function to build the arguments used by Invoke-FFMpeg
    .DESCRIPTION
        Dynamically generates an array list of arguments based on parameters passed by the user,
        the preset selected, and a few hard coded default arguments based on my personal preference.
        If custom preset arguments are passed, they will override the default values. 
    .OUTPUTS
        Array list of ffmpeg arguments
#>
function Set-FFMpegArgs {      
    [CmdletBinding()]
    param (
        # Encoder to use
        [Parameter(Mandatory = $true)]
        [string]$Encoder,

        # Audio options
        [Parameter(Mandatory = $true)]
        [array]$Audio,

        # Subtitle options
        [Parameter(Mandatory = $true)]
        [array]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset,

        # Crop dimensions for the output file
        [Parameter(Mandatory = $true)]
        [int[]]$CropDimensions,

        # Rate Control configuration
        [Parameter(Mandatory = $true)]
        [array]$RateControl,

        # Preset parameter values, default or modified by user
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
        [string]$PsyRd,

        # Filter to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [int[]]$NoiseReduction,

        # Enable tree algorithm
        [Parameter(Mandatory = $false)]
        [int]$Tree,

        # Transform unit recursion depth (intra, inter)
        [Parameter(Mandatory = $false)]
        [int[]]$TuDepth,
 
        # Early exit setting for tu recursion depth
        [Parameter(Mandatory = $false)]
        [int]$LimitTu,

        # Enable/disable strong-intra-smoothing
        [Parameter(Mandatory = $false)]
        [int]$IntraSmoothing,

        # Enable NLMeans denoising filter
        [Parameter(Mandatory = $false)]
        [hashtable]$NLMeans,

        # Number of frame threads the encoder should use
        [Parameter(Mandatory = $false)]
        [int]$Threads,

        # Encoder level to use. Default is unset (encoder decision)
        [Parameter(Mandatory = $false)]
        [string]$Level,

        # Video buffering verifier: (bufsize, maxrate)
        [Parameter(Mandatory = $false)]
        [int[]]$VBV,
        
        [Parameter(Mandatory = $false)]
        [array]$FFMpegExtra,

        # Extra encoder parameters passed by user
        [Parameter(Mandatory = $false)]
        [hashtable]$EncoderExtra,

        # HDR data
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

    # Split rate control array
    $twoPass = $RateControl[2]
    $passType = $RateControl[3]
    $RateControl = $RateControl[0..($RateControl.Length - 3)]

    ## Unpack extra parameters ##

    if ($PSBoundParameters['FFMpegExtra']) {
        $ffmpegExtraArray = [ArrayList]@()
        foreach ($arg in $FFMpegExtra) {
            if ($arg -is [hashtable]) {
                foreach ($entry in $arg.GetEnumerator()) {
                    # Skip crop args. Handled in Set-VideoFilter
                    if ($entry.Value -notmatch "crop") {
                        $ffmpegExtraArray.AddRange(@("$($entry.Name)", "$($entry.Value)"))
                    }
                }
            }
            else { $ffmpegExtraArray.Add($arg) > $null }
        }
    }

    $skip = @{}
    @('OpenGop', 'Keyint', 'MinKeyInt', 'Sao').ForEach({ $skip.$_ = $false })
    if ($PSBoundParameters['EncoderExtra']) {
        $encoderExtraArray = [ArrayList]@()
        foreach ($arg in $EncoderExtra.GetEnumerator()) {
            if ($arg.Name -eq 'sao') { $skip.Sao = $true } 
            elseif ($arg.Name -eq 'open-gop') { $skip.OpenGOP = $true } 
            elseif ($arg.Name -eq 'keyint') { $skip.Keyint = $true } 
            elseif ($arg.Name -eq 'min-keyint') { $skip.MinKeyint = $true } 
            else {
                $encoderExtraArray.Add("$($arg.Name)=$($arg.Value)") > $null
            }
        }
    }

    ## Base Array Declarations ##

    #Primary array list initialized with global values
    [ArrayList]$ffmpegArgsAL = @(
        '-probesize'
        '100MB'
        '-i'
        "`"$($Paths.InputFile)`""
        if ($TrackTitle['VideoTitle']) {
            '-metadata:s:v:0'
            "title=$($TrackTitle['VideoTitle'])"
        }
        '-color_range'
        'tv'
        '-map'
        '0:v:0'
        '-c:v'
        ($Encoder -eq 'x265') ? 'libx265' : 'libx264'
        $Audio
        $Subtitles
        '-preset'
        $Preset
        $RateControl
    )

    # Settings common to both encoders
    [ArrayList]$baseArray = @(
        "qcomp=$QComp"
        "bframes=$($PresetParams.BFrames)"
        "aq-mode=$($PresetParams.AqMode)"
        "merange=$($PresetParams.Merange)"
        "rc-lookahead=$($PresetParams.RCLookahead)"
        "ref=$($PresetParams.Ref)"
        "aq-strength=$AqStrength"
        "deblock=$($Deblock[0]),$($Deblock[1])"
        if ($VBV) {
            "vbv-bufsize=$($VBV[0])"
            "vbv-maxrate=$($VBV[1])"
        }
    )

    # Assign settings unique to encoders
    [ArrayList]$encoderBaseArray =

    if ($Encoder -eq 'x265') {
         @(
            "tu-intra-depth=$($TuDepth[0])"
            "tu-inter-depth=$($TuDepth[1])"
            "limit-tu=$LimitTu"
            "b-intra=$($PresetParams.BIntra)"
            "psy-rdoq=$($PresetParams.PsyRdoq)"
            "nr-intra=$($NoiseReduction[0])"
            "nr-inter=$($NoiseReduction[1])"
            "strong-intra-smoothing=$IntraSmoothing"
            "cutree=$Tree"
            if ($PsyRd) {
                # If user accidentally enters in x264 format
                if ($PsyRd -match '(?<v1>\d\.?\d{0,2}).*\,.*\d.*' -and ([double]$Matches.v1 -lt 5.01)) {
                    "psy-rd=$($Matches.v1.Trim())"
                }
                elseif ([double]$PsyRd -lt 5.01) {
                    "psy-rd=$PsyRd"
                }
                else {
                    Write-Warning "Invalid input for psy-rd. Using default: 2.00"
                    'psy-rd=2.00'
                }
                
            }
            if ($PSBoundParameters['Threads']) {
                "frame-threads=$Threads"
            }
            if ($PSBoundParameters['Level']) {
                "level-idc=$Level"
            }
        )
    }
    else {
        @(
            "mbtree=$Tree"
            "nr=$($NoiseReduction[0])"
            if ($PSBoundParameters['Threads']) {
                "threads=$Threads"
            }
            if ($PSBoundParameters['Level']) {
                "level=$Level"
            }
            # user entered both psy values as one string
            # WIP: '^(?<v1>\d\.?\d{0,2}).*\,.*(?<v2>\d+\.?\d+)$'
            if ($PSBoundParameters['PsyRd'] -match '\d\.?\d{0,2}.*\,.*\d.*') {
                "psy-rd=$($PsyRd -replace '\s', '')"
            }
            elseif ($PSBoundParameters['PsyRd'] -match '\d\.?\d{0,2}.*') {
                "psy-rd=$($PsyRd -replace '\s', ''),$($PresetParams.PsyRdoq)"
            }
            else {
                'psy-rd=1.00,0.00'
            }
        )
    }

    # Combine base arrays
    $encoderBaseArray.AddRange($baseArray)

    ## Build Argument Array Lists ##

    # Set test encode arguments

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
    # If TestFrames is not used but a start code is passed
    elseif (!$PSBoundParameters['TestFrames'] -and $ffmpegExtraArray -contains '-ss') {
        $i = $ffmpegExtraArray.IndexOf('-ss')
        $ffmpegArgsAL.InsertRange($ffmpegArgsAL.IndexOf('-i'), @($ffmpegExtraArray[$i], $ffmpegExtraArray[$i + 1]))
        $ffmpegExtraArray.RemoveRange($i, 2)
    }
    
    # Set hard coded defaults unless overridden
    switch ($skip) {
        { $skip.OpenGOP -eq $false } { $encoderBaseArray.Add('open-gop=0') > $null }
        { $skip.KeyInt -eq $false } { $encoderBaseArray.Add('keyint=192') > $null }
        { $skip.MinKeyInt -eq $false } { $encoderBaseArray.Add('min-keyint=24') > $null }
    }
    
    # Set video specific filter arguments

    $vfHash = @{
        CropDimensions = $CropDimensions
        Scale          = $Scale
        FFMpegExtra    = $FFMpegExtra
        Deinterlace    = $Deinterlace
        Verbose        = $setVerbose
        NLMeans        = $NLMeans
    }
    try {
        $vfArray = Set-VideoFilter @vfHash
    }
    catch {
        Write-Error "Video filter exception: $($_.Exception)" -ErrorAction Stop
    }

    if ($vfArray) { $ffmpegArgsAL.AddRange($vfArray) }

    # Set res and bit depth related arguments for encoders

    if ($HDR) {
        $ffmpegArgsAL.AddRange(@('-pix_fmt', $HDR.PixelFmt))
        # Arguments specific to 2160p HDR
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
        $pixFmt = ($Encoder -eq 'x265') ? 'yuv420p10le' : 'yuv420p'
        $ffmpegArgsAL.AddRange(@('-pix_fmt', $pixFmt))
        # Arguments specific to 1080p SDR
        $resArray = @(
            'colorprim=bt709'
            'transfer=bt709'
            'colormatrix=bt709'
        )
    }
    $encoderBaseArray.AddRange($resArray)

    # Set ffmpeg extra arguments if passed
    if ($ffmpegExtraArray) {
        Write-Verbose "FFMPEG EXTRA ARGS ARE: `n $($ffmpegExtraArray -join ' ')`n"
        Write-Verbose "NOTE: If -ss was passed, it was moved before the file input and deleted from the above array"
        $ffmpegArgsAL.AddRange($ffmpegExtraArray) 
    }
    # Add extra encoder arguments if passed
    if ($encoderExtraArray) {
        $encoderBaseArray.AddRange($encoderExtraArray)
    }

    if ($twoPass) {
        [ArrayList]$x265FirstPassArray = switch -Regex ($passType) {
            "^d[efault]*$" {
                @(
                    $encoderBaseArray
                    "subme=$($PresetParams.Subme)"
                )
                break
            }
            "^f[ast]*$" {
                @(
                    $encoderBaseArray
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
                    $encoderBaseArray
                    'rect=0'
                    'amp=0'
                    'max-merge=2'
                    'subme=2'
                )
                break
            }
        }

        # Create copy for 2nd pass parameters
        $ffmpegPassTwoArgsAL = $ffmpegArgsAL.Clone()

        # Add remaining parameters for first/second pass based on encoder
        if ($Encoder -eq 'x265') {
            $x265FirstPassArray.AddRange(@('pass=1', "stats='$($Paths.X265Log)'"))
            $x265SecondPassArray = $encoderBaseArray.Clone()
            $x265SecondPassArray.AddRange(@('pass=2', "stats='$($Paths.X265Log)'", "subme=$($PresetParams.Subme)"))
 
            $ffmpegArgsAL.AddRange(@('-x265-params', "`"$($x265FirstPassArray -join ':')`"")) 
            $ffmpegPassTwoArgsAL.AddRange(@('-x265-params', "`"$($x265SecondPassArray -join ':')`""))
        }
        else {
            $x264FirstPassArray = $encoderBaseArray.Clone()
            $x264FirstPassArray.AddRange(@('pass=1', "stats='$($Paths.X265Log)'", "subme=$($PresetParams.Subme)"))
            $x264SecondPassArray = $x264FirstPassArray.Clone()
            $x264SecondPassArray[$x264SecondPassArray.IndexOf('pass=1')] = 'pass=2'

            $ffmpegArgsAL.AddRange(@('-x264-params', "`"$($x264FirstPassArray -join ':')`"")) 
            $ffmpegPassTwoArgsAL.AddRange(@('-x264-params', "`"$($x264SecondPassArray -join ':')`""))
        }
        
        Write-Verbose "FFMPEG FIRST PASS ARRAY IS: `n $($ffmpegArgsAL -join " ")`n"
        Write-Verbose "FFMPEG SECOND PASS ARRAY IS: `n $($ffmpegPassTwoArgsAL -join " ")`n"

        return @($ffmpegArgsAL, $ffmpegPassTwoArgsAL)
    }
    # CRF/1-Pass
    else {
        #Add remaining argument and join with ffmpeg array
        $encoderBaseArray.Add("subme=$($PresetParams.Subme)") > $null

        ($Encoder -eq 'x265') ?
        ($ffmpegArgsAL.AddRange(@('-x265-params', "`"$($encoderBaseArray -join ':')`""))) :
        ($ffmpegArgsAL.AddRange(@('-x264-params', "`"$($encoderBaseArray -join ':')`"")))

        Write-Verbose "FFMPEG ARGUMENT ARRAY IS:`n $($ffmpegArgsAL -join " ")`n"

        return $ffmpegArgsAL
    }
}
