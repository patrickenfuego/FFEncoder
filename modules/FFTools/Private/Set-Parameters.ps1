function Set-Parameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]$ScriptParams,

        # Parameter help description
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Preset
    )
    #Settings for x265 default variables based on preset
    switch ($Preset) {
        'ultrafast'   { $pSubme = 0; $pBIntra = 0; $pBframes = 3 }
        'superfast'   { $pSubme = 1; $pBIntra = 0; $pBframes = 3 }
        'veryfast'    { $pSubme = 1; $pBIntra = 0; $pBframes = 4 }
        'faster'      { $pSubme = 2; $pBIntra = 0; $pBframes = 4 }
        'fast'        { $pSubme = 2; $pBIntra = 0; $pBframes = 4 }
        'medium'      { $pSubme = 2; $pBIntra = 0; $pBframes = 4 }
        'slow'        { $pSubme = 3; $pBIntra = 0; $pBframes = 4 }
        'slower'      { $pSubme = 4; $pBIntra = 1; $pBframes = 8 }
        'veryslow'    { $pSubme = 4; $pBIntra = 1; $pBframes = 8 }
        'placebo'     { $pSubme = 5; $pBIntra = 1; $pBframes = 8 } 
    }

    if ($ScriptParams.BIntra) { $bIntra = 1 } else { $bIntra = $pBIntra }

    if ($ScriptParams.Subme) { $subme = $ScriptParams.Subme }
    else { $subme = $pSubme }

    if ($ScriptParams.BFrames) { $bframes = $ScriptParams.BFrames }
    else { $bframes = $pBframes }

    $params = @{
        Subme   = $subme
        BIntra  = $bIntra
        BFrames = $bframes
    }

    return $params
}