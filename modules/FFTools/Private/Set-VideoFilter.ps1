<#
    .SYNOPSIS
        Private function for setting video filters
    .DESCRIPTION
        Sets video filters passed via the script. If manual filters
        are passed via -FFMpegExtra parameter, they are joined with
        other script parameters here
#>

function Set-VideoFilter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [int[]]$CropDimensions,

        [Parameter(Mandatory = $false, Position = 1)]
        [hashtable]$Scale,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Unsharp,

        [Parameter(Mandatory = $false, Position = 2)]
        [array]$FFMpegExtra,

        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$Deinterlace,

        [Parameter(Mandatory = $false)]
        [hashtable]$NLMeans
    )

    # Initialize safe defaults
    [array]$vfArray = $null
    $nlStr = $null
    $unsharpStr = $null

    # Verify NLMeans if passed or use defaults
    if ($PSBoundParameters['NLMeans']) {
        if (!$NLMeans.ContainsKey('s')) {
            Write-Warning "No NLMeans strength value specified. Using default: 1.0"
            $NLMeans.s = 1.0
        }
        if (!$NLMeans.ContainsKey('p')) {
            $NLMeans.p = 7
        }
        if (!$NLMeans.ContainsKey('pc')) {
            $NLMeans.pc = 5
        }
        if (!$NLMeans.ContainsKey('r')) {
            $NLMeans.r = 3
        }
        if (!$NLMeans.ContainsKey('rc')) {
            $NLMeans.rc = 3
        }
        $nlStr = "nlmeans=$($NLMeans['s']):$($NLMeans['p']):$($NLMeans['pc']):$($NLMeans['r']):$($NLMeans['rc'])"
    }

    # Set size & strength of unsharp filter if presets are used
    if ($PSBoundParameters['Unsharp'] -and $Unsharp) {
        if ($Unsharp.Size -notlike 'custom=*') {
            $size, $type = switch ($Unsharp.Size) {
                'luma_small'     { 'lx=3:ly=3', 'luma' }
                'luma_medium'    { 'lx=5:ly=5', 'luma' }
                'luma_large'     { 'lx=7:ly=7', 'luma' }
                'chroma_small'   { 'cx=3:cy=3', 'chroma' }
                'chroma_medium'  { 'cx=5:cy=5', 'chroma' }
                'chroma_large'   { 'cx=7:cy=7', 'chroma' }
                'yuv_small'      { 'lx=3:ly=3:cx=3:cy=3', 'yuv' }
                'yuv_medium'     { 'lx=5:ly=5:cx=5:cy=5', 'yuv' }
                'yuv_large'      { 'lx=7:ly=7:cx=7:cy=7', 'yuv' }
                default {
                    Write-Error "Unknown unsharp size argument. This should be unreachable" -ErrorAction Stop
                }
            }
            # Set strength if preset is used
            $strength = switch ($Unsharp.Strength) {
                'sharpen_mild'  { 
                    switch ($type) {
                        'luma'   { 'la=1.0' }
                        'chroma' { 'ca=1.0' }
                        'yuv'   { 'la=1.0:ca=1.0'}
                    }
                 }
                 'sharpen_medium' {
                    switch ($type) {
                        'luma'   { 'la=1.5' }
                        'chroma' { 'ca=1.5' }
                        'yuv'   { 'la=1.5:ca=1.5'}
                    }
                }
                'sharpen_strong' {
                    switch ($type) {
                        'luma'   { 'la=2.0' }
                        'chroma' { 'ca=2.0' }
                        'yuv'   { 'la=2.0:ca=2.0'}
                    }
                }
                'blur_mild'  { 
                    switch ($type) {
                        'luma'   { 'la=-1.0' }
                        'chroma' { 'ca=-1.0' }
                        'yuv'   { 'la=-1.0:ca=-1.0'}
                    }
                }
                 'blur_medium' {
                    switch ($type) {
                        'luma'   { 'la=-1.5' }
                        'chroma' { 'ca=-1.5' }
                        'yuv'   { 'la=-1.5:ca=-1.5'}
                    }
                }
                'blur_strong' {
                    switch ($type) {
                        'luma'   { 'la=-2.0' }
                        'chroma' { 'ca=-2.0' }
                        'yuv'   { 'la=-2.0:ca=-2.0'}
                    }
                }
                default { 
                    Write-Error "Unknown Unsharp strength or type, filter will be skipped. This should be unreachable"
                    $null
                }
            }

            [string]$unsharpStr = $strength ? ("unsharp=$size`:$strength") : $null
        }
        # User passed a custom unsharp string
        elseif ($Unsharp.Size -like 'custom=*') {
            if ($Unsharp.Size -like 'unsharp=*') {
                [string]$unsharpStr = ($Unsharp.Size.Replace('custom=', '')).Trim()
            }
            else {
                [string]$unsharpStr = ($Unsharp.Size.Replace('custom=', 'unsharp=')).Trim()
            }
        }
        # Failsafe
        else {
            Write-Error "Unknown argument for unsharp, filter will be skipped. This should be unreachable"
            $unsharpStr = $null
        }
    }

    # If manual crop dimensions are passed, parse them out
    if ($CropDimensions -contains -1) {
        [string]$vfStr = $FFMpegExtra.Where({ $_['-vf'] }, 'SkipUntil', 1) |
            Select-Object -ExpandProperty '-vf'
        $splitVf = ($vfStr -split ',').Trim()
        $cropStr = $splitVf.Where({ $_ -like 'crop*' })

        $match = [regex]::Matches($cropStr, "crop=w?=?(?<width>\d{3,4}):h?=?(?<height>\d{3,4})")
        # Perform regex match to get crop dimensions
        if ($match) {
            $CropDimensions = @($match.Groups[1].Value, $match.Groups[2].Value)

            # Remove crop args from the vf string and save the rest
            $manVfString = $splitVf.Where({ $_ -notlike 'crop*' }) -join ','
        }
        else {
            $msg = "Error parsing crop parameters from video filter string in FFMpegExtra"
            $params = @{
                Exception         = [System.ArgumentException]::new($msg)
                RecommendedAction = 'Verify crop parameters'
                Category          = 'InvalidArgument'
                CategoryActivity  = 'Parsing crop values for scaling'
                TargetObject      = $vfStr
                ErrorId           = 80
            }
            Write-Error @params -ErrorAction Stop
        }
    }
    else {
        # Parse out manual video filter if present
        $manVfString = $FFMpegExtra.Where({ $_['-vf'] }) |
            Select-Object -ExpandProperty '-vf'
    } 

    # Setup scaling related variables
    if ($PSBoundParameters['Scale']) {
        [int]$scaleRes = $Scale.Resolution -replace 'p', ''
        [string]$sType = $Scale.Scale.ToLower()
        #set flag for filter
        $set = switch ($sType) {
            'scale' { 'flags' }
            'zscale' { 'f' }
        }
        # Scaling down from 2160p
        if ($CropDimensions[0] -gt 3000) {
            $widthRes = switch ($Scale.Resolution) {
                '1080p' { $CropDimensions[0] / 2 }
                '720p' { $CropDimensions[0] / 3 }
            }
        }
        elseif ($CropDimensions[0] -gt 1300 -and $CropDimensions[0] -lt 3000) {
            # scale up/down 1080p
            $widthRes = ($CropDimensions[1] -lt $scaleRes) ?
                ($CropDimensions[0] * 2) : 
                ($CropDimensions[0] / 1.5)
        }
        # scaling up from 720p
        elseif ($CropDimensions[0] -lt 1300) {
            $widthRes = switch ($Scale.Resolution) {
                '1080p' { $CropDimensions[0] * 1.5 }
                '2160p' { $CropDimensions[0] * 3 }
            }
        }
        else {
            $msg = "Crop dimensions were not found or are out of range. Cannot scale."
            $params = @{
                Exception         = [System.ArgumentException]::new($msg)
                RecommendedAction = 'Verify scaling dimensions'
                Category          = 'InvalidArgument'
                CategoryActivity  = 'Setting crop values for scaling'
                TargetObject      = $Scale
                ErrorId           = 81
            }
            Write-Error @params -ErrorAction Stop
        }
    }
    
    # Build argument array and join
    $tmpArray = @(
        "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])"
        if ($Deinterlace) {
            'yadif'
        }
        if ($PSBoundParameters['Scale']) {
            "$sType=w=$widthRes`:h=-2:$set=$($Scale.ScaleFilter)"
        }
        if ($unsharpStr) {
            $unsharpStr
        }
        if ($manVfString) {
            $manVfString
        }
        if ($nlStr) {
            $nlStr
        }
    )
    
    # If string is not empty, generate array
    if ($tmpArray) {
        $vfString = $tmpArray -join ','
        $vfArray = @('-vf', "`"$vfString`"")
    }
    else { $vfArray = $null }

    Write-Verbose "VIDEO FILTER ARRAY:`n  $($vfArray -join ' ')`n"
    return $vfArray
}
