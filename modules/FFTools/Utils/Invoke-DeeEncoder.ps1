Using namespace System.IO

<#
    .SYNOPSIS
        Invoke the Dolby Encoding Engine (DEE)
    .DESCRIPTION
        Provides an alternative option for encoding audio with Dolby codecs. Wrapper executable is invoked
        as a background job parallel to the primary script
    .PARAMETER Paths
        Paths and titles for input and output files
    .PARAMETER Codec
        Codec used for audio encoding
    .PARAMETER ChannelCount
        The number of channels in the output file (i.e. 8 for 7.1 audio)
    .PARAMETER Bitrate
        Output audio bitrate in kb/s
    .NOTES
        Requires the Dolby Encoding Engine executable. Wrapper executable only makes using dee easier
#>
function Invoke-DeeEncoder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        [Parameter(Mandatory = $true)]
        [string]$Codec,

        [Parameter(Mandatory = $true)]
        [int]$ChannelCount,

        [Parameter(Mandatory = $false)]
        [int]$Bitrate,

        [Parameter(Mandatory = $false)]
        [switch]$Stereo
    )

    $logPath = [Path]::Join(([FileInfo]$Paths.InputFile).DirectoryName, 'dee.log')
    $outputPath = ([FileInfo]$Paths.OutputFile).DirectoryName

    Write-Output "Preparing DEE encoder..." >$logPath
    Write-Verbose "Parameters:`n`n$([pscustomobject]$PSBoundParameters | Out-String)" 4>>$logPath

    if (!(Get-Command 'dee')) {
        Write-Warning "Could not find dee executable in PATH. Returning" 3>&1 >>$logPath
        return
    }
    # Set verbose for Invoke-mkvMerge because of scope change
    if ($PSBoundParameters['Verbose']) { $setVerbose = $true }

    $codecStr, $downmix = switch ($Codec) {
        { $_ -in 'dee_dd', 'dee_ac3' -and !$Stereo }    { 'dd', $null  }
        { $_ -in 'dee_dd', 'dee_ac3' -and $Stereo }     { 'dd', 2  }
        { $_ -in 'dee_ddp', 'dee_eac3' -and $Stereo }   { 'ddp', 2 }
        { $_ -in 'dee_ddp', 'dee_eac3' -and !$Stereo }  { 'ddp', $null }
        { $_ -in 'dee_ddp_51', 'dee_eac3_51' }          { 'ddp', 6 }
        'dee_thd'                                       { 'thd' }
    }

    $audioBase = ($Paths.InputFile.EndsWith('mkv')) ? ("$($Paths.Title)_audio.mka") : ("$($Paths.Title)_audio.m4a")
    $Paths.AudioPath = [Path]::Join(([FileInfo]$Paths.InputFile).DirectoryName, $audioBase)

    if (![File]::Exists($Paths.AudioPath)) {
        Write-Verbose "ThreadJob: Multiplexing audio for DEE...`n" 4>>$logPath

        $remuxPaths = @{
            Input    = $Paths.InputFile
            Output   = $Paths.AudioPath
            Title    = $Paths.Title
            Language = $Paths.Language
            LogPath  = $Paths.LogPath
        }
        if ((Get-Command 'mkvmerge')) {
            Write-Output "mkvmerge detected. Multiplexing audio stream..." >>$logPath
            Invoke-MkvMerge -Paths $remuxPaths -Mode 'extract' -Verbose:$setVerbose
        }
        else {
            Write-Output "Multiplexing audio stream with ffmpeg..." >>$logPath
            ffmpeg -i $Paths.InputFile -map 0:a:0 -c:a:0 copy -map -0:t? -map_chapters -1 $Paths.AudioPath
        }

        if ([File]::Exists($Paths.AudioPath) -and ([FileInfo]($Paths.AudioPath)).Length -lt 10) {
            Write-Output "There was an issue extracting the audio track for dee" >>$logPath
            return
        }
        Start-Sleep -Milliseconds 500
    }

    # Create the directory structure
    $tmpPath = [Path]::Join(([FileInfo]$Paths.InputFile).DirectoryName, 'dee_tmp')
    if (![Directory]::Exists($tmpPath)) {
        [Directory]::CreateDirectory($tmpPath) > $null
    }

    # Modify toml file with temporary path set to the input file directory
    $binRoot = [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, 'bin')
    $deePath = switch ($osInfo.OperatingSystem) {
        'Windows' { [Path]::Join($binRoot, 'windows\dee_wrapper\deew.exe') }
        'Linux'   { [Path]::Join($binRoot, 'linux/dee_wrapper/deew') }
        'Mac'     { [Path]::Join($binRoot, 'mac/dee_wrapper/deew')  }
    }
    
    if (!$deePath) {
        Write-Output "No compatible OS found. Exiting..." >>$logPath
        return
    }
    else {
        Write-Output "deew path: $deePath`n" >>$logPath
    }
    
    # Modify the toml file with tmp directory
    $deeToml = [Path]::Join($($deePath -replace 'deew.*', ''), 'config.toml')
    (Get-Content $deeToml -Raw) -replace 'temp_path.*', "temp_path = '$tmpPath'" | 
        Set-Content $deeToml

    Write-Verbose "Deew TOML contents:`n" 4>>$logPath
    Write-Verbose "$((Get-Content $deeToml).ForEach({"$_`n"}))`n" 4>>$logPath

    # Setup encoder array
    $deeArgs = @(
        '-i'
        $Paths.AudioPath
        '-o'
        $outputPath
        '-f'
        $codecStr
        if ($Bitrate) { 
            '-b'
            $Bitrate
        }
        if ($downmix) {
            '-dm'
            $downmix
        }
    )

    Write-Verbose "Dee Arguments:`n$($deeArgs | Out-String)" 4>>$logPath
    
    # Run the encoder
    try {
        if ($Stereo) {
            # Pipe 'y' to avoid confirmation prompt for stereo
            'y' | & $deePath $deeArgs 2>&1 >>$logPath
        }
        else {
            & $deePath $deeArgs 2>&1 >>$logPath
        }
    }
    catch {
        Write-Error "An exception occurred running deew: $($_.Exception.Message). Returning...`n" 2>>$logPath
        return
    }
   
    # Delete the temp directory
    if ($LASTEXITCODE) {
        Start-Sleep -Seconds 3
        Remove-Item $tmpPath -Recurse -Force
        # sometimes the dee_tmp folder just won't die
        if ([Directory]::Exists($tmpPath)) {
            [Directory]::Delete($tmpPath)
        }
    }
}

