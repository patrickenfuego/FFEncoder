function Get-SubtitleStream {
    [CmdletBinding()]
    param (

        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Language
    )

    $cleanLanguage = $Language.Replace('!', '')
    # Set normalized name based on ISO code
    $langStr = switch ($cleanLanguage) {
        'eng' { 'English' }
        'fre' { 'French' }
        'ger' { 'German' }
        'spa' { 'Spanish' }
        'dut' { 'Dutch' }
        'nld' { 'Dutch' }
        'dan' { 'Danish' }
        'fin' { 'Finnish' }
        'nor' { 'Norwegian' }
        'rus' { 'Russian' }
        'cze' { 'Czech' }
        'pol' { 'Polish' }
        'chi' { 'Chinese' }
        'zho' { 'Chinese' }
        'kor' { 'Korean' }
        'rum' { 'Romanian' }
        'gre' { 'Greek' }
        'ell' { 'Greek' }
        'hin' { 'Hindi' }
        'ind' { 'Indonesian' }
        'ara' { 'Arabic' }
        'bul' { 'Bulgarian' }
        'est' { 'Estonian' }
        'heb' { 'Hebrew' }
        'slv' { 'Slovenian' }
        'tur' { 'Turkish' }
        'vie' { 'Vietnamese' }
        Default { 
            Write-Host "'$Language' is not supported. No subtitles will be copied. Use the -Help parameter to view supported languages"
            return $null
        }
    }

    $probe = ffprobe -hide_banner -loglevel error -show_streams -select_streams s -show_entries stream=codec_name -print_format json  `
        -i $InputFile
    
    [int]$i = 0
    [string[]]$subArray = $probe | ConvertFrom-Json | Select-Object -ExpandProperty streams | ForEach-Object {
        if (($_.tags.language -like $Language) -and $Language -notlike '!*') { $i }
        # Add subs that don't match the negation
        elseif ($Language -like '!*' -and ($_.tags.language -notlike $Language.Replace('!', ''))) { $i }

        $i++
    }

    if ($subArray.Count -gt 0) {
        ($Language -notlike '!*') ?
        ( Write-Host "$langStr subtitles found! $($subArray.Count) stream(s) will be copied.`n") :
        ( Write-Host "Non-$langStr subtitles found! $($subArray.Count) stream(s) will be copied.`n")
       
        return $subArray
    }
    else {
        Write-Host "No subtitles matching '$Language' were found. Subtitles will not be copied" @warnColors
        Write-Host
        return $null
    }
}
