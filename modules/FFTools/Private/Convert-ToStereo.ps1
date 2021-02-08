function Convert-ToStereo {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$InputFile,

        [Parameter()]
        [string]$Codec,

        [Parameter()]
        [int]$Bitrate,

        [Parameter()]
        [int]$AudioFrames,

        [Parameter()]
        [bool]$RemuxStream,

        [Parameter()]
        [hashtable]$OutputPath
    )
    #Assign the audio parameter array based on codec
    $audioArgs = switch ($Codec) {
        { @('fdkaac', 'faac') -contains $_ } { 
            Write-Host "** FDK AAC AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'libfdk_aac', '-vbr', 3) }
            elseif (1..5 -contains $Bitrate) { @('-c:a', 'libfdk_aac', '-vbr', $Bitrate) }
            else { @('-c:a', 'libfdk_aac', '-b:a', $Bitrate) }
        }
        { @('dd', 'ac3') -contains $_ } {
            Write-Host "** DOLBY DIGITAL AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'ac3', '-b:a', '192k') }
            else { @('-c:a', 'ac3', '-b:a', $Bitrate) }
        }
        'aac' {
            Write-Host "** AAC AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'aac', '-b:a', '128k') }
            else { @('-c:a', 'aac', '-b:a', $Bitrate) }
        }
        'eac3' {
            Write-Host "** DOLBY DIGITAL PLUS AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'eac3', '-b:a', '128k') }
            else { @('-c:a', 'eac3', '-b:a', $Bitrate) }
        }
        'dts' {
            Write-Host "** DTS AUDIO SELECTED - STEREO **" @progressColors
            if (!$Bitrate) { @('-c:a', 'dca', '-strict', -2) }
            else { @('-c:a', 'dca', '-b:a', $Bitrate, '-strict', -2) }
        }
        'flac' { 
            Write-Host "** FLAC AUDIO SELECTED - STEREO **" @progressColors
            @('-c:a', 'flac')
        }
        Default { 
            Write-Warning "Could not verify argument array or codec during stereo downmix. Stream will be ignored"
            return $null 
        }
    }
    
    $stereoArgs = $audioArgs + @('-af', 'pan=stereo|FL=0.5*FC+0.707*FL+0.707*BL+0.5*LFE|FR=0.5*FC+0.707*FR+0.707*BR+0.5*LFE')
    [string]$muxedStreamPath = Join-Path -Path $OutputPath.Root -ChildPath "muxed.mkv"

    if ($RemuxStream) {
        Write-Host "Copy stream and audio filtering cannot be used simultaneously. " @warnColors -NoNewline
        Write-Host "Multiplexing audio stream 0 out of the container for conversion..."
        if (Test-Path -Path $muxedStreamPath) {
            Write-Host "Multiplexed audio track found. Skipping creation..." @warnColors
        }
        #If the target stereo file already exists, prompt to delete it
        if (Test-Path -Path $OutputPath.StereoPath) { Remove-FilePrompt -Path $OutputPath.StereoPath -Type "Stereo" }
        else { 
            ffmpeg -hide_banner -i $InputFile -loglevel error -map 0:a:0 -c:a copy -map -0:t? -map_chapters -1 `
                -vn -sn $muxedStreamPath
        }
        Write-Host "downmixing multi-channel audio file to stereo...`n" @progressColors
        if ($PSBoundParameters['AudioFrames']) {
            $AudioFrames = $AudioFrames * 1.5
            ffmpeg -ss 00:01:30 -i $muxedStreamPath -loglevel error -frames:a $AudioFrames $stereoArgs $OutputPath.StereoPath
        }
        else {
            ffmpeg -i $muxedStreamPath $stereoArgs $OutputPath.StereoPath 2>$OutputPath.LogPath
            Start-Sleep -Seconds 1
        }

        return $null
    }
    else { 
        Write-Host "downmixing multi-channel audio stream to stereo...`n" @progressColors
        $stereoArgs = $stereoArgs[1..($stereoArgs.Length - 1)]
        return $stereoArgs 
    }
}

# $params = @{
#     InputFile   = "M:\Blu Ray Rips\The.Bourne.Identity.2002.UHD.BluRay.2160p.DTS-X.7.1.HEVC.REMUX-FraMeSToR\The.Bourne.Identity.2002.UHD.mkv"
#     Codec       = 'faac'
#     Bitrate     = 3
#     AudioFrames = 500
#     RemuxStream = $true
#     OutputPath  = @{StereoPath = "M:\Blu Ray Rips\The.Bourne.Identity.2002.UHD.BluRay.2160p.DTS-X.7.1.HEVC.REMUX-FraMeSToR\The.Bourne.Identity_stereo.mkv"
#         Root                  = "M:\Blu Ray Rips\The.Bourne.Identity.2002.UHD.BluRay.2160p.DTS-X.7.1.HEVC.REMUX-FraMeSToR\"
#     }
# }

# Convert-ToStereo @params
