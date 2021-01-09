<#
    function that searches for an existing AC3 or DTS audio stream and returns the index if found.

    .PARAMETER Codec
        The audio codec to search for. Accepts AC3 (Dolby Digital) and DTS Audio as arguments
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
    }
    $probe = ffprobe -hide_banner -loglevel error -show_streams -select_streams a -print_format json `
        -show_entries "stream=codec_name,channel_layout,channels,index,bit_rate,profile" `
        -i $InputFile

    [int]$i = 0
    $probe | ConvertFrom-Json | Select-Object -ExpandProperty streams | ForEach-Object {
        if ($_.profile -like $Codec -and $_.codec_name -like $Codec) {
            $bitrate = $_.bit_rate
            $index = $i  
        }
        elseif ([string]::IsNullOrEmpty($_.profile) -and $_.codec_name -like $Codec) {
            $bitrate = $_.bit_rate
            $index = $i
        }
        else { $index = $false; $i++ }     
    }
    
    if ($index) { Write-Host "$codecStr stream found. Bit rate: $($bitrate / 1000) kb/s`n" }
    else { Write-Host "A $codecStr stream could not be found. Audio will be transcoded to the selected format.`n" @warnColors}
    return $index
}


