<#
    .SYNOPSIS
        Watches for CTRL+C interrupts and clean exits all running jobs and scripts
#>
function Watch-ScriptTerminated {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )

    if ($Host.UI.RawUI.KeyAvailable -and ($key = $Host.UI.RawUI.ReadKey("AllowCtrlC,NoEcho,IncludeKeyUp"))) {
        # If user hits Ctrl+C
        if ([int]$key.Character -eq 3) {
            Write-Progress "Terminated" -Completed
            Write-Warning "CTRL+C was detected - shutting down all running jobs before exiting the script"
            # Clean up all running jobs before exiting
            Get-Job | Stop-Job -PassThru | Remove-Job -Force -Confirm:$false

            $psReq ? (Write-Host "$($aRed)$Message$($reset)") :
                     (Write-Host $Message @errColors)

            $console.WindowTitle = $currentTitle
            [console]::TreatControlCAsInput = $false
            exit 77
        }

        # Flush the key buffer again for the next loop
        $Host.UI.RawUI.FlushInputBuffer()
    }
}