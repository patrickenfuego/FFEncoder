function New-CropFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputPath,

        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CropFilePath
    )


    #if the crop file already exists (from a test run for example) return the path. Else, use ffmpeg to create one
    if (Test-Path -Path $cropFilePath) { 
        Write-Host "Crop file already exists. Skipping crop file generation..."
        return
    }
    else {
        #Crop segments running in parallel. Putting these jobs in a loop hurts performance as it creates a new runspacepool for each item
        Start-RSJob -Name "Crop Start" -ArgumentList $InputPath -ScriptBlock {
            param($inFile)
            $c1 = ffmpeg -ss 90 -skip_frame nokey -y -hide_banner -i $inFile -t 00:08:00 -vf fps=1/2,cropdetect=round=4 -an -sn -f null - 2>&1
            Write-Output -InputObject $c1
        } 
        
        Start-RSJob -Name "Crop Mid" -ArgumentList $InputPath -ScriptBlock {
            param($inFile)
            $c2 = ffmpeg -ss 00:20:00 -skip_frame nokey -y -hide_banner -i $inFile -t 00:08:00 -vf fps=1/2,cropdetect=round=4 -an -sn -f null - 2>&1
            Write-Output -InputObject $c2
        } 

        Start-RSJob -Name "Crop End" -ArgumentList $InputPath -ScriptBlock {
            param($inFile)
            $c3 = ffmpeg -ss 00:40:00 -skip_frame nokey -y -hide_banner -i $inFile -t 00:08:00 -vf fps=1/2,cropdetect=round=4 -an -sn -f null - 2>&1
            Write-Output -InputObject $c3
        } 

        Get-RSJob | Wait-RSJob | Receive-RSJob | Out-File -FilePath $CropFilePath -Append
    }
}