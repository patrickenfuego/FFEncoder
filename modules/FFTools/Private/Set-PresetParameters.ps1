<#
    .SYNOPSIS
        Sets parameters to encoder presets if not passed by the user
    .DESCRIPTION
        If the user passes a script parameter that alters a standard preset value,
        this function will set and return that value. Otherwise, the encoder's preset
        default will be used for consistency
#>

function Set-PresetParameters {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Preset,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]$Encoder
    )
    #Settings for x265 default variables based on preset
    if ($Encoder -eq 'x265') {
        switch ($Preset) {
            'ultrafast'   { $pSubme = 0; $pBIntra = 0; $pBframes = 3; $pPsyRdoq = 0; $pAqMode = 0; $pRef = 1; $pMerange = 57; $pRCLookahead = 5 }
            'superfast'   { $pSubme = 1; $pBIntra = 0; $pBframes = 3; $pPsyRdoq = 0; $pAqMode = 0; $pRef = 1; $pMerange = 57; $pRCLookahead = 10 }
            'veryfast'    { $pSubme = 1; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2; $pRef = 2; $pMerange = 57; $pRCLookahead = 15 }
            'faster'      { $pSubme = 2; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2; $pRef = 2; $pMerange = 57; $pRCLookahead = 15 }
            'fast'        { $pSubme = 2; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2; $pRef = 3; $pMerange = 57; $pRCLookahead = 15 }
            'medium'      { $pSubme = 2; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 0; $pAqMode = 2; $pRef = 3; $pMerange = 57; $pRCLookahead = 20 }
            'slow'        { $pSubme = 3; $pBIntra = 0; $pBframes = 4; $pPsyRdoq = 1; $pAqMode = 2; $pRef = 4; $pMerange = 57; $pRCLookahead = 25 }
            'slower'      { $pSubme = 4; $pBIntra = 1; $pBframes = 8; $pPsyRdoq = 1; $pAqMode = 2; $pRef = 5; $pMerange = 57; $pRCLookahead = 40 }
            'veryslow'    { $pSubme = 4; $pBIntra = 1; $pBframes = 8; $pPsyRdoq = 1; $pAqMode = 2; $pRef = 5; $pMerange = 57; $pRCLookahead = 40 }
            'placebo'     { $pSubme = 5; $pBIntra = 1; $pBframes = 8; $pPsyRdoq = 1; $pAqMode = 2; $pRef = 5; $pMerange = 92; $pRCLookahead = 60 }
            default       { throw "Unrecognized preset option in Set-PresetParameters - x265" }
        }    
    }
    else {
        # Set psy-trellis here purely for convenience. It's not an actual preset parameter
        switch ($Preset) {
            'ultrafast'   { $pSubme = 0; $pBframes = 0; $pAqMode = 0; $pMerange = 16; $pRef = 1; $pRCLookahead = 0; $pPsyRdoq = 0.00 }
            'superfast'   { $pSubme = 1; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 1; $pRCLookahead = 0; $pPsyRdoq = 0.00 }
            'veryfast'    { $pSubme = 2; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 1; $pRCLookahead = 10; $pPsyRdoq = 0.00 }
            'faster'      { $pSubme = 4; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 2; $pRCLookahead = 20; $pPsyRdoq = 0.00 }
            'fast'        { $pSubme = 6; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 2; $pRCLookahead = 30; $pPsyRdoq = 0.00 }
            'medium'      { $pSubme = 6; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 3; $pRCLookahead = 40; $pPsyRdoq = 0.00 }
            'slow'        { $pSubme = 8; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 5; $pRCLookahead = 50; $pPsyRdoq = 0.00 }
            'slower'      { $pSubme = 9; $pBframes = 3; $pAqMode = 1; $pMerange = 16; $pRef = 8; $pRCLookahead = 60; $pPsyRdoq = 0.00 }
            'veryslow'    { $pSubme = 10; $pBframes = 8; $pAqMode = 1; $pMerange = 24; $pRef = 16; $pRCLookahead = 60; $pPsyRdoq = 0.00 }
            'placebo'     { $pSubme = 11; $pBframes = 16; $pAqMode = 1; $pMerange = 24; $pRef = 16; $pRCLookahead = 60; $pPsyRdoq = 0.00 }
            default       { throw "Unrecognized preset option in Set-PresetParameters - x264" }
        }
    }

    # If user passes custom params, set them. Otherwise, use preset defaults
    $subme = $Settings.Subme     ? $Settings.Subme : $pSubme
    $bframes = $Settings.BFrames ? $Settings.BFrames : $pBframes
    $aqMode = $Settings.AqMode   ? $Settings.AqMode : $pAqMode
    $ref = $Settings.Ref         ? $Settings.Ref : $pRef
    $merange = $Settings.Merange ? $Settings.Merange : $pMerange
    $RCL = $Settings.RCLookahead ? $Settings.RCLookahead : $pRCLookahead
    $psyRdoq = $Settings.PsyRdoq ? $Settings.PsyRdoq : $pPsyRdoq

    # Save base return parameters
    $params = @{
        Subme       = $subme
        BFrames     = $bframes
        AqMode      = $aqMode
        Ref         = $ref
        Merange     = $merange
        RCLookahead = $RCL
        PsyRdoq     = $psyRdoq
    }

    if ($Encoder -eq 'x265') {
        $bIntra = $Settings.BIntra ? 1 : $pBIntra
        $params['BIntra'] = $bIntra
    }

    return $params
}
