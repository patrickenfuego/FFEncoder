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
        # Crop dimensions for the output file
        [Parameter(Mandatory = $true, Position = 1)]
        [Alias("Crop", "CropDim")]
        [int[]]$CropDimensions,

        # Audio preference for the output file
        [Parameter(Mandatory = $false)]
        [Alias("Audio", "A")]
        [array]$AudioInput,

        # Parameter help description
        [Parameter(Mandatory = $false)]
        [Alias("S")]
        [string]$Subtitles,

        # x265 preset setting
        [Parameter(Mandatory = $false)]
        [Alias("P")]
        [string]$Preset,

        # x265 CRF / 1 pass ABR array of arguments
        [Parameter(Mandatory = $true)]
        [array]$RateControl,

        # Deblock filter setting
        [Parameter(Mandatory = $false)]
        [Alias("DBF")]
        [int[]]$Deblock,

        # aq-mode setting. Default is 2
        [Parameter(Mandatory = $false)]
        [Alias("AQM")]
        [int]$AqMode,

        # aq-strength. Higher values equate to a lower QP, but can also increase bitrate significantly
        [Parameter(Mandatory = $false)]
        [Alias("AQS")]
        [double]$AqStrength,

        # psy-rd. Psycho visual setting
        [Parameter(Mandatory = $false)]
        [double]$PsyRd,

        # psy-rdoq (trellis). Psycho visual setting
        [Parameter(Mandatory = $false)]
        [Alias("PRDQ")]
        [double]$PsyRdoq,

        # Filter to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [Alias("NR")]
        [int[]]$NoiseReduction,

        # Powerful denoising filter
        [Parameter(Mandatory = $false)]
        [Alias("NL")]
        [hashtable]$NLMeans,

        #Transform unit recursion depth (intra, inter)
        [Parameter(Mandatory = $false)]
        [Alias("TU")]
        [int[]]$TuDepth,

        #Early exit setting for TU recursion depth
        [Parameter(Mandatory = $false)]
        [Alias("LTU")]
        [int]$LimitTu,

        # Adjusts the quantizer curve compression factor
        [Parameter(Mandatory = $false)]
        [Alias("Q")]
        [double]$QComp,

        # Maximum number of consecutive b-frames
        [Parameter(Mandatory = $false)]
        [int]$BFrames,

        # Enables the evaluation of intra modes in B slices
        [Parameter(Mandatory = $false)]
        [int]$BIntra,

        # Subpel motion refinement
        [Parameter(Mandatory = $false)]
        [int]$Subme,

        # Enable/disable strong-intra-smoothing
        [Parameter(Mandatory = $false)]
        [Alias("SIS")]
        [int]$IntraSmoothing,

        # Number of frame threads the encoder should use
        [Parameter(Mandatory = $false)]
        [int]$FrameThreads,

        # Encoder level to use. Default is unset
        [Parameter(Mandatory = $false)]
        [string]$Level,

        # Encoder level to use. Default is unset
        [Parameter(Mandatory = $false)]
        [int[]]$VBV,

        [Parameter(Mandatory = $false)]
        [array]$FFMpegExtra,

        [Parameter(Mandatory = $false)]
        [hashtable]$x265Extra,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [Alias("L")]
        [hashtable]$Paths,

        # Scale setting
        [Parameter(Mandatory = $false)]
        [Alias("Resize", "DS")]
        [hashtable]$Scale,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        [Alias("T")]
        [int]$TestFrames,

        # Starting Point for test encodes. Integers are treated as a frame #
        [Parameter(Mandatory = $false)]
        [Alias("Start", "TS")]
        [string]$TestStart,

        # Deinterlacing
        [Parameter(Mandatory = $false)]
        [Alias("DI")]
        [switch]$Deinterlace,

        # Skip DV even if present
        [Parameter(Mandatory = $false)]
        [Alias("NoDV", "SDV")]
        [switch]$SkipDolbyVision,

        # Skip HDR10+ even if present
        [Parameter(Mandatory = $false)]
        [Alias("NoD10P", "STP")]
        [switch]$SkipHDR10Plus,

        # Enable Verbose output
        [Parameter(Mandatory = $false)]
        [Alias("V")]
        [string]$Verbosity
    )

    function Write-Banner {
        if ($TestFrames) {
            $startStr = switch -Wildcard ($TestStart) {
                '*f'    { "Frame $($TestStart -replace 'f', '')" }
                '*t'    { "$($TestStart -replace 't', '') Seconds" }
                default { "$TestStart" }
            }
            Write-Host ""
            Write-Host "----- TEST ENCODE -----" @warnColors
            Write-Host "Start:`t`t$startStr" @warnColors
            Write-Host "Duration:`t$TestFrames Frames`n" @warnColors
        }
        Write-Host "To view your progress, run " -NoNewline
        Write-Host "Get-Content `"$($Paths.LogPath)`" -Tail 10" @emphasisColors -NoNewline
        Write-Host " in a different PowerShell session`n`n"
    }

    if ($PSBoundParameters['Verbosity']) {
        $VerbosePreference = 'Continue'
    }
    else {
        $VerbosePreference = 'SilentlyContinue'
    }

    #Determine the resolution and fetch metadata if 4K
    if ($CropDimensions[2]) { 
        $skipDv = ($SkipDolbyVision) ? $true : $false
        $skip10P = ($SkipHDR10Plus) ? $true : $false
        #Get HDR metadata. Re-throw any errors from function & exit call stack
        try {
            $HDR = Get-HDRMetadata $Paths.InputFile $Paths.HDR10Plus $Paths.DvPath $skipDv $skip10P
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    else { $HDR = $null }
    
    #Building the audio argument array(s) based on user input
    $audioParam1 = @{
        Paths       = $Paths
        UserChoice  = $AudioInput[0].Audio
        Bitrate     = $AudioInput[0].Bitrate
        Stream      = 0
        Stereo      = $AudioInput[0].Stereo
        RemuxStream = $false
    }
    $audio = Set-AudioPreference @audioParam1
    if ($null -ne $AudioInput[1]) {
        #Verify if stream copying and a named codec are used together
        $copyOpt = @('copy', 'c', 'copyall', 'ca', 0, 1, 2, 3, 4, 5)
        if ($AudioInput[1].Stereo -and 
            $copyOpt -contains $AudioInput[0].Audio -and 
            $copyOpt -notcontains $AudioInput[1].Audio) {
            
            $remuxStream = $true
        }
        else { $remuxStream = $false }

        $audioParam2 = @{
            Paths       = $Paths
            UserChoice  = $AudioInput[1].Audio
            Bitrate     = $AudioInput[1].Bitrate
            Stream      = 1
            Stereo      = $AudioInput[1].Stereo
            AudioFrames = $TestFrames
            RemuxStream = $remuxStream
        }
        $audio2 = Set-AudioPreference @audioParam2

        if ($null -ne $audio2) { $audio = $audio + $audio2 }
    }
    Write-Verbose "AUDIO ARGUMENTS:`n$($audio -join " ")`n"
    
    #Set args to preset default if not modified by the user via parameters
    $presetArgs = @{ 
        Subme   = $subme 
        BIntra  = $BIntra 
        BFrames = $BFrames 
        PsyRdoq = $PsyRdoq 
        AqMode  = $AqMode 
    }
    #Set preset based arguments based on user input
    $presetParams = Set-PresetParameters -ScriptParams $presetArgs -Preset $Preset
    Write-Verbose "PRESET PARAMETER VALUES:`n$($presetParams | Out-String)`n"
    #Builds the subtitle argument array based on user input
    $subs = Set-SubtitlePreference -InputFile $Paths.InputFile -UserChoice $Subtitles

    #Set the base arguments and pass them to Set-FFMpegArgs or Set-DvArgs functions
    $baseArgs = @{
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
        TuDepth        = $TuDepth
        LimitTu        = $LimitTu
        IntraSmoothing = $IntraSmoothing
        FrameThreads   = $FrameThreads
        Level          = $Level
        VBV            = $VBV
        FFMpegExtra    = $FFMpegExtra
        x265Extra      = $x265Extra
        HDR            = $HDR
        Paths          = $Paths
        Scale          = $Scale
        TestFrames     = $TestFrames
        TestStart      = $TestStart
        Deinterlace    = $Deinterlace
        Verbosity      = $Verbosity
    }

    if ($HDR.DV -eq $true) { $dvArgs = Set-DVArgs @baseArgs } else { $ffmpegArgs = Set-FFMpegArgs @baseArgs }
    # If Dolby Vision is found and args not empty/null, encode with Dolby Vision using x265 pipe
    if ($dvArgs) {
        if ($IsLinux -or $IsMacOS) { 
            $hevcPath = [regex]::Escape($Paths.hevcPath)  
        }

        #Two pass x265 encode
        if ($null -ne $dvArgs.x265Args2) {
            Write-Host
            Write-Host "**** 2-Pass ABR Selected @ $($RateControl[1])b/s ****" @emphasisColors
            Write-Host "***** STARTING x265 PIPE PASS 1 *****" @progressColors
            Write-Banner

            if ($IsLinux -or $IsMacOS) {
                bash -c "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | x265 $($dvArgs.x265Args1) -o $hevcPath" 2>$Paths.LogPath
            }
            else {
                cmd.exe /c "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | x265 $($dvArgs.x265Args1) -o `"$($Paths.hevcPath)`"" 2>$Paths.LogPath
            }

            Write-Host
            Write-Host "***** STARTING x265 PIPE PASS 2 *****" @progressColors
            Write-Banner
            
            if ($IsLinux -or $IsMacOS) {
                bash -c "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | x265 $($dvArgs.x265Args2) -o $hevcPath" 2>>$Paths.LogPath
            }
            else {
                cmd.exe /c "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | x265 $($dvArgs.x265Args2) -o `"$($Paths.hevcPath)`"" 2>>$Paths.LogPath
            }
        }
        #CRF/One pass x265 encode
        else {
            Write-Host "**** CRF $($RateControl[1]) Selected ****" @emphasisColors
            Write-Host "***** STARTING x265 PIPE *****" @progressColors
            Write-Banner

            if ($IsLinux -or $IsMacOS) {
                bash -c "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | x265 $($dvArgs.x265Args1) -o $hevcPath" 2>$Paths.LogPath
            }
            else {
                cmd.exe /c "ffmpeg -hide_banner -loglevel panic $($dvArgs.FFMpegVideo) | x265 $($dvArgs.x265Args1) -o `"$($Paths.hevcPath)`"" 2>$Paths.LogPath
            }
        }
        #Mux/convert audio and subtitle streams separately from elementary hevc stream
        if ($audio -ne '-an' -or ($null -ne $audio2 -and $audio2 -ne '-an') -or $subs -ne '-sn') {
            Write-Host "Converting audio/subtitles..."
            $Paths.tmpOut = $Paths.OutputFile -replace '^(.*)\.(.+)$', '$1-TMP.$2'
            if ($PSBoundParameters['TestFrames']) {
                #cut stream at video frame marker
                ffmpeg -hide_banner -loglevel panic -ss 00:01:30 $dvArgs.FFMpegOther -frames:a $($TestFrames + 100) -y $Paths.tmpOut 2>>$Paths.LogPath
            }
            else {
                ffmpeg -hide_banner -loglevel panic $dvArgs.FFMpegOther -y $Paths.tmpOut 2>>$Paths.LogPath
            }
        }
        else { 
            if ((Get-Command 'mkvextract') -and $Paths.InputFile.EndsWith('mkv')) {
                #Extract chapters if no other streams are copied
                Write-Verbose "No additional streams selected. Generating chapter file..."
                $Paths.ChapterPath = "$($Paths.OutputFile -replace '^(.*)\.(.+)$', '$1_chapters.xml')"
                if (!(Test-Path -Path $Paths.ChapterPath -ErrorAction SilentlyContinue)) {
                    mkvextract "$($Paths.InputFile)" chapters "$($Paths.ChapterPath)"
                    if (!$?) { 
                        Write-Host "Extracting chapters FAILED. Verify that the input file contains chapters" @warnColors
                    }
                } 
                else { Write-Verbose "Chapter file already exists. Skipping creation..." }
            }
            else { $Paths.ChapterPath = $null }
        }

        #If mkvmerge is available and output stream is mkv, mux streams back together
        if ((Get-Command 'mkvmerge') -and $Paths.OutputFile.EndsWith('mkv')) {
            Invoke-MkvMerge -Paths $Paths -Verbosity $Verbosity
        }
        else {
            Write-Host "MkvMerge not found in PATH. Mux the HEVC stream manually to retain Dolby Vision"
        }

        Write-Host ""
    }
    #Two pass encode
    elseif ($ffmpegArgs.Count -eq 2 -and $RateControl[0] -eq '-b:v') {
        Write-Host "**** 2-Pass ABR Selected @ $($RateControl[1])b/s ****" @emphasisColors
        Write-Host "***** STARTING FFMPEG PASS 1 *****" @progressColors
        Write-Host "Generating 1st pass encoder metrics..."
        Write-Banner

        if ((Test-Path $Paths.X265Log) -and [int]([math]::Round((Get-Item $Paths.X265Log).Length / 1MB, 2)) -gt 10) {
            Write-Host "A full x265 first pass log already exists. Proceeding to second pass...`n" @warnColors
        }
        else {
            ffmpeg $ffmpegArgs[0] -f null - 2>$Paths.LogPath
        }

        Write-Host
        Write-Host "***** STARTING FFMPEG PASS 2 *****" @progressColors
        Write-Banner

        ffmpeg $ffmpegArgs[1] $Paths.OutputFile 2>>$Paths.LogPath
    }
    #CRF encode
    elseif ($RateControl[0] -eq '-crf') {
        Write-Host "**** CRF $($RateControl[1]) Selected ****" @emphasisColors
        Write-Host "***** STARTING FFMPEG *****" @progressColors
        Write-Banner

        ffmpeg $ffmpegArgs $Paths.OutputFile 2>$Paths.LogPath
    }
    #One pass encode
    elseif ($RateControl[0] -eq '-b:v') {
        Write-Host "**** 1 Pass ABR Selected @ $($RateControl[1])b/s ****" @emphasisColors
        Write-Host "***** STARTING FFMPEG *****" @progressColors
        Write-Banner

        ffmpeg $ffmpegArgs $Paths.OutputFile 2>$Paths.LogPath
    }
    #Should be unreachable. Throw error and exit script if rate control cannot be detected
    else {
        throw "Rate control method could not be determined from input parameters"
        exit 2
    }
}

