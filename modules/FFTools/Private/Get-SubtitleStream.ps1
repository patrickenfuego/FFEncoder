function Get-SubtitleStream {
    [CmdletBinding()]
    param (

        # Parameter help description
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Language
    )

    $subArray = @()
    $langStr = switch ($Language) {
        "eng" { "English" }
        "fre" { "French" }
        "ger" { "German" }
        "spa" { "Spanish" }
        "dut" { "Dutch" }
        "dan" { "Danish" }
        "fin" { "Finnish" }
        "nor" { "Norwegian" }
        "cze" { "Czech" }
        "pol" { "Polish" }
        "chi" { "Chinese" }
        "kor" { "Korean" }
        "gre" { "Greek" }
        "rum" { "Romanian" }
        Default { 
            Write-Host "'$Language' is not supported. No subtitles will be copied. Use the -Help parameter to view supported languages"
            return $null
        }
    }

    $probe = ffprobe -hide_banner -loglevel error -show_streams -select_streams s -show_entries stream=codec_name -print_format json  `
        -i $InputFile
    
    [int]$i = 0
    $probe | ConvertFrom-Json | Select-Object -ExpandProperty streams | ForEach-Object {
        if ($_.tags.language -eq $Language) { $subArray += $i }
        $i++
    }

    if ($subArray.Count -gt 0) {
        Write-Host "$langStr subtitles found! $($subArray.Count) stream(s) will be copied.`n"
        return $subArray
    }
    else {
        Write-Host "No subtitles matching '$Language' were found. Subtitles will not be copied" @warnColors
        Write-Host
        return $null
    }
}
