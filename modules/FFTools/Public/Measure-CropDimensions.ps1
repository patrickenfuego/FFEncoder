<#
    Enumerates the crop file to find the max crop width and height values

    .PARAMETER cropPath
        The path to the crop file
#>
function Measure-CropDimensions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CropFilePath,

        [Parameter(Mandatory = $false, Position = 1)]
        [AllowNull()]
        [string]$Resolution
    )

    if (!$CropFilePath) { 
        throw "There was an issue reading the crop file. This usually happens when an empty file was generated on a previous run." 
    }
    Write-Host "`nScanning crop file for dimensions..."
    $cropFile = Get-Content $CropFilePath
    $cropHeight = 0
    $cropWidth = 0
    foreach ($line in $CropFile) {
        if ($line -match "Parsed_cropdetect.*w:(?<width>\d+) h:(?<height>\d+).*") {
            [int]$height = $Matches.height
            [int]$width = $Matches.width
    
            if ($width -gt $cropWidth) { $cropWidth = $width }
            if ($height -gt $cropHeight) { $cropHeight = $height }
        }
    }
    
    if ($cropWidth -eq 0 -or $cropHeight -eq 0) {
        throw "One or both of the crop values are equal to 0. Check the input path and try again."
        exit 2
    }
    elseif ($cropWidth -ge 3000) { $enableHDR = $true }
    else { $enableHDR = $false }

    Write-Host "** CROP DIMENSIONS SUCCESSFULLY RETRIEVED ** " @progressColors
    if (!$PSBoundParameters['Resolution']) {
        Write-Host "Dimensions: $cropWidth x $cropHeight`n"
    }
    elseif ($Resolution -eq '1080p') {
        switch ($cropWidth) {
            { $_ -ge 3000 }   { Write-Host "Dimensions (Downscaled): $($cropWidth / 2) x $($cropHeight / 2)`n" }
            { $_ -le 1280 }   { Write-Host "Dimensions (Upscaled): $($cropWidth * 1.5) x $([math]::Ceiling($cropHeight * 1.5))`n" }
        }
    }
    elseif ($Resolution -eq '2160p') {
        switch ($cropWidth) {
            { $_ -gt 1280 -and $_ -le 1920 }  { Write-Host "Dimensions (Upscaled): $($cropWidth * 2) x $($cropHeight * 2)`n" }
            { $_ -le 1280 }                   { Write-Host "Dimensions (Upscaled): $($cropWidth * 3) x $($cropHeight * 3)`n" }
        }
    }
    elseif ($Resolution -eq '720p') {
        switch ($cropWidth) {
            { $_ -ge 3000 }                   { Write-Host "Dimensions (Downscaled): $($cropWidth / 3) x $([math]::Ceiling($cropHeight / 3))`n" }
            { $_ -gt 1280 -and $_ -le 1920}   { Write-Host "Dimensions (Downscaled): $($cropWidth / 1.5) x $([math]::Ceiling($cropHeight / 1.5))`n" }
        }
    }
    else {
        Write-Warning "Failed to print crop dimensions"
    }

    return @($cropWidth, $cropHeight, $enableHDR) 
}
