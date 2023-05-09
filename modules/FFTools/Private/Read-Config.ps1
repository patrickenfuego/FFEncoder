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
    .PARAMETER FFMpegConfigFile
        Location of script configuration file. Default is ../../../config/script.ini
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
            [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, 'config', 'ffmpeg.ini'),

        [Parameter(Mandatory = $false)]
        [string]$ScriptConfigFile = 
            [Path]::Join((Get-Item $PSScriptRoot).Parent.Parent.Parent, 'config', 'script.ini')
    )

    # Internal helper function to write warnings about invalid keys
    function Write-KeyWarning([string[]]$ValidKeys, [string]$Type, [string]$KeyName) {
        $keys = $ValidKeys -join ', '
        Write-Host "`nParse Config: '$KeyName' is not a valid configuration option for [$Type]. Options:`n`t$keys" @errColors
    }

    $encoderHash = @{}
    $ffmpegHash = @{}
    $switchOptHash = @{}
    $tagHash = @{}
    $vmafHash = @{}
    $ffmpegArray = [System.Collections.Generic.List[string]]@()
    $skipEncoder = $skipFFMpeg = $skipScript = $false
    # Acceptable keys for the script config
    $scriptKeys = @('RemoveFiles', 'DisableProgress', 'ExitOnError', 'SkipHDR10Plus', 
                    'SkipDolbyVision', 'GenerateReport', 'HDR10PlusSkipReorder')
    $tagKeys = @('Path', 'APIKey', 'Properties', 'SkipProperties', 'Title', 'Year',
                 'NoMux', 'AllowClobber')
    $vmafKeys = @('EnableSSIM', 'EnablePSNR', 'LogFormat', 'VMAFResizeKernel')

    if (![File]::Exists($EncoderConfigFile)) {
        $skipEncoder = $true
    }
    if (![File]::Exists($FFMpegConfigFile)) {
        Write-Warning "Skipping ffmpeg config...file does not exist"
        $skipFFMpeg = $true
    }
    if (![File]::Exists($ScriptConfigFile)) {
        Write-Warning "Skipping script config...file does not exist"
        $skipScript = $true
    }

    if ($skipEncoder -and $skipFFMpeg -and $skipScript) {
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
        # Parse [Arguments]
        foreach ($line in $ffmpegINI[1..($noArgs - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -like '*=*') {
                $name, $value = ($line -split '=', 2).Trim()
                # Append leading dash if not present
                if ($name -notlike '-*') { $name = "-$name" }
                $ffmpegHash[$name] = $value
            }
        }
        # Parse [NoArguments]
        foreach ($line in $ffmpegINI[($noArgs + 1)..($ffmpegINI.Length - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -notlike '*=*') {
                # Append leading dash if not present
                $value = ($line -notlike '-*') ? "-$line" : $line
                $ffmpegArray.Add($value)
            }
        }
    }
    if (!$skipScript) {
        $scriptINI = [File]::ReadAllLines($ScriptConfigFile)
        $tagGen = $scriptINI.IndexOf('[MKVTagGenerator]')
        $vmaf = $scriptINI.IndexOf('[VMAF]')
        # Parse [Script] options
        foreach ($line in $scriptINI[1..($tagGen - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -like '*=*') {
                $name, $value = ($line -split '=', 2).Trim()
                if ($name -in $scriptKeys) {
                    try {
                        $switchOptHash[$name] = [Convert]::ToBoolean($value)
                    }
                    catch {
                        Write-Host "`nParse Config: Expected Boolean value for '$name'. Received '$value'" @errColors
                        $switchOptHash[$name] = $false
                    }
                }
                else {
                    Write-KeyWarning -ValidKeys $scriptKeys -Type 'SwitchOptions' -KeyName $name
                }
            }
        }
        # Parse [MKVTagGenerator] options
        foreach ($line in $scriptINI[($tagGen + 1)..($vmaf - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -like '*=*') {
                # Skip unset values
                if ($line -like '*None') { continue }
                $name, $value = ($line -split '=', 2).Trim()
                if ($name -in $tagKeys) {
                    if ($name -in 'NoMux', 'AllowClobber') {
                        try {
                            $tagHash[$name] = [Convert]::ToBoolean($value)
                        }
                        catch {
                            Write-Host "`nParse Config: Expected Boolean value for '$name'. Received '$value'" @errColors
                            $tagHash[$name] = $false
                        }
                    }
                    elseif ($name -in 'Properties', 'SkipProperties') {
                        $value = ($value -split ',').Trim()
                        $tagHash[$name] = $value
                    }
                    else { $tagHash[$name] = $value }
                }
                else {
                    Write-KeyWarning -ValidKeys $tagKeys -Type 'MKVTagGenerator' -KeyName $name
                }
            }
        }
        # Parse [VMAF] options
        foreach ($line in $scriptINI[($vmaf + 1)..($scriptINI.Length - 1)]) {
            if ($line -and $line -notlike ';*' -and $line -like '*=*') {
                $name, $value = ($line -split '=', 2).Trim()
                if ($name -in $vmafKeys) {
                    if ($name -in 'EnableSSIM', 'EnablePSNR') {
                        try {
                            $vmafHash[$name] = [Convert]::ToBoolean($value)
                        }
                        catch {
                            Write-Host "`nParse Config: Expected Boolean value for '$name'. Received '$value'" @errColors
                            $vmafHash[$name] = $false
                        }
                    }
                    else {
                        $vmafHash[$name] = $value
                    }
                }
                else {
                    Write-KeyWarning -ValidKeys $vmafKeys -Type 'VMAF' -KeyName $name
                }
            }
        }
    }

    $returnHash = @{
        Encoder     = ($encoderHash.Count -gt 0)   ? $encoderHash   : $null
        FFMpegHash  = ($ffmpegHash.Count -gt 0)    ? $ffmpegHash    : $null
        ScriptHash  = ($switchOptHash.Count -gt 0) ? $switchOptHash : $null
        FFMpegArray = ($ffmpegArray.Count -gt 0)   ? $ffmpegArray   : $null
        TagHash     = ($tagHash.Count -gt 0)       ? $tagHash       : $null
        VMAFHash    = ($vmafHash.Count -gt 0)      ? $vmafHash      : $null
    }

    Write-Verbose "`n-------------------- Configuration File Contents --------------------`n"
    Write-Verbose "Parsed Encoder Hash: $($encoderHash | Out-String)"
    Write-Verbose "Parsed FFMpeg Argument Hash: $($ffmpegHash | Out-String)"
    Write-Verbose "Parsed FFMpeg NoArgument Array: $ffmpegArray"
    Write-Verbose "Parsed Tag Hash: $($tagHash | Out-String)"
    Write-Verbose "Parsed Script Switch Option Hash: $($switchOptHash | Out-String)"
    Write-Verbose "Parsed VMAF Hash: $($vmafHash | Out-String)"

    return $returnHash
}
