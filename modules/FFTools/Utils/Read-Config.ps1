using namespace System.IO

<#
    .SYNOPSIS
        Parses FFEncoder .ini file
    .DESCRIPTION
        Users may add default values to the encoder.ini file if they do not
        wish to set them manually each run with the -EncoderExtra option.
        The values parsed from this file will be added to -EncoderExtra
        automatically.
    .PARAMETER Encoder
        User selected encoder
    .PARAMETER EncoderConfigFile
        Location of encoder configuration file. Default is ../../../config/encoder.ini
    .PARAMETER FFMpegConfigFile
        Location of ffmpeg configuration file. Default is ../../../config/ffmpeg.ini
#>
function Read-Config {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Encoder,

        [Parameter(Mandatory = $false)]
        [string]$EncoderConfigFile = 
            [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, 'config', 'encoder.ini'),

        [Parameter(Mandatory = $false)]
        [string]$FFMpegConfigFile = 
            [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, 'config', 'ffmpeg.ini')
    )

    $encoderHash = @{}
    $ffmpegHash = @{}
    $ffmpegArray = [System.Collections.Generic.List[string]]@()
    $skipEncoder, $skipFFMpeg = $false, $false

    if (![File]::Exists($EncoderConfigFile)) {
        $skipEncoder = $true
    }
    if (![File]::Exists($FFMpegConfigFile)) {
        Write-Host "Skipping ffmpeg config"
        $skipFFMpeg = $true
    }

    if ($skipEncoder -and $skipFFMpeg) {
        Write-Warning "Could not locate configuration file paths. Configurations will not be copied"
        return
    }
    
    if (!$skipEncoder) {
        $encoderINI = [File]::ReadAllLines($EncoderConfigFile)
        $start = $encoderINI.IndexOf("[$encoder]")
        foreach ($line in $encoderINI[($start + 1)..($encoderINI.Length - 1)]) {
            if ($line.StartsWith('[')) {
                break
            }
            elseif ($line -notlike '*=*') {
                continue
            }
            elseif ($line -and $line -notlike ';*') {
                $name, $value = $line.Split('=').Trim()
                $encoderHash[$name] = $value
            }
        }
    }
    if (!$skipFFMpeg) {
        $ffmpegINI = [File]::ReadAllLines($FFMpegConfigFile)
        $noArgs = $ffmpegINI.IndexOf('[NoArguments]')
        # Parse Arguments
        foreach ($line in $ffmpegINI[1..($noArgs - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -like '*=*') {
                $name, $value = ($line -split '=', 2).Trim()
                $ffmpegHash[$name] = $value
            }
        }
        # Parse NoArguments
        foreach ($line in $ffmpegINI[($noArgs + 1)..($ffmpegINI.Length - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -notlike '*=*') {
                $ffmpegArray.Add($line)
            }
        }
    }

    $returnHash = @{
        Encoder     = ($encoderHash.Count -gt 0) ? $encoderHash : $null
        FFMpegHash  = ($ffmpegHash.Count -gt 0) ? $ffmpegHash : $null
        FFMpegArray = ($ffmpegArray.Count -gt 0) ? $ffmpegArray : $null
    }

    Write-Verbose "Parsed config file contents:`n  $($returnHash | Out-String)"

    return $returnHash
}
