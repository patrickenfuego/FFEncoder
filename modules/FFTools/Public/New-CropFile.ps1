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
        Write-Host "Generating crop file in Parallel...`n"
        $segments = @(
            @{ Start = '90'; Length =  '00:08:00'; Duration = 0 }
            @{ Start = '00:20:00'; Length =  '00:08:00'; Duration = 20 } 
            @{ Start = '00:40:00'; Length =  '00:08:00'; Duration = 40 } 
            @{ Start = '01:00:00'; Length =  '00:08:00'; Duration = 70 } 
            @{ Start = '01:20:00'; Length =  '00:03:00'; Duration = 85 } 
            @{ Start = '01:30:00'; Length =  '00:03:00'; Duration = 95 } 
        )
        $cropJob = $segments | ForEach-Object -Parallel {
            if ($Using:duration -gt $_.Duration) {
                $c = ffmpeg -ss $_.Start -skip_frame nokey -hide_banner -i $Using:InputPath -t $_.Length -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
                Write-Output -InputObject $c
            } 
        } -AsJob 

        $cropJob | Wait-Job | Receive-Job | Out-File -FilePath $CropFilePath -Append | Stop-Job
    }

    Start-Sleep -Milliseconds 500
    if ((Get-Content $CropFilePath).Count -gt 10) {
        Write-Host "`n** CROP FILE SUCCESSFULLY GENERATED **" @progressColors
    }
    #If the crop file fails to generate, sleep for 5 seconds and perform a recursive call to try again
    else {
        #base case
        if ($Count -eq 0) { throw "There was an issue creating the crop file. Check the input path and try again." }
        else {
            Write-Host "`nAn error occurred while generating the crop file contents. Retrying in 5 seconds..." @warnColors
            Start-Sleep -Seconds 5
            $Count--
            New-CropFile -InputPath $InputPath -CropFilePath $CropFilePath -Count $Count
        }
    }
}
