<#
    .SYNOPSIS
        Writes the progress of the encode to the console
    .DESCRIPTION
        Quickly scans the source file for the total number of frames (no demuxing) and retrieves the 
        current frame from the log to form a progress bar. The status is updated every 2 seconds.
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

    if ($PSBoundParameters['TestFrames']) {
        $frameCount = $TestFrames
    }
    else {
        if (!$SecondPass) {
            Write-Progress "Gathering frame count for progress display..."
            $frameStr = ffmpeg -i $InputFile -map 0:v:0 -c:v copy -f null - 2>&1
        }
        # Select-String does not work on this output for some reason?
        $tmp = $frameStr | Select-Object -Index ($frameStr.Count - 2)
        [int]$frameCount = $tmp | 
            Select-String -Pattern '^frame=(\d+)\s.*' | 
                ForEach-Object { $_.Matches.Groups[1].Value }
    }
    
    # While job is running, track progress
    while ((Get-Job -Name $JobName).State -ne 'Completed') {
        # Wait until log is available
        do {
            Start-Sleep -Milliseconds 100
        } until ([File]::Exists($LogPath))

        if ($DolbyVision) {
            [int]$currentFrame = Get-Content $LogPath -Tail 1 | 
                Select-String -Pattern '^(\d+)' | 
                    ForEach-Object { $_.Matches.Groups[1].Value }
        }
        else {
            [int]$currentFrame = Get-Content $LogPath -Tail 1 | 
                Select-String -Pattern '^frame=\s+(\d+) .*' | 
                    ForEach-Object { $_.Matches.Groups[1].Value }
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
            Start-Sleep -Seconds 1.5
        }
        else {
            Start-Sleep -Milliseconds 500
        } 
    }

    Start-Sleep -Milliseconds 250
    Write-Progress "Complete" -Completed
}
