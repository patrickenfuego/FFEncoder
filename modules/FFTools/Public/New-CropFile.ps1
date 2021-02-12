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
        $duration
        if ($duration) { return $duration } else { return $null }
    }

    Import-Module -Name ".\modules\PoshRSJob"

    #if the crop file already exists (from a test run for example) return the path. Else, use ffmpeg to create one
    if (Test-Path -Path $CropFilePath) { 
        Write-Host "Crop file already exists. Skipping crop file generation..." @warnColors
        return
    }
    else {
        Write-Host "Generating crop file...`n"
        #Crop segments running in parallel. Putting these jobs in a loop hurts performance as it creates a new runspace pool for each job
        Start-RSJob -Name "Crop 00:01:30" -ArgumentList $InputPath -Throttle 4 -ScriptBlock {
            $c1 = ffmpeg -ss 90 -skip_frame nokey -hide_banner -i $Using:InputPath -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
            Write-Output -InputObject $c1
        } 
        
        Start-RSJob -Name "Crop 00:20:00" -ArgumentList $InputPath -Throttle 4 -ScriptBlock {
            $c2 = ffmpeg -ss 00:20:00 -skip_frame nokey -hide_banner -i $Using:InputPath -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
            Write-Output -InputObject $c2
        } 

        if ((Get-Duration) -gt 40) {
            Start-RSJob -Name "Crop 00:40:00" -ArgumentList $InputPath -Throttle 4 -ScriptBlock {
                $c3 = ffmpeg -ss 00:40:00 -skip_frame nokey -hide_banner -i $Using:InputPath -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
                Write-Output -InputObject $c3
            } 
        }

        if ((Get-Duration) -gt 70) {
            Start-RSJob -Name "Crop 01:00:00" -ArgumentList $InputPath -Throttle 4 -ScriptBlock {
                $c4 = ffmpeg -ss 01:00:00 -skip_frame nokey -hide_banner -i $Using:InputPath -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
                Write-Output -InputObject $c4
            }
        }

        if ((Get-Duration) -gt 85) {
            Start-RSJob -Name "Crop 01:20:00" -ArgumentList $InputPath -Throttle 4 -ScriptBlock {
                $c5 = ffmpeg -ss 01:20:00 -skip_frame nokey -hide_banner -i $Using:InputPath -t 00:03:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
                Write-Output -InputObject $c5
            }
        }

        if ((Get-Duration) -gt 95) {
            Start-RSJob -Name "Crop 01:30:00" -ArgumentList $InputPath -Throttle 4 -ScriptBlock {
                $c6 = ffmpeg -ss 01:20:00 -skip_frame nokey -hide_banner -i $Using:InputPath -t 00:03:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
                Write-Output -InputObject $c6
            }
        }

        Get-RSJob | Wait-RSJob | Receive-RSJob | Out-File -FilePath $CropFilePath -Append
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
