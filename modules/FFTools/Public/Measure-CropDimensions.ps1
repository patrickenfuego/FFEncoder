<#
    .SYNOPSIS    
        Enumerates the crop file to find the max crop width and height values
    .PARAMETER FilePath
        The path to the crop file
    .PARAMETER Resolution
        Resizing resolution. Used for display purposes.
#>
function Measure-CropDimensions
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript(
            { Test-Path $_ },
            ErrorMessage = "Crop file path '{0}' does not exist"
        )]
        [string]$FilePath,

        [Parameter(Mandatory = $false, Position = 1)]
        [AllowNull()]
        [string]$Resolution
    )

    $cropContent = [System.IO.File]::ReadAllLines($FilePath)

    if (!$cropContent) {
        $msg = 'Crop file content is empty. Delete the existing file ' +
               'and re-run the script.'
        $params = @{
            RecommendedAction = 'Delete crop file and re-run the script'
            Category          = 'ReadError'
            Exception         = [System.IO.EndOfStreamException]::new($msg)
            CategoryActivity  = 'Crop File Measurement'
            TargetObject      = $FilePath
            ErrorId           = 6
        }
        Write-Error @params -ErrorAction Stop
    }

    Write-Host "`nScanning crop file for dimensions..."
    
    $cropHeight = $cropWidth = 0
    foreach ($line in $cropContent) {
        if ($line -match "Parsed_cropdetect.*w:(?<width>\d+) h:(?<height>\d+).*") {
            [int]$height = $Matches.height
            [int]$width = $Matches.width
    
            if ($width -gt $cropWidth) { $cropWidth = $width }
            if ($height -gt $cropHeight) { $cropHeight = $height }
        }
    }
    
    # Exit function if either or both crop values are 0
    if ($cropWidth -eq 0 -or $cropHeight -eq 0) {
        if ($cropWidth -eq 0 -and $cropHeight -eq 0) {
            $msg = "Both crop values cannot be equal to 0"
            $src = $cropWidth
        }
        elseif ($cropWidth -eq 0 -and $cropHeight -gt 0) {
            $msg = "Crop width cannot be equal to zero"
            $src = $cropWidth
        }
        else {
            $msg = "Crop height cannot be equal to zero"
            $src = $cropHeight
        }
        $params = @{
            RecommendedAction = 'Check the input file and try again'
            Category          = 'InvalidResult'
            Exception         = [System.ArgumentException]::new($msg)
            CategoryActivity  = 'Crop File Measurement'
            TargetObject      = $src
            ErrorId           = 7
        }
        Write-Error @params -ErrorAction Stop
    }

    Write-Host "$("`u{25c7}" * 2) CROP DIMENSIONS SUCCESSFULLY RETRIEVED $("`u{25c7}" * 2)" @progressColors
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

    return @($cropWidth, $cropHeight)
}
