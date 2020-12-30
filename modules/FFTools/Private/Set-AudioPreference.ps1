<#
    Helper function which sets the audio encoding method
    .PARAMETER UserChoice
        Options are copy (passthrough), aac, and none
#>
function Set-AudioPreference {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$UserChoice
    )
    switch -Regex ($UserChoice) {
        #If c or copy is selected
        { $_ -match "^c.*" } { return "-c:a copy" }
        #If aac is selected, prompt for variable bit rate value
        { $_ -match "aac" } {
            $prompt = [System.Text.StringBuilder]::new()
            [void]$prompt.
            AppendLine("`nPlease select the AAC encoder quality level (1 = low quality, 5 = high quality):`n").
            AppendLine("1.`t20-32 kbps/channel").
            AppendLine("2.`t20-32 kbps/channel").
            AppendLine("3.`t48-56 kbps/channel").
            AppendLine("4.`t20-32 kbps/channel").
            AppendLine("5.`t96-112 kbps/channel")
            do {
                [int]$vbr = Read-Host -Prompt $prompt.ToString()
            } until ($vbr -le 5 -and $vbr -ge 1)
            return "-c:a aac -vbr $vbr"
        }
        #If n or none is selected. This is also the default behavior
        { $_ -match "^n.*" } { return "-an" }
        default { return "-an" }
    }
}