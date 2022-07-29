using namespace System.IO

<#
    .SYNOPSIS
        Calls ffmpeg to encode the input file using CRF or 1 Pass ABR rate control
    .DESCRIPTION
        This function takes the input parameters and uses them to encode a 4K HDR file.
        It uses module functions from FFTools to set video metadata, audio, and
        subtitle preferences
    .INPUTS
        Path of the source file to be encoded
        Path of the output file
        Crop dimensions for the output file
        Audio preference
        Subtitle preference
        Rate Control method
        Optional x265 parameter values that differ from -Preset
    .OUTPUTS
        4K HDR encoded video file
    .NOTES
        HDR metadata can be collected using module function Get-HDRMetadata
        Get-AudioPreference is a private function that is not publicly loaded by the module
#>
function Invoke-FFMpeg {      
    [CmdletBinding()]
    param (
        # Encoder to use
        [Parameter(Mandatory = $true)]
        [string]$Encoder,

        # Crop dimensions for the output file
        [Parameter(Mandatory = $true)]
        [Alias('Crop', 'CropDim')]
        [int[]]$CropDimensions,

        # Audio preference for the output file
        [Parameter(Mandatory = $false)]
        [Alias('Audio', 'A')]
        [array]$AudioInput,

        # Subtitle option
        [Parameter(Mandatory = $false)]
        [Alias('S')]
        [string]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias('P')]
        [string]$Preset,

        # x265 CRF / 1 pass ABR array of arguments
        [Parameter(Mandatory = $true)]
        [Alias('RC')]
        [array]$RateControl,

        # Deblock filter setting
        [Parameter(Mandatory = $false)]
        [Alias('DBF')]
        [int[]]$Deblock,

        # aq-mode setting. Default is 2
        [Parameter(Mandatory = $false)]
        [Alias('AQM')]
        [int]$AqMode,

        # aq-strength. Higher values equate to a lower QP, but can also increase bitrate significantly
        [Parameter(Mandatory = $false)]
        [Alias('AQS')]
        [double]$AqStrength,

        # psy-rd. Psycho visual setting
        [Parameter(Mandatory = $false)]
        [Alias('PsyRDO')]
        [string]$PsyRd,

        # psy-rdoq (trellis). Psycho visual setting
        [Parameter(Mandatory = $false)]
        [Alias('PRDQ', 'PsyTrellis')]
        [double]$PsyRdoq,

        # Filter to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [Alias('NR')]
        [int[]]$NoiseReduction,

        # Powerful denoising filter
        [Parameter(Mandatory = $false)]
        [Alias('NL')]
        [hashtable]$NLMeans,

        # Sharpen/blur filter
        [Parameter(Mandatory = $false)]
        [Alias('U')]
        [hashtable]$Unsharp,

        # Transform unit recursion depth (intra, inter)
        [Parameter(Mandatory = $false)]
        [Alias('TU')]
        [int[]]$TuDepth,

        # Early exit setting for TU recursion depth
        [Parameter(Mandatory = $false)]
        [Alias('LTU')]
        [int]$LimitTu,

        # Adjusts the quantizer curve compression factor
        [Parameter(Mandatory = $false)]
        [Alias('Q')]
        [double]$QComp,

        # The number of reference frames to use
        [Parameter(Mandatory = $false)]
        [int]$Ref,

        # Enable or disable (CU | MB)Tree algorithm
        [Parameter(Mandatory = $false)]
        [Alias('MBTree', 'CUTree')]
        [int]$Tree,

        # Motion Estimation range
        [Parameter(Mandatory = $false)]
        [Alias('MR')]
        [int]$Merange,

        # Maximum number of consecutive b-frames
        [Parameter(Mandatory = $false)]
        [Alias('B')]
        [int]$BFrames,

        # Enables the evaluation of intra modes in B slices
        [Parameter(Mandatory = $false)]
        [Alias('BINT')]
        [int]$BIntra,

        # Subpel motion refinement
        [Parameter(Mandatory = $false)]
        [Alias('Subpel')]
        [int]$Subme,

        # Enable/disable strong-intra-smoothing
        [Parameter(Mandatory = $false)]
        [Alias('SIS')]
        [int]$IntraSmoothing,

        # Number of frame threads the encoder should use
        [Parameter(Mandatory = $false)]
        [Alias('FrameThreads')]
        [int]$Threads,

        # Rate control lookahead buffer
        [Parameter(Mandatory = $false)]
        [Alias('RCL', 'Lookahead')]
        [int]$RCLookahead,

        # Encoder level to use. Default is unset
        [Parameter(Mandatory = $false)]
        [Alias('L')]
        [string]$Level,

        # Encoder level to use. Default is unset
        [Parameter(Mandatory = $false)]
        [Alias('VideoBuffer')]
        [int[]]$VBV,

        # Additional ffmpeg options
        [Parameter(Mandatory = $false)]
        [Alias('FE', 'FFExtra')]
        [array]$FFMpegExtra,

        # Additional encoder-specific options
        [Parameter(Mandatory = $false)]
        [Alias('Extra')]
        [hashtable]$EncoderExtra,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        # Scale setting
        [Parameter(Mandatory = $false)]
        [Alias('Resize')]
        [hashtable]$Scale,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        #[Alias('T')]
        [int]$TestFrames,

        # Starting Point for test encodes. Integers are treated as a frame #
        [Parameter(Mandatory = $false)]
        [Alias('Test')]
        [string]$TestStart,

        # Deinterlacing
        [Parameter(Mandatory = $false)]
        [Alias('DI')]
        [switch]$Deinterlace,

        # Skip DV even if present
        [Parameter(Mandatory = $false)]
        [Alias('NoDV', 'SkipDV')]
        [switch]$SkipDolbyVision,

        # Skip HDR10+ even if present
        [Parameter(Mandatory = $false)]
        [Alias('No10P', 'Skip10P')]
        [switch]$SkipHDR10Plus,

        # Skip HDR10+ even if present
        [Parameter(Mandatory = $false)]
        [Alias('NoProgressBar')]
        [switch]$DisableProgress
    )

    # Writes the banner information during encoding
    function Write-Banner {
        if ($TestFrames) {
            $startStr = switch -Wildcard ($TestStart) {
                '*f' { "Frame $($TestStart -replace 'f', '')" }
                '*t' { "$($TestStart -replace 't', '') Seconds" }
                default { "$TestStart" }
            }
            Write-Host ""
            if ($psReq) {
                $PSStyle.Formatting.TableHeader = $aYellow
                Write-Host "$($aYellow+$PSStyle.Bold)$("`u{294E}" * 3) TEST ENCODE $("`u{294E}" * 3)"
            }
            else { Write-Host "$("`u{294E}" * 3) TEST ENCODE $("`u{294E}" * 3)" @warnColors }

            [PSCustomObject]@{
                Start    = "$startStr  "
                Duration = "$TestFrames Frames"
            } | Format-Table -AutoSize

            if ($psReq) { $PSStyle.Formatting.TableHeader = "`e[32;1m" }
        }
        if ($psReq) {
            $cmd = "$($aCyan+$italicOn)Get-Content $($aBMagenta)`"$($Paths.LogPath)`" $($aCyan)-Tail 10"
            $msg = "To view detailed progress, run $cmd $($reset)in a different PowerShell session`n"
            Write-Host $msg
        }
        else {
            Write-Host "To view detailed progress, run " -NoNewline
            Write-Host "Get-Content `"$($Paths.LogPath)`" -Tail 10" @emphasisColors -NoNewline
            Write-Host " in a different PowerShell session`n"
        }
    }

    # Infer primary language based on streams (for muxing) - NOT always accurate, but pretty close
    $streams = ffprobe $Paths.InputFile -show_entries stream=index:stream_tags=language `
        -select_streams a -v 0 -of compact=p=0:nk=1
    [string]$lang = $streams -replace '\d\|', '' | Group-Object |
        Sort-Object -Property Count -Descending |
            Select-Object -First 1 -ExpandProperty Name
    $Paths.Language = $lang

    <#
        HDR METADATA

        Check for HDR metadata, validate results, and handle errors
        Throw an error for 4K HDR encoding with x264 (not supported by this script)
        Write a warning if HDR object is null, but proceed with execution
    #>

    if ($CropDimensions[2]) {
        $skipDv = ($SkipDolbyVision) ? $true : $false
        $skip10P = ($SkipHDR10Plus) ? $true : $false
        # Get HDR metadata. Re-throw any errors from function & exit call stack
        try {
            $params = @{
                InputFile       = $Paths.InputFile
                HDR10PlusPath   = $Paths.HDR10Plus
                DolbyVisionPath = $Paths.DvPath
                SkipDolbyVision = $skipDv
                SkipHDR10Plus   = $skip10P
                Verbose         = $setVerbose
            }
            $HDR = Get-HDRMetadata @params
        }
        catch [System.ArgumentNullException] {
            Write-Host "`u{203C} Failed to get HDR metadata: $($_.Exception.Message). Metadata will not be copied" @errColors
            $HDR = $null
        }
    }
    else { $HDR = $null }

    # Throw error if attempting to encode 4K HDR content with x264
    if ($HDR -and $Encoder -eq 'x264') {
        $msg = 'FFEncoder only supports 4K HDR encoding with x265, per industry standards'
        $params = @{
            RecommendedAction = 'Use x265 instead'
            Exception         = [System.InvalidOperationException]::new($msg)
            Category          = "InvalidOperation"
            TargetObject      = $Encoder
            ErrorId           = 200
        }

        $console.WindowTitle = $currentTitle
        Write-Error @params -ErrorAction Stop
    }

    <#
        AUDIO ARGUMENTS
        SUBTITLE ARGUMENTS

        Condense user arguments into hashtable objects
        Verify input combinations
        Create final audio array
        Set subtitle array based on user input

    #>

    $copyOpt = @('copy', 'c', 'copyall', 'ca') + 1..12
    # Verify if stream copying and a named codec are used together
    if ($copyOpt -notcontains $AudioInput[0].Audio -and 
        $copyOpt -contains $AudioInput[1].Audio) {
            
        $remuxStream = $true
    }
    else {
        $remuxStream = $false
    }
    
    $audioParam1 = @{
        UserChoice  = $AudioInput[0].Audio
        Bitrate     = $AudioInput[0].Bitrate
        Stream      = 0
        Stereo      = $AudioInput[0].Stereo
        RemuxStream = $remuxStream
        Paths       = $Paths
        Verbose     = $setVerbose
    }
    $audio = Set-AudioPreference @audioParam1

    if ($null -ne $AudioInput[1]) {
        # Verify if stream copying and a named codec are used together
        if ($copyOpt -contains $AudioInput[0].Audio -and 
            $copyOpt -notcontains $AudioInput[1].Audio) {
            
            $remuxStream = $true
        }
        else { $remuxStream = $false }

        $audioParam2 = @{
            UserChoice  = $AudioInput[1].Audio
            Bitrate     = $AudioInput[1].Bitrate
            Stream      = 1
            Stereo      = $AudioInput[1].Stereo
            RemuxStream = $remuxStream
            Paths       = $Paths
            Verbose     = $setVerbose
        }
        $audio2 = Set-AudioPreference @audioParam2

    }
    else { $audio2 = $null }

    # Determine audio combinations
    if ($null -eq $audio -and $null -eq $audio2) { $audio = '-an' }
    elseif ($null -eq $audio -and $null -ne $audio2) { $audio = $audio2 }
    elseif ($null -ne $audio2) { $audio = $audio + $audio2 }
    
    Write-Verbose "AUDIO ARGUMENTS:`n$($audio -join " ")`n"

    # Builds the subtitle argument array based on user input
    $subs = Set-SubtitlePreference -InputFile $Paths.InputFile -UserChoice $Subtitles
    
    <#
        VERIFY CROSS-ENCODER ARGUMENTS
        PRESET PARAMETERS

        If user does not modify the defaults via parameters, revert to preset values
    #>

    # Confirm shared encoder settings are within valid ranges
    $settings = @{
        Encoder = $Encoder
        Subme   = ([ref]$Subme)
        QComp   = ([ref]$Qcomp)
        AQMode  = ([ref]$AqMode)
        Threads = ([ref]$Threads)
        Level   = ([ref]$Level)
    }
    
    Confirm-Parameters @settings -Verbose:$setVerbose

    # Gather preset-related parameters
    $presetArgs = @{ 
        Subme       = $subme 
        BIntra      = $BIntra 
        BFrames     = $BFrames 
        PsyRdoq     = $PsyRdoq 
        AqMode      = $AqMode
        Ref         = $Ref
        Merange     = $Merange
        RCLookahead = $RCLookahead
    }
    # Set preset based arguments based on user input
    $presetParams = Set-PresetParameters -Settings $presetArgs -Preset $Preset -Encoder $Encoder -Verbose:$setVerbose
    Write-Verbose "PRESET PARAMETER VALUES:`n$($presetParams | Out-String)`n"

    <#
        BUILD FINAL ARGUMENT ARRAYS

        Set the base arguments
        Pass arguments to Set-FFMpegArgs or Set-DvArgs functions to prepare for encoding
    #>

    $baseArgs = @{
        Encoder        = $Encoder 
        Audio          = $audio
        Subtitles      = $subs
        Preset         = $Preset
        CropDimensions = $CropDimensions
        RateControl    = $RateControl
        PresetParams   = $presetParams
        QComp          = $QComp
        PsyRd          = $PsyRd
        Deblock        = $Deblock
        AqStrength     = $AqStrength
        NoiseReduction = $NoiseReduction
        NLMeans        = $NLMeans
        Unsharp        = $Unsharp
        TuDepth        = $TuDepth
        LimitTu        = $LimitTu
        Tree           = $Tree
        IntraSmoothing = $IntraSmoothing
        Threads        = $Threads
        Level          = $Level
        VBV            = $VBV
        FFMpegExtra    = $FFMpegExtra
        EncoderExtra   = $EncoderExtra
        HDR            = $HDR
        Paths          = $Paths
        Scale          = $Scale
        TestFrames     = $TestFrames
        TestStart      = $TestStart
        Deinterlace    = $Deinterlace
        Verbose        = $setVerbose
    }

    if ($HDR.DV -eq $true) {
        $dovi = $true
        $baseArgs.Remove('Encoder')
        $dvArgs = Set-DVArgs @baseArgs
    } 
    else {
        $dovi = $false
        $ffmpegArgs = Set-FFMpegArgs @baseArgs
    }

    # If Dolby Vision is found and args not empty/null, encode with Dolby Vision using x265 pipe
    if ($dvArgs) {
        if ($IsLinux -or $IsMacOS) { 
            $Paths.HevcPath = [regex]::Escape($Paths.HevcPath)
        }

        # Pull the x265 name from PATH to account for any mods. Selects the first result
        $x265 = Get-Command 'x265*' | Select-Object -First 1 -ExpandProperty Source | Split-Path -LeafBase
        Write-Verbose "x265 EXECUTABLE NAME: $x265`n"

        # Two pass x265 encode
        if ($null -ne $dvArgs.x265Args2) {
            Write-Host
            Write-Host "$("`u{2726}" * 3) 2-Pass ABR Selected @ $($RateControl[1] -replace '(.*)(\w+)$', '$1 $2')b/s $("`u{2726}" * 3)" @emphasisColors
            Write-Host "$boldOn$("`u{25c7}" * 4) STARTING x265 PIPE PASS 1 $("`u{25c7}" * 4)$boldOff" @progressColors
            Write-Host "Generating 1st pass encoder metrics...`n"
            Write-Banner

            # If VS script was passed
            if (![string]::IsNullOrEmpty($Paths.VPY)) {
                $shellArgsPass1 = ($IsLinux -or $IsMacOS) ?
                    ('bash', '-c', "$($dvArgs.Vapoursynth) | $x265 $($dvArgs.x265Args1) -o $($Paths.hevcPath)") :
                    ('cmd.exe', '/c', "$($dvArgs.Vapoursynth) | $x265 $($dvArgs.x265Args1) -o `"$($Paths.hevcPath)`"")

                $shellArgsPass2 = ($IsLinux -or $IsMacOS) ?
                    ('bash', '-c', "$($dvArgs.Vapoursynth) | $x265 $($dvArgs.x265Args2) -o $($Paths.hevcPath)") :
                    ('cmd.exe', '/c', "$($dvArgs.Vapoursynth) | $x265 $($dvArgs.x265Args2) -o `"$($Paths.hevcPath)`"")
            }
            else {
                $shellArgsPass1 = ($IsLinux -or $IsMacOS) ?
                    ('bash', '-c', "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | $x265 $($dvArgs.x265Args1) -o $($Paths.hevcPath)") :
                    ('cmd.exe', '/c', "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | $x265 $($dvArgs.x265Args1) -o `"$($Paths.hevcPath)`"")

                $shellArgsPass2 = ($IsLinux -or $IsMacOS) ?
                    ('bash', '-c', "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | $x265 $($dvArgs.x265Args2) -o $($Paths.hevcPath)") :
                    ('cmd.exe', '/c', "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | $x265 $($dvArgs.x265Args2) -o `"$($Paths.hevcPath)`"")
            }

            Write-Verbose "FULL CLI PASS 1:`n  $($shellArgsPass1 -join ' ')`n"
            Write-Verbose "FULL CLI PASS 2:`n  $($shellArgsPass2 -join ' ')`n"

            if ($DisableProgress) {
                & $shellArgsPass1[0] $shellArgsPass1[1] $shellArgsPass1[2] 2>Paths.$LogPath
            }
            else {
                Start-ThreadJob -Name '1st Pass' -ArgumentList $shellArgsPass1, $Paths.LogPath -ScriptBlock {
                    param ([array]$ShellArgs, [string]$LogPath)

                    & $ShellArgs[0] $ShellArgs[1] $ShellArgs[2] 2>$LogPath
                } | Out-Null

                $params = @{
                    InputFile   = $Paths.InputFile
                    LogPath     = $Paths.LogPath
                    TestFrames  = $TestFrames
                    JobName     = '1st Pass'
                    SecondPass  = $false
                    DolbyVision = $dovi
                    Verbose     = $setVerbose
                }
                Write-EncodeProgress @params
            }

            Write-Host
            Write-Host "$boldOn$("`u{25c7}" * 4) STARTING x265 PIPE PASS 2 $("`u{25c7}" * 4)$boldOff" @progressColors
            Write-Banner

            if ($DisableProgress) {
                & $shellArgsPass2[0] $shellArgsPass2[1] $shellArgsPass2[2] 2>Paths.$LogPath
            }
            else {
                Start-ThreadJob -Name '2nd Pass' -ArgumentList $shellArgsPass2, $Paths.LogPath -ScriptBlock {
                    param ([array]$ShellArgs, [string]$LogPath)

                    & $ShellArgs[0] $ShellArgs[1] $ShellArgs[2] 2>$LogPath
                } | Out-Null

                $params = @{
                    InputFile   = $Paths.InputFile
                    LogPath     = $Paths.LogPath
                    TestFrames  = $TestFrames
                    JobName     = '2nd Pass'
                    SecondPass  = $true
                    DolbyVision = $dovi
                    Verbose     = $setVerbose
                }
                Write-EncodeProgress @params
            }
        }
        # CRF/One pass x265 encode
        else {
            Write-Host "$("`u{2726}" * 3) CRF $($RateControl[1]) Selected $("`u{2726}" * 3)" @emphasisColors
            Write-Host "$boldOn$("`u{25c7}" * 4) STARTING x265 PIPE $("`u{25c7}" * 4)$boldOff" @progressColors
            Write-Banner

            if (![string]::IsNullOrEmpty($Paths.VPY)) {
                $shellArgs = ($IsLinux -or $IsMacOS) ?
                    ('bash', '-c', "$($dvArgs.Vapoursynth) | $x265 $($dvArgs.x265Args1) -o $($Paths.hevcPath)") :
                    ('cmd.exe', '/c', "$($dvArgs.Vapoursynth) | $x265 $($dvArgs.x265Args1) -o `"$($Paths.hevcPath)`"")
            }
            else {
                $shellArgs = ($IsLinux -or $IsMacOS) ?
                    ('bash', '-c', "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | $x265 $($dvArgs.x265Args1) -o $($Paths.HevcPath)") :
                    ('cmd.exe', '/c', "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | $x265 $($dvArgs.x265Args1) -o `"$($Paths.HevcPath)`"")
            }

            Write-Verbose "FULL CLI:`n  $($shellArgs -join ' ')`n"

            if ($DisableProgress) {
                & $shellArgs[0] $shellArgs[1] $shellArgs[2] 2>Paths.$LogPath
            }
            else {
                Start-ThreadJob -Name 'crf' -ArgumentList $shellArgs, $Paths.LogPath -ScriptBlock {
                    param ([array]$ShellArgs, [string]$LogPath)

                    & $ShellArgs[0] $ShellArgs[1] $ShellArgs[2] 2>$LogPath
                } | Out-Null

                $params = @{
                    InputFile   = $Paths.InputFile
                    LogPath     = $Paths.LogPath
                    TestFrames  = $TestFrames
                    JobName     = 'crf'
                    SecondPass  = $false
                    DolbyVision = $dovi
                    Verbose     = $setVerbose
                }
                Write-EncodeProgress @params
            }
        }
        # Mux/convert audio and subtitle streams separately from elementary hevc stream
        if ($audio -ne '-an' -or ($null -ne $audio2 -and $audio2 -ne '-an') -or $subs -ne '-sn') {
            Write-Host "Converting audio/subtitles..."
            $Paths.TmpOut = $Paths.OutputFile -replace '^(.*)\.(.+)$', '$1-TMP.$2'
            if ($PSBoundParameters['TestFrames']) {
                # Cut stream at video frame marker
                ffmpeg -hide_banner -loglevel panic -ss 00:01:30 $dvArgs.FFMpegOther -frames:a $($TestFrames + 100) `
                    -y $Paths.tmpOut 2>>$Paths.LogPath
            }
            else {
                ffmpeg -hide_banner -loglevel panic $dvArgs.FFMpegOther -y $Paths.tmpOut 2>>$Paths.LogPath
            }
        }
        else { 
            if ((Get-Command 'mkvextract') -and $Paths.InputFile.EndsWith('mkv')) {
                # Extract chapters if no other streams are copied
                Write-Verbose "No additional streams selected. Generating chapter file..."
                $Paths.ChapterPath = "$($Paths.OutputFile -replace '^(.*)\.(.+)$', '$1_chapters.xml')"
                if (!(Test-Path -Path $Paths.ChapterPath -ErrorAction SilentlyContinue)) {
                    mkvextract "$($Paths.InputFile)" chapters "$($Paths.ChapterPath)"
                    if (!$?) { 
                        Write-Host "Extracting chapters FAILED. Verify that the input file contains chapters" @warnColors
                        $Paths.ChapterPath = $null
                    }
                } 
                else { Write-Verbose "Chapter file already exists. Skipping creation..." }
            }
            else { $Paths.ChapterPath = $null }
        }

        # If mkvmerge is available and output stream is mkv, mux streams back together
        if ((Get-Command 'mkvmerge') -and $Paths.OutputFile.EndsWith('mkv')) {
            # Set the paths needed for mkvmerge
            $muxPaths = @{
                Input    = $Paths.HevcPath
                Output   = $Paths.OutputFile
                Title    = $Paths.Title
                Language = $Paths.Language
            }
            if ($Paths.ChapterPath) {
                $muxPaths.Temp = $Paths.ChapterPath
                $muxPaths.Chapters = $true
            }
            elseif (!$Paths.ChapterPath -and !$Paths.TmpOut) {
                $muxPaths.VideoOnly = $true 
            }
            else {
                $muxPaths.Temp = $Paths.TmpOut
            }
            Invoke-MkvMerge -Paths $muxPaths -Mode 'dv' -Verbose:$setVerbose
        }
        else {
            Write-Host "MkvMerge not found in PATH. Mux the HEVC stream manually to retain Dolby Vision"
        }

        Write-Host ""
    } # End DoVi

    # Two pass encode
    elseif ($ffmpegArgs.Count -eq 2 -and $RateControl[0] -eq '-b:v') {
        Write-Host "$("`u{2726}" * 3) 2-Pass ABR Selected @ $($RateControl[1] -replace '(.*)(\w+)$', '$1 $2')b/s $("`u{2726}" * 3)" @emphasisColors
        Write-Host "$boldOn$("`u{25c7}" * 4) STARTING FFMPEG PASS 1 - $Encoder $("`u{25c7}" * 4)$boldOff" @progressColors
        Write-Host "Generating 1st pass encoder metrics...`n"
        Write-Banner

        if (([math]::Round(([FileInfo]($Paths.X265Log)).Length / 1MB, 2)) -gt 10) {
            $msg = "A large x265 first pass log already exists. If this isn't a full log, " +
                   "stop and delete the log before proceeding. Continuing to second pass..."
            if ($psReq) {
                Write-Host "$($aYellow+$boldOn)$msg`n"
            }
            else {
                Write-Host "$msg`n" @warnColors
            }
        }
        else {
            if ($DisableProgress) {
                ffmpeg $ffmpegArgs[0] -f null - 2>$Paths.LogPath
            }
            else {
                $ffArgsPass1 = $ffmpegArgs[0]
                $ffArgsPass2 = $ffmpegArgs[1]
                $log = $Paths.LogPath

                Start-ThreadJob -Name 'ffmpeg 1st Pass' -ArgumentList $ffArgsPass1, $log -ScriptBlock {
                    param ($ffArgsPass1, $log)

                    ffmpeg $ffArgsPass1 -f null - 2>$log
                } | Out-Null

                $params = @{
                    InputFile   = $Paths.InputFile
                    LogPath     = $Paths.LogPath
                    TestFrames  = $TestFrames
                    JobName     = 'ffmpeg 1st Pass'
                    SecondPass  = $false
                    Verbose     = $setVerbose
                    DolbyVision = $dovi
                }
                Write-EncodeProgress @params
            } 
        }

        Write-Host "$boldOn$("`u{25c7}" * 4) STARTING FFMPEG PASS 2 - $Encoder $("`u{25c7}" * 4)$boldOff" @progressColors
        Write-Banner

        if ($DisableProgress) {
            ffmpeg $ffmpegArgs[1] $Paths.OutputFile 2>>$Paths.LogPath
        }
        else {
            Start-ThreadJob -Name 'ffmpeg 2nd Pass' -ArgumentList $ffArgsPass2, $Paths.OutputFile, $log -ScriptBlock {
                param ($ffArgsPass2, $out, $log)
    
                ffmpeg $ffArgsPass2 $out 2>>$log
            } | Out-Null
    
            $params = @{
                InputFile   = $Paths.InputFile
                LogPath     = $Paths.LogPath
                TestFrames  = $TestFrames
                JobName     = 'ffmpeg 2nd Pass'
                SecondPass  = $true
                Verbose     = $setVerbose
                DolbyVision = $dovi
            }
            Write-EncodeProgress @params
        }  
    }
    # CRF encode
    elseif ($RateControl[0] -eq '-crf') {
        Write-Host "$("`u{2726}" * 3) CRF $($RateControl[1]) Selected $("`u{2726}" * 3)" @emphasisColors
        Write-Host "$boldOn$("`u{25c7}" * 4) STARTING FFMPEG - $Encoder $("`u{25c7}" * 4)$boldOff" @progressColors
        Write-Banner

        if ($DisableProgress) {
            ffmpeg $ffmpegArgs $Paths.OutputFile 2>$Paths.LogPath
        }
        else {
            Start-ThreadJob -Name ffmpeg -ArgumentList $ffmpegArgs, $Paths.OutputFile, $Paths.LogPath -ScriptBlock {
                param ($ffmpegArgs, $out, $log)
    
                ffmpeg $ffmpegArgs $out 2>$log
            } | Out-Null
        }    
    }
    # One pass encode
    elseif ($RateControl[0] -eq '-b:v') {
        Write-Host "$("`u{2726}" * 3) 1 Pass ABR Selected @ $($RateControl[1] -replace '(.*)(\w+)$', '$1 $2')b/s  $("`u{2726}" * 3)" @emphasisColors
        Write-Host "$boldOn$("`u{25c7}" * 4) STARTING FFMPEG - $Encoder $("`u{25c7}" * 4)$boldOff" @progressColors
        Write-Banner

        if ($DisableProgress) {
            ffmpeg $ffmpegArgs $Paths.OutputFile 2>$Paths.LogPath
        }
        else {
            Start-ThreadJob -Name ffmpeg -ArgumentList $ffmpegArgs, $Paths.OutputFile, $Paths.LogPath -ScriptBlock {
                param ($ffmpegArgs, $out, $log)
    
                ffmpeg $ffmpegArgs $out 2>$log
            } | Out-Null
        } 
    }
    # Should be unreachable. Throw error and exit script if rate control cannot be detected
    else {
        $params = @{
            Exception    = [System.FieldAccessException]::new('Rate control method could not be determined from input parameters')
            Category     = 'InvalidResult'
            TargetObject = $RateControl
            ErrorId      = 101
        }
        $console.WindowTitle = $currentTitle
        Write-Error @params -ErrorAction Stop
    }

    <#
        TRACK ENCODING PROGRESS

        Periodically grab current frame from log
        Display progress bar based on total frame count
        2-pass & dovi are called separately
        TODO: Find a way to call function once for all modes
    #>

    if ($ffmpegArgs.Count -ne 2 -and !$DisableProgress -and !$dovi) {
        $params = @{
            InputFile   = $Paths.InputFile
            LogPath     = $Paths.LogPath
            TestFrames  = $TestFrames
            JobName     = 'ffmpeg'
            SecondPass  = $false
            DolbyVision = $dovi
            Verbose     = $setVerbose
        }
        Write-EncodeProgress @params
    }

    # Remove ffmpeg jobs
    Get-Job -State Completed | Remove-Job
    Write-Host ""
}

