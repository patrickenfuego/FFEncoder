<#
    Enumerates the crop file to find the max crop width and height

    .PARAMETER cropPath
        The path to the crop file
#>
function Measure-CropDimensions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$CropFilePath
    )

    if (!$CropFilePath) { throw "There was an issue reading the crop file. This usually happens when an empty file was generated on a previous run." }
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
    }
    else {
        Write-Host "** CROP DIMENSIONS SUCCESSFULLY RETRIEVED ** " @progressColors
        Write-Host "Dimensions: $cropWidth x $cropHeight`n"
        return @($cropWidth, $cropHeight) 
    }
    
}