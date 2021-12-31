<#
    .SYNOPSIS
        Private utility function to confirm ScaleFilter parameter
    .DESCRIPTION
        Confirms the scaling filter used if passed by the user. If an invalid
        filter is passed, the user will be continuously prompted to input a valid one
    .NOTES
        Moved this logic away from the main script to clean things up a bit
#>

function Confirm-ScaleFilter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Scale,

        [Parameter(Mandatory = $true, Position = 0)]
        [string]$ScaleFilter,

        [Parameter(Mandatory = $false)]
        [switch]$ExitOnError
    )
    
    if ($Scale -eq "Scale") {
        $validArgs = @("fast_bilinear", "neighbor", "area", "gauss", "sinc", "spline", "lanczos", "bilinear", "bicubic")
        if ($validArgs -notcontains $ScaleFilter) {
            if (!$ExitOnError) {
                Write-Host "Invalid scaling filter for 'scale'. Valid parameters: $($validArgs -join ', ')" @warnColors
                do {
                    $ScaleFilter = Read-Host "Enter a valid scaling filter"
                } until ($ScaleFilter -in $validArgs)
            }
            else {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid scaling filter for 'scale'. Valid parameters: $($validArgs -join ', ')"),
                        'ScaleFilter',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $ScaleFilter
                    )
                )
            }
        }
    }
    elseif ($Scale -eq "ZScale") {
        #Verify that zscale is included with build
        if (($(ffmpeg 2>&1) -join ' ') -notmatch "libzimg") {
            $params = @{
                Message           = "libzimg not found. Verify that the --enable-libzimg flag is enabled in ffmpeg"
                RecommendedAction = "Use Scale instead, or re-compile ffmpeg with libzimg"
                Category          = "NotEnabled"
                CategoryActivity  = "libzimg Library"
                TargetObject      = $Scale
                ErrorId           = 5
            }
            Write-Error @params -ErrorAction Stop
        }
                
        $validArgs = @("point", "spline16", "spline36", "bilinear", "bicubic", "lanczos")
        if ($validArgs -notcontains $ScaleFilter) {
            if (!$ExitOnError) {
                Write-Host "Invalid scaling filter for 'scale'. Valid parameters: $($validArgs -join ', ')" @warnColors
                do {
                    $ScaleFilter = Read-Host "Enter a valid scaling filter"
                } until ($ScaleFilter -in $validArgs)
            }
            else {
                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        ([System.ArgumentException]"Invalid scaling filter for 'zscale'. Valid parameters: $($validArgs -join ', ')"),
                        'ScaleFilter',
                        [System.Management.Automation.ErrorCategory]::InvalidArgument,
                        $ScaleFilter
                    )
                )
            }
        }
    }

    return $ScaleFilter
}