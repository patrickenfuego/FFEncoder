<#
    .SYNOPSIS
        Helper function which builds the audio argument arrays for ffmpeg based on user input
    .PARAMETER InputFile
        The source (input) file. This is used to determine the number of audio channels for lossy encoding
    .PARAMETER UserChoice
        Audio option selected before running the script. See documentation for all available options
    .PARAMETER Bitrate
        Bitrate for the selected audio stream in kb/s. Values 1-5 are reserved for libfdk's variable bitrate 
        (vbr) encoder
    .PARAMETER Stream
        References the different output streams if a second audio option is passed to the script
    .NOTES
        ffmpeg cannot decode Dolby Atmos streams, nor can they be identified using ffprobe. If you try and
        copy a Dolby Atmos track, the script will fail. 
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

        [Parameter(Mandatory = $false)]
        [int]$AudioFrames,

        [Parameter(Mandatory = $false)]
        [string]$TestStart,

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
        else {
            Write-Host "Bitrate per channel: ~ $bitsPerChannel`n"
        }
    }

    $stereoArgs = @("-filter:a:$Stream", 'pan=stereo|FL=0.5*FC+0.707*FL+0.707*BL+0.5*LFE|FR=0.5*FC+0.707*FR+0.707*BR+0.5*LFE')
    $noPrint = @('copy', 'c', 'copyall', 'ca', 'none', 'n', 'flac', 'f', 'dee_thd') + 0..12
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
    elseif ($UserChoice -in $dee['DeeArgs']) {
        $trackTitle['DeeTitle'] = $trackName
    }
    else {
        $trackTitle["AudioTitle$($Stream + 1)"] = $trackName
    }

    Write-Host "**** Audio Stream $($Stream + 1) ****" @emphasisColors

    # If dee has been used, set value to 0 to prevent stream mismatch
    if ($dee['DeeUsed']) { $Stream = 0 }

    $audioArgs = switch -Regex ($UserChoice) {
        "^c[opy]*$" {
            Write-Host "** COPY AUDIO SELECTED **" @progressColors
            Write-Host "Audio stream 0 will be copied`n"
            @('-map', '0:a:0', '-c:a:0', 'copy')
            break
        }
        "c[opy]*a[ll]*" {
            Write-Host "** COPY ALL AUDIO SELECTED **" @progressColors
            Write-Host "All audio streams will be copied`n"
            @('-map', '0:a', '-c:a', 'copy')
            break
        }
        "^aac$" {
            Write-Host "** AAC AUDIO SELECTED **" @progressColors
            if (!$Bitrate) { $Bitrate = $Stereo ? 128 : 512 }
            @('-map', '0:a:0', "-c:a:$Stream", 'aac', "-b:a:$Stream", "$Bitrate`k")
            break
        }
        "^dts$" {
            Write-Host "** DTS AUDIO SELECTED **" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-b:a', "$Bitrate`k") }
            $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
            if ($i) {
                $sChannels = Get-ChannelCount -ID $i
                Write-Host "Channel count: $sChannels`n"
                @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'dca', '-strict', -2) }
            break
        }
        "f[dk]*aac$" {
            Write-Host "** FDK AAC AUDIO SELECTED **" @progressColors
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
            Write-Host "** AAC_AT AUDIO SELECTED **" @progressColors
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
            Write-Host "**DOLBY ENCODING SUITE - TRUEHD AUDIO SELECTED**" @progressColors
            Write-Host "Input audio has $channels channels" 
            $dee['DeeUsed'] = $true
            'dee_thd'
            break
        }
        { @('dee_ddp', 'dee_eac3') -contains $_ } {
            Write-Host "**DOLBY ENCODING SUITE - DOLBY DIGITAL PLUS AUDIO SELECTED**" @progressColors
            if (!$Bitrate) {
                $deeDefault = switch ($channels) {
                    8       { 1024 }
                    6       { 768 }
                    default { 0 }
                }
                $Bitrate = $deeDefault
            }
            $dee['DeeUsed'] = $true
            'dee_ddp'
            break
        }
        { @('dee_ddp_51', 'dee_eac3_51') -contains $_ } {
            Write-Host "**DOLBY ENCODING SUITE - DOLBY DIGITAL PLUS AUDIO SELECTED**" @progressColors
            if (!$Bitrate) {
                $deeDefault = 768
                $Bitrate = $deeDefault
            }
            $channels = 6
            $dee['DeeUsed'] = $true
            'dee_ddp_51'
            break
        }
        { @('dee_dd', 'dee_ac3') -contains $_ } {
            Write-Host "**DOLBY ENCODING SUITE - DOLBY DIGITAL AUDIO SELECTED**" @progressColors
            $dee['DeeUsed'] = $true
            if (!$Bitrate) {
                $deeDefault = switch ($channels) {
                    6       { 640 }
                    8       { 640 }
                    default { 0   }
                }
                $Bitrate = $deeDefault
            }
            'dee_dd'
            break
        }
        { @('eac3', 'ddp') -contains $_ } {
            Write-Host "** DOLBY DIGITAL PLUS (E-AC3) AUDIO SELECTED **" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'eac3', '-b:a', "$Bitrate`k") }
            $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
            if ($i) {
                $sChannels = Get-ChannelCount -ID $i
                Write-Host "Channel count: $sChannels`n"
                @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'eac3') }
            break
        }
        { @('ac3', 'dd') -contains $_ } {
            Write-Host "** DOLBY DIGITAL (AC3) AUDIO SELECTED **" @progressColors
            if ($Bitrate) { @('-map', '0:a:0', "-c:a:$Stream", 'ac3', '-b:a', "$Bitrate`k") }
            $i = Get-AudioStream -Codec $UserChoice -InputFile $Paths.InputFile
            if ($i) {
                $sChannels = Get-ChannelCount -ID $i
                Write-Host "Channel count: $sChannels`n"
                @('-map', "0:a:$i", "-c:a:$Stream", 'copy')
            }
            else { @('-map', '0:a:0', "-c:a:$Stream", 'ac3', "-b:a:$Stream", '640k') }
            break
        }
        { 0..12 -contains $_ } { 
            Write-Host "AUDIO STREAM $UserChoice SELECTED" @progressColors
            Write-Host "Stream $UserChoice from input will be mapped to stream $Stream in the output"
            @('-map', "0:a:$UserChoice`?", "-c:a:$Stream", 'copy')
            break
        }
        "^f[lac]*" {
            Write-Host "** FLAC AUDIO SELECTED **" @progressColors
            @('-map', '0:a:0', "-c:a:$Stream", 'flac')
            break
        }
        "^n[one]?" {
            Write-Host "** NO AUDIO SELECTED **" @progressColors
            Write-Host "All audio streams will be excluded from the output file`n"
            $null
            break
        }
        default { 
            Write-Warning "No matching audio preference was found. Audio will not be copied"
            $null 
        }
    }

    # If not stream copying, append track label
    if ($audioArgs -and ($audioArgs[-1] -ne 'copy') -and ($audioArgs -notin $dee['DeeArgs'])) {
        if ($dee['DeeUsed']) { $ident = 2 }
        $title = $Stereo ? ("title=`"$($TrackTitle['StereoTitle'])`"") : ("title=`"$($TrackTitle["AudioTitle$($ident)"])`"")
        $audioArgs = $audioArgs + @("-metadata:s:a:$Stream", $title)
    }

    # Print relevant info to console based on user choice
    if ($UserChoice -notin $noPrint) { 
        if ('dts', 'ac3', 'dd', 'eac3' -contains $UserChoice -and !$i) { 
            $bitsPerChannel = "$($Bitrate / 6) kb/s"
        }
        elseif ($deeDefault) {
            if ($UserChoice -notlike 'dee_thd') {
                $bitStr = [math]::Round($deeDefault / $channels, 2)
                $bitsPerChannel = "$bitStr kb/s"
            }
            else {
                $bitsPerChannel = 0
            }
        }
        else {
            $bitsPerChannel = "$($Bitrate / $channels) kb/s"
        }

        Write-BitrateInfo $channels $bitsPerChannel
    }
    
    <#
        BACKGROUND JOBS

        Dee
        Stereo

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
        Start-ThreadJob -Name 'Dee Encoder' -StreamingHost $Host -ArgumentList $deeParams, $PSModuleRoot, $setVerbose -ScriptBlock {
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
    elseif ($RemuxStream -and $Stereo) {
        Write-Verbose "Preparing audio..."
        # Set audio paths based on container
        if ($Paths.InputFile.EndsWith('mkv')) {
            $Paths.AudioPath = [System.IO.Path]::Join($(Split-Path $Paths.InputFile -Parent), "$($Paths.Title)_audio.mka")
        }
        elseif ($Paths.InputFile.EndsWith('mp4')) {
            $Paths.AudioPath = [System.IO.Path]::Join($(Split-Path $Paths.InputFile -Parent), "$($Paths.Title)_audio.m4a")
        }
        else {
            Write-Warning "Cannot determine container audio format for conversion to stereo"
            return $null
        }

        Write-Verbose "Remuxed Audio path for jobs: $($Paths.AudioPath)"

        # If dee encoder is running, wait for audio multiplex to finish
        if ((Get-Job -Name 'Dee Encoder' -ErrorAction SilentlyContinue) -and
            (![System.IO.File]::Exists($Paths.AudioPath))) {

            $method = 0
            Start-Sleep -Seconds 160
        }
        elseif ([System.IO.File]::Exists($Paths.AudioPath)) {
            $method = 0
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

        Write-Host "Spawning stereo encoder in a separate process...`n" @progressColors
    
        # Modify and combine arrays for background job
        $stereoArgs[0] = '-af'
        $index = [array]::IndexOf($audioArgs, "-c:a:$Stream")
        $audioArgs[$index] = '-c:a:0'
        $fullArgs = $audioArgs + $stereoArgs

        Write-Verbose "Stereo fullArgs are: $fullArgs"
        
        # Start background job to encode stereo. Mux out audio if needed
        Start-ThreadJob -Name 'Stereo Encoder' -ScriptBlock {
            $tPaths = $Using:Paths
            # Source function
            Import-Module $Using:PSModuleRoot -Function Invoke-MkvMerge
            # Extract the stereo track if needed
            switch ($Using:method) {
                0 { Write-Verbose "External audio file already exists. Skipping creation" }
                1 { Invoke-MkvMerge -Paths $Using:remuxPaths -Mode 'extract' }
                2 { 
                    ffmpeg -hide_banner -i $tPaths.InputFile -loglevel error -map 0:a:0 -c:a copy `
                        -map -0:t? -map_chapters -1 -vn -sn $tPaths.AudioPath
                }
                default { Write-Verbose "Could not determine extraction method"; exit 17 }
            }
            
            # Encode the stereo track
            ffmpeg -i $tPaths.AudioPath $Using:fullArgs -y $tPaths.StereoPath

        } | Out-Null

        return $null
    }
    else { return $audioArgs }
}
