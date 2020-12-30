function Measure-AacBitrate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [int]$Quality

    )
    [int]$numOfChannels = ffprobe -i $InputFile -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0
    Write-Host "`nAudio stream 0 has $numOfChannels channels`n"

    switch ($Quality) {
        1 { $bitrate = $numOfChannels * 32 }
        2 { $bitrate = $numOfChannels * 48 }
        3 { $bitrate = $numOfChannels * 64 }
        4 { $bitrate = $numOfChannels * 72 }
        5 { $bitrate = $numOfChannels * 112 }
        default { Write-Verbose "DEBUG: AAC bitrate switch failed. Received: $Quality. Expected: 1-5" }
    }
    $bitRateStr = "$bitrate`k"
    return $bitrateStr
}