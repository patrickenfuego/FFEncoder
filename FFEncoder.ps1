<#
    .SYNOPSIS
        Cross-platform script for encoding HD/FHD/UHD audio/video content using ffmpeg, VapourSynth, x264, and x265
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
        ## Copy everything EXCEPT English subtitles and all audio streams ##
        ./FFEncoder.ps1 -i "~/Movies/Ex.Machina.2014.DTS-HD.mkv" -CRF 22.0 -Subtitles !eng -Audio copyall -o "~/Movies/Ex Machina (2014) DTS-HD.mkv"
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
        ## ScaleKernel 2160p video down to 1080p using zscale and spline36 ##
        .\FFEncoder "$HOME\Videos\Ex.Machina.2014.DTS-HD.2160p.mkv" -Scale zscale -ScaleFilter spline36 -Res 1080p -CRF 18 -o "$HOME\Videos\Ex Machina (2014) DTS-HD 1080p.mkv"
    .EXAMPLE
        ## Use a Vapoursynth script as input
        .\FFEncoder 'in.mkv' -VapourSynthScript "$HOME/script.vpy -CRF 18 -o 'out.mkv'"
    .INPUTS
        HD/FHD/UHD video file
        Vapoursynth Script
    .OUTPUTS
        Crop file
        Log file(s)
        Intermediary/temporary files
        Encoded video file
    .NOTES
        For script binaries to work, they must be included in the system PATH (consult OS documentation for more information):
            - ffmpeg
            - deew / dee
            - mkvmerge
            - mkvextract
            - x265
    .PARAMETER Help
        Displays help information for the script
    .PARAMETER TestFrames
        Performs a test encode with the number of frames provided
    .PARAMETER TestStart
        Starting point for test encodes. Accepts 3 formats:
            - 00:01:30 - Sexagesimal time format. This is the default
            - 200f     - Frame specifier. Add the 'f' modifier after the frame number to specify a starting frame. Accurate to +/- 1 frame
            - 200t     - Time specifier, in seconds. Add the 't' modifier after the number to specify a starting time. Accepts floating point values
    .PARAMETER InputPath
        Location of the file to be encoded
    .PARAMETER Audio
        Audio selection options. FFEncoder has several audio options:
            * copy/c           - Pass through the primary audio stream without re-encoding
            * copyall/ca       - Pass through all audio streams without re-encoding
            * none/n           - No audio will be copied
            * aac              - Convert primary audio stream to AAC. Default setting is 512 kb/s for multi-channel, and 128 kb/s for stereo
            * fdkaac/faac      - Convert primary audio stream to AAC using FDK AAC. Default setting is -vbr 3
            * aac_at           - Convert the primary audio stream to AAC using Apple's Core AudioToolbox encoder. MacOS only
            * dts              - Convert/copy DTS to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing DTS stream will be copied
            * ac3              - Convert/copy AC3 to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing AC3 stream will be copied
            * eac3             - Convert/copy E-AC3 to the output file. If -AudioBitrate is present, the stream will be transcoded. If not, any existing E-AC3 stream will be copied
            * flac/f           - Convert the primary audio stream to FLAC lossless audio
            * Stream #         - Copy an audio stream by its identifier in ffmpeg
            * dee_ddp/dee_eac3 - Encode Dolby Digital Plus audio using Dolby Encoding Engine (requires external software, not included)
            * dee_ddp_51       - Force encode Dolby Digital Plus 5.1 audio using Dolby Encoding Engine (requires external software, not included)
            * dee_dd/dee_ac3   - Encode Dolby Digital audio using Dolby Encoding Engine (requires external software, not included)
            * dee_thd          - Encode TrueHD audio using Dolby Encoding Engine (requires external software, not included)
    .PARAMETER AudioBitrate
        Specifies the bitrate for the chosen codec (in kb/s). Values 1-5 are used to signal -vbr with libfdk_aac or special options with aac_at
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
            - Dutch             - "dut" / "nld"
            - Danish            - "dan"
            - Finnish           - "fin"
            - Norwegian         - "nor"
            - Czech             - "cze"
            - Polish            - "pol"
            - Chinese           - "chi" / "zho"
            - Korean            - "kor"
            - Greek             - "gre" / "ell"
            - Romanian          - "rum"
            - Arabic            - "ara"
            - Bulgarian         - "bul"
            - Estonian          - "est"
            - Indonesian        - "ind"
            - Hindi             - "hin"
            - Turkish           - "tur"
            - Vietnamese        - "vie"
            - Thai              - "tha"
            - Slovenian         - "slv"
            - Hebrew            - "heb"
        Prefixing a '!' before any language will return all subtitles EXCLUDING that language
    .PARAMETER Preset
        The x265 preset to be used. Ranges from "placebo" (slowest) to "ultrafast" (fastest). Slower presets improve quality by enabling additional, more expensive, x265 parameters at the expensive of encoding time.
        Recommended presets (depending on source and purpose) are slow, medium, or fast. 
    .PARAMETER CRF
        Constant rate factor setting for video rate control. This setting attempts to keep quality consistent from frame to frame, and is most useful for targeting a specific quality level.    
        Ranges from 0.0 to 51.0. Lower values equate to a higher bitrate (better quality). Recommended: 14.0 - 24.0. At very low values, the output file may actually grow larger than the source.
        CRF 4.0 is considered mathematically lossless in x265 (vs. CRF 0.0 in x264)
    .PARAMETER ConstantQP
        Constant quantizer rate control mode. Forces a consistent QP throughout the encode. Generally not recommended outside of testing.
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
    .PARAMETER ScaleKernel
        Upscale/downscale input to a different resolution using the specified convolution kernel
    .PARAMETER ScaleFilter
        Filtering method used for rescaling input with the -Scale parameter. Compatible arguments:
            - scale: fast_bilinear, neighbor, area, gauss, sinc, spline, bilinear, bicubic, lanczos
            - zscale: point, spline16, spline36, bilinear, bicubic, lanczos
        If an argument is chosen which exists in both sets, zscale will be used if available
    .PARAMETER Unsharp
        Enable the unsharp filter and specify the search range. Use one of the presets specified in the project wiki, in the form:
            <luma|chroma|yuv>_<small|medium|large>
        or pass a custom filter string as:
            'custom=<filter string>'
        Mandatory parameter for sharpening/blurring a video source.
        
    .PARAMETER UnsharpStrength
        Sets the strength of the unsharp filter. Use one of the presets defined in the project wiki, in the form: <sharpen|blur>_<mild|medium|strong>
    .PARAMETER Resolution
        Upscale/downscale resolution used with the -Scale parameter. Default value is 1080p (1920 x 1080)
    .PARAMETER SkipDolbyVision
        Skip Dolby Vision encoding, even if metadata is present
    .PARAMETER DolbyVisionMode
        Specify the Dolby Vision mode used to generate the RPU file. Options:
            - 8.1 - Profile 8.1 (Backward compatible with HDR10)
            - 8.4 - Profile 8.4 (Backward compatible with HLG)
            - 8.1m - Profile 8.1 with FEL mapping retained (requires VapourSynth to process)
    .PARAMETER SkipHDR10Plus
        Skip HDR10+ encoding, even if metadata is present
    .PARAMETER HDR10PlusSkipReorder
        Fix for HDR10+ decoding order. Whether this parameter should be used must be validated manually
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
    .PARAMETER ReportType
        Specifies the type of report to generate. Options:
            - text
            - html (default)
    .PARAMETER GenerateMKVTagFile
        Generate an XML tag file for MKV containers using the TMDB API. Requires a valid TMDB API key
    .PARAMETER CompareVMAF
        Switch to enable a VMAF comparison. Mandatory to enable this feature
    .PARAMETER EnablePSNR
        VMAF option. Enables Peak Signal to Noise Ratio (PSNR) evaluation
    .PARAMETER EnableSSIM
        VMAF option. Enables Structural Similarity Index Measurement (SSIM) evaluation
    .PARAMETER VMAFResizeKernel
        VMAF option. Specify which kernel to use for resizing the distorted stream (default is bicubic)
    .PARAMETER LogFormat
        Specify the log format for VMAF. Options:
            - json
            - csv
            - sub
            - xml
    .PARAMETER VapourSynthScript
        Pass a VapourSynth script for filtering. Note that all filtering (including cropping) must be done in the VS script
    .lINK
        Check out the full documentation and script wiki on GitHub - https://github.com/patrickenfuego/FFEncoder
    .LINK
        FFMpeg documentation - https://ffmpeg.org
    .LINK
        x265 HEVC Documentation - https://x265.readthedocs.io/en/master/introduction.html
#>

using namespace System.IO

[CmdletBinding(DefaultParameterSetName = 'CRF')]
param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Help')]
    [Alias('H')]
    [switch]$Help,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('x264', 'x265')]
    [Alias('Enc')]
    [string]$Encoder = 'x265',

    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'CRF', HelpMessage='Enter full path to source file')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'VMAF', HelpMessage='Enter full path to source file')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'PASS', HelpMessage='Enter full path to source file')]
    [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'QP', HelpMessage='Enter full path to source file')]
    [ValidateScript(
        { Test-Path $_ },
        ErrorMessage = "Path '{0}' does not exist."
    )]
    [Alias('I', 'Reference', 'Source')]
    [string]$InputPath,

    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'QP')]
    [ValidateScript(
        {
            if (!(Test-Path $_)) {
                throw "Could not locate Vapoursynth script. Check the script path and try again"
            }
            if (($(ffmpeg 2>&1) -join ' ') -notmatch 'vapoursynth') {
                throw "ffmpeg was not compiled with Vapoursynth. Ensure the '--enable-vapoursynth' flag was set during compilation"
            }
            $true
        }
    )]
    [Alias('VSScript', 'VPY')]
    [string]$VapourSynthScript,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('copy', 'c', 'copyall', 'ca', 'aac', 'none', 'n', 'ac3', 'dee_dd', 'dee_ac3', 'dd', 'dts', 'flac', 'f',
        'eac3', 'ddp', 'dee_ddp', 'dee_eac3', 'dee_ddp_51', 'dee_eac3_51', 'dee_thd', 'fdkaac', 'faac', 'aac_at', 
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)]
    [Alias('A')]
    [string]$Audio = 'copy',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(-1, 3000)]
    [Alias('AB', 'ABitrate')]
    [int]$AudioBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('2CH', 'ST')]
    [switch]$Stereo,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('copy', 'c', 'copyall', 'ca', 'aac', 'none', 'n', 'ac3', 'dee_dd', 'dee_ac3', 'dd', 'dts', 'flac', 'f',
        'eac3', 'ddp', 'dee_ddp', 'dee_eac3', 'dee_ddp_51', 'dee_eac3_51', 'dee_thd', 'fdkaac', 'faac', 'aac_at', 
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
    )]
    [Alias('A2')]
    [string]$Audio2 = 'none',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(-1, 3000)]
    [Alias('AB2', 'ABitrate2')]
    [int]$AudioBitrate2,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('2CH2', 'ST2')]
    [switch]$Stereo2,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('all', 'a', 'copyall', 'ca', 'none', 'default', 'd', 'n', 'eng', 'fre', 'ger', 'spa', 'dut', 'dan', 
        'fin', 'nor', 'cze', 'pol', 'chi', 'zho', 'kor', 'gre', 'rum', 'rus', 'swe', 'est', 'ind', 'slv', 'tur', 'vie',
        'hin', 'heb', 'ell', 'bul', 'ara', 'por', 'nld', 'tha',
        '!eng', '!fre', '!ger', '!spa', '!dut', '!dan', '!fin', '!nor', '!cze', '!pol', '!chi', '!zho', '!kor', '!ara',
        '!rum', '!rus', '!swe', '!est', '!ind', '!slv', '!tur', '!vie', '!hin', '!heb', '!gre', '!ell', '!bul', '!por',
        '!nld', '!tha'
    )]
    [Alias('S', 'Subs')]
    [string]$Subtitles = 'default',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet("placebo", "veryslow", "slower", "slow", "medium", "fast", "faster", "veryfast", "superfast", "ultrafast")]
    [Alias('P')]
    [string]$Preset = 'slow',

    [Parameter(Mandatory = $true, ParameterSetName = 'CRF', HelpMessage = 'Enter CRF value (1-51)')]
    [ValidateRange(0.0, 51.0)]
    [Alias('C')]
    [double]$CRF,

    [Parameter(Mandatory = $true, ParameterSetName = 'QP')]
    [ValidateRange(0, 51)]
    [Alias('QP')]
    [int]$ConstantQP,

    [Parameter(Mandatory = $true, ParameterSetName = 'PASS', HelpMessage = 'Enter 2-pass Average Bitrate (Ex: 5M or 5000k)')]
    [Alias('VBitrate')]
    [ValidateScript(
        {
            $_ -cmatch "(?<num>\d+\.?\d{0,2})(?<suffix>[K k M]+)"
            if ($Matches) {
                switch ($Matches.suffix) {
                    'K' { 
                        if ($Matches.num -gt 99000 -or $Matches.num -lt 1000) {
                            throw "Bitrate out of range. Must be between 1,000-99,000 kb/s"
                        }
                        else { $true }
                    }
                    'M' {
                        if ($Matches.num -gt 99 -or $Matches.num -le 1) {
                            throw "Bitrate out of range. Must be between 1-99 Mb/s"
                        }
                        else { $true }
                    }
                    default { throw "Invalid Suffix. Suffix must be 'K/k' (kb/s) or 'M' (Mb/s)" }
                }
            }
            else { throw "Invalid bitrate input. Example formats: 10000k (10,000 kb/s) | 10M (10 Mb/s)" }
        }
    )]
    [string]$VideoBitrate,

    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [ValidateRange(1, 2)]
    [int]$Pass = 2,

    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [ValidateSet('Default', 'd', 'Fast', 'f', 'Custom', 'c')]
    [Alias('FPT', 'PassType')]
    [string]$FirstPassType = 'Default',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(-6, 6)]
    [ValidateCount(2, 2)]
    [Alias('DBF')]
    [int[]]$Deblock = @(-2, -2),

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 4)]
    [Alias('AQM')]
    [int]$AqMode,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0.0, 3.0)]
    [Alias('AQS')]
    [double]$AqStrength = 1.00,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('PRD', 'PsyRDO')]
    [string]$PsyRd,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0.0, 50.0)]
    [Alias('PRQ', 'PsyTrellis')]
    [double]$PsyRdoq,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(1, 16)]
    [int]$Ref,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 1)]
    [Alias('MBTree', 'CUTree')]
    [int]$Tree = 1,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(1, 32768)]
    [Alias('MR')]
    [int]$Merange,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 2000)]
    [ValidateCount(1, 2)]
    [Alias('NR')]
    [int[]]$NoiseReduction = @(0, 0),

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(1, 4)]
    [ValidateCount(2, 2)]
    [Alias('TU')]
    [int[]]$TuDepth = @(1, 1),

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(1, 4)]
    [Alias('LTU')]
    [int]$LimitTu = 0,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0.0, 1.0)]
    [Alias("Q")]
    [double]$QComp = 0.60,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 16)]
    [Alias('B')]
    [int]$BFrames,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 1)]
    [Alias('BINT')]
    [int]$BIntra,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 11)]
    [Alias('SM', 'Subpel')]
    [int]$Subme,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 1)]
    [Alias('SIS')]
    [int]$StrongIntraSmoothing = 1,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('1', '1b', '2', '1.1', '1.2', '1.3', '2.1', '21', '2.2', '3.1', '3.2', '4', '4.1', '4.2', '41',
        '5', '5.1', '51', '5.2', '52', '6', '6.1', '61', '6.2', '62', '8.5', '85')]
    [Alias('L')]
    [string]$Level,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateCount(2, 2)]
    [Alias('VideoBuffer')]
    [int[]]$VBV,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(1, 64)]
    [Alias('FrameThreads')]
    [int]$Threads,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateRange(0, 250)]
    [Alias('RCL', 'Lookahead')]
    [int]$RCLookahead,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('FE', 'FFExtra')]
    [array]$FFMpegExtra,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('Extra')]
    [hashtable]$EncoderExtra,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('T', 'Test')]
    [int]$TestFrames,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('Start', 'TS')]
    [string]$TestStart = '00:01:30',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('Del', 'RM')]
    [switch]$RemoveFiles,

    # Filtering related parameters
    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
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
    [Alias('NL')]
    [hashtable]$NLMeans,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ArgumentCompletions(
        'luma_small', 'luma_medium', 'luma_large', 'chroma_small',
        'chroma_medium', 'chroma_large', 'yuv_small', 'yuv_medium',
        'yuv_large'
    )]
    [Alias('U')]
    [string]$Unsharp,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet(
        'sharpen_mild', 'sharpen_medium', 'sharpen_strong',
        'blur_mild', 'blur_medium', 'blur_strong'
    )]
    [Alias('UStrength')]
    [string]$UnsharpStrength = 'sharpen_mild',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('DI')]
    [switch]$Deinterlace,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('point', 'spline16', 'spline36', 'bilinear', 'bicubic', 'lanczos',
        'fast_bilinear', 'neighbor', 'area', 'gauss', 'sinc', 'spline', 'bicublin')]
    [Alias('ResizeKernel')]
    [string]$ScaleKernel = 'bilinear',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('2160p', '1080p', '720p')]
    [Alias('Res', 'R')]
    [string]$Resolution,

    # Utility parameters
    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('Report', 'GR')]
    [switch]$GenerateReport,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('text', 'html')]
    [Alias('ReportFormat')]
    [string]$ReportType = 'html',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('NoDV', 'SDV')]
    [switch]$SkipDolbyVision,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateSet('8.1', '8.4', '8.1m')]
    [Alias('DoViMode')]
    [string]$DolbyVisionMode = '8.1',

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [alias('No10P', 'STP')]
    [switch]$SkipHDR10Plus,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('SkipReorder')]
    [switch]$HDR10PlusSkipReorder,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [Alias('Exit')]
    [switch]$ExitOnError,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [alias('NoProgressBar')]
    [switch]$DisableProgress,

    [Parameter(Mandatory = $false, ParameterSetName = 'CRF')]
    [Parameter(Mandatory = $false, ParameterSetName = 'PASS')]
    [Parameter(Mandatory = $false, ParameterSetName = 'QP')]
    [ValidateScript(
        {
            $flag = $false
            if ($null -eq $_['APIKey']) {
                throw 'MKV Tag Hashtable must include an APIKey entry'
            }
            foreach ($k in $_.Keys) {
                if ($k -notin 'APIKey', 'Path', 'Title', 'Year', 'Properties', 'SkipProperties', 'NoMux', 'AllowClobber') {
                    throw "Invalid key. Valid keys are 'APIKey', 'Path', 'Title', 'Year', 'Properties', 'SkipProperties', 'NoMux', 'AllowClobber'"
                }
                else { $flag = $true }
            }
            if ($flag) { $true }
            else { throw "Invalid MKV Tag hashtable" }
        }
    )]
    [Alias('CreateTagFile')]
    [hashtable]$GenerateMKVTagFile,

    [Parameter(Mandatory = $true, ParameterSetName = 'CRF', HelpMessage = 'Enter full path to encoded output file')]
    [Parameter(Mandatory = $true, ParameterSetName = 'VMAF', HelpMessage = 'Enter full path to encoded output file')]
    [Parameter(Mandatory = $true, ParameterSetName = 'PASS', HelpMessage = 'Enter full path to encoded output file')]
    [Parameter(Mandatory = $true, ParameterSetName = 'QP', HelpMessage = 'Enter full path to encoded output file')]
    [ValidateNotNullOrEmpty()]
    [Alias('O', 'Encode', 'Distorted')]
    [string]$OutputPath,

    ## VMAF-Specific Parameters
    [Parameter(Mandatory = $true, ParameterSetName = 'VMAF')]
    [Alias('VMAF', 'EnableVMAF')]
    [switch]$CompareVMAF,

    [Parameter(Mandatory = $false, ParameterSetName = 'VMAF')]
    [alias('SSIM')]
    [switch]$EnableSSIM,

    [Parameter(Mandatory = $false, ParameterSetName = 'VMAF')]
    [alias('PSNR')]
    [switch]$EnablePSNR,

    [Parameter(Mandatory = $false, ParameterSetName = 'VMAF')]
    [ValidateSet('json', 'xml', 'csv', 'sub')]
    [Alias('LogType', 'VMAFLog')]
    [string]$LogFormat = 'json',

    [Parameter(Mandatory = $false, ParameterSetName = 'VMAF')]
    [ValidateSet('point', 'spline16', 'spline36', 'bilinear', 'bicubic', 'lanczos',
        'fast_bilinear', 'neighbor', 'area', 'gauss', 'sinc', 'spline', 'bicublin')]
    [Alias('VMAFKernel')]
    [string]$VMAFResizeKernel = 'bicubic'
)

#########################################################
# Function Definitions                                  #        
#########################################################

# Returns an object containing the paths needed throughout the script
function Set-ScriptPaths ([hashtable]$OS) {
    # Split file paths into their components
    $root = Split-Path $InputPath -Parent
    $oRoot = Split-Path $OutputPath -Parent
    $title = Split-Path $InputPath -LeafBase
    $oTitle = Split-Path $OutputPath -LeafBase
    $oExt = Split-Path $OutputPath -Extension

    # Creating path strings used throughout the script
    $cropPath = [Path]::Join($root, "$title`_crop.txt")
    $logPath = [Path]::Join($root, "$title`_encode.log")
    $x265Log = [Path]::Join($root, "x265_2pass.log")
    $stereoPath = [Path]::Join($root, "$oTitle`_stereo.$oExt")
    $hdr10PlusPath = [Path]::Join($root, "metadata.json")
    $dvPath = [Path]::Join($root, "rpu.bin")
    $hevcPath = [Path]::Join($oRoot, "$oTitle.hevc")

    $repExt = ($ReportType -eq 'html') ? 'html' : 'rep'
    $reportPath = [Path]::Join($root, "$oTitle.$repExt")

    if ($psReq) {
        Write-Host "Crop file path is: $($PSStyle.Foreground.Cyan+$PSStyle.Underline)$cropPath"
        Write-Host ""
    }
    else {
        Write-Host "Crop file path is: " -NoNewline
        Write-Host "<$cropPath>" @emphasisColors
        Write-Host ""
    }

    # Check for existing log - concurrent encodes of same source
    if ([File]::Exists($logPath) -and 
        ((Get-Process 'ffmpeg' -ErrorAction SilentlyContinue) -or 
        (Get-Process 'x265*' -ErrorAction SilentlyContinue))) {
        
        # Check if a process is writing to the current log file
        $length1 = ([FileInfo]$logPath).Length
        Start-Sleep -Seconds 1.2
        $length2 = ([FileInfo]$logPath).Length

        if ($length2 -gt $length1) {
            $logCount = (Get-ChildItem $root -Filter '*encode*.log' | Measure-Object).Count
            if ($logCount) {
                Write-Host "Existing encode detected...creating a separate log file" @warnColors
                $logPath = [Path]::Join($root, "$title`_encode$($logCount + 1).log")
            }
        }
    }

    $pathObject = @{
        InputFile  = $InputPath
        Root       = $root
        OutRoot    = $oRoot
        Extension  = $oExt
        RemuxPath  = $remuxPath
        StereoPath = $stereoPath
        CropPath   = $cropPath
        LogPath    = $logPath
        X265Log    = $x265Log
        Title      = $oTitle
        InTitle    = $title
        ReportPath = $reportPath
        HDR10Plus  = $hdr10PlusPath
        DvPath     = $dvPath
        HevcPath   = $hevcPath
        OutputFile = $OutputPath
    }
    if ($VapoursynthScript) {
        $pathObject['VPY'] = $VapoursynthScript
    }

    Write-Verbose "PATHS OBJECT:`n  $($pathObject | Out-String)"
    
    return $pathObject
}

## End Functions ##

#########################################################
# Main Script Logic                                     #    
#########################################################

<#
    SETUP

    Help
    Console config
    Verbose preference
    Verify PowerShell version
    Import Module
    Import Config File contents
#>

# Print help content and exit
if ($Help) { 
    Get-Help .\FFEncoder.ps1 -Full
    exit 0 
}
# Enable verbose logging if passed. Cascade down setVerbose
if ($PSBoundParameters['Verbose']) {
    $VerbosePreference = 'Continue'
    $ErrorView = 'NormalView'
    $Global:setVerbose = $true
}
else { 
    $VerbosePreference = 'SilentlyContinue'
    $Global:setVerbose = $false 
}

# Set console options for best experience
$Global:console = $Host.UI.RawUI
$Global:currentTitle = $console.WindowTitle
$console.ForegroundColor = 'White'
$console.BackgroundColor = 'Black'
$console.WindowTitle = 'FFEncoder'
# Reset intercept if previous exit wasn't clean
[console]::TreatControlCAsInput = $false

# Import FFTools module
Import-Module -Name "$PSScriptRoot\modules\FFTools" -Force
Write-Verbose "`n`n---------------------------------------"

# Import config file options
$params = @{
    EncoderExtra = $EncoderExtra
    FFMpegExtra  = $FFMpegExtra
    Encoder      = $Encoder
    Verbose      = $setVerbose
}
$EncoderExtra, $FFMpegExtra, $scriptHash, $tagHash, $vmafHash = Import-Config @params

# Source version functions
. $([Path]::Join($ScriptsDirectory, 'VerifyVersions.ps1')).ToString()
# Verify the current version of pwsh & exit if version not satisfied
$Global:psReq = Confirm-PoshVersion
# Check for updates to FFencoder and prompt to download if git is available
Update-FFEncoder -CurrentRelease $release -Verbose:$setVerbose

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$startTime = (Get-Date).ToLocalTime()

# Write the welcome banner
Write-Host "----------------------------------------------------------------------------------------------" @emphasisColors
if ($psReq) {
    Write-Host "$($PSStyle.Foreground.FromRGB(92, 255, 114))$($PSStyle.Bold)$($banner1)$($PSStyle.Reset)"
    Write-Host "$($PSStyle.Foreground.FromRGB(97, 30, 164))$($PSStyle.Bold)$($banner2)$($PSStyle.Reset)"
}
else {
    Write-Host $banner1 -ForegroundColor 'Green' -BackgroundColor 'Black'
    Write-Host $banner2 -ForegroundColor 'Magenta' -BackgroundColor 'Black'
}
Write-Host "----------------------------------------------------------------------------------------------" @emphasisColors

Write-Host "Start Time: $startTime`n"

if ($PSBoundParameters['CompareVMAF']) {
    Write-Host "   $("`u{25c7}" * 3) VMAF Selected $("`u{25c7}" * 3)" @emphasisColors
    Write-Host "$("`u{25c7}" * 4) STARTING ASSESSMENT $("`u{25c7}" * 4)" @progressColors
    Write-Host ""

    # Check params from config file
    if ($vmafHash) {
        foreach ($item in $vmafHash.GetEnumerator()) {
            if (!$PSBoundParameters[$item.Name]) {
                Set-Variable "$($item.Name)" -Value $item.Value
                Write-Verbose "VMAF Variable set: $($item.Name) = $(Get-Variable "$($item.Name)" -ValueOnly)"
            }
            else {
                Write-Verbose "VMAF variable $($item.Name) set via parameter. Skipping..."
            }
        }
        Write-Host ""
    }

    $params = @{
        Source        = $InputPath
        Encode        = $OutputPath
        SSIM          = $EnableSSIM
        PSNR          = $EnablePSNR
        LogFormat     = $LogFormat
        ResizeKernel  = $VMAFResizeKernel
        Verbose       = $setVerbose
    }

    try {
        Invoke-VMAF @params
        $console.WindowTitle = $currentTitle
        exit 0
    }
    catch {
        Write-Error "An exception occurred during VMAF comparison: $($_.Exception.Message)"
        $console.WindowTitle = $currentTitle
        exit 43
    }
}

# Set switch params from config if not passed via param
if ($scriptHash) {
    foreach ($item in $scriptHash.GetEnumerator()) {
        if (!$PSBoundParameters[$item.Name]) {
            Set-Variable "$($item.Name)" -Value $item.Value
            Write-Verbose "Switch Variable set: $($item.Name) = $(Get-Variable "$($item.Name)" -ValueOnly)"
        }
        else {
            Write-Verbose "Switch variable $($item.Name) set via parameter. Skipping..."
        }
    }
    Write-Host ""
}

# Set tag generator hash. Parameter option overrides config
if (!$PSBoundParameters['GenerateMKVTagFile'] -and $tagHash) {
    $GenerateMKVTagFile = $tagHash
}

# Validate and set script params from config file values
if ($EncoderExtra) {
    Write-Host "Parsing encoder configuration...`n" @progressColors
    $removeKeys = [System.Collections.ArrayList]::new()
    $x = $PsStyle.Bold + "`u{2717}" + $PSStyle.BoldOff
    $c1 = $PSStyle.Foreground.Blue
    $c2 = $PSStyle.Foreground.Red
    
    # Create hash mapping between script params and associated encoder settings
    $paramHash = @{
        'Deblock'              = 'deblock'
        'AqMode'               = 'aq-mode'
        'AqStrength'           = 'aq-strength'
        'PsyRd'                = 'psy-rd'
        'PsyRdoq'              = 'psy-rdoq'
        'Ref'                  = 'ref'
        'Tree'                 = 'cutree', 'mbtree'
        'Merange'              = 'Merange'
        'NoiseReduction'       = 'nr', 'nr-inter', 'nr-intra'
        'TuDepth'              = 'tu-inter-depth', 'tu-intra-depth'
        'LimitTu'              = 'limit-tu'
        'QComp'                = 'qcomp'
        'Bframes'              = 'bframes'
        'BIntra'               = 'b-intra'
        'Subme'                = 'subme'
        'StrongIntraSmoothing' = 'strong-intra-smoothing'
        'Level'                = 'level', 'level-idc'
        'VBV'                  = 'vbv-bufsize', 'vbv-maxrate'
        'Threads'              = 'threads', 'frame-threads', 'F'
        'RcLookahead'          = 'rc-lookahead'
    }
    foreach ($item in $EncoderExtra.GetEnumerator()) {
        # If setting is in hash, get the key
        $hasValue = $paramHash.Values.Contains($item.Name)
        if ($hasValue -notcontains $true) {
            continue
        }
        $key = $paramHash.Keys.Where({ $paramHash[$_] -contains $item.Name })
        # Related setting param not passed via CLI
        if (!$PSBoundParameters[$key]) {
            if ($key -eq 'VBV') {
                $v1, $v2 = $EncoderExtra['vbv-bufsize', 'vbv-maxrate']
                if ($v1 -and $v2) {
                    [int[]]$val = $v1, $v2
                    Set-Variable -Name $key -Value $val
                }
                else {
                    $def = ($null -eq $v1) ? $v2 : $v1
                    $msg = "$c2$x Missing value for VBV: Expected $c1'vbv-bufsize','vbv-maxrate'$c2 set, received " +
                           "$c1'$($v1 ?? 'null')','$($v2 ?? 'null')'$c2. Setting VBV default to $c1'$def,$def'"
                    Write-Host $msg
                    [int[]]$val = $def, $def
                    Set-Variable -Name $key -Value $val
                }
            }
            elseif ($key -eq 'TuDepth') {
                $v1, $v2 = $EncoderExtra['tu-intra-depth', 'tu-intra-depth']
                if ($v1 -and $v2) { 
                    [int[]]$val = $v1, $v2
                    Set-Variable -Name $key -Value $val
                }
                else {
                    $def = ($null -eq $v1) ? $v2 : $v1
                    $msg = "$c2$x Missing value for TUDepth: Expected $c1'tu-intra-depth','tu-inter-depth'$c2 set, " +
                           "received $c1'$($v1 ?? 'null')','$($v2 ?? 'null')'$c2. Setting TUDepth to $c1'$def,$def'"
                    Write-Host $msg
                    [int[]]$val = $def, $def
                    Set-Variable -Name $key -Value $val
                }
            }
            elseif ($key -eq 'Deblock') {
                if (([regex]::Match($item.Value, '-?\d,-?\d')).Success) {
                    [int[]]$val = $item.Value -split ','
                    Set-Variable -Name $key -Value $val
                }
                else {
                    [string]$d = $Deblock -join ','
                    Write-host "$c2$x Invalid format for 'deblock': Expected $c1'<int>,<int>'$c2. Using default: $c1$d"
                }
            }
            else {
                Set-Variable -Name $key -Value $item.Value
            }
        }
        # Can't delete keys during iteration. Delete after
        $removeKeys.Add($item.Name) > $null
    }

    if ($removeKeys) {
        Write-Verbose "Encoder keys to remove: $($removeKeys -join ',')"
        $removeKeys.ForEach({ $EncoderExtra.Remove($_) })
    }
}

# Generating paths to various files
$paths = Set-ScriptPaths -OS $osInfo

# if the output path already exists, prompt to delete the existing file or exit script. Otherwise, try to create it
if ([File]::Exists($paths.OutputFile)) { 
    Remove-FilePrompt -Path $paths.OutputFile -Type 'Primary'
}
else { 
    if (![Directory]::Exists(([FileInfo]$paths.OutputFile).DirectoryName)) {
        Write-Host "Creating output path directory structure..." @progressColors
        [Directory]::CreateDirectory(([FileInfo]$paths.OutputFile).DirectoryName) > $null
        if (!$?) {
            $console.WindowTitle = $currentTitle
            Write-Error "Could not create the specified output directory" -ErrorAction Stop
        }
    }
}

<#
    VALIDATE:
    
    Confirm test encode parameters
    Confirm scaling parameters
    Confirm unsharp parameters
    Audio check
        - Warn if transcoding lossy -> lossy
        - Disable audio params if source has no audio

    If Vapoursynth is used, filtering-related checks are ignored - must be handled
    in Vapoursynth
#>

# Verify test parameters and prompt if one is missing (unless ExitOnError is present)
if ($PSBoundParameters['TestStart'] -and !$PSBoundParameters['TestFrames']) {
    Write-Host 'The -TestStart parameter was passed without a frame count duration' @errColors
    $params = @{
        Prompt  = 'Enter the number of test frames to use: '
        Timeout = 25000
        Mode    = 'Integer'
        Count   = 3
    }
    try {
        $TestFrames = Read-TimedInput @params -Verbose:$setVerbose
    }
    catch {
        Write-Host "`u{203C} $($_.Exception.Message). Setting default test case: 2000 frames" @errColors
        $TestFrames = 2000
    }
}

# Check the source resolution
$sourceResolution = Get-MediaInfo $InputPath | Select-Object Width, Height | 
    ForEach-Object { "$($_.Width)x$($_.Height)" }

# If VS is used, skip video filtering
if (!$PSBoundParameters['VapoursynthScript']) {
    # If scale is used, verify arguments and handle errors
    if ($PSBoundParameters['ScaleKernel']) {
        $isScale = $true
        try {
            $scaleType, $filter = Confirm-ScaleFilter -Filter $ScaleKernel -Verbose:$setVerbose
        }
        catch {
            Write-Host "`u{203C} $($_.Exception.Message). The output will not be scaled`n" @errColors
            $isScale = $false
        }
    }
    else { $isScale = $false }

    # If scaling is used, check if Resolution was passed & set hashtable
    if ($isScale) {
        # Warn if no resolution was passed, and set to a default
        if (!$PSBoundParameters['Resolution']) {
            $defaultResolution = switch ($sourceResolution) {
                '3840x2160' { '1080p' }
                '1920x1080' { '2160p' }
                '1280x720'  { '1080p' }
            }
            Write-Warning "No resolution specified for scaling. Using a default based on source: $defaultResolution"
            Write-Host ""
        }

        # Collect the arguments into a hashtable
        $scaleHash = @{
            ScaleKernel = $scaleType
            ScaleFilter = $filter 
            Resolution  = $Resolution ??= $defaultResolution
        }
    }

    # Verify unsharp params and prompt for new value if necessary
    if ($PSBoundParameters['Unsharp']) {
        $unsharpSet = @('luma_small', 'luma_medium', 'luma_large', 'chroma_small',
                        'chroma_medium', 'chroma_large', 'yuv_small', 'yuv_medium',
                        'yuv_large')

        if ($Unsharp -notin $unsharpSet -and $Unsharp -notlike 'custom=*') {
            $unsharpOptions = ($unsharpSet + 'custom=<filter_string>') |
                Join-String -Separator "`r`n`t`u{2022} " `
                    -OutputPrefix "$($boldOn)  Valid options for Unsharp$($boldOff):`n`t`u{2022} "
            Write-Host "Invalid option entered for Unsharp:`n$unsharpOptions"
            $params = @{
                Prompt      = 'Enter a valid option: '
                Timeout     = 50000
                Mode        = 'Select'
                Count       = 4
                InputObject = $unsharpSet
            }
            $Unsharp = Read-TimedInput @params
            Write-Host ""
        }

        if (!$PSBoundParameters['UnsharpStrength'] -and $Unsharp -notlike 'custom=*') {
            Write-Warning "No value was passed for -UnsharpStrength. Using default: 'sharpen_mild'"
            $UnsharpStrength = 'sharpen_mild'
        }
    }

    if ($Unsharp -and $UnsharpStrength) {
        $unsharpHash = @{
            Size     = $Unsharp
            Strength = $UnsharpStrength
        }
    }
    else { $unsharpHash = $null }
    
    <#
        CROP FILE GENERATION
        HDR ELIGIBILITY VERIFICATION

        If crop arguments are passed via FFMpegExtra, don't generate crop file
        If HDR metadata is present but x264 is selected, exit on error (not supported)
    #>

    if ($PSBoundParameters['FFMpegExtra']) {
        $custom = $FFMpegExtra.Where({ $_['-vf'] -like '*crop*' })
        $skipCropFile = $custom ? $true : $false
    }
    if ($skipCropFile) {
        Write-Host "Crop override arguments detected. Skipping crop file generation" @warnColors
        Write-Host ""
        # Check if source is 4K for HDR metadata
        $cropDim = ($sourceResolution -like '3840x2160*') ? ( @(-1, -1, $true) ) : ( @(-1, -1, $false) )
    }
    else {
        New-CropFile -InputPath $paths.InputFile -CropFilePath $paths.CropPath -Count 1 -Verbose:$setVerbose
        # Calculating the crop values. Re-throw terminating error if one occurs
        $cropDim = Measure-CropDimensions -FilePath $paths.CropPath -Resolution $Resolution -Verbose:$setVerbose
    }
}
# Vapoursynth is used
else {
    $format = "$($PSStyle.Foreground.Yellow)$($PSStyle.Bold)$($PSStyle.Italic)"
    $msg = "Vapoursynth script detected - $format all filtering (cropping, resizing, etc.) must be done using Vapoursynth`n"
    Write-Host $msg

    # Set dummy values for required parameters
    $cropDim = ($sourceResolution -like '3840x2160*') ? @(-2, -2, $true) : @(-2, -2, $false)
}

# Validate audio in the input file
$isLossless = Confirm-Audio -InputPath $paths.InputFile -Verbose:$setVerbose
if ($isLossless -eq $false) {
    $test1 = @('^c[opy]*$', 'c[opy]*a[ll]*', '^n[one]?').Where({ $Audio -notmatch $_ }, 'SkipUntil', 1)
    $test2 = @('^c[opy]*$', 'c[opy]*a[ll]*', '^n[one]?').Where({ $Audio2 -notmatch $_ }, 'SkipUntil', 1)
    $test3 = @('^aac$', '^dts$', 'eac3', 'ddp', 'ac3', 'dd').Where({ $Audio -match $_ }, 'SkipUntil', 1)
    $test4 = @('^aac$', '^dts$', 'eac3', 'ddp', 'ac3', 'dd').Where({ $Audio2 -match $_ }, 'SkipUntil', 1)
    $allChecks = $test1, $test2, $test3, $test4 -contains $true
    if (!$allChecks) {
        Write-Warning "Audio stream 0 is not lossless. Transcoding to another lossy codec is NOT recommended"
    }
}
elseif ($null -eq $isLossless) {
    Write-Warning "No audio streams were found in the source file. Audio parameters will be ignored"
    $Audio = $Audio2 = 'none'
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
        1       { @('-b:v', $VideoBitrate, $false, $false) }
        default { @('-b:v', $VideoBitrate, $true, $FirstPassType) }
    }
}
elseif ($PSBoundParameters['ConstantQP']) {
    $rateControl = @('-qp', $ConstantQP, $false, $false)
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
    Encoder              = $Encoder
    CropDimensions       = $cropDim
    AudioInput           = $audioArray
    Subtitles            = $Subtitles
    Preset               = $Preset
    RateControl          = $rateControl
    Deblock              = $Deblock
    Deinterlace          = $Deinterlace
    AqMode               = $AqMode
    AqStrength           = $AqStrength
    PsyRd                = $PsyRd
    PsyRdoq              = $PsyRdoq
    NoiseReduction       = $NoiseReduction
    NLMeans              = $NLMeans
    Unsharp              = $unsharpHash
    TuDepth              = $TuDepth
    LimitTu              = $LimitTu
    Tree                 = $Tree
    Merange              = $Merange
    Ref                  = $Ref 
    Qcomp                = $QComp
    BFrames              = $BFrames
    BIntra               = $BIntra
    Subme                = $Subme 
    IntraSmoothing       = $StrongIntraSmoothing
    Threads              = $Threads
    RCLookahead          = $RCLookahead
    Level                = $Level
    VBV                  = $VBV
    FFMpegExtra          = $FFMpegExtra
    EncoderExtra         = $EncoderExtra
    Scale                = $scaleHash
    Paths                = $paths
    Verbose              = $setVerbose
    TestFrames           = $TestFrames
    TestStart            = $TestStart
    SkipDolbyVision      = $SkipDolbyVision
    DolbyVisionMode      = $DolbyVisionMode
    SkipHDR10Plus        = $SkipHDR10Plus
    HDR10PlusSkipReorder = $HDR10PlusSkipReorder
    DisableProgress      = $DisableProgress
}

try {
    Invoke-FFMpeg @ffmpegParams
}
catch {
    $params = @{
        Message           = "An error occurred during ffmpeg invocation. Exception:`n$($_.Exception)"
        RecommendedAction = 'Correct the Error Message'
        Category          = 'InvalidArgument'
        CategoryActivity  = 'FFmpeg Function Invocation'
        TargetObject      = $ffmpegParams
        ErrorId           = 55
    }

    $console.WindowTitle = $currentTitle
    [console]::TreatControlCAsInput = $false
    Get-Job | Stop-Job -PassThru | Remove-Job -Force
    Write-Error @params -ErrorAction Stop
}

<#
    POST ENCODE
    
    Jobs Muxing
    Results
    Generate Report
    Generate MKV Tag File
    Cleanup

    TODO: Refactor this mess
#>

Start-Sleep -Milliseconds 500

$skipBackgroundAudioMux = $false
$mId = 0
# Check for running jobs
$deeRunning = (Get-Job -Name 'Dee Encoder' -ErrorAction SilentlyContinue).State -eq 'Running'
$audioRunning = (Get-Job -Name 'Audio Encoder' -ErrorAction SilentlyContinue).State -eq 'Running'
# Set the temporary output file
$output = $paths.OutputFile -replace '^(.+)\.(.+)', '$1 (1).$2'

# Handle dee encoded audio. If a stereo track was created, add it as well
if ($Audio -like '*dee*' -or $Audio2 -like '*dee*') {
    # Check for stereo and add it
    if ($audioRunning) {
        Write-Host "Audio Encoder background job is still running. Pausing..." @warnColors
        do {
            Start-Sleep -Seconds 1
        } until ((Get-Job 'Audio Encoder').State -eq 'Completed')
        Write-Host "Multiplexing audio track back into the output file..." @progressColors
        Get-Job -State Completed -ErrorAction SilentlyContinue | Remove-Job
        $skipBackgroundAudioMux = $true
    }
    
    # Mux in the dee encoded file if job isn't running
    if ($deeRunning) {
        Write-Host "Dee Encoder background job is still running. Pausing..." @warnColors
        do {
            Start-Sleep -Seconds 1
        } until ((Get-Job 'Dee Encoder').State -eq 'Completed')
        Get-Job -State Completed -ErrorAction SilentlyContinue | Remove-Job
    }
    Write-Host "Multiplexing DEE track back into the output file..." @progressColors
    Get-Job -State Completed -ErrorAction SilentlyContinue | Remove-Job

    if ((Get-Command 'mkvmerge') -and $OutputPath.EndsWith('mkv')) {
        #Find the dee encoded output file
        $deePath = Get-ChildItem $paths.OutRoot |
            Where-Object { $_.Name -like "$($paths.InTitle).*3" -or $_.Name -like "$($paths.InTitle).thd" } |
                Select-Object -First 1 -ExpandProperty FullName

        $muxPaths = @{
            Input    = $paths.OutputFile
            Output   = $output
            Audio    = $deePath
            Title    = $paths.Title
            Language = $paths.Language
            LogPath  = $paths.LogPath
        }
        if ($skipBackgroundAudioMux) {
            $muxPaths.ExternalAudio = $paths.StereoPath
            $mId = 3
        }
        else { $mId = 2 }

        Invoke-MkvMerge -Paths $muxPaths -Mode 'remux' -ModeID $mId -Verbose:$setVerbose
    }
    # If no mkvmerge, mux with ffmpeg
    else {
        
        $fArgs = @(
            '-i'
            "$($paths.OutputFile)"
            '-i'
            $deePath
            if ($skipBackgroundAudioMux) {
                '-i'
                "$($paths.StereoPath)"
            }
            '-loglevel'
            'error'
            '-map'
            0
            '-map'
            '1:a'
            if ($skipBackgroundAudioMux) {
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

    # Remove the DEE audio file if switch is present
    if ($RemoveFiles) { [File]::Delete($deePath) }
}

# If stream copy and stereo are used, mux the stream back into the container
if ([File]::Exists($Paths.StereoPath) -and !$skipBackgroundAudioMux) {
    if ($audioRunning) {
        Write-Host "Audio encoder background job is still running. Pausing..." @warnColors
        do {
            Start-Sleep -Seconds 1
        } until ((Get-Job 'Audio Encoder').State -eq 'Completed')
        Get-Job -State Completed -ErrorAction SilentlyContinue | Remove-Job
    }
    Write-Host "Multiplexing external audio track back into the output file..." @progressColors

    # If mkvmerge is available, use it instead of ffmpeg
    if ((Get-Command 'mkvmerge') -and $OutputPath.EndsWith('mkv')) {
        $muxPaths = @{
            Input         = $paths.OutputFile
            Output        = $output
            ExternalAudio = $paths.StereoPath
            Title         = $paths.Title
            Language      = $paths.Language
            LogPath       = $paths.LogPath
        }
        Invoke-MkvMerge -Paths $muxPaths -Mode 'remux' -ModeID 1 -Verbose:$setVerbose
    }
    # if not mkv or no mkvmerge, mux with ffmpeg
    else {
        ffmpeg -i $paths.OutputFile -i $paths.StereoPath -loglevel error -map 0 -map 1:a -c copy -y $output
    }
}

# Verify if temp output file exists and delete it if it is at least as large or larger than original output
if ([File]::Exists($output) -and 
    (([FileInfo]($output)).Length -ge ([FileInfo]($paths.OutputFile)).Length)) {

    [File]::Delete($paths.OutputFile)
    if (!$?) { 
        Write-Host ""
        Write-Host "Could not delete the original output file. It may be in use by another process" @warnColors 
    }

    # Delete background audio file if it exists
    if ([File]::Exists($paths.StereoPath)) {
        [File]::Delete($paths.StereoPath)
    }
    if (!$?) { 
        Write-Host ""
        Write-Host "Could not delete the background audio file. It may be in use by another process" @warnColors 
    }
    # Rename the new output file and assign the name for reference
    $paths.OutputFile = (Rename-Item $output -NewName "$($paths.Title).$($paths.Extension)" -PassThru).FullName
}
elseif ([File]::Exists($output) -and 
        (([FileInfo]($output)).Length -le ([FileInfo]($Paths.OutputFile)).Length)) {

    Write-Host "The new output file is smaller than the input file. A muxing issue may have occurred" @warnColors
}

# Generate tag file if passed
if ($GenerateMKVTagFile) {
    try {
        if (!$GenerateMKVTagFile['Path']) {
            $GenerateMKVTagFile['Path'] = $paths.OutputFile.Replace(".$($paths.Extension)", '.xml')
        }
        & $([Path]::Join($ScriptsDirectory, 'MatroskaTagGenerator.ps1')).ToString() @GenerateMKVTagFile
    }
    catch {
        Write-Host "An error occurred while generating the tag file: $($_.Exception.Message)`n" @errColors
    }
}

# Display a quick view of the finished log file, the end time and total encoding time
switch ($Encoder) {
    'x265' {
             [File]::Exists($paths.DvPath) ? 
                 (Get-Content -Path $Paths.LogPath -Tail 10) : 
                 (Get-Content -Path $Paths.LogPath -Tail 8)
    }
    'x264'  { Get-Content -Path $Paths.LogPath -Tail 19 }
    default { Write-Warning "Unknown encoder. Summary will not be displayed" }
}
$endTime = (Get-Date).ToLocalTime()
Write-Host "`nEnd time: $endTime"
$stopwatch.Stop()
"Encoding Time: {0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds`n" -f $stopwatch.Elapsed

# Generate the report file if parameter is present
if ($GenerateReport) {
    $params = @{
        DateTimes  = @($startTime, $endTime)
        Duration   = $stopwatch
        Paths      = $paths
        TwoPass    = ($PSBoundParameters['VideoBitrate'] -and $Pass -eq 2) ? $true : $false
        Encoder    = $Encoder
        ReportType = $ReportType
        Verbose    = $setVerbose
    }
    Write-Report @params
}

# Delete extraneous files if switch is present
if ($RemoveFiles) {
    Write-Host "Removing extra files..." -NoNewline
    Write-Host "The input, output, and report files will not be deleted" @warnColors
    $delArray = @(
        '*.txt', '*.log', 'muxed.mkv', '*.cutree', '*_stereo.mkv', '*.json', '*.bin', '*.ec3'
        )
    Remove-Item "$($paths.Root)\*" -Include $delArray -Recurse -Force
}

# If deew log exists, copy content to main log and delete
if ($Audio -like 'dee*' -or $Audio2 -like 'dee*') {
    $deeLog = [Path]::Join(([FileInfo]$InputPath).DirectoryName, 'dee.log')
    if ([File]::Exists($deeLog)) {
        Add-Content $paths.LogPath -Value "`n`n-------- Deew Encoder Log --------`n`n"
        Add-Content $paths.LogPath -Value (Get-Content -Path $deeLog)
    }
    if ($?) {
        [File]::Delete($deeLog)
    }
}

# Restore window title
$console.WindowTitle = $currentTitle
# Run the garbage collector to ensure no memory leaks
[System.GC]::Collect()
