using namespace System.Collections

<#
    .SYNOPSIS
        Read and import configuration files
#>
function Import-Config {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [Generic.List[object]]$FFMpegExtra,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [hashtable]$EncoderExtra,

        [Parameter(Mandatory = $true)]
        [string]$Encoder
    )

    # Check for duplicate keys
    function Confirm-Keys ([hashtable]$Parameter, [hashtable]$Config, [string]$Type) {
        [array]$keyCheck = $Parameter.Keys.Where({ $_ -in $Config.Keys })
        if ($keyCheck) {
            $msg = "Duplicate options found in $Type config file and Parameter:`n`t" +
                   "$keyCheck`n" + "Parameter option(s) will be used in place of config"
            Write-Warning $msg
            $keyCheck.ForEach({ $Config.Remove($_) })
        }
    }

    try {
        # Read config file for additional options
        $config = Read-Config -Encoder $Encoder -Verbose:$setVerbose
    }
    catch {
        Write-Error "Failed to read config file(s): $($_.Exception.Message)"
        return $null, $null, $null
    }

    # Try to parse the config files
    try {
        # Add multi-valued ffmpeg config options to existing hash
        if ($config['FFMpegHash']) {
            if ($FFMpegExtra) {
                $index = $ffmpegExtra.FindIndex( {
                        $args[0] -is [hashtable]
                    } )

                if ($index -ne -1) {
                    # Catch error if duplicate keys are present
                    Confirm-Keys -Parameter $FFMpegExtra[$index] -Config $config['FFMpegHash'] -Type 'ffmpeg'
                    $FFMpegExtra[$index] += $config['FFMpegHash']
                }
                else { $FFMpegExtra.Add($config['FFMpegHash']) }
            }
            else {
                $FFMpegExtra = @()
                $FFMpegExtra.Add($config['FFMpegHash'])
            }
        }
    }
    catch {
        $e = $_.Exception.Message
        Write-Error "Failed to parse ffmpeg Argument settings from config file: $e"
    }

    try {
        # Add single valued ffmpeg config options
        if ($config['FFMpegArray']) {
            if ($FFMpegExtra) { $ffmpegExtra.AddRange($config['FFMpegArray']) }
            else {
                $FFMpegExtra = @()
                $FFMpegExtra.AddRange($config['FFMpegArray'])
            }
        }
    }
    catch {
        $e = $_.Exception.Message
        Write-Error "Failed to parse ffmpeg NoArgument config file: $e"
    }

    try {
        # Add encoder settings from config file
        if ($config['Encoder']) { 
            if ($EncoderExtra) {
                # Catch error if duplicate keys are present
                Confirm-Keys -Parameter $EncoderExtra -Config $config['Encoder'] -Type 'Encoder'
                $EncoderExtra += $config['Encoder']
            }
            else { $EncoderExtra = $config['Encoder'] }
        }
    }
    catch {
        $e = $_.Exception.Message
        Write-Error "Failed to parse encoder extra config file: $e"
    }

    return $EncoderExtra, $FFMpegExtra, $config['ScriptHash'], $config['TagHash'], $config['VMAFHash']
}
