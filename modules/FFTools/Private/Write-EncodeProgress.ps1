<#
    .SYNOPSIS
        Writes the progress of the encode to the console
    .DESCRIPTION
        Quickly scans the source file for the total number of frames (no demuxing) and retrieves the 
        current frame from the log to form a progress bar. The status is updated every 2 seconds.
    .NOTES
        This function has an inner function that doubles as a trap for CTRL+C, as it runs after all of the big
        ThreadJobs start
#>

function Write-EncodeProgress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $true)]
        [string]$LogPath,

        [Parameter(Mandatory = $true)]
        [int]$TestFrames,

        [Parameter(Mandatory = $true)]
        [string]$JobName,

        [Parameter(Mandatory = $true)]
        [bool]$SecondPass,

        [Parameter(Mandatory = $true)]
        [bool]$DolbyVision
    )

    <#
        .SYNOPSIS
            Watches for CTRL+C interrupts and clean exits all running jobs and scripts
    #>
    function Watch-ScriptTerminated ([string]$Message) {
        if ($Host.UI.RawUI.KeyAvailable -and ($Key = $Host.UI.RawUI.ReadKey("AllowCtrlC,NoEcho,IncludeKeyUp"))) {
            # If user hits Ctrl+C
            if ([int]$Key.Character -eq 3) {
                Write-Progress "Terminated" -Completed
                Write-Warning "CTRL+C was detected - shutting down all running jobs before exiting the script"
                # Clean up all running jobs before exiting
                Get-Job | Stop-Job -PassThru | Remove-Job -Force -Confirm:$false

                $psReq ? (Write-Host "$($aRed)$Message$($reset)") :
                         (Write-Host $Message @errColors)
                $console.WindowTitle = $currentTitle
                [console]::TreatControlCAsInput = $False
                exit 77
            }
            # Flush the key buffer again for the next loop
            $Host.UI.RawUI.FlushInputBuffer()
        }
    }

    # Intercept ctrl+C for graceful shutdown of jobs
    [console]::TreatControlCAsInput = $True
    Start-Sleep -Milliseconds 500
    $Host.UI.RawUI.FlushInputBuffer()

    if ($PSBoundParameters['TestFrames']) {
        $frameCount = $TestFrames
    }
    # Gather total frame count without demuxing
    else {
        if (!$SecondPass) {
            Write-Progress "Gathering frame count for progress display..."
            $frameStr = ffmpeg -i $InputFile -map 0:v:0 -c:v copy -f null - 2>&1
        }
        # Select-String does not work on this output for some reason?
        $tmp = $frameStr | Select-Object -Index ($frameStr.Count - 2)
        [int]$frameCount = $tmp | 
            Select-String -Pattern '^frame=\s*(\d+)\s.*' |
                ForEach-Object { $_.Matches.Groups[1].Value }

        if (!$frameCount) {
            Write-Progress "Could not retrieve frame count" -Completed
            return
        }
    }
    
    # While job is running, track progress
    while ((Get-Job -Name $JobName).State -ne 'Completed') {
        # Check if script was terminated. If so, exit gracefully & terminate jobs
        Watch-ScriptTerminated -Message $exitBanner
        # Wait until log is available
        do {
            Start-Sleep -Milliseconds 100
        } until ([File]::Exists($LogPath))

        try {
            if ($DolbyVision) {
                $currentFrameStr = Get-Content $LogPath -Tail 1 | 
                    Select-String -Pattern '^(\d+)' |
                        ForEach-Object { $_.Matches.Groups[1].Value }
            }
            else {
                $currentFrameStr = Get-Content $LogPath -Tail 1 |
                    Select-String -Pattern '^frame=\s*(\d+)\s*.*' | 
                        ForEach-Object { $_.Matches.Groups[1].Value }
            }

            if (($currentFrameStr -as [int]) -is [int]) {
                [int]$currentFrame = $currentFrameStr 
            }
            else {
                $currentFrame = $currentFrame
            }
        }
        catch {
            Write-Verbose "Error: $currentFrame is not an integer"
            continue
        }

        if ($currentFrame) {
            $progress = ($currentFrame / $frameCount) * 100
            $status = "$([math]::Round($progress, 2))% Complete"
            $activity = "Encoding Frame $currentFrame of $frameCount"

            $params = @{
                PercentComplete = $progress
                Status          = $status
                Activity        = $activity
            }
            Write-Progress @params
            Start-Sleep -Seconds 1
        }
        else {
            Start-Sleep -Milliseconds 500
        } 
    }

    Start-Sleep -Milliseconds 250
    Write-Progress "Complete" -Completed
}
