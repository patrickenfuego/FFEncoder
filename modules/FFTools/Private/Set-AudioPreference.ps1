<#
    Helper function which sets the audio encoding method
    .PARAMETER UserChoice
        Options are copy (passthrough), aac, and none
#>
function Set-AudioPreference {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$UserChoice,

        # Parameter help description
        [Parameter(Mandatory = $false, Position = 2)]
        [int]$AacBitrate
    )

    if ($UserChoice -match "^c[opy]?") { return @('-c:a', 'copy') }
    elseif ($UserChoice -match "aac") {
        [int]$numOfChannels = ffprobe -i $InputFile -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0
        $bitrate = "$($numOfChannels * $AacBitrate)k"
        Write-Host "Input file has $numOfChannels channels. Total AAC bitrate: $bitrate`bps" 
        return @('-c:a', 'aac', '-b:a', $bitrate)
    }
    elseif ($UserChoice -match "^n[one]?") { return '-an' }
    else { Write-Verbose "No matching audio preference was found. Audio will not be copied"; return '-an' }
}