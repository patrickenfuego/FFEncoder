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

        [Parameter(Mandatory = $false, Position = 2)]
        [array]$FFMpegExtra,

        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$Deinterlace,

        [Parameter(Mandatory = $false)]
        [hashtable]$NLMeans
    )

    [array]$vfArray = $null

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

    # if manual crop dimensions are passed, parse them out
    if ($CropDimensions -contains -1) {
        [string]$cropStr = $FFMpegExtra.Where({ $_['-vf'] -match 'crop' }) | 
            Select-Object -ExpandProperty '-vf'
        if ($cropStr -match "crop=w?=?(?<width>\d{3,4}):h?=?(?<height>\d{3,4})") {
            $width, $height = $Matches.width, $Matches.height
            $CropDimensions = @($width, $height)
        }
        else {
            $msg = "Error parsing crop parameter regex in FFMpegExtra"
            $params = @{
                Exception         = [System.ArgumentException]::new($msg)
                RecommendedAction = 'Verify crop parameters'
                Category          = 'InvalidArgument'
                CategoryActivity  = 'Parsing crop values for scaling'
                TargetObject      = $cropStr
                ErrorId           = 80
            }
            Write-Error @params -ErrorAction Stop 
        }
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

    # If array contains -1, manual crop params were set via FFMpegExtra parameter
    $customCrop = $false
    if ($CropDimensions -contains -1) {
        $customCrop = $true
        $manVfString = $null
        foreach ($i in $FFMpegExtra) {
            if ($i -is [hashtable]) {
                foreach ($j in $i.GetEnumerator()) {
                    if ($j.Name -eq '-vf') {
                        [string]$manVfString = $j.Value
                        break
                    }
                }
            }
        }
    }
    
    # Build argument array and join
    [array]$tmpArray = @(
        if ($Deinterlace) {
            "yadif"
        }
        if (!$customCrop) {
            "crop=w=$($CropDimensions[0]):h=$($CropDimensions[1])"
        }
        if ($PSBoundParameters['Scale']) {
            "$sType=w=$widthRes`:h=-2:$set=$($Scale.ScaleFilter)"
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
        $vfString = $tmpArray -join ","
        $vfArray = @('-vf', "`"$vfString`"")
    }

    Write-Verbose "VIDEO FILTER ARRAY:`n$($vfArray -join ' ')`n"
    return $vfArray
}
