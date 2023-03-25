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
        [hashtable]$EncoderExtra
    )

    # Try to parse the config files
    try {
        # Read config file for additional options
        $config = Read-Config -Encoder $Encoder

        # Add multi-valued ffmpeg config options to existing hash
        if ($config['FFMpegHash']) {
            if ($FFMpegExtra) {
                $index = $ffmpegExtra.FindIndex( {
                    $args[0] -is [hashtable]
                } )

                if ($index -ne -1) {
                    # Catch error if duplicate keys are present
                    $FFMpegExtra[$index] += $config['FFMpegHash']
                }
                else { $FFMpegExtra.Add($config['FFMpegHash']) }
            }
            else {
                $FFMpegExtra = @()
                $FFMpegExtra.Add($config['FFMpegHash'])
            }
        }

        # Add single valued ffmpeg config options
        if ($config['FFMpegArray']) {
            if ($FFMpegExtra) { $ffmpegExtra.AddRange($config['FFMpegArray']) }
            else {
                $FFMpegExtra = @()
                $FFMpegExtra.AddRange($config['FFMpegArray'])
            }
        }

        # Add encoder settings from config file
        if ($config['Encoder']) { 
            if ($EncoderExtra) {
                $EncoderExtra += $config['Encoder']
            }
            else { $EncoderExtra = $config['Encoder'] }
        }
    }
    catch {
        $e = $_.Exception.Message
        Write-Error "Failed to parse the configuration file(s): $e"
    }

    return $EncoderExtra, $FFMpegExtra
}