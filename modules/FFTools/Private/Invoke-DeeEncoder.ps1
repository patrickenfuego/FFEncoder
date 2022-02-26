<#
    .SYNOPSIS
        Setup scripting and execution of the Dolby Encoding Engine
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
        Write-Host "Could not find dee executable in PATH. Returning" @warnColors
        return
    }

    $outputPath = Split-Path $Paths.OutputFile -Parent

    $codecStr = switch ($Codec) {
        { $_ -in 'dee_dd', 'dee_ac3' }     { 'dd'  }
        { $_ -in 'dee_ddp', 'dee_eac3' }   { 'ddp' }
        'dee_thd'                          { 'thd' }
    }

    # Mux out audio if not already present
    if ($Paths.InputFile.EndsWith('mkv')) { 
        $Paths.AudioPath = Join-Path (Split-Path $Paths.InputFile -Parent) -ChildPath "$($Paths.Title)_audio.mka"
    }
    elseif ($Paths.InputFile.EndsWith('mp4')) {
        $Paths.AudioPath = Join-Path (Split-Path $Paths.InputFile -Parent) -ChildPath "$($Paths.Title)_audio.m4a"
    }

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

        if ((Test-Path $Paths.AudioPath) -and (Get-Item $Paths.AudioPath).Length -lt 10) {
            Write-Host "There was an issue extracting the audio" @warnColors
        }
        Start-Sleep -Milliseconds 750
    }

    # Create the directory structure
    $tmpPath = Join-Path (Split-Path $Paths.InputFile -Parent) -ChildPath 'dee_tmp'
    if (![System.IO.Directory]::Exists($tmpPath)) {
        [System.IO.Directory]::CreateDirectory($tmpPath) > $null
    }

    # Modify toml file with temporary path set to the input file directory
    $deeRoot = Join-Path (Get-Item $PSScriptRoot).Parent.Parent.Parent -ChildPath 'util_scripts\deew'
    $deeScript = Join-Path $deeRoot -ChildPath 'deew.py'
    $deeToml = Join-Path $deeRoot -ChildPath 'config.toml'
    (Get-Content $deeToml -Raw) -replace 'temp_path.*', "temp_path = '$tmpPath'" | 
        Set-Content $deeToml
    
    # Verify Python requirements and install missing packages if necessary
    $reqPkgs = @('rich', 'toml', 'xmltodict')
    $installedPkgs = pip list --format json | ConvertFrom-Json | Select-Object -ExpandProperty Name
    $diff = [System.Linq.Enumerable]::Except([string[]] $reqPkgs, [string[]] $installedPkgs)
    if (![System.Linq.Enumerable]::Any($diff)) { Write-Verbose "All python packages installed" }
    else {
        Write-Host "Installing python dependencies..." @progressColors
        try {
            $pkgs = $diff -join ' ' && pip install $pkgs
        }
        catch {
            $msg = "An error occurred installing python dependencies for dee. Exception:`n  $($_.Exception.Message)`n" +
                   "Manually install the required packages from requirements.txt"
            Write-Host $msg @errColors
            exit -1
        }
    }

    # Setup encoder array
    $deeArgs = @(
        $deeScript
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
    python $deeArgs

    # Delete the temp file
    if ($?) { 
        Start-Sleep -Seconds 5
        Remove-Item $tmpPath -Force
    }
}

