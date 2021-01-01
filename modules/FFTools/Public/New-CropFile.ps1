###################################################################
#
#   Written by: Patrick Kelly
#   Last Modified: 12/31/2020
#
###################################################################
<#
    .SYNOPSIS
        Module function that generates a crop file, which can be used for auto-cropping black borders in video files
    .DESCRIPTION
        This function generates a crop file that can be used for auto-cropping videos with ffmpeg. 
        It uses multi-threading to analyze 3 separate segments of the input file simultaneously, 
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
        [string]$CropFilePath
    )

    #if the crop file already exists (from a test run for example) return the path. Else, use ffmpeg to create one
    if (Test-Path -Path $CropFilePath) { 
        Write-Host "Crop file already exists. Skipping crop file generation..."
        return
    }
    else {
        #Crop segments running in parallel. Putting these jobs in a loop hurts performance as it creates a new runspacepool for each item
        Start-RSJob -Name "Crop Start" -ArgumentList $InputPath -ScriptBlock {
            param($inFile)
            $c1 = ffmpeg -ss 90 -skip_frame nokey -y -hide_banner -i $inFile -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
            Write-Output -InputObject $c1
        } 
        
        Start-RSJob -Name "Crop Mid" -ArgumentList $InputPath -ScriptBlock {
            param($inFile)
            $c2 = ffmpeg -ss 00:20:00 -skip_frame nokey -y -hide_banner -i $inFile -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
            Write-Output -InputObject $c2
        } 

        Start-RSJob -Name "Crop End" -ArgumentList $InputPath -ScriptBlock {
            param($inFile)
            $c3 = ffmpeg -ss 00:40:00 -skip_frame nokey -y -hide_banner -i $inFile -t 00:08:00 -vf fps=1/2,cropdetect=round=2 -an -sn -f null - 2>&1
            Write-Output -InputObject $c3
        } 

        Get-RSJob | Wait-RSJob | Receive-RSJob | Out-File -FilePath $CropFilePath -Append
    }
}