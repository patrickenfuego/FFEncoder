using namespace System.IO

<#
    .SYNOPSIS
        Cross-platform script for encoding HD/FHD/UHD video content using ffmpeg and x265
    .DESCRIPTION
        This script that is meant to make video encoding easier with ffmpeg. Instead of manually changing
        the script parameters for each encode, you can pass dynamic parameters to this script using a  
        simplified, yet powerful, API. Supports HD/FHD/UHD encoding with automatic fetching of HDR 
        metadata (including HDR10+), automatic cropping, and multiple audio & subtitle options.   
    .EXAMPLE
        ## Windows ##
        .\FFEncoder.ps1 -InputPath "Path\To\file.mkv" -CRF 16.5 -Preset medium -Deblock -3,-3 -Audio copy -OutputPath "Path\To\Encoded\File.mkv"
    .EXAMPLE
        ## MacOS or Linux ##
        ./FFEncoder.ps1 -InputPath "Path/To/file.mp4" -CRF 16.5 -Preset medium -Deblock -2,-2 -Audio none -OutputPath "Path/To/Encoded/File.mp4"
    .EXAMPLE 
        ## Test run. Encode only 10 frames ##
        ./FFEncoder.ps1 "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -CRF 20.0 -Audio copy -Subtitles none -TestFrames 10 -OutputPath "~/Movies/Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE
        ## Using shorthand parameter aliases ##
        .\FFEncoder.ps1 "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -c 20.5 -a c -dbf -3,-3 -a copyall -s d -o "C:\Users\user\Videos\Ex Machina Test.mkv" -t 500
    .EXAMPLE
        ## Copy English subtitles and all audio streams ##
        ./FFEncoder.ps1 -i "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -CRF 22.0 -Subtitles eng -Audio copyall -o "~/Movies/Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Copy existing AC3 stream, or transcode to AC3 if no existing streams are found ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio ac3 -Subtitles default -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Copy the primary audio stream and transcode a second audio stream to FDK AAC 2.0 using VBR 5 ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio c -Audio 2 faac -ABitrate2 5 -Stereo2 -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE 
        ## Encode the video at 25 mb/s using the -VideoBitrate parameter ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -Audio copy -VideoBitrate 25M -OutputPath "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv" 
    .EXAMPLE 
        ## Adjust psycho visual settings and aq-mode level/strength ##
        ./FFEncoder.ps1 "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -PsyRd 4.0 -PsyRdoq 1.50 -AqMode 1 -AqStrength 0.90 -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE
        ## Pass additional ffmpeg arguments not covered by other script parameters ##
        .\FFEncoder.ps1 -i "C:\Users\user\Videos\Ex.Machina.2014.DTS-HD.mkv" -CRF 18 -FFMpegExtra @{'-t' = 20}, 'nostats' -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE
        ## Pass additional x265 arguments not covered by other script parameters ##
        ./FFEncoder.ps1 "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -PsyRd 4.0 -CRF 20 -x265Extra @{'max-merge' = 1} -o "C:\Users\user\Videos\Ex Machina (2014) DTS-HD.mkv"
    .EXAMPLE
        ## Scale 2160p video down to 1080p using zscale and spline36 ##
        .\FFEncoder "$HOME\Videos\Ex.Machina.2014.DTS-HD.2160p.mkv" -Scale zscale -ScaleFilter spline36 -Res 1080p -CRF 18 -o "$HOME\Videos\Ex Machina (2014) DTS-HD 1080p.mkv"
    .INPUTS
        HD/FHD/UHD video file 
    .OUTPUTS
        crop.txt - File used for auto-cropping
        4K HDR encoded video file
    .NOTES
        For FFEncoder to work, the ffmpeg directory must be in your system PATH (consult your OS documentation for info on how to verify this)

        Be sure to include an extension at the end of your output file (.mkv, .mp4, .ts, etc.),
        or you may be left with a file that will not play
 
    .PARAMETER Help
        Displays help information for the script
    .PARAMETER TestFrames
        Performs a test encode with the number of frames provided
    .PARAMETER TestStart
        Starting point for test encodes. Accepts 3 formats:
            - 00:01:30 - Standard time format. This is the default
            - 200f     - Frame specifier. Add the 'f' modifier after the frame number to specify a starting frame. Accurate to +/- 1 frame
            - 200t     - Time specifier, in seconds. Add the 't' modifier after the number to specify a starting time. Accepts floating point values
    .PARAMETER InputPath
        Location of the file to be encoded
    .PARAMETER Audio
        Audio selection options. FFEncoder has 5 audio options:
            * copy/c       - Pass through the primary audio stream without re-encoding
            * copyall/ca   - Pass through all audio streams without re-encoding
            * none/n       - No audio will be copied
            * aac          - Convert primary audio stream to AAC. Default setting is 512 kb/s for multi-channel, and 128 kb/s for stereo
            * fdkaac/faac  - Convert primary audio stream to AAC using FDK AAC. Default setting is -vbr 3
            * aac_at       - Convert the primary audio stream to AAC using Apple's Core AudioToolbox encoder. MacOS only
            * dts          - Convert/copy DTS to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing DTS stream will be copied
            * ac3          - Convert/copy AC3 to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing AC3 stream will be copied
            * eac3         - Convert/copy E-AC3 to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing E-AC3 stream will be copied
            * flac/f       - Convert the primary audio stream to FLAC lossless audio
            * Stream #    - Copy an audio stream by its identifier in ffmpeg 
    .PARAMETER AudioBitrate
        Specifies the bitrate for the chosen codec (in kb/s). Values 1-5 are used to signal -vbr with libfdk_aac
    .PARAMETER Stereo
        Switch to downmix the paired audio stream to stereo
    .PARAMETER Subtitles
        Supports passthrough of embedded subtitles with the following options and languages:
            - All               - "all"  / "a"
            - None              - "none" / "n"
            - Default (first)   - "default" / "d"
            - English           - "eng"
            - French            - "fra"
            - German            - "ger"
            - Spanish           - "spa"
            - Dutch             - "dut"
            - Danish            - "dan"
            - Finnish           - "fin"
            - Norwegian         - "nor"
            - Czech             - "cze"
            - Polish            - "pol"
            - Chinese           - "chi"
            - Korean            - "kor"
            - Greek             - "gre"
            - Romanian          - "rum"
    .PARAMETER Preset
        The x265 preset to be used. Ranges from "placebo" (slowest) to "ultrafast" (fastest). Slower presets improve quality by enabling additional, more expensive, x265 parameters at the expensive of encoding time.
        Recommended presets (depending on source and purpose) are slow, medium, or fast. 
    .PARAMETER CRF
        Constant rate factor setting for video rate control. This setting attempts to keep quality consistent from frame to frame, and is most useful for targeting a specific quality level.    
        Ranges from 0.0 to 51.0. Lower values equate to a higher bitrate (better quality). Recommended: 14.0 - 24.0. At very low values, the output file may actually grow larger than the source.
        CRF 4.0 is considered mathematically lossless in x265 (vs. CRF 0.0 in x264)
    .PARAMETER VideoBitrate
        Average bitrate (ABR) setting for video rate control. This can be used as an alternative to CRF rate control, and is most useful for targeting a specific file size (bitrate / duration).
        Use the 'K' suffix to denote kb/s, or the 'M' suffix for mb/s:
            ex: 10000k (10,000 kb/s)
            ex: 10m (10 mb/s) | 10.5M (10.5 mb/s)
    .PARAMETER Pass
        The number of passes to perform when running an average bitrate encode using the VIdeoBitrate parameter
    .PARAMETER FirstPassType
        Tuning option for the first pass of a two pass encode. Accepted values (from slowest to fastest): Default/d, Custom/c, Fast/f. Default value is 'Default'/'d'.
        x265 only, as x264 automatically reduces certain settings during the first pass unless the slow-firstpass parameter is used
    .PARAMETER Deblock
        Deblock filter settings. The first value represents strength, and the second value represents frequency
    .PARAMETER AqMode
        x265 AQ mode setting. Ranges from 0 (disabled) - 3 (x264) / 4 (x265). See encoder documentation for more info on AQ Modes and how they work
    .PARAMETER AqStrength
        Adjusts the adaptive quantization offsets for AQ. Raising AqStrength higher than 2 will drastically affect the QP offsets, and can lead to high bitrates
    .PARAMETER PsyRd
        Psycho-visual enhancement. Higher values of PsyRd/PsyRDO strongly favor similar energy over blur.
        x265: Expects a decimal value
            ex: 1.00
        x264: You may pass psy-rdo and psy-trellis as one value like you normally would (MUST be quoted or errors will occur), or pass only psy-rdo
            ex: '1.00,0.05' - Passing both psy-rdo and psy-trellis
            ex: 1.00        - Passing only psy-rdo
    .PARAMETER PsyRdoq
        Psycho-visual enhancement. Favors high AC energy in the reconstructed image, but it less efficient than PsyRd.
        x264: This parameter can also be used for psy-trellis
    .PARAMETER NoiseReduction
        Filter to help reduce high frequency noise (such as film grain). 
        x265: First value represents intra frames, and the second value represents inter frames
        x264: Pass a single integer value
    .PARAMETER TuDepth
        Recursion depth for transform units (TU). Accepted values are 1-4. First value represents intra depth, and the second value represents inter depth. 
        Default values are 1, 1 (x265 only)
    .PARAMETER LimitTu
        Early exit condition for TU depth recursion. Accepted values are 0-4. Default is 0 (x265 only)
    .PARAMETER BFrames
        The number of consecutive B-Frames within a GOP. This is especially helpful for test encodes to determine the ideal number of B-Frames to use
    .PARAMETER BIntra 
        Enables the evaluation of intra modes in B slices. Accepted values are 0 (off) or 1 (on). Has a minor impact on performance (x265 only)
    .PARAMETER Subme
        The amount of subpel motion refinement to perform. At values larger than 2, chroma residual cost is included. Has a large performance impact
    .PARAMETER Merange
        Sets the motion estimation range. Higher values result in a more thorough motion vector search during inter-frame prediction
    .PARAMETER Ref
        Sets the number of reference frames used. Default value is based on the preset used. For x264, this may affect hardware compatibility
    .PARAMETER Tree
        Enable or disable encoder-specific motion vector lookahead algorithm. 1 is enabled, 0 is disabled
    .PARAMETER StrongIntraSmoothing
        Enables/disables strong-intra-smoothing. Default enabled (x265 only)
    .PARAMETER RCLookahead
        Sets the rate control lookahead size. Higher values will use more memory, but provide better compression efficiency
    .PARAMETER Threads
        Set the number of threads used by the encoder. More threads equate to faster encoding, but with slightly decreased quality. If no value is passed, the encoder default
        is used based on the number of logical CPU cores available to the system. If you aren't sure what this does, don't set it
    .PARAMETER Level
        Specifies the encoder level to use. Default value is unset (let the encoder decide)
    .PARAMETER VBV
        Sets video buffering verifier options. If passed, requires 2 arguments in the following order: (vbv-bufsize, vbv-maxrate). Default is unset (decided by the encoder level)
    .PARAMETER QComp
        Sets the quantizer curve compression factor, which effects the bitrate variance throughout the encode
    .PARAMETER OutputPath
        Location of the encoded output video file
    .PARAMETER FFMpegExtra
        Pass additional settings to ffmpeg that are not supplied by the script. Accepts single array arguments or hashtables in the form of <key = value>.
        WARNING: The script does not check for valid syntax, and assumes you know what you're doing
    .PARAMETER EncoderExtra
        Pass additional settings to the encoders that are not supplied by the script. Settings must be passed as a hashtable in the form of <key = value>.
        WARNING: The script does not check for valid syntax, and assumes you know what you're doing
    .PARAMETER Scale
        Upscale/downscale input to a different resolution. Compatible arguments are scale (ffmpeg default) or zscale (requires libzimg library)
    .PARAMETER ScaleFilter
        Filtering method used for rescaling input with the -Scale parameter. Compatible arguments:
            - scale: fast_bilinear, neighbor, area, gauss, sinc, spline, bilinear, bicubic, lanczos
            - zscale: point, spline16, spline36, bilinear, bicubic, lanczos
    .PARAMETER Resolution
        Upscale/downscale resolution used with the -Scale parameter. Default value is 1080p (1920 x 1080)
    .PARAMETER SkipDolbyVision
        Skip Dolby Vision encoding, even if metadata is present
    .PARAMETER SkipHDR10Plus
        Skip HDR10+ encoding, even if metadata is present
    .PARAMETER ExitOnError
        Converts certain non-terminating errors to terminating ones, such as input validation prompts. This can prevent blocking on automation when one
        running instance encounters an error
    .PARAMETER DisableProgress
        Switch to disable the progress bar during encoding
    .PARAMETER RemoveFiles
        Switch to delete extraneous files generated by the script (crop file, log file, etc.). The input, output, and report files will not be deleted
    .PARAMETER Deinterlace
        Deinterlacing filter using yadif. Currently only works with CRF encoding
    .PARAMETER GenerateReport
        Generates a user friendly report file with important encoding metrics pulled from the log file. File is saved with a .rep extension
    .lINK
        Check out the full documentation on GitHub - https://github.com/patrickenfuego/FFEncoder
    .LINK
        FFMpeg documentation - https://ffmpeg.org
    .LINK
        x265 HEVC Documentation - https://x265.readthedocs.io/en/master/introduction.html

#>

[CmdletBinding(DefaultParameterSetName = "CRF")]
param (
    [Parameter(Mandatory = $true, ParameterSetName = "Help")]
    [Alias("H", "/?", "?")]
    [switch]$Help,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("x264", "x265")]
    [Alias("Enc")]
    [string]$Encoder = "x265",

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = "Pass")]
    [ValidateScript( { if (Test-Path $_) { $true } else { throw 'Input path does not exist' } } )]
    [Alias("I")]
    [string]$InputPath,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("copy", "c", "copyall", "ca", "aac", "none", "n", "ac3", "dee_dd", "dee_ac3", "dd", "dts", "flac", "f",
        "eac3", "ddp", "dee_ddp", "dee_eac3", "dee_thd", "fdkaac", "faac", "aac_at", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)]
    [Alias("A")]
    [string]$Audio = "copy",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(-1, 3000)]
    [Alias("AB", "ABitrate")]
    [int]$AudioBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("2CH", "ST")]
    [switch]$Stereo,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("copy", "c", "copyall", "ca", "aac", "none", "n", "ac3", "dee_dd", "dee_ac3", "dd", "dts", "flac", "f",
        "eac3", "ddp", "dee_ddp", "dee_eac3", "dee_thd", "fdkaac", "faac", "aac_at", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)]
    [Alias("A2")]
    [string]$Audio2 = "none",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(-1, 3000)]
    [Alias("AB2", "ABitrate2")]
    [int]$AudioBitrate2,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("2CH2", "ST2")]
    [switch]$Stereo2,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("all", "a", "copyall", "ca", "none", "default", "d", "n", "eng", "fre", "ger", "spa", "dut", "dan", "fin", "nor", "cze", 
        "pol", "chi", "kor", "gre", "rum", "rus", "swe")]
    [Alias("S", "Subs")]
    [string]$Subtitles = "default",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("placebo", "veryslow", "slower", "slow", "medium", "fast", "faster", "veryfast", "superfast", "ultrafast")]
    [Alias("P")]
    [string]$Preset = "slow",

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [ValidateRange(0.0, 51.0)]
    [Alias("C")]
    [double]$CRF,

    [Parameter(Mandatory = $true, ParameterSetName = "Pass")]
    [Alias("VBitrate")]
    [ValidateScript(
        {
            $_ -cmatch "(?<num>\d+\.?\d{0,2})(?<suffix>[K k M]+)"
            if ($Matches) {
                switch ($Matches.suffix) {
                    "K" { 
                        if ($Matches.num -gt 99000 -or $Matches.num -lt 1000) {
                            throw "Bitrate out of range. Must be between 1,000-99,000 kb/s"
                        }
                        else { $true }
                    }
                    "M" {
                        if ($Matches.num -gt 99 -or $Matches.num -le 1) {
                            throw "Bitrate out of range. Must be between 1-99 mb/s"
                        }
                        else { $true }
                    }
                    default { throw "Invalid Suffix. Suffix must be 'K/k' (kb/s) or 'M' (mb/s)" }
                }
            }
            else { throw "Invalid bitrate input. Example formats: 10000k (10,000 kb/s) | 10M (10 mb/s)" }
        }
    )]
    [string]$VideoBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 2)]
    [int]$Pass = 2,

    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("Default", "d", "Fast", "f", "Custom", "c")]
    [Alias("FPT", "PassType")]
    [string]$FirstPassType = "Default",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(-6, 6)]
    [ValidateCount(2, 2)]
    [Alias("DBF")]
    [int[]]$Deblock = @(-2, -2),

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 4)]
    [Alias("AQM")]
    [int]$AqMode,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.0, 3.0)]
    [Alias("AQS")]
    [double]$AqStrength = 1.00,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("PRD", "PsyRDO")]
    [string]$PsyRd,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.0, 50.0)]
    [Alias("PRQ", "PsyTrellis")]
    [double]$PsyRdoq,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 16)]
    [int]$Ref,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 1)]
    [Alias("MBTree", "CUTree")]
    [int]$Tree = 1,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 32768)]
    [Alias("MR")]
    [int]$Merange,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 2000)]
    [ValidateCount(1, 2)]
    [Alias("NR")]
    [int[]]$NoiseReduction = @(0, 0),

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateScript(
        {
            if ($_.Count -eq 0) { throw "NLMeans Hashtable must contain at least 1 value" }
            $flag = $false
            foreach ($k in $_.Keys) {
                if ($k -notin 's', 'p', 'pc', 'r', 'rc') {
                    throw "Invalid key. Valid keys are 's', 'p', 'pc', 'r', 'rc'"
                }
                else { $flag = $true }
            }
            if ($flag = $true) { $true }
            else { throw "Invalid NLMeans hashtable. See https://ffmpeg.org/ffmpeg-filters.html#nlmeans-1" }
        }
    )]
    [Alias("NL")]
    [hashtable]$NLMeans,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 4)]
    [ValidateCount(2, 2)]
    [Alias("TU")]
    [int[]]$TuDepth = @(1, 1),

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 4)]
    [Alias("LTU")]
    [int]$LimitTu = 0,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0.0, 1.0)]
    #[Alias("Q")]
    [double]$QComp = 0.60,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 16)]
    [Alias("B")]
    [int]$BFrames,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 1)]
    [Alias("BINT")]
    [int]$BIntra,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 11)]
    [Alias("SM", "Subpel")]
    [int]$Subme,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 1)]
    [Alias("SIS")]
    [int]$StrongIntraSmoothing = 1,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet('1', '1b', '2', '1.1', '1.2', '1.3', '2.1', '21', '2.2', '3.1', '3.2', '4', '4.1', '4.2', '41', '5', '5.1', '51',
        '5.2', '52', '6', '6.1', '61', '6.2', '62', '8.5', '85')]
    [Alias('L')]
    [string]$Level,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateCount(2, 2)]
    [int[]]$VBV,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(1, 64)]
    [Alias("FrameThreads")]
    [int]$Threads,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateRange(0, 250)]
    [Alias("RCL", "Lookahead")]
    [int]$RCLookahead,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("FE", "ffmpeg")]
    [array]$FFMpegExtra,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("Extra")]
    [hashtable]$EncoderExtra,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("T", "Test")]
    [int]$TestFrames,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("Start", "TS")]
    [string]$TestStart = "00:01:30",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("Del", "RM")]
    [switch]$RemoveFiles,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [Alias("DI")]
    [switch]$Deinterlace,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("Scale", "ZScale")]
    [Alias("Resize", "Resample")]
    [string]$Scale,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("point", "spline16", "spline36", "bilinear", "bicubic", "lanczos",
        "fast_bilinear", "neighbor", "area", "gauss", "sinc", "spline", "bicublin")]
    [Alias("SF", "ResizeType")]
    [string]$ScaleFilter = "bilinear",

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [ValidateSet("2160p", "1080p", "720p")]
    [Alias("Res", "R")]
    [string]$Resolution,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [alias("Report", "GR")]
    [switch]$GenerateReport,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [alias("NoDV", "SDV")]
    [switch]$SkipDolbyVision,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [alias("No10P", "STP")]
    [switch]$SkipHDR10Plus,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [alias("Exit")]
    [switch]$ExitOnError,

    [Parameter(Mandatory = $false, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $false, ParameterSetName = "Pass")]
    [alias("NoProgressBar")]
    [switch]$DisableProgress,

    [Parameter(Mandatory = $true, ParameterSetName = "CRF")]
    [Parameter(Mandatory = $true, ParameterSetName = "Pass")]
    [ValidateNotNullOrEmpty()]
    [Alias("O")]
    [string]$OutputPath
)

#########################################################
# Set Console Configuration for Best Experience         #                   
#########################################################

$console = (Get-Host).UI.RawUI
$currentTitle = $console.WindowTitle
$console.ForegroundColor = 'White'
$console.BackgroundColor = 'Black'
$console.WindowTitle = 'FFEncoder'

#########################################################
# Define Variables                                      #                   
#########################################################

# $banner_old = @'
# _____  _      _               _   _         _____ _____ _____                     _           
# |  ___(_)_ __(_)_ __   __ _  | | | |_ __   |  ___|  ___| ____|_ __   ___ ___   __| | ___ _ __ 
# | |_  | | '__| | '_ \ / _` | | | | | '_ \  | |_  | |_  |  _| | '_ \ / __/ _ \ / _` |/ _ \ '__|
# |  _| | | |  | | | | | (_| | | |_| | |_) | |  _| |  _| | |___| | | | (_| (_) | (_| |  __/ |   
# |_|   |_|_|  |_|_| |_|\__, |  \___/| .__/  |_|   |_|   |_____|_| |_|\___\___/ \__,_|\___|_|   
#                       |___/        |_|     
# '@

$banner1 = @'
             _____  _      _               _   _                   
             |  ___(_)_ __(_)_ __   __ _  | | | |_ __    
             | |_  | | '__| | '_ \ / _` | | | | | '_ \  
             |  _| | | |  | | | | | (_| | | |_| | |_) |    
             |_|   |_|_|  |_|_| |_|\__, |  \___/| .__/   
                                   |___/        |_|         

'@

$banner2 = @'
███████ ███████ ███████ ███    ██  ██████  ██████  ██████  ███████ ██████  
██      ██      ██      ████   ██ ██      ██    ██ ██   ██ ██      ██   ██ 
█████   █████   █████   ██ ██  ██ ██      ██    ██ ██   ██ █████   ██████  
██      ██      ██      ██  ██ ██ ██      ██    ██ ██   ██ ██      ██   ██ 
██      ██      ███████ ██   ████  ██████  ██████  ██████  ███████ ██   ██ 

'@

#########################################################
# Function Definitions                                  #        
#########################################################

# Returns an object containing the paths needed throughout the script
function Set-ScriptPaths ([hashtable]$OS) {
    if ($InputPath -match "(?<root>.*(?:\\|\/)+)(?<title>.*)\.(?<ext>[a-z 2 4]+)") {
        $root = $Matches.root
        $title = $Matches.title
        $ext = $Matches.ext
        if ($OutputPath -match "(?<oRoot>.*(?:\\|\/)+)(?<oTitle>.*)\.(?<oExt>[a-z 2 4]+)") {
            $oRoot = $Matches.oRoot
            $oTitle = $Matches.oTitle
            $oExt = $Matches.oExt
        }
        # If regex match can't be made on the output path, use input matches instead
        else {
            $oRoot = $root
            $oTitle = $title
            $oExt = $ext
        }
        # Creating path strings used throughout the script
        $cropPath = [Path]::Join($root, "$title`_crop.txt")
        $logPath = [Path]::Join($root, "$title`_encode.log")
        $x265Log = [Path]::Join($root, "x265_2pass.log")
        $stereoPath = [Path]::Join($root, "$oTitle`_stereo.$oExt")
        $reportPath = [Path]::Join($root, "$oTitle.rep")
        $hdr10PlusPath = [Path]::Join($root, "metadata.json")
        $dvPath = [Path]::Join($root, "rpu.bin")
        $hevcPath = [Path]::Join($oRoot, "$oTitle.hevc")
    }
    # Regex match could not be made on the folder pattern
    else {
        Write-Host "Could not match root folder pattern. Using OS default path instead..."
        Write-Host $os.OperatingSystem "detected. Using path: <$($os.DefaultPath)>"
        # Creating path strings if regex match fails - use OS default
        $cropPath = Join-Path -Path $os.DefaultPath -ChildPath "crop.txt"
        $logPath = Join-Path -Path $os.DefaultPath -ChildPath "encode.log"
        $x265Log = Join-Path -Path $os.DefaultPath -ChildPath "x265_2pass.log"
        $stereoPath = Join-Path -Path $os.DefaultPath -ChildPath "stereo.mkv"
        $reportPath = Join-Path -Path $os.DefaultPath -ChildPath "report.rep"
        $hdr10PlusPath = Join-Path -Path $os.DefaultPath -ChildPath "metadata.json"
        $dvPath = Join-Path -Path $os.DefaultPath -ChildPath "rpu.bin"
        $hevcPath = Join-Path -Path $os.DefaultPath -ChildPath "hevc.hevc"
    }

    if ($psReq) {
        Write-Host "Crop file path is: $($PSStyle.Foreground.Cyan+$PSStyle.Underline)$cropPath"
        Write-Host ""
    }
    else {
        Write-Host "Crop file path is: " -NoNewline
        Write-Host "<$cropPath>" @emphasisColors
        Write-Host ""
    }

    $pathObject = @{
        InputFile  = $InputPath
        Root       = $root
        Extension  = $oExt
        RemuxPath  = $remuxPath
        StereoPath = $stereoPath
        CropPath   = $cropPath
        LogPath    = $logPath
        X265Log    = $x265Log
        Title      = $oTitle
        ReportPath = $reportPath
        HDR10Plus  = $hdr10PlusPath
        DvPath     = $dvPath
        HevcPath   = $hevcPath
        OutputFile = $OutputPath
    }
    return $pathObject
}

## End Functions ##

#########################################################
# Main Script Logic                                     #    
#########################################################

<#
    SETUP

    Help
    Verbose preference
    Verify PowerShell version
    Import Module
#>

# Print help content and exit
if ($Help) { Get-Help .\FFEncoder.ps1 -Full; exit 0 }
# Enable verbose logging if passed
if ($PSBoundParameters['Verbose']) { $vLevel = 'Continue' }

# Verify PowerShell version
if (!(Get-Command 'pwsh') -or (Get-Command 'pwsh').Version -lt [version]'7.0.0.0') { 
    $params = @{
        Category  = "NotInstalled"
        Exception = [System.ExecutionEngineException]::new("The script requires PowerShell 7.0 or greater")
        ErrorId   = -1
    }
    Write-Error @params -ErrorAction Stop
}
# If pwsh 7 is installed, but currently running from Windows PowerShell context
elseif ($PSVersionTable.PSVersion -lt [version]'7.0.0.0') {
    $msg = "Currently running with PowerShell $($PSVersionTable.PSVersion.Major). Switch to PowerShell 7"
    $params = @{
        Category  = "InvalidOperation"
        Exception = [System.ExecutionEngineException]::new($msg)
        ErrorId   = -2
    }
    Write-Error @params -ErrorAction Stop
}

# Check if system meets requirements for $PSStyle
$Global:psReq = ($PSVersionTable.PSVersion -ge [version]'7.2.0.0') ? $true : $false

# Import FFTools module
Import-Module -Name "$PSScriptRoot\modules\FFTools"

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$startTime = (Get-Date).ToLocalTime()

# Write the welcome banner
Write-Host "----------------------------------------------------------------------------------------------" @emphasisColors
if ($psReq) {
    Write-Host "$($PSStyle.Foreground.FromRGB(92, 255, 114))$($PSStyle.Bold)$($banner1)$($PSStyle.Reset)"
    Write-Host "$($PSStyle.Foreground.FromRGB(97, 30, 164))$($PSStyle.Bold)$($banner2)$($PSStyle.Reset)"
}
else {
    $bColors = @{ ForegroundColor = 'Magenta'; BackgroundColor = 'Black' }
    Write-Host $banner1 @bColors
    Write-Host $banner2 @bColors
}
Write-Host "----------------------------------------------------------------------------------------------" @emphasisColors

Write-Host "Start Time: $startTime`n"

# Generating paths to various files
$paths = Set-ScriptPaths -OS $osInfo
# if the output path already exists, prompt to delete the existing file or exit script. Otherwise, try to create it
if ([File]::Exists($paths.OutputFile)) { 
    Remove-FilePrompt -Path $paths.OutputFile -Type "Primary" 
}
else { 
    if (![Directory]::Exists($(Split-Path $paths.OutputFile -Parent))) {
        Write-Host "Creating output path directory structure..." @progressColors
        [Directory]::CreateDirectory($(Split-Path $paths.OutputFile -Parent)) > $null
        if (!$?) { 
            Write-Error "Could not create the specified output directory" -ErrorAction Stop
        }
    }
}

<#
    VALIDATE INPUT - Check:
    
    Parameter combinations
        - TODO: Too complicated for parameter sets...try dynamic params?
    Primary audio type if transcoding was selected
        - Warn if transcoding lossy -> lossy
    x264 or x265 settings that use different value ranges
#>

# Verify test parameters and prompt if one is missing (unless ExitOnError is present)
if ($PSBoundParameters['TestStart'] -and !$PSBoundParameters['TestFrames']) {
    $params = @{
        Message          = "No test duration was specified using -TestFrames"
        Category         = "InvalidArgument"
        CategoryActivity = "Test Encode"
        TargetObject     = $TestFrames
        ErrorId          = 2
    }
    
    if (!$PSBoundParameters['ExitOnError']) {
        Write-Error @params
        # Prompt to enter TestFrames. Loop until an integer is entered
        do {
            $TestFrames = Read-Host "Enter the number of test frames to use"
        } until (($TestFrames -as [int]) -is [int])
        $TestFrames = [int]$TestFrames
    }
    else { Write-Error @params -ErrorAction Stop }
}

# If scale is used, verify arguments and handle errors
if (($PSBoundParameters['ScaleFilter'] -or $PSBoundParameters['Resolution']) -and 
    !$PSBoundParameters['Scale']) {

    $params = @{
        Message           = "Scaling parameters were passed, but no scaling method was specified"
        RecommendedAction = 'Enter a value for $Scale'
        Category          = "InvalidArgument"
        CategoryActivity  = "Scale Parameter"
        TargetObject      = $Scale
        ErrorId           = 3
    }
    
    if (!$PSBoundParameters['ExitOnError']) {
        Write-Error @params
        # Loop until a valid entry is entered
        do {
            $Scale = Read-Host "Enter a scaling method (scale or zscale)"
        } until ($Scale -in "Scale", "Zscale")
    }
    else { Write-Error @params -ErrorAction Stop }
}
# Verify the scaling filter passed is compatible with the scale method
elseif ($PSBoundParameters['Scale'] -and $PSBoundParameters['ScaleFilter']) {
    try {
        $ScaleFilter = $PSBoundParameters['ExitOnError'] ? 
        (Confirm-ScaleFilter -Scale $Scale -ScaleFilter $ScaleFilter -ExitOnError:$true) :
        (Confirm-ScaleFilter -Scale $Scale -ScaleFilter $ScaleFilter -ExitOnError:$false)

        Write-Verbose "Scale filter is: $ScaleFilter"
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
    
    # Warn if no scale filter was passed
    if (!$PSBoundParameters['ScaleFilter']) {
        Write-Warning "No scaling filter specified for scaling. Using default: bilinear"
        Write-Host ""
    }
    # Warn if no resolution was passed, and set to 1080p
    if (!$PSBoundParameters['Resolution']) {
        Write-Warning "No resolution specified for scaling. Using default: 1080p"
        Write-Host ""
        $Resolution = '1080p'
    }

    # Collect the arguments into a hashtable
    $scaleHash = @{
        Scale       = $Scale
        ScaleFilter = $ScaleFilter
        Resolution  = $Resolution
    }
}

# Validate input audio
$res = ffprobe -hide_banner -loglevel error -select_streams a:0 -of default=noprint_wrappers=1:nokey=1 `
    -show_entries "stream=codec_name,profile" `
    -i $Paths.InputFile

if ($res) {
    $lossless = (($res[0] -like 'truehd') -xor ($res[1] -like 'DTS-HD MA') -xor ($res[0] -like 'flac')) ? 
    $true : $false
    $test1 = @("^c[opy]*$", "c[opy]*a[ll]*", "^n[one]?").Where({ $Audio -match $_ })
    $test2 = @("^c[opy]*$", "c[opy]*a[ll]*", "^n[one]?").Where({ $Audio2 -match $_ })
    if (!$lossless -and (!$test1 -or !$test2)) {
        $msg = "Audio stream 0 is not lossless. Transcoding to another lossy codec is NOT recommended " +
        "(If you're stream copying a codec by name, ignore this)"
        Write-Warning $msg
    }
}
elseif (!$res -and ($PSBoundParameters['Audio'] -or $PSBoundParameters['Audio2'])) {
    Write-Warning "No audio streams were found in the source file. Audio parameters will be ignored"
    $Audio = 'none'
    $Audio2 = 'none'
}

<#
    CROP FILE GENERATION
    HDR ELIGIBILITY VERIFICATION

    If crop arguments are passed via FFMpegExtra, don't generate crop file
    If HDR metadata is present but x264 is selected, exit on error (not supported)
#>

$skipCropFile = $false
if ($PSBoundParameters['FFMpegExtra']) {
    foreach ($arg in $FFMpegExtra) {
        if ($arg -is [hashtable]) {
            foreach ($val in $arg.Values) {
                if ($val -match "crop") { $skipCropFile = $true }
            }
        }
    }
}
if ($skipCropFile) {
    Write-Host "Crop override arguments detected. Skipping crop file generation" @warnColors
    Write-Host ""
    # Check if source is 4K for HDR metadata
    $res = ffprobe -v error -select_streams v:0 -show_entries stream=width, height -of csv=s=x:p=0 $InputPath
    $cropDim = ($res -like '3840x2160?') ? ( @(-1, -1, $true) ) : ( @(-1, -1, $false) )
}
else {
    New-CropFile -InputPath $paths.InputFile -CropFilePath $paths.CropPath -Count 1
    # Calculating the crop values. Re-throw terminating error if one occurs
    $cropDim = Measure-CropDimensions -CropFilePath $paths.CropPath -Resolution $Resolution
}

<#
    SET RATE CONTROL

    Set parameter arrays based on input
#>

if ($PSBoundParameters['CRF']) {
    $rateControl = @('-crf', $CRF, $false, $false)
}
elseif ($PSBoundParameters['VideoBitrate']) {
    $rateControl = switch ($Pass) {
        1 { @('-b:v', $VideoBitrate, $false, $false) }
        Default { @('-b:v', $VideoBitrate, $true, $FirstPassType) }
    }
}
else {
    Write-Warning "There was an error verifying rate control. This statement should be unreachable. CRF 18.0 will be used"
    $rateControl = @('-crf', '18.0', $false, $false)
}

<#
    FORMAT AUDIO STRUCTURE

    Condense audio parameters so that they can be passed around easily
#>

$audioHash1 = @{
    Audio   = $Audio
    Bitrate = $AudioBitrate
    Stereo  = $Stereo
}
if ($PSBoundParameters['Audio2']) {
    $audioHash2 = @{
        Audio   = $Audio2
        Bitrate = $AudioBitrate2
        Stereo  = $Stereo2
    }
}
else { $audioHash2 = $null }
$audioArray = @($audioHash1, $audioHash2)


<#
    FFMPEG PARAMETERS

    Set argument hashtable for encoders
#>

$ffmpegParams = @{
    Encoder         = $Encoder
    CropDimensions  = $cropDim
    AudioInput      = $audioArray
    Subtitles       = $Subtitles
    Preset          = $Preset
    RateControl     = $rateControl
    Deblock         = $Deblock
    Deinterlace     = $Deinterlace
    AqMode          = $AqMode
    AqStrength      = $AqStrength
    PsyRd           = $PsyRd
    PsyRdoq         = $PsyRdoq
    NoiseReduction  = $NoiseReduction
    NLMeans         = $NLMeans
    TuDepth         = $TuDepth
    LimitTu         = $LimitTu
    Tree            = $Tree
    Merange         = $Merange
    Ref             = $Ref 
    Qcomp           = $QComp
    BFrames         = $BFrames
    BIntra          = $BIntra
    Subme           = $Subme 
    IntraSmoothing  = $StrongIntraSmoothing
    Threads         = $Threads
    RCLookahead     = $RCLookahead
    Level           = $Level
    VBV             = $VBV
    FFMpegExtra     = $FFMpegExtra
    EncoderExtra    = $EncoderExtra
    Scale           = $scaleHash
    Paths           = $paths
    Verbosity       = $vLevel
    TestFrames      = $TestFrames
    TestStart       = $TestStart
    SkipDolbyVision = $SkipDolbyVision
    SkipHDR10Plus   = $SkipHDR10Plus
    DisableProgress = $DisableProgress
}

try {
    Invoke-FFMpeg @ffmpegParams
}
catch {
    $params = @{
        Message           = "An error occurred before ffmpeg could be invoked. Message:`n$($_.Exception.Message)"
        RecommendedAction = 'Correct the Error Message'
        Category          = "InvalidArgument"
        CategoryActivity  = "FFmpeg Function Invocation"
        TargetObject      = $ffmpegParams
        ErrorId           = 55
    }

    Write-Error @params -ErrorAction Stop
}

<#
    POST ENCODE
    
    Muxing
    Results
    Generate Report
    Cleanup

    TODO: Refactor this mess
#>

Start-Sleep -Milliseconds 500

$skipStereo = $false
$mId = 0
# Check for running jobs
$deeRunning = (Get-Job -Name 'Dee Encoder' -ErrorAction SilentlyContinue).State -eq 'Running'
$stereoRunning = (Get-Job -Name 'Stereo Encoder' -ErrorAction SilentlyContinue).State -eq 'Running'
# Set the temporary output file
$output = $Paths.OutputFile -replace '^(.+)\.(.+)', '$1 (1).$2'

# Handle dee encoded audio. If a stereo track was created, add it as well
if (($Audio -like '*dee*' -or $Audio2 -like '*dee*') -and $OutputPath.EndsWith('mkv')) {
    # Check for stereo and add it
    if ([File]::Exists($Paths.StereoPath) -and !$stereoRunning) {
        $skipStereo = $true
        Get-Job -State Completed -ErrorAction SilentlyContinue | Remove-Job
    }
    elseif ([File]::Exists($Paths.StereoPath) -and $stereoRunning) {
        Write-Host "Stereo Encoder background job is still running. Mux the file manually" @warnColors
    }
    
    # Mux in the dee encoded file if job isn't running
    if ($deeRunning) {
        Write-Host "Dee Encoder background job is still running. Mux the file manually" @warnColors
    }
    else {
        Get-Job -State Completed -ErrorAction SilentlyContinue | Remove-Job

        if ((Get-Command 'mkvmerge') -and $OutputPath.EndsWith('mkv')) {
            #Find the dee encoded output file
            $deePath = Get-ChildItem $(Split-Path $Paths.OutputFile -Parent) |
                Where-Object { $_ -like '*.*3' -or $_ -like '*.thd' } | 
                    Select-Object -First 1 -ExpandProperty FullName

            $muxPaths = @{
                Input    = $paths.OutputFile
                Output   = $output
                Audio    = $deePath
                Title    = $paths.Title
                Language = $paths.Language
            }
            if ($skipStereo) {
                $muxPaths.Stereo = $paths.StereoPath
                $mId = 3
            }
            else { $mId = 2 }

            Invoke-MkvMerge -Paths $muxPaths -Mode 'remux' -ModeID $mId
        }
        # If no mkvmerge, mux with ffmpeg
        else {
            
            $fArgs = @(
                '-i'
                "$($Paths.OutputFile)"
                '-i'
                $deePath
                if ($skipStereo) {
                    '-i'
                    "$($Paths.StereoPath)"
                }
                '-loglevel'
                'error'
                '-map'
                0
                '-map'
                '1:a'
                if ($skipStereo) {
                    '-map'
                    '2:a'
                }
                '-c'
                'copy'
                '-y'
                $output
            )

            ffmpeg $fArgs
        }

        if ($PSBoundParameters['RemoveFiles']) { Remove-Item $deePath -Force }
    }
}

# If stream copy and stereo are used, mux the stream back into the container
if ((@('copy', 'c', 'copyall', 'ca') -contains $Audio) -and $Stereo2 -and !$skipStereo) {
    if ($stereoRunning) {
        Write-Host "Stereo encoder background job is still running. Mux the file manually" @warnColors
    }
    else {
        Write-Host "`nMultiplexing stereo track back into the output file..." @progressColors

        # If mkvmerge is available, use it instead of ffmpeg
        if ((Get-Command 'mkvmerge') -and $OutputPath.EndsWith('mkv')) {
            $muxPaths = @{
                Input    = $Paths.OutputFile
                Output   = $output
                Audio    = $paths.StereoPath
                Title    = $paths.Title
                Language = $Paths.Language
            }
            $mId = 1
            Invoke-MkvMerge -Paths $muxPaths -Mode 'remux' -ModeID 1
        }
        # if not mkv or no mkvmerge, mux with ffmpeg
        else {
            ffmpeg -i $paths.OutputFile -i $paths.StereoPath -loglevel error -map 0 -map 1:a -c copy -y $output
        }
    }
}

# Verify if temp output file exists and delete it if it is at least as large or larger than original output
if ([File]::Exists($output) -and 
    (([FileInfo]($output)).Length -ge ([FileInfo]($Paths.OutputFile)).Length)) {

    Remove-Item $Paths.OutputFile -Force

    if (!$?) { 
        Write-Host ""
        Write-Host "Could not delete the original output file. It may be in use by another process" @warnColors 
    }
    #[File]::Move($output, "$($paths.Title).$($paths.Extension)")
    Rename-Item $output "$($paths.Title).$($paths.Extension)"
}

# Display a quick view of the finished log file, the end time and total encoding time
($Encoder -eq 'x265') ? (Get-Content -Path $Paths.LogPath -Tail 8) : (Get-Content -Path $Paths.LogPath -Tail 19)
$endTime = (Get-Date).ToLocalTime()
Write-Host "`nEnd time: $endTime"
$stopwatch.Stop()
"Encoding Time: {0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds`n" -f $stopwatch.Elapsed

# Generate the report file if parameter is present
if ($PSBoundParameters['GenerateReport']) {
    $twoPass = ($PSBoundParameters['VideoBitrate'] -and $Pass -eq 2) ? $true : $false
    $params = @{
        DateTimes = @($startTime, $endTime)
        Duration  = $stopwatch
        Paths     = $paths
        TwoPass   = $twoPass
        Encoder   = $Encoder
    }
    Write-Report @params
}

# Delete extraneous files if switch is present
if ($PSBoundParameters['RemoveFiles']) {
    Write-Host "Removing extra files..." -NoNewline
    Write-Host "The input, output, and report files will not be deleted" @warnColors
    Get-ChildItem -Path $paths.Root | ForEach-Object { 
        Remove-Item -LiteralPath $_.FullName -Include "*.txt", "*.log", "muxed.mkv", "*.cutree", "*_stereo.mkv", "*.json", "*.bin"
    }
}

# Restore window title
$console.WindowTitle = $currentTitle
# Run the garbage collector to ensure no memory leaks
[System.GC]::Collect()
