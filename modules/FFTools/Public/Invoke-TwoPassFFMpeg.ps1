function Invoke-TwoPassFFMpeg {
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

        # x265 CRF / constant bitrate array of arguments
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

        # Filters to help reduce high frequency noise (grain)
        [Parameter(Mandatory = $false)]
        [Alias("NRTR")]
        [int[]]$NoiseReduction,

        # Adjusts the quantizer curve compression factor
        [Parameter(Mandatory = $false)]
        [Alias("Q")]
        [double]$QComp,

        # Maximum number of consecutive b-frames
        [Parameter(Mandatory = $false)]
        [int]$BFrames,

        # Path to the log file
        [Parameter(Mandatory = $true)]
        [Alias("L")]
        [hashtable]$Paths,

        # Switch to enable a test run 
        [Parameter(Mandatory = $false)]
        [Alias("T")]
        [int]$TestFrames
    )

    function Write-FirstBanner {
        Write-Host "***** STARTING FFMPEG PASS 1 *****" @progressColors
        Write-Host "Generating 1st pass encoder metrics..."
    }

    function Write-SecondBanner {
        Write-Host
        Write-Host "***** STARTING FFMPEG PASS 2 *****" @progressColors
        Write-Host "To view your progress, run " -NoNewline
        Write-Host "Get-Content '$($Paths.LogPath)' -Tail 10" @emphasisColors -NoNewline
        Write-Host " in a different PowerShell session`n"
    }
    
    if ($CropDimensions[2]) { $UHD = $true; $HDR = Get-HDRMetadata $Paths.InputFile }
    else { $UHD = $false }
    #Builds the audio argument array(s) based on user input
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
        $copyOpt = @("copy", "c", "copyall", "ca")
        if ($AudioInput[1].Stereo -and 
            $copyOpt -contains $AudioInput[0].Audio -and 
            $copyOpt -notcontains $AudioInput[1].Audio) {
            $audioParam2 = @{
                Paths       = $Paths
                UserChoice  = $AudioInput[1].Audio
                Bitrate     = $AudioInput[1].Bitrate
                Stream      = 1
                Stereo      = $AudioInput[1].Stereo
                AudioFrames = $TestFrames
                RemuxStream = $true
            }
        }
        else {
            $audioParam2 = @{
                Paths       = $Paths
                UserChoice  = $AudioInput[1].Audio
                Bitrate     = $AudioInput[1].Bitrate
                Stream      = 1
                Stereo      = $AudioInput[1].Stereo
                AudioFrames = $TestFrames
                RemuxStream = $false
            } 
        }
        $audio2 = Set-AudioPreference @audioParam2
        if ($null -ne $audio2) { $audio = $audio + $audio2 }
    }
    #Builds the subtitle argument array based on user input
    $subs = Set-SubtitlePreference -InputFile $Paths.InputFile -UserChoice $Subtitles

    Write-Host "** 2 Pass Rate Control Selected **" @emphasisColors

    if ($UHD) {
        if ($PSBoundParameters['TestFrames']) {
            Write-FirstBanner
            Write-Host "`n`nTest Run Enabled. Analyzing $TestFrames frames`n" @warnColors
            ffmpeg -probesize 100MB -ss 00:01:30 -i $Paths.InputFile -frames:v $TestFrames -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 -an -sn $RateControl -preset $Preset -pix_fmt $HDR.PixelFmt `
                -x265-params "pass=1:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):bframes=$BFrames`:`
                colorprim=$($HDR.ColorPrimaries):transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):aud=1:hrd=1::level-idc=5.1:sao=0:rc-lookahead=48:subme=4:`
                chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr10-opt=1:b-intra=1:frame-threads=2" `
                -f null - 2>$Paths.LogPath
                
            Start-Sleep -Seconds 1
    
            Write-SecondBanner
            Write-Host "`nTest Run Enabled. Encoding $TestFrames frames`n" @warnColors
            ffmpeg -probesize 100MB -ss 00:01:30 -i $Paths.InputFile -frames:v $TestFrames -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -pix_fmt $HDR.PixelFmt `
                -x265-params "pass=2:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):bframes=$BFrames`:`
                colorprim=$($HDR.ColorPrimaries):transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):aud=1:hrd=1::level-idc=5.1:sao=0:rc-lookahead=48:subme=4:`
                chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr10-opt=1:b-intra=1:frame-threads=2" `
                $Paths.OutputFile 2>$Paths.LogPath
        }
        #Run a full 2 pass encode
        else {
            Write-FirstBanner
            ffmpeg -probesize 100MB -i $Paths.InputFile -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 -an -sn $RateControl -preset $Preset -pix_fmt $HDR.PixelFmt `
                -x265-params "pass=1:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):bframes=$BFrames`:`
                colorprim=$($HDR.ColorPrimaries):transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):aud=1:hrd=1::level-idc=5.1:sao=0:rc-lookahead=48:subme=4:`
                chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr10-opt=1:b-intra=1:frame-threads=2" `
                -f null - 2>$Paths.LogPath
                
            Start-Sleep -Seconds 1
    
            Write-SecondBanner
            ffmpeg -probesize 100MB -i $Paths.InputFile -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -pix_fmt $HDR.PixelFmt `
                -x265-params "pass=2:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):bframes=$BFrames`:`
                colorprim=$($HDR.ColorPrimaries):transfer=$($HDR.Transfer):colormatrix=$($HDR.ColorSpace):aud=1:hrd=1::level-idc=5.1:sao=0:rc-lookahead=48:subme=4:`
                chromaloc=2:$($HDR.MasterDisplay)L($($HDR.MaxLuma),$($HDR.MinLuma)):max-cll=$($HDR.MaxCLL),$($HDR.MaxFAL):hdr10-opt=1:b-intra=1:frame-threads=2" `
                $Paths.OutputFile 2>$Paths.LogPath
        }
    }
    #Encode SDR content (1080p and below)
    else {
        if ($PSBoundParameters['TestFrames']) {
            Write-FirstBanner
            Write-Host "`n`nTest Run Enabled. Analyzing $TestFrames frames`n" @warnColors
            ffmpeg -probesize 100MB -ss 00:01:30 -i $Paths.InputFile -frames:v $TestFrames -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 -an -sn $RateControl -preset $Preset -profile:v main10 -pix_fmt yuv420p10le `
                -x265-params "pass=1:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):`
                sao=0:rc-lookahead=48:subme=4:bframes=$BFrames`:b-intra=1:merange=44:colorprim=bt709:transfer=bt709:colormatrix=bt709:frame-threads=2" `
                -f null - 2>$Paths.LogPath
                
            Start-Sleep -Seconds 1
    
            Write-SecondBanner
            Write-Host "`n`nTest Run Enabled. Encoding $TestFrames frames`n" @warnColors
            ffmpeg -probesize 100MB -ss 00:01:30 -i $Paths.InputFile -frames:v $TestFrames -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -profile:v main10 -pix_fmt yuv420p10le `
                -x265-params "pass=2:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):`
                sao=0:rc-lookahead=48:subme=4:bframes=$BFrames`:b-intra=1:merange=44:colorprim=bt709:transfer=bt709:colormatrix=bt709:frame-threads=2" `
                $Paths.OutputFile 2>$Paths.LogPath
        }
        #Run a full 2 pass encode
        else {
            Write-FirstBanner
            ffmpeg -probesize 100MB -i $Paths.InputFile -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -profile:v main10 -pix_fmt yuv420p10le `
                -x265-params "pass=1:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):`
                sao=0:rc-lookahead=48:subme=4:bframes=$BFrames`:b-intra=1:merange=44:colorprim=bt709:transfer=bt709:colormatrix=bt709:frame-threads=2" `
                -f null - 2>$Paths.LogPath
                
            Start-Sleep -Seconds 1
    
            Write-SecondBanner
            ffmpeg -probesize 100MB -i $Paths.InputFile -vf "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])" `
                -color_range tv -map 0:v:0 -c:v libx265 $audio $subs $RateControl -preset $Preset -profile:v main10 -pix_fmt yuv420p10le `
                -x265-params "pass=2:stats='$($Paths.X265Log)':nr-intra=$($NoiseReduction[0]):nr-inter=$($NoiseReduction[1]):aq-mode=$AqMode`:`
                aq-strength=$AqStrength`:psy-rd=$PsyRd`:psy-rdoq=$PsyRdoq`:open-gop=0:qcomp=$QComp`:keyint=120:deblock=$($Deblock[0]),$($Deblock[1]):`
                sao=0:rc-lookahead=48:subme=4:bframes=$BFrames`:b-intra=1:merange=44:colorprim=bt709:transfer=bt709:colormatrix=bt709:frame-threads=2" `
                $Paths.OutputFile 2>$Paths.LogPath
        }
    }
}