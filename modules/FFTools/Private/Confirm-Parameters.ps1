<#
    .SYNOPSIS
        Validate input parameter values for shared settings in x264/x265
    .DESCRIPTION
        Many settings are shared in x264/x265 but have different acceptable values/ranges. This function verifies
        that user entered values do not exceed the specified encoder's criteria (where applicable)
    .NOTES
        Receives values by reference so they can be modified without returning them from the child scope
#>

function Confirm-Parameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Encoder,

        [Parameter(Mandatory = $false)]
        [ref]$Subme,

        [Parameter(Mandatory = $false)]
        [ref]$Threads,

        [Parameter(Mandatory = $false)]
        [ref]$QComp,

        [Parameter(Mandatory = $false)]
        [ref]$Level,

        [Parameter(Mandatory = $false)]
        [ref]$AQMode
    )

    $x264Levels = @('1', '1b', '1.1', '1.2', '1.3', '2', '2.1', '2.2', '3', '3.1', '3.2', '4', '4.1', '4.2', '5', '5.1')
    $x265Levels = @('1', '2', '2.1', '21', '3', '3.1', '31', '4', '4.1', '41', '5', '5.1', '51', '5.2', '52', '6', '6.1', '61', '6.2', '62', '8.5', '85')

    # Validate shared encoder parameters
    if ($PSBoundParameters['Subme'].Value -gt 7 -and $Encoder -eq 'x265') {
        Write-Warning "Maximum subme value exceeded for x265. Changing value to $($aBlue)7$aYellow (max)"
        $Subme.Value = 7
    }
    if ($PSBoundParameters['AQMode'].Value -gt 3 -and $Encoder -eq 'x264') {
        Write-Warning "Unknown aq-mode for x264: $aRed$($AQMode.Value)$aYellow. Changing value to $($aBlue)1$aYellow (default)"
        $AqMode.Value = 1
    }
    if ($PSBoundParameters['Qcomp'].Value -lt 0.50 -and $Encoder -eq 'x265') {
        Write-Warning "Invalid qcomp value for x265: $aRed$($QComp.Value)$aYellow. Value must be between $($aBlue)0.50 - 1.0$aYellow. Changing value to 0.60 (default)"
        $Qcomp.Value = 0.60
    }
    if ($PSBoundParameters['Threads'].Value -gt 16 -and $Encoder -eq 'x265') {
        Write-Warning "Invalid frame-threads value for x265: $aRed$($Threads.Value)$aYellow. Value must be between $($aBlue)1 - 16$aYellow. Changing value to 0 (autodetect)"
        $Threads.Value = 0
    }
    # Validate encoder Level. If an invalid level is passed, set to $null and let the encoder decide
    if ($PSBoundParameters['Level'].Value -and ($PSBoundParameters['Level'].Value -notin $x264Levels) -and ($Encoder -eq 'x264')) {
        Write-Warning "Invalid x264 Level: $aRed$($Level.Value)$aYellow. Valid inputs: $aBlue< $($x264Levels -join ' | ') >$aYellow. Reverting to encoder default (unset)"
        $Level.Value = $null
    }
    elseif ($PSBoundParameters['Level'].Value -and ($PSBoundParameters['Level'].Value -notin $x265Levels) -and ($Encoder -eq 'x265')) {
        Write-Warning "Invalid x265 Level: $aRed$($Level.Value)$aYellow. Valid inputs: $aBlue< $($x265Levels -join ' | ') >$aYellow. Reverting to encoder default (unset)"
        $Level.Value = $null
    }

    Write-Host ""
}
