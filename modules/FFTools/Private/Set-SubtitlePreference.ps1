function Set-SubtitlePreference {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$UserChoice
    )

    if ($UserChoice -match "a[ll]*$") {
        Write-Host "** ALL SUBTITLES SELECTED **" @progressColors
        Write-Host "All subtitle streams will be copied`n"
        return @('-map', '0:s?', '-c:s', 'copy')
    }
    elseif ($UserChoice -match "n[one]*$") {
        Write-Host "** NO SUBTITLES SELECTED **" @progressColors
        Write-Host "All subtitle streams will be excluded from the output file`n"
        return '-sn'
    }
    elseif ($UserChoice -match "d[efault]*$") {
        Write-Host "** DEFAULT SUBTITLE SELECTED **" @progressColors
        Write-Host "The primary subtitle stream will be copied`n"
        return @('-map', '0:s:0?', '-c:s', 'copy')
    }
    else {
        Write-Host "** $($UserChoice.ToUpper()) SUBTITLES SELECTED **" @progressColors
        $subStreams = Get-SubtitleStream -InputFile $InputFile -Language $UserChoice
        if ($null -ne $subStreams) {
            $args = @()
            foreach ($s in $subStreams) {
                $args += '-map', "0:s:$s`?", '-c:s', 'copy'
            }
            return $args
        }
        else {
            Write-Warning "No matching subtitle preference was found. Subtitles will not be copied`n"
            return '-sn' 
        }
    }
}