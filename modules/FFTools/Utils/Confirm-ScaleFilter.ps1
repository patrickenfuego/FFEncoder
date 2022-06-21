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
        [string]$Filter,

        [Parameter(Mandatory = $false)]
        [switch]$ExitOnError
    )

    $scaleArgs = @('fast_bilinear', 'neighbor', 'area', 'gauss', 'sinc', 'spline')
    $zscaleArgs = @('point', 'spline16', 'spline36')
    $sharedArgs = @('bilinear', 'bicubic', 'lanczos')

    # Format output display for filters
    $formatScale = $scaleArgs + $sharedArgs |
        Join-String -Separator "`r`n`t`u{2022} " -OutputPrefix "$($boldOn)  Valid Arguments for scale (ffmpeg default)$($boldOff):`n`t`u{2022} "
    $formatZScale = $zscaleArgs + $sharedArgs | 
        Join-String -Separator "`r`n`t`u{2022} " -OutputPrefix "$($boldOn)  Valid Arguments for zscale$($BoldOff):`n`t`u{2022} "

    Write-Verbose "Checking for matching scale filters"
    $scaleType = switch ($Filter) {
        { $_ -in $scaleArgs }  { 'Scale' }
        { $_ -in $zscaleArgs } { 'ZScale' }
        # For shared, set to zscale initially as it's a better library
        { $_ -in $sharedArgs } { 'Zscale' }
        default { $null }
    }

    if (!$scaleType) {
        Write-Host "Invalid scaling filter entered:`n$formatScale`n$formatZScale`n" @errColors

        $params = @{
            Prompt      = 'Enter a valid scaling filter to use: '
            Timeout     = 30000
            Mode        = 'Scale'
            Count       = 4
            InputObject = ($scaleArgs + $zscaleArgs)
        }
        $Filter = Read-TimedInput @params
    }

    # Verify that zscale is included with the build
    if ($scaleType -eq 'ZScale') {
        # If zscale is NOT included
        if (($(ffmpeg 2>&1) -join ' ') -notmatch 'libzimg') {
            # If shared arg, change to Scale. Else, throw an error
            if ($Filter -in $sharedArgs) { $scaleType = 'Scale' }
            else {
                $params = @{
                    Message           = "`u{274C} 'libzimg' was not found in your version of ffmpeg. The selected filter requires zscale"
                    RecommendedAction = "Verify that the '--enable-libzimg' flag is enabled in ffmpeg"
                    Category          = 'NotEnabled'
                    CategoryActivity  = 'Set zscale Filter'
                    TargetObject      = $ScaleFilter
                    ErrorId           = 5
                }
                Write-Error @params

                $st = $bold + $aRed
                $msg = "Choose a filter for scale (ffmpeg default) instead, or type " +
                       "$($st)e[xit]$reset/$st`q[uit]$reset.`n$formatScale"

                Write-Host $msg
                
                $prompt = $psReq ? ("$($ul)Enter a valid scaling filter to use$($ulOff): ") : ("Enter a valid scaling filter to use: ")
                $params = @{
                    Prompt      = $prompt
                    Timeout     = 30000
                    Mode        = 'Scale'
                    Count       = 4
                    InputObject = $scaleArgs
                }
                # If the prompt times out, set scale variables to null
                try {
                    $Filter = Read-TimedInput @params
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
    }

    if ($Filter) {
        Write-Verbose "Returning from Scale function: $scaleType and $Filter"
        return $scaleType, $Filter
    }
    else {
        Write-Error "The prompt timed out waiting for input" -ErrorAction Stop
    }
}
