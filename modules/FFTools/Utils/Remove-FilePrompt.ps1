<#
    .SYNOPSIS
        Creates a PowerShell friendly prompt for deleting existing files
#>

function Remove-FilePrompt {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Path,

        [Parameter()]
        [string]$Type
    )

    Write-Host "`n"

    $title = "$Type Output Path Already Exists"
    $prompt = "Would you like to delete it?"
    $yesPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", 
        "Delete the existing file and proceed with script execution"
    $noPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&No", 
        "Do not delete the existing file and exit the script. The file must be renamed or deleted before continuing"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yesPrompt, $noPrompt)
    $response = $host.ui.PromptForChoice($title, $prompt, $options, 1)

    switch ($response) {
        0 { 
            [System.IO.File]::Delete($Path)
            if ($?) {
                if ($psReq) {
                    $msg = "$aGreen`File $($aCyan+$ul)$Path$($ulOff)$aGreen was successfully deleted"
                    Write-Host $msg
                }
                else {
                    Write-Host "`nFile <" -NoNewline @progressColors 
                    Write-Host "$Path" -NoNewline @emphasisColors
                    Write-Host "> was successfully deleted`n" @progressColors
                }   
            }
            else {
                if ($psReq) {
                    $msg = "$aRed`File $($aBlue+$ul)$Path$($ulOff+$aRed) could not be deleted. Make sure it is not in use by another process. Exiting script..."
                    Write-Host $msg
                }
                else {
                    Write-Host "<" -NoNewline @warnColors
                    Write-Host $Path @emphasisColors
                    Write-Host "> could not be deleted. Make sure it is not in use by another process. Exiting script..." @warnColors
                    exit 68
                }
                
            }
        }
        1 { 
            Write-Host "Please choose a different file name, or delete the existing file`n" @warnColors
            Write-Host $exitBanner @errColors
            exit 0
        }
        default { 
            throw "An error occurred while attempting to delete <$Path> via prompt. This should be unreachable"
            exit 55
        }
    }

    Write-Host ""
}
