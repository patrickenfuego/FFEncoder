<#
    Helper function which sets the audio encoding method
    .PARAMETER UserChoice
        Options are copy (passthrough), aac, and none
#>
function Set-AudioPreference {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$UserChoice,

        # Parameter help description
        [Parameter(Mandatory = $false, Position = 2)]
        [int]$AacBitrate
    )
    switch -Regex ($UserChoice) {
        #If 'c' or 'copy' is selected
        { $_ -match "^c[opy]?" } { return @('-c:a', 'copy') }
        #If aac is selected, prompt for quality level (uses CBR for native ffmpeg aac)
        { $_ -match "aac" } {
            [int]$numOfChannels = ffprobe -i $InputFile -show_entries stream=channels -select_streams a:0 -of compact=p=0:nk=1 -v 0
            $bitrate = $numOfChannels * $AacBitrate
            return @('-c:a', 'aac', '-b:a', $bitrate)
        }
        #If 'n' or 'none' is selected. This is also the default behavior
        { $_ -match "^n[one]?" } { return '-an' }
        default { return '-an' }
    }
}