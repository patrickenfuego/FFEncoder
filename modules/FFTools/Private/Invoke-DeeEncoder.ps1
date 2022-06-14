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
        [int]$Bitrate
    )

    if (!(Get-Command 'dee')) {
        Write-Warning "Could not find dee executable in PATH. Returning"
        return
    }

    $outputPath = Split-Path $Paths.OutputFile -Parent

    $codecStr = switch ($Codec) {
        { $_ -in 'dee_dd', 'dee_ac3' }     { 'dd'  }
        { $_ -in 'dee_ddp', 'dee_eac3' }   { 'ddp' }
        'dee_thd'                          { 'thd' }
    }

    $audioBase = ($Paths.InputFile.EndsWith('mkv')) ? ("$($Paths.Title)_audio.mka") : ("$($Paths.Title)_audio.m4a")
    $Paths.AudioPath = [Path]::Join($(Split-Path $Paths.InputFile -Parent), $audioBase)

    if (!(Test-Path $Paths.AudioPath -ErrorAction SilentlyContinue)) {
        Write-Host "Multiplexing audio..." @progressColors

        $remuxPaths = @{
            Input    = $Paths.InputFile
            Output   = $Paths.AudioPath
            Title    = $Paths.Title
            Language = $Paths.Language
        }
        if ((Get-Command 'mkvmerge')) {
            Invoke-MkvMerge -Paths $remuxPaths -Mode 'extract'
        }
        else {
            ffmpeg -i $Paths.InputFile -map 0:a:0 -c:a:0 copy -map -0:t? -map_chapters -1 $Paths.AudioPath
        }

        if ([File]::Exists($Paths.AudioPath) -and ([FileInfo]($Paths.AudioPath)).Length -lt 10) {
            Write-Host "There was an issue extracting the audio track for dee" @warnColors
            return
        }
        Start-Sleep -Milliseconds 750
    }

    # Create the directory structure
    $tmpPath = [Path]::Join($(Split-Path $Paths.InputFile -Parent), 'dee_tmp')
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
        return
    }
    
    $deeToml = [Path]::Join($($deePath -replace 'deew.*', ''), 'config.toml')
    (Get-Content $deeToml -Raw) -replace 'temp_path.*', "temp_path = '$tmpPath'" | 
        Set-Content $deeToml

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
    )
    # Run the encoder
    & $deePath $deeArgs

    # Delete the temp file
    if ($?) { 
        Start-Sleep -Seconds 2
        [Directory]::Delete($tmpPath)
        #Remove-Item $tmpPath -Force
    }
}

