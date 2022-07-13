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
        Write-Host "$("`u{25c7}" * 2) ALL SUBTITLES SELECTED $("`u{25c7}" * 2)" @progressColors
        Write-Host "All subtitle streams will be copied"
        return @('-map', '0:s?', '-c:s', 'copy')
    }
    elseif ($UserChoice -match "n[one]*$") {
        Write-Host "$("`u{25c7}" * 2) NO SUBTITLES SELECTED $("`u{25c7}" * 2)" @progressColors
        Write-Host "All subtitle streams will be excluded from the output file`n"
        return '-sn'
    }
    elseif ($UserChoice -match "d[efault]*$") {
        Write-Host "$("`u{25c7}" * 2) DEFAULT SUBTITLE SELECTED $("`u{25c7}" * 2)" @progressColors
        Write-Host "The primary subtitle stream will be copied"
        return @('-map', '0:s:0?', '-c:s', 'copy')
    }
    else {
        if ($UserChoice -like "!*") {
            $lang = $UserChoice.Replace('!', '').ToUpper()
            Write-Host "$("`u{25c7}" * 2) SKIP $lang SUBTITLES SELECTED $("`u{25c7}" * 2)" @progressColors
            Write-Host "All subtitle streams of this language will be ignored"
        }
        else {
            Write-Host "$("`u{25c7}" * 2) $($UserChoice.ToUpper()) SUBTITLES SELECTED $("`u{25c7}" * 2)" @progressColors
            Write-Host "Only subtitles of this language will be copied"
        }
        $subStreams = Get-SubtitleStream -InputFile $InputFile -Language $UserChoice
        if ($subStreams) {
            foreach ($s in $subStreams) {
                [string[]]$sArgs += '-map', "0:s:$s`?", '-c:s', 'copy'
            }
            return $sArgs
        }
        else {
            Write-Warning "No matching subtitle preference was found. Subtitles will not be copied"
            return '-sn' 
        }
    }
}