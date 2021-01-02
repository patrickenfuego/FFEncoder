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
    Write-Host "Crop Dimensions: "`n$cropWidth "x" $cropHeight`n
    if ($cropWidth -eq 0 -or $cropHeight -eq 0) {
        throw "One or both of the crop values are equal to 0. Check the input path and try again."
    }
    else { return @($cropWidth, $cropHeight) }
    
}