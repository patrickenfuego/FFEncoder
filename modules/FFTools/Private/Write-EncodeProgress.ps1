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

    # Intercept ctrl+C for graceful shutdown of jobs
    [console]::TreatControlCAsInput = $true
    Start-Sleep -Milliseconds 500
    $Host.UI.RawUI.FlushInputBuffer()

    if ($PSBoundParameters['TestFrames']) {
        $frame['FrameCount'] = $TestFrames
    }
    elseif (!$SecondPass -or ($frame['FrameCount'] -le 0)) {
        Write-Progress "Gathering frame count for progress display..."
        $frameStr = ffmpeg -hide_banner -i $InputFile -map 0:v:0 -c:v copy -f null - 2>&1

        # Select-String does not work on this output for some reason?
        $tmp = $frameStr | Select-Object -Index ($frameStr.Count - 2)
        [int]$frame['FrameCount'] = $tmp | 
            Select-String -Pattern '^frame=\s*(\d+)\s.*' |
                ForEach-Object { $_.Matches.Groups[1].Value }

        if (!$frame['FrameCount']) {
            Write-Progress "Error" -Completed
            $msg = "Failed to parse frame count from string"
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    ([System.ArgumentNullException]$msg),
                    'frame',
                    [System.Management.Automation.ErrorCategory]::InvalidResult,
                    $frame['FrameCount']
                )
            )
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
                $params = @{
                    Pattern    = '(?<fr>\d+)\/?\d{0,8}(?=\s+frames)[^\d]+(?<fps>\d+\.?\d*)(?=\s+fps)'
                    AllMatches = $true
                }
                $currentFrameStr, $fpsStr = Get-Content $LogPath -Tail 1 |
                    Select-String @params |
                        ForEach-Object { $_.Matches.Groups[1].Value, $_.Matches.Groups[2].Value }
            }
            else {
                $params = @{
                    Pattern    = '^frame=\s*(?<fr>\d+)\s*fps=\s*(?<fps>\d+\.?\d*)(?=\s*q)'
                    AllMatches = $true
                }
                $currentFrameStr, $fpsStr = Get-Content $LogPath -Tail 1 |
                    Select-String @params | 
                        ForEach-Object { $_.Matches.Groups[1].Value, $_.Matches.Groups[2].Value }
            }

            if (($currentFrameStr -as [int]) -is [int]) {
                [int]$currentFrame = $currentFrameStr
            }
            if (($fpsStr -as [double]) -is [double]) {
                [double]$fps = $fpsStr
            }
        }
        catch {
            Write-Verbose "Error: $currentFrame or $fps is not a number"
            continue
        }

        if ($currentFrame -and $fps) {
            $progress = ($currentFrame / $frame['FrameCount']) * 100
            $status = '{0:N1}% Complete' -f $progress
            $activity = "Encoding Frame $currentFrame of $($frame['FrameCount']), $('{0:N2}' -f $fps) FPS"

            $params = @{
                PercentComplete = $progress
                Status          = $status
                Activity        = $activity
            }
            Write-Progress @params
            Start-Sleep -Seconds 1.2
        }
        else {
            Start-Sleep -Milliseconds 500
        } 
    }

    Start-Sleep -Milliseconds 250
    Write-Progress "Complete" -Completed
}
