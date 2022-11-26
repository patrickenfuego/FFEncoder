<#
    .SYNOPSIS
        Watches for CTRL+C interrupts and clean exits all running jobs and scripts
    .PARAMETER Message
        Banner message to display on exit
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
            # Clean up all running jobs before exiting. x265 never wants to die, requires special handling
            if ($proc = Get-Process -Name '*x265*') {
                $id = ($proc).Id
                [scriptblock]$sb = {
                    param($Id)
                    # Verify that the process parent is cmd before killing it
                    # Not foolproof, but best form of identification I can think of currently
                    Get-Process -Id $Id | 
                        Select-Object -ExpandProperty Parent |
                            Select-Object -ExpandProperty ProcessName
                }
                # More than 1 process returned
                if ($id.Length -gt 1) {
                    $parents = $id.ForEach({ & $sb -Id $_ })
                    if ('cmd' -in $parents) {
                        $index = [array]::IndexOf($parents, 'cmd')
                        $kid = $id[$index]
                        Write-Verbose "Script Termination - Killing PID: $kid"
                        Stop-Process -Id $kid -Force
                    }
                }
                else {
                    $parent = & $sb -Id $id
                    if ($parent -eq 'cmd') { Stop-Process -Id $id -Force }
                }
            }

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