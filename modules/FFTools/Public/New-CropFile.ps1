<#
    .SYNOPSIS
        Module function that generates a crop file, which can be used for auto-cropping black borders in video files
    .DESCRIPTION
        This function generates a crop file that can be used for auto-cropping videos with ffmpeg. 
        It uses multi-threading to analyze up to 4 separate segments of the input file simultaneously, 
        which is then queued and written to the crop file.
    .INPUTS
        Path of the source file to be encoded
        Path of the crop file to be created
    .OUTPUTS
        Crop file in .txt format
    .NOTES
        This function only generates the crop file. Additional logic is needed to analyze the crop file for max width/height
        values to be used for cropping.
#>

function New-CropFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputPath,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$CropFilePath,

        [Parameter(Mandatory = $true, Position = 2)]
        [int]$Count
    )

    function Get-Duration {
        $duration = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 `
            -i $InputPath
        $duration = $duration / 60
        if ($duration) { return $duration } else { return $null }
    }

    $duration = Get-Duration

    if (Test-Path -Path $CropFilePath) { 
        Write-Host "Crop file already exists. Skipping crop file generation..." @warnColors
        return
    }
    else {
        $segments = @(
            @{ Start = '90'; Length = '00:00:45'; Duration = 0 }
            @{ Start = '00:05:00'; Length = '00:00:45'; Duration = 7 }
            @{ Start = '00:10:00'; Length = '00:00:45'; Duration = 11 }
            @{ Start = '00:15:00'; Length = '00:00:45'; Duration = 16 }
            @{ Start = '00:20:00'; Length = '00:00:45'; Duration = 21 }
            @{ Start = '00:25:00'; Length = '00:00:45'; Duration = 26 }
            @{ Start = '00:30:00'; Length = '00:00:45'; Duration = 31 }
            @{ Start = '00:35:00'; Length = '00:00:45'; Duration = 36 }
            @{ Start = '00:40:00'; Length = '00:00:45'; Duration = 41 }
            @{ Start = '00:45:00'; Length = '00:00:45'; Duration = 46 }
            @{ Start = '00:50:00'; Length = '00:00:45'; Duration = 51 }
            @{ Start = '00:55:00'; Length = '00:00:45'; Duration = 56 }
            @{ Start = '01:00:00'; Length = '00:00:45'; Duration = 61 }
            @{ Start = '01:05:00'; Length = '00:00:45'; Duration = 66 }
            @{ Start = '01:10:00'; Length = '00:00:45'; Duration = 71 }
            @{ Start = '01:15:00'; Length = '00:00:45'; Duration = 76 }
            @{ Start = '01:20:00'; Length = '00:00:45'; Duration = 81 }
            @{ Start = '01:25:00'; Length = '00:00:45'; Duration = 86 }
            @{ Start = '01:30:00'; Length = '00:00:40'; Duration = 91 }
            @{ Start = '01:35:00'; Length = '00:00:40'; Duration = 96 }
            @{ Start = '01:40:00'; Length = '00:00:40'; Duration = 101 }
            @{ Start = '01:45:00'; Length = '00:00:40'; Duration = 106 }
            @{ Start = '01:50:00'; Length = '00:00:40'; Duration = 111 }
            @{ Start = '01:55:00'; Length = '00:00:35'; Duration = 116 }
            @{ Start = '02:00:00'; Length = '00:00:35'; Duration = 121 }
            @{ Start = '02:05:00'; Length = '00:00:35'; Duration = 126 }
            @{ Start = '02:10:00'; Length = '00:00:35'; Duration = 131 }
            @{ Start = '02:15:00'; Length = '00:00:35'; Duration = 136 }
            @{ Start = '02:20:00'; Length = '00:00:35'; Duration = 141 }
            @{ Start = '02:25:00'; Length = '00:00:35'; Duration = 146 }
            @{ Start = '02:30:00'; Length = '00:00:30'; Duration = 151 }
            @{ Start = '02:35:00'; Length = '00:00:30'; Duration = 156 }
            @{ Start = '02:40:00'; Length = '00:00:30'; Duration = 161 }
            @{ Start = '02:45:00'; Length = '00:00:30'; Duration = 166 }
            @{ Start = '02:50:00'; Length = '00:00:30'; Duration = 171 }
            @{ Start = '02:55:00'; Length = '00:00:30'; Duration = 176 }
            @{ Start = '03:00:00'; Length = '00:00:30'; Duration = 181 }
            @{ Start = '03:05:00'; Length = '00:00:30'; Duration = 186 }
            @{ Start = '03:10:00'; Length = '00:00:30'; Duration = 191 }
            @{ Start = '03:15:00'; Length = '00:00:25'; Duration = 196 }
            @{ Start = '03:20:00'; Length = '00:00:25'; Duration = 201 }
            @{ Start = '03:25:00'; Length = '00:00:25'; Duration = 206 }
            @{ Start = '03:30:00'; Length = '00:00:25'; Duration = 211 }

        )
        #Determine the number of threads based on duration
        $threadCount = 0
        foreach ($entry in $segments) {
            if ($duration -gt $entry.Duration) { $threadCount++ } else { break }
        }
        #Create queue and synchronize it for thread safety
        $queue = [System.Collections.Queue]::new()
        1..$threadCount | ForEach-Object { $queue.Enqueue($_) }
        $syncQueue = [System.Collections.Queue]::Synchronized($queue)
        #Run the crop jobs
        $cropJob = $segments | ForEach-Object -AsJob -ThrottleLimit 6 -Parallel {
            $sqCopy = $Using:syncQueue
            if ($Using:duration -gt $_.Duration) {
                $c = ffmpeg -ss $_.Start -skip_frame nokey -hide_banner -i $Using:InputPath -t $_.Length -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
                Write-Output -InputObject $c
        
                $sqCopy.Dequeue()
            } 
        } 
        #Update status bar
        while ($cropJob.State -eq 'Running') {
            if ($syncQueue.Count -gt 0) {
                $status = ((1 / $syncQueue.Count) * 100)
                Write-Progress -Activity "Generating Crop File" -Status "Progress ->" -PercentComplete $status
                Start-Sleep -Milliseconds 100
            }
        }

        Write-Progress -Activity "Sending Data to Crop File" -Status "Writing..."
        $cropJob | Wait-Job | Receive-Job | Out-File -FilePath $CropFilePath -Append | Stop-Job
        Write-Progress -Activity "Cropping Complete!" -Completed
    }

    Start-Sleep -Milliseconds 500
    if ((Get-Content $CropFilePath).Count -gt 10) {
        Write-Host "`n** CROP FILE SUCCESSFULLY GENERATED **" @progressColors
    }
    #If the crop file fails to generate, sleep for 5 seconds and perform a recursive call to try again
    else {
        #base case
        if ($Count -eq 0) { 
            throw "There was an issue creating the crop file. Check the input path and try again."
            exit 2
        }
        else {
            Write-Host "`nAn error occurred while generating the crop file contents. Retrying in 5 seconds..." @warnColors
            Start-Sleep -Seconds 5
            $Count--
            if (Test-Path $CropFilePath) { Remove-Item -Path $CropFilePath -Force }
            New-CropFile -InputPath $InputPath -CropFilePath $CropFilePath -Count $Count
        }
    }
}
