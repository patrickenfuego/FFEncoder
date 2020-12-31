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
        [string]$UserChoice
    )
    switch -Regex ($UserChoice) {
        #If 'c' or 'copy' is selected
        { $_ -match "^c[opy]?" } { return @('-c:a', 'copy') }
        #If aac is selected, prompt for quality level (uses CBR for native ffmpeg aac)
        { $_ -match "aac" } {
            $prompt = [System.Text.StringBuilder]::new()
            [void]$prompt.
            AppendLine("`nPlease select the AAC encoder quality level (1 = low quality, 5 = high quality):`n").
            AppendLine("1.`t32 kbps/channel").
            AppendLine("2.`t48 kbps/channel").
            AppendLine("3.`t64 kbps/channel").
            AppendLine("4.`t72 kbps/channel").
            AppendLine("5.`t112 kbps/channel")
            do {
                [int]$qLevel = Read-Host -Prompt $prompt.ToString()
            } until ($qLevel -le 5 -and $qLevel -ge 1)

            #Call function to calculate the bitrate based on choice
            $bitrate = Measure-AacBitrate $InputFile $qLevel
            return @('-c:a', 'aac', '-b:a', $bitrate)
        }
        #If 'n' or 'none' is selected. This is also the default behavior
        { $_ -match "^n[one]?" } { return '-an' }
        default { return '-an' }
    }
}