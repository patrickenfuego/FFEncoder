<#
    .SYNOPSIS
        Function that searches for an existing AC3, EAC3, or DTS audio stream and returns the index if found
    .PARAMETER Codec
        The audio codec to search for. Accepts AC3 (Dolby Digital), EAC3, and DTS Audio as arguments
    .PARAMETER InputFile
        The input file to probe
#>
function Get-AudioStream {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Codec,

        [Parameter(Mandatory = $true)]
        [string]$InputFile
    )
    $codecStr = switch ($Codec) {
        "DTS" { "DTS Core Audio" }
        "AC3" { "Dolby Digital" }
        "EAC3" { "Dolby Digital Plus" }
    }
    $probe = ffprobe -hide_banner -loglevel error -show_streams -select_streams a -print_format json `
        -show_entries "stream=codec_name,channel_layout,channels,index,bit_rate,profile" `
        -i $InputFile

    [int]$i = 0
    $probe | ConvertFrom-Json | Select-Object -ExpandProperty streams | ForEach-Object {
        #Distinguishing between DTS Master Audio and DTS core audio
        if ($_.profile -like $Codec -and $_.codec_name -like $Codec) {
            $bitrate = $_.bit_rate
            $index = $i  
        }
        #Matching for all other supported codecs
        elseif ([string]::IsNullOrEmpty($_.profile) -and $_.codec_name -like $Codec) {
            $bitrate = $_.bit_rate
            $index = $i
        }
        else { $index = $false; $i++ }   
    }
    
    if ($index) { Write-Host "$codecStr stream found at index $index. Bit rate: $($bitrate / 1000) kb/s" }
    else { Write-Host "A $codecStr stream could not be found. Audio will be transcoded to the selected format." @warnColors; Write-Host }
    return $index
}


