<#
    .SYNOPSIS
        Helper function which builds the audio argument arrays for ffmpeg based on user input
    .PARAMETER InputFile
        The source (input) file. This is used to determine the number of audio channels for lossy encoding
    .PARAMETER UserChoice
        Audio option selected before running the script. See documentation for all available options
    .PARAMETER Bitrate
        Bitrate for the selected audio stream in kb/s. Values 1-5 are reserved for FDK AAC's variable bitrate 
        (vbr) encoder
    .PARAMETER Stream
        References the different output streams if a second audio option is passed to the script
    .PARAMETER Stereo
        Switch to enable stereo downmixing
    .PARAMETER RemuxStream
        Switch to enable external (background) audio encoding when stream copying is used
    .PARAMETER Paths
        File paths and names used throughout the module
#>
function Set-AudioPreference {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$UserChoice,

        [Parameter(Mandatory = $false, Position = 1)]
        [int]$Bitrate,

        [Parameter(Mandatory = $false, Position = 2)]
        [int]$Stream,

        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$Stereo,

        [Parameter(Mandatory = $true)]
        [bool]$RemuxStream,

        [Parameter(Mandatory = $true)]
        [hashtable]$Paths
    )

    <#
        Private Inner Functions
    #>

    # Private inner function that returns the number of channels for the primary audio stream
    function Get-ChannelCount ([int]$ID) {  
        [int]$numOfChannels = ffprobe -i $Paths.InputFile -show_entries stream=channels `
            -select_streams a:$ID -of compact=p=0:nk=1 -v 0
        return $numOfChannels
    }
    # Private inner function that prints audio data when the -Bitrate parameter is used
    function Write-BitrateInfo ($channels, $bitsPerChannel) {
        Write-Host "Audio stream 0 has $channels channels. " -NoNewline
        if (@("eac3", "dts", "ac3", "dd") -contains $UserChoice) {
            Write-Host "7.1 channel layout will be downmixed to 5.1" @warnColors
        }
        elseif ($bitsPerChannel -like '*0 kb/s*') {
            Write-Host "Bits per channel unknown (no bitrate specified or VBR selected)`n"
        }
        elseif ($bitsPerChannel -eq 'variable') {
            Write-Host "The selected option uses variable bitrate encoding"
        }
        else {
            Write-Host "Bitrate per channel: ~ $bitsPerChannel`n"
        }
    }

    $stereoArgs = @("-filter:a:$Stream", 'pan=stereo|FL=0.5*FC+0.707*FL+0.707*BL+0.5*LFE|FR=0.5*FC+0.707*FR+0.707*BR+0.5*LFE')
    $noPrint = @('copy', 'c', 'copyall', 'ca', 'none', 'n') + 0..12
    $dArgs = @('dee_ddp', 'dee_eac3', 'eac3', 'ddp', 'dee_dd', 'dee_ac3', 'ac3', 'dd')
    $split = $dArgs.Length / 2

     # Set the track title
     $channels = Get-ChannelCount -ID 0
     $channelStr = switch ($channels) {
         1   { '1.0' }
         2   { '2.0' }
         6   { '5.1' }
         7   { '6.1' }
         8   { '7.1' }
     }

     if ($Stereo) { $channelStr = '2.0' }
    
    # Set the track title based on user input and channel count
    $trackName = 

    if ($UserChoice -in $dArgs[0..$($split - 1)])                { "E-AC3 $channelStr" }
    elseif ($UserChoice -in 'dee_ddp_51', 'dee_eac3_51')         { "E-AC3 5.1" }
    elseif ($UserChoice -in $dArgs[$split..($dArgs.Length-1)])   { "AC3 $channelStr" }
    elseif ($Userchoice -like '*aac*')                           { "AAC $channelStr" }
    elseif ($Userchoice -like 'dts')                             { "DTS $channelStr" }
    elseif ($Userchoice -like 'f*')                              { "FLAC $channelStr" }
    elseif ($Userchoice -like '*thd*')                           { "TrueHD $channelStr" }
    else                                                         { '' }

    if ($Stereo -and $RemuxStream) { 
        $trackTitle['StereoTitle'] = $trackName
    }
    elseif ($RemuxStream) {
        $trackTitle['ExternalTitle'] = $trackName
    }
    elseif ($UserChoice -in $dee['DeeArgs']) {
        $trackTitle['DeeTitle'] = $trackName
    }
    else {
        $trackTitle["AudioTitle$($Stream + 1)"] = $trackName
    }

    Write-Host "$("`u{2726}" * 3) Audio Stream $($Stream + 1) $("`u{2726}" * 3)" @emphasisColors

    # If dee has been used, set value to 0 to prevent stream mismatch
    if ($dee['DeeUsed']) { $Stream = 0 }

    $audioArgs = switch -Regex ($UserChoice) {
        "^c[opy]*$" {
            Write-Host "$("`u{25c7}" * 2) COPY AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            Write-Host "Audio stream 0 will be copied`n"
            @('-map', '0:a:0', '-c:a:0', 'copy')
            break
        }
        "c[opy]*a[ll]*" {
            Write-Host "$("`u{25c7}" * 2) COPY ALL AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            Write-Host "All audio streams will be copied`n"
            @('-map', '0:a', '-c:a', 'copy')
            break
        }
        "^aac$" {
            Write-Host "$("`u{25c7}" * 2) AAC AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if (!$Bitrate) { $Bitrate = $Stereo ? 128 : 512 }
            @('-map', '0:a:0', "-c:a:$Stream", 'aac', '-b:a', "$Bitrate`k")
            break
        }
        "^dts$" {
            Write-Host "$("`u{25c7}" * 2) DTS AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-b:a', "$Bitrate`k") }
            else {
                $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
                if ($i) {
                    $sChannels = Get-ChannelCount -ID $i
                    Write-Host "Channel count: $sChannels`n"
                    @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
                }
                else { @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-strict', -2) }
            }
            break
        }
        "f[dk]*aac$" {
            Write-Host "$("`u{25c7}" * 2) FDK AAC AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if (!$Bitrate) { 
                Write-Host "No bitrate specified. Using VBR 3" @warnColors
                @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-vbr', 3)
            }
            elseif (1..5 -contains $Bitrate) { 
                Write-Host "VBR selected. Quality value: $Bitrate"
                @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-vbr', $Bitrate)
            }
            else {
                Write-Host "CBR Selected. Bitrate: $Bitrate`k"
                @('-map', '0:a:0', "-c:a:$Stream", 'libfdk_aac', '-b:a', "$Bitrate`k")
            }
            break
        }
        '^aac_at$' {
            Write-Host "$("`u{25c7}" * 2) AAC_AT AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if (!$Bitrate) { 
                Write-Host "No mode specified. Using auto VBR" @warnColors
                @('-map', '0:a:0', "-c:a:$Stream", 'aac_at')
            }
            elseif (-1..3 -contains $Bitrate) { 
                Write-Host "VBR selected. Quality value: $Bitrate"
                @('-map', '0:a:0', "-c:a:$Stream", 'aac_at', '-aac_at_mode', $Bitrate)
            }
            else {
                Write-Host "Invalid mode selection for aac_at. Using auto VBR" @warnColors
                @('-map', '0:a:0', "-c:a:$Stream", 'aac_at')
            }
            break
        }
        '^dee_thd$' {
            Write-Host "$("`u{25c7}" * 2) DOLBY ENCODING SUITE - TRUEHD AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            Write-Host "Input audio has $channels channels" 
            $dee['DeeUsed'] = $true
            'dee_thd'
            break
        }
        { @('dee_ddp', 'dee_eac3') -contains $_ } {
            Write-Host "$("`u{25c7}" * 2) DOLBY ENCODING SUITE - DOLBY DIGITAL PLUS AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if (!$Bitrate) {
                $deeDefault = switch ($channels) {
                    8       { 960 }
                    6       { 640 }
                    default { 768 }
                }
                $Bitrate = $deeDefault
            }
            $dee['DeeUsed'] = $true
            'dee_ddp'
            break
        }
        { @('dee_ddp_51', 'dee_eac3_51') -contains $_ } {
            Write-Host "$("`u{25c7}" * 2) DOLBY ENCODING SUITE - DOLBY DIGITAL PLUS AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            $dee['DeeUsed'] = $true
            if (!$Bitrate) {
                $deeDefault = 640
                $Bitrate = $deeDefault
            }
            $channels = 6
            'dee_ddp_51'
            break
        }
        { @('dee_dd', 'dee_ac3') -contains $_ } {
            Write-Host "$("`u{25c7}" * 2) DOLBY ENCODING SUITE - DOLBY DIGITAL AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            $dee['DeeUsed'] = $true
            if (!$Bitrate) {
                $deeDefault = switch ($channels) {
                    6       { 640 }
                    8       { 960 }
                    default { 640 }
                }
                $Bitrate = $deeDefault
            }
            'dee_dd'
            break
        }
        { @('eac3', 'ddp') -contains $_ } {
            Write-Host "$("`u{25c7}" * 2) DOLBY DIGITAL PLUS (E-AC3) AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'eac3', '-b:a', "$Bitrate`k") }
            else {
                $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
                if ($i) {
                    $sChannels = Get-ChannelCount -ID $i
                    Write-Host "Channel count: $sChannels`n"
                    @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
                }
                else { @('-map', '0:a:0', "-c:a:$Stream", 'eac3', '-b:a', '640k') }
            }
            break
        }
        { @('ac3', 'dd') -contains $_ } {
            Write-Host "$("`u{25c7}" * 2) DOLBY DIGITAL (AC3) AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'eac3', '-b:a', "$Bitrate`k") }
            else {
                $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
                if ($i) {
                    $sChannels = Get-ChannelCount -ID $i
                    Write-Host "Channel count: $sChannels`n"
                    @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
                }
                else { @('-map', '0:a:0', "-c:a:$Stream", 'ac3', '-b:a', '640k') }
            }
            break
        }
        { 0..12 -contains $_ } { 
            Write-Host "AUDIO STREAM $UserChoice SELECTED" @progressColors
            Write-Host "Stream $UserChoice from input will be mapped to stream $Stream in the output"
            @('-map', "0:a:$UserChoice`?", "-c:a:$Stream", 'copy')
            break
        }
        "^f[lac]*" {
            Write-Host "$("`u{25c7}" * 2) FLAC AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            @('-map', '0:a:0', "-c:a:$Stream", 'flac')
            break
        }
        "^n[one]?" {
            Write-Host "$("`u{25c7}" * 2) NO AUDIO SELECTED $("`u{25c7}" * 2)" @progressColors
            Write-Host "No audio streams will be included in the output file`n"
            $null
            break
        }
        default { 
            Write-Warning "No matching audio preference was found. Audio will not be copied"
            $null 
        }
    }

    # If not stream copying, append track label
    if ($audioArgs -and ($audioArgs[-1] -ne 'copy') -and ($audioArgs -notin $dee['DeeArgs']) -and !$RemuxStream) {
        if ($dee['DeeUsed']) { $ident = 2 }
        $title = $Stereo ? ("title=`"$($TrackTitle['StereoTitle'])`"") : ("title=`"$($TrackTitle["AudioTitle$($ident)"])`"")
        $audioArgs = $audioArgs + @("-metadata:s:a:$Stream", $title)
    }

    # Print relevant info to console based on user choice
    if ($UserChoice -notin $noPrint) { 
        if ('dts', 'ac3', 'dd', 'eac3' -contains $UserChoice -and !$i) { 
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
        }
        elseif ($UserChoice -in $dee['DeeArgs']) {
            if ($UserChoice -notlike 'dee_thd') {
                $bitStr = [math]::Round($Bitrate / $channels, 2)
                $bitsPerChannel = "$bitStr kb/s"
            }
            else {
                $bitsPerChannel = 'variable'
            }
        }
        elseif ($UserChoice -in 'f', 'flac', 'fdkaac', 'faac') {
            $bitsPerChannel = 'variable'
        }
        else {
            $bitsPerChannel = "$($Bitrate / $channels) kb/s"
        }

        Write-BitrateInfo $channels $bitsPerChannel
    }
    
    <#
        BACKGROUND JOBS

        Dee
        External audio (if stream copy is used)

        TODO: Cleanup and simplification
    #>

    # Start a background job to run Dolby Encoder if selected
    if ($UserChoice -like '*dee*') {
        Write-Verbose "DEE - Audio bitrate is: $Bitrate"
        Write-Host "Spawning dee encoder in a separate process`n" @emphasisColors
        # Create hash of dee params to marshall across process line
        $deeParams = @{
            Paths        = $Paths
            Codec        = $audioArgs
            ChannelCount = $channels
            Bitrate      = $Bitrate
            Stereo       = $Stereo
        }

        $threadArgs = @($deeParams, $PSModuleRoot, $setVerbose)
        Start-ThreadJob -Name 'Dee Encoder' -StreamingHost $Host -ArgumentList $threadArgs -ScriptBlock {
            param ($DeeParams, $Module, $Verbose)

            # Source functions & variable
            Import-Module $Module -Function Invoke-DeeEncoder, Invoke-MkvMerge -Variable osInfo

            $Global:osInfo = $osInfo
            Invoke-DeeEncoder @DeeParams -Verbose:$Verbose
        } | Out-Null

        return $null
    }
    elseif (!$RemuxStream -and $Stereo) {
        return $audioArgs + $stereoArgs
    }
    elseif ($RemuxStream) {
        # Set audio paths based on container
        if ($Paths.InputFile.EndsWith('mkv')) {
            $Paths.AudioPath = [System.IO.Path]::Join($(Split-Path $Paths.InputFile -Parent), "$($Paths.Title)_audio.mka")
        }
        elseif ($Paths.InputFile.EndsWith('mp4')) {
            $Paths.AudioPath = [System.IO.Path]::Join($(Split-Path $Paths.InputFile -Parent), "$($Paths.Title)_audio.m4a")
        }
        else {
            Write-Warning "Could not determine container format for background encoding. Encode the audio manually"
            return $null
        }

        # If dee encoder is running, wait for audio multiplex to finish
        if ((Get-Job -Name 'Dee Encoder' -ErrorAction SilentlyContinue) -and
            (![System.IO.File]::Exists($Paths.AudioPath))) {
            $method = 0
            Start-Sleep -Seconds 160
        }
        elseif ([System.IO.File]::Exists($Paths.AudioPath)) {
            # Delete empty file if it exists
            if ((Get-Item $Paths.AudioPath).Length -eq 0) {
                Write-Verbose "Empty audio file found. Deleting..."
                [System.IO.File]::Delete($Paths.AudioPath)
                if ((Get-Command 'mkvmerge') -and $Paths.InputFile.EndsWith('mkv')) {
                    $method = 1
                }
                elseif ($Paths.InputFile.EndsWith('mkv') -xor $Paths.InputFile.EndsWith('mp4')) {
                    $method = 2
                }
            }
            else { $method = 0 }
        }
        elseif ((Get-Command 'mkvmerge') -and $Paths.InputFile.EndsWith('mkv')) {
            $method = 1

            $remuxPaths = @{
                Input    = $Paths.InputFile
                Output   = $Paths.AudioPath
                Language = $Paths.Language
                LogPath  = $Paths.LogPath
            }
        }
        elseif ($Paths.InputFile.EndsWith('mkv') -xor $Paths.InputFile.EndsWith('mp4')) {
            $method = 2
        }
        else {
            Write-Warning "An error occurred while extracting the audio stream"
            return $null
        }

        Write-Host "Stream copy detected: Spawning audio encoder in a separate thread...`n" @progressColors
    
        # Modify and combine arrays for background job
        #$stereoArgs[0] = '-af'
        $index = [array]::IndexOf($audioArgs, "-c:a:$Stream")
        $audioArgs[$index] = '-c:a:0'
        #$fullArgs = $audioArgs + $stereoArgs

        if ($Stereo) {
            $stereoArgs[0] = '-af'
            $audioArgs = $audioArgs + $stereoArgs
            $title = $trackTitle['StereoTitle']
        }
        else {
            $title = $trackTitle['ExternalTitle']
        }

        Write-Verbose "Background audio arguments:`n  $audioArgs`n"
        
        # Start background job to encode stereo. Mux out audio if needed
        Start-ThreadJob -Name 'Audio Encoder' -StreamingHost $Host -ScriptBlock {
            $tPaths = $Using:Paths
            # Source function
            Import-Module $Using:PSModuleRoot -Function Invoke-MkvMerge -Variable warnColors
            # Extract the stereo track if needed
            switch ($Using:method) {
                0 { Write-Host "External audio file already exists. Skipping creation`n" @warnColors }
                1 { Invoke-MkvMerge -Paths $Using:remuxPaths -Mode 'extract' -Verbose:$Using:setVerbose }
                2 { 
                    ffmpeg -hide_banner -i $tPaths.InputFile -loglevel error -map 0:a:0 -c:a copy `
                        -map -0:t? -map_chapters -1 -vn -sn $tPaths.AudioPath
                }
                default {
                    Write-Host "Could not determine audio extraction method. Exiting background job" @warnColors
                    exit 17 
                }
            }
            
            # Encode the audio track
            ffmpeg -hide_banner -i $tPaths.AudioPath -metadata:s:a:0 "title=`"$Using:title`"" $Using:audioArgs -y `
                $tPaths.StereoPath 2>$audioDebugLog

        } | Out-Null

        return $null
    }
    else { return $audioArgs }
}
