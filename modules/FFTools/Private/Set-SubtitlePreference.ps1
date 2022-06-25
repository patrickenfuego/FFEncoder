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

    if ($UserChoice -match "a[ll]*$" -or $UserChoice -match "c[opy]*a[ll]*") {
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
    elseif ($UserChoice -like "!*") {
        $lang = $UserChoice.Replace('!', '').ToUpper()
        Write-Host "** SKIP $lang SUBTITLES SELECTED **" @progressColors
        Write-Host "All subtitle streams of this language will be ignored"
        $subStreams = Get-SubtitleStream -InputFile $InputFile -Language $UserChoice
        if ($subStreams) {
            foreach ($s in $subStreams) {
                [string[]]$sArgs += '-map', "0:s:$s`?", '-c:s', 'copy'
            }
            return $sArgs
        }
        else {
            Write-Warning "No matching subtitle preference was found. Subtitles will not be copied`n"
            return '-sn' 
        }
    }
    else {
        Write-Host "** $($UserChoice.ToUpper()) SUBTITLES SELECTED **" @progressColors
        Write-Host "Only subtitles of this language will be copied"
        $subStreams = Get-SubtitleStream -InputFile $InputFile -Language $UserChoice
        if ($subStreams) {
            foreach ($s in $subStreams) {
                [string[]]$sArgs += '-map', "0:s:$s`?", '-c:s', 'copy'
            }
            return $sArgs
        }
        else {
            Write-Warning "No matching subtitle preference was found. Subtitles will not be copied`n"
            return '-sn' 
        }
    }
}