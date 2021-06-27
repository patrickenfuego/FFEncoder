function Set-PresetParameters {
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
        'ultrafast'   { $pSubme = 0; $pBIntra = 0; $pBframes = 3; $pPsyRdoq = 0; $pAqMode = 0 }
        'superfast'   { $pSubme = 1; $pBIntra = 0; $pBframes = 3; $pPsyRdoq = 0; $pAqMode = 0 }
        'veryfast'    { $pSubme = 1; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2 }
        'faster'      { $pSubme = 2; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2 }
        'fast'        { $pSubme = 2; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2 }
        'medium'      { $pSubme = 2; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2 }
        'slow'        { $pSubme = 3; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 1; $pAqMode = 2 }
        'slower'      { $pSubme = 4; $pBIntra = 1; $pBframes = 8; $pPsyRdoq = 1; $pAqMode = 2 }
        'veryslow'    { $pSubme = 4; $pBIntra = 1; $pBframes = 8; $pPsyRdoq = 1; $pAqMode = 2 }
        'placebo'     { $pSubme = 5; $pBIntra = 1; $pBframes = 8; $pPsyRdoq = 1; $pAqMode = 2 }
        default       { throw "Unrecognized preset option in Set-PresetParameters" }
    }
    #If user passes custom params, set them. Otherwise, use preset defaults
    $ScriptParams.BIntra ? ($bIntra = 1) : ($bIntra = $pBIntra)
    $ScriptParams.Subme ? ($subme = $ScriptParams.Subme) : ($subme = $pSubme)
    $ScriptParams.BFrames ? ($bframes = $ScriptParams.BFrames) : ($bframes = $pBframes)
    $ScriptParams.PsyRdoq ? ($psyRdoq = $ScriptParams.PsyRdoq) : ($psyRdoq = $pPsyRdoq)
    $ScriptParams.AqMode ? ($aqMode = $ScriptParams.AqMode) : ($aqMode = $pAqMode)

    $params = @{
        Subme   = $subme
        BIntra  = $bIntra
        BFrames = $bframes
        PsyRdoq = $psyRdoq
        AqMode  = $aqMode
    }

    return $params
}