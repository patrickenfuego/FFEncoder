<#
    .SYNOPSIS
        Batch encode multiple files using FFEncoder.ps1
    .DESCRIPTION
        This basic script is useful if you want to encode multiple files using the
        same input parameters without re-entering them multiple times
    .PARAMETER RootDirectory
        Root of directory holding the files to convert
    .PARAMETER OutputDirectory
        Desired output directory of encoded files
    .NOTES
        All files ending in mkv, mp4, ts, or m2ts will be included while iterating
        the input directory

        Output file name is dynamically generated based on the output directory and the
        input file name. '(1)' is appended to ensure no overwrites
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript(
        {
            if (!(Test-Path $_ -PathType Container)) { 
                throw "Input directory does not exist"
                $false
            }
            else { $true }
        }
    )]
    [string]$RootDirectory,

    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateScript(
        {
            if (!(Test-Path $_ -PathType Container)) { 
                throw "Output directory does not exist"
                $false
            }
            else { $true }
        }
    )]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Parameters
)

#Current valid Parameter keys for FFEncoder
$validKeys = @(
    'Help'
    'InputPath'
    'Audio'
    'AudioBitrate'
    'Stereo'
    'Audio2'
    'AudioBitrate2'
    'Stereo2'
    'Subtitles'
    'Preset'
    'CRF'
    'VideoBitrate'
    'FirstPassType'
    'Deblock'
    'AqMode'
    'AqStrength'
    'PsyRd'
    'PsyRdoq'
    'NoiseReduction'
    'TuDepth'
    'LimitTu'
    'QComp'
    'BFrames'
    'BIntra'
    'Subme'
    'StrongIntraSmoothing'
    'Level'
    'VBV'
    'FrameThreads'
    'FFMpegExtra'
    'x265Extra'
    'TestFrames'
    'TestStart'
    'RemoveFiles'
    'Deinterlace'
    'Scale'
    'ScaleFilter'
    'Resolution'
    'GenerateReport'
    'SkipDolbyVision'
    'SkipHDR10Plus'
    'OutputPath'
)

$ffencoder = Join-Path (Split-Path $PSScriptRoot -Parent) -ChildPath "FFEncoder.ps1"
Write-Verbose "FFEncoder path is: $ffencoder"

#confirm parameters entered match valid keys
$confirmedParams = @{}
foreach ($item in $Parameters.GetEnumerator()) {
    if ($item.Name -in $validKeys) {
        $confirmedParams[$item.Name] = $item.Value
    }
}

#Run batch encode on all media files in RootDirectory
Get-ChildItem "$RootDirectory\*" -Include '*.mkv', '*.mp4', '*.m2ts', '*.ts' | ForEach-Object {
    try {
        $outFile = Join-Path $OutputDirectory -ChildPath "$($_.Name)(1)$($_.Extension)"
        & $ffencoder @confirmedParams -InputPath $_.FullName -OutputPath $outFile
    }
    catch {
        Write-Error "An exception occurred. Skipping..." -CategoryActivity "Encoding $($_.Name)"
        continue
    }
}
