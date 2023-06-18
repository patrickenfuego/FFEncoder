<#
    .SYNOPSIS       
        Function that gathers HDR metadata automatically using ffprobe
    .PARAMETER InputFile
        Path to source file. This is the file to be encoded
    .PARAMETER HDR10PlusPath
        Output path of the json file containing HDR10+ metadata
    .PARAMETER DolbyVisionPath
        Output path of the RPU binary file containing Dolby Vision metadata
    .PARAMETER SkipDolbyVision
        Skip Dolby Vision metadata extraction
    .PARAMETER SkipHDR10Plus
        Skip HDR10+ metadata extraction
    .PARAMETER HDR10PlusSkipReorder
        Skip reordering of HDR10+ metadata. Use this when metadata ordering is incorrect.
        Determining whether this is necessary must be confirmed manually.
    .Outputs
        PowerShell hashtable containing relevant HDR metadata
    .NOTES
        Calls utility function(s) to check for and generate HDR10+/DoVi metadata
    
        If the HDR10+/DoVi parser cannot be found, this function will ignore it and only grab
        the base layer metadata.
#>

function Get-HDRMetadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript(
            { Test-Path $_ },
            ErrorMessage = "Input file '{0}' does not exist"
        )]
        [string]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$HDR10PlusPath,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$DolbyVisionPath,

        [Parameter(Mandatory = $false)]
        [bool]$SkipDolbyVision,

        [Parameter(Mandatory = $false)]
        [bool]$SkipHDR10Plus,

        [Parameter(Mandatory = $false)]
        [switch]$HDR10PlusSkipReorder
    )

    # Constants for mastering display color primaries
    Set-Variable -Name DCI_P3 -Value "G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)" -Option Constant
    Set-Variable -Name BT_2020 -Value "G(8500,39850)B(6550,2300)R(35400,14600)WP(15635,16450)" -Option Constant

    Write-Host "Retrieving HDR Metadata..."

    # Gather HDR metadata using ffprobe
    $probe = ffprobe -hide_banner -loglevel error -select_streams V -print_format json `
        -show_frames -read_intervals "%+#5" -show_entries "frame=color_space,color_primaries,color_transfer,side_data_list,pix_fmt" `
        -i $InputFile

    $metadata = $probe | ConvertFrom-Json | 
        Select-Object -ExpandProperty frames | 
            Where-Object { $_.pix_fmt -like "yuv420p10le" } |
                Select-Object -First 1

    if (!$metadata) {
        Write-Warning "10-bit pixel format could not be found within the first 5 frames. Ensure the input file supports HDR."
        Write-Host "HDR metadata will not be copied" @warnColors
        return $false
    }

    [string]$pixelFmt = $metadata.pix_fmt
    [string]$colorSpace = $metadata.color_space
    [string]$colorPrimaries = $metadata.color_primaries
    [string]$colorTransfer = $metadata.color_transfer
    # Compares the red coordinates to determine the mastering display color primaries
    if ($metadata.side_data_list[0].red_x -match "35400/\d+" -and 
        $metadata.side_data_list[0].red_y -match "14600/\d+") {
        $masterDisplayStr = $BT_2020
    }
    elseif ($metadata.side_data_list[0].red_x -match "34000/\d+" -and
        $metadata.side_data_list[0].red_y -match "16000/\d+") {
        $masterDisplayStr = $DCI_P3
    }
    else { 
        Write-Error "Unknown mastering display colors found. Only BT.2020 and DCI-P3 are supported." -ErrorAction Stop
    }
    # HDR min and max luminance values
    [int]$minLuma = $metadata.side_data_list[0].min_luminance -replace "/.*", ""
    [int]$maxLuma = $metadata.side_data_list[0].max_luminance -replace "/.*", ""
    # MAx content light level and max frame average light level
    $maxCLL = $metadata.side_data_list[1].max_content
    $maxFAL = $metadata.side_data_list[1].max_average
   
    $metadataObj = @{
        PixelFmt       = $pixelFmt
        ColorSpace     = $colorSpace
        ColorPrimaries = $colorPrimaries
        Transfer       = $colorTransfer
        MasterDisplay  = $masterDisplayStr
        MaxLuma        = $maxLuma
        MinLuma        = $minLuma
        MaxCLL         = $maxCLL
        MaxFAL         = $maxFAL
    }

    if (!$metadataObj) {
        # Throw a function terminating error
        $msg = 'HDR object is null - ffprobe may have failed to retrieve the data. Results might be incorrect'
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                ([System.ArgumentNullException]$msg),
                'metadataObj',
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $metadataObj
            )
        )
    }
    else {
        # Check if input has HDR10+ metadata and generate json if skip not present
        if (!$SkipHDR10Plus -and (Test-Path $HDR10PlusPath)) {
            $params = @{
                InputFile            = $InputFile
                HDR10PlusPath        = $HDR10PlusPath
                HDR10PlusSkipReorder = $HDR10PlusSkipReorder
            }
            $isHDR10Plus = Confirm-HDR10Plus @params
        }
        else { 
            Write-Verbose "Skipping HDR10+"
            $isHDR10Plus = $false
        }
        $metadataObj['HDR10Plus'] = $isHDR10Plus

        # Check if input has Dolby Vision metadata and generate rpu if skip not present
        if (!$SkipDolbyVision) {
            $isDV = Confirm-DolbyVision -InputFile $InputFile -DolbyVisionPath $DolbyVisionPath -DropHDR10Plus:$SkipHDR10Plus
        }
        else { 
            Write-Verbose "Skipping Dolby Vision"
            $isDV = $false 
        }
        $metadataObj['DV'] = $isDV

        Write-Host "$("`u{25c7}" * 2) HDR METADATA SUCCESSFULLY RETRIEVED $("`u{25c7}" * 2)" @progressColors
        Write-Host ""

        return $metadataObj
    }
}