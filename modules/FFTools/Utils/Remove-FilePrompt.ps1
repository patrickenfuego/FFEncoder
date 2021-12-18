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
    "Delete the existing file. you will be asked to confirm again before proceeding"
    $noPrompt = New-Object System.Management.Automation.Host.ChoiceDescription "&No", 
    "Do not delete the existing file and exit the script. The file must be renamed or deleted before continuing"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yesPrompt, $noPrompt)
    $response = $host.ui.PromptForChoice($title, $prompt, $options, 1)

    switch ($response) {
        0 { 
            Remove-Item -Path $Path -Include "*.mkv", "*.mp4", "*.ts", "*.m2ts", "*.avi" -Confirm 
            if ($?) { 
                Write-Host "`nFile <" -NoNewline @progressColors 
                Write-Host "$Path" -NoNewline @emphasisColors
                Write-Host "> was successfully deleted`n" @progressColors 
            }
            else { 
                Write-Host "<" -NoNewline @warnColors
                Write-Host $Path @emphasisColors
                Write-Host "> could not be deleted. Make sure it is not in use by another process. Exiting script..." @warnColors
                exit 2
            }
        }
        1 { 
            Write-Host  "Please choose a different file name, or delete the existing file. Exiting script..." @warnColors
            exit 0
        }
        default { 
            throw "An error occurred while attempting to delete <$Path> via prompt. This should be unreachable"
            exit 2
        }
    }
}
