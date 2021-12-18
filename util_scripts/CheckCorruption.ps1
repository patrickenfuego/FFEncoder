<#
    .SYNOPSIS
        Quick and dirty check for media file corruption
    .DESCRIPTION
        Simple script that uses ffmpeg to verify if a file
        contains corrupted blocks. ffmpeg is run as a background
        job with format type null and verbosity level error.
        Contents of the job are output to a file, which is checked
        every 2 seconds for errors
    .PARAMETER File
        Input file to verify
    .PARAMETER ExitOnError
        Immediately exits the background job when the first error
        occurs
    .PARAMETER Segment
        Breaks the job into 2 parts that run simultaneously. More
        resource intensive 
#>

param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript(
        {
            if (Test-Path $_) { $true }
            else {
                Write-Error "Input file does not exist" -CategoryActivity "Check Corruption"
                $false
            }
        }
    )]
    [Alias('F')]
    [string]$File,

    [Parameter()]
    [Alias('Exit')]
    [switch]$ExitOnError,

    [Parameter()]
    [Alias('Pieces', 'S')]
    [switch]$Segment
)

$errColors = @{ ForegroundColor = 'Red'; BackgroundColor = 'Black' }

$log = Join-Path "$(Split-Path $File -Parent)" -ChildPath "error_check.log"
if (Test-Path $log) { Remove-Item $log }

Start-Sleep -Milliseconds 500

if ($PSBoundParameters['Segment']) {
    Write-Host "Running segmented error check"
    #Get duration for splitting
    $duration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 `
        -i $File

    $segments = @(
        @{ Id = 1; Start = 0; End = (($duration / 2) - 1); Log = $log }
        @{ Id = 2; Start = ($duration / 2); End = $duration; Log = ($log -replace '.log', '2.log') }
    )

    foreach ($s in $segments) {
        Start-Job -Name "ffmpeg job $($s.Id)" -ScriptBlock {
            ffmpeg -v error -ss $Using:s.Start -i $Using:File -to $Using:s.End -f null - 2>$Using:s.Log
        }
    }
}
#Run as a single background job
else {
    Start-Job -Name 'ffmpeg Error Check' -ScriptBlock {
        ffmpeg -v error -i $Using:File -f null - 2>$Using:log
    }
}

#Wait for jobs to complete. If -ExitOnError, exit on first occurrence of log data
$count = 0
while ((Get-Job).State -eq 'Running') {
    Start-Sleep -Seconds 2

    if ($Segment) {
        if ((Get-Content $segments[0].Log).Count -gt 0 -or (Get-Content $segments[1].Log).Count -gt 0) {
            $count++
        }
    }
    else {
        if ((Get-Content $log).Count -gt 0) {
            $count++
        } 
    }

    Write-Host "File <$File> has $count error(s)"
    if ($count -and $PSBoundParameters['ExitOnError']) {
        Write-Host "First error detected. Exiting script..." @errColors
        Get-Job | Stop-Job | Remove-Job -Force
        break
    }
}

if (!$Segment) {
    Get-Job | Receive-Job | Stop-Job | Remove-Job -Force
}


#Check for errors that occurred at EOF (catch errors occurring after job(s) complete)
if ($Segment) {
    if ((Get-Content $segments[0].Log).Count -gt 0 -or (Get-Content $segments[1].Log).Count -gt 0) {
        $count = (Get-Content $segments[0].Log).Count + (Get-Content $segments[1].Log).Count
        Get-Content $segments[1].Log | Out-File $segments[0].Log -Append
        Remove-Item $segments[1].Log
    }
}
elseif ((Get-Content $log).Count -gt 0) {
    $count = (Get-Content $log).Count
}

if ($count -eq 0) {
    Write-Host "No errors detected! Huzzah!!"
}
else {
    Write-Host "`n`nFile check reported " -NoNewline
    Write-Host $count -ForegroundColor Red -BackgroundColor Black -NoNewline
    Write-Host " error(s)"
}
