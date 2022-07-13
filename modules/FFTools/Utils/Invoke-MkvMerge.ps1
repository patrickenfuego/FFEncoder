<#
    .SYNOPSIS
        Private helper function to handle the script's remuxing needs
    .DESCRIPTION
        If MKVToolnix is installed (and the file is mkv), this function is used to remux
        tracks instead of ffmpeg.
    .PARAMETER Paths
        File paths and variables used throughout the script, compacted into a hashtable
    .PARAMETER Mode
        Specifies the mkvmerge mode
            extract - Extracts a file from the source
            dv      - Handles Dolby Vision muxing, which has some unique behavior (TODO - merge into remux)
            remux   - Handles muxing of externally encoded files back into the output container
            
    .PARAMETER ModeID
        Identifies the remuxing mode
            1 - Stream copy & encode remux
            2 - Dee stream encode remux
            3 - Stereo & dee stream remux
    .NOTES
        This function is a fucking mess and needs refactoring
#>

function Invoke-MkvMerge {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]$Paths,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Mode,

        [Parameter(Mandatory = $false)]
        [int]$ModeID
    )

    # Mode for muxing externally encoded files
    if ($Mode -eq 'remux') {
        if (![System.IO.File]::Exists($Paths.Audio) -and
            ![System.IO.File]::Exists($Paths.ExternalAudio)) {
                
            Write-Host "mkvmerge: Could not locate the external audio path. Returning..." @warnColors
            return
        }
        
        $tCount = (mkvmerge $Paths.Input -i | Where-Object { $_ -like '*audio*' }).Count
        # Determine likely order of container layout (audio before subs, 0:0 being video)
        $tracks = switch ($tCount) {
            0 { $null }
            1 { '0:1' }
            2 { '0:1,0:2' }
            3 { '0:1,0:2,0:3' }
            4 { '0:1,0:2,0:3,0:4' }
            5 { '0:1,0:2,0:3,0:4,0:5' }
        }

        $trackOrder = switch ($ModeID) {
            1 {
                switch ($tCount) {
                    0       { '0:0,1:0' }
                    1       { '0:0,0:1,1:0' }
                    default { '0:0,0:1,1:0', $($tracks -replace '0:1,?', '') -join ',' }
                }
            }
            2 { $tracks ? ('0:0,1:0', $tracks -join ',') : '0:0,1:0' }
            3 { $tracks ? ('0:0,1:0,2:0', $tracks -join ',') : '0:0,1:0,2:0' }
            default { '0:0,1:0' }
        }

        $remuxArgs = @(
            '--output'
            "$($Paths.Output)"
            '--language'
            "0:$($Paths.Language)"
            if ($TrackTitle['VideoTitle']) {
                '--track-name'
                "0:$($TrackTitle['VideoTitle'])"
            }
            '('
            "$($Paths.Input)"
            ')'
            if ($Paths.Audio) {
                '--language'
                "0:$($Paths.Language)"
                '--track-name'
                ($ModeID -in 2, 3) ? "0:$($trackTitle['DeeTitle'])" : "0:$($trackTitle['StereoTitle'])" 
            ($ModeID -in 2, 3) ? "0:$($trackTitle['DeeTitle'])" : "0:$($trackTitle['StereoTitle'])" 
                ($ModeID -in 2, 3) ? "0:$($trackTitle['DeeTitle'])" : "0:$($trackTitle['StereoTitle'])" 
                '('
                "$($Paths.Audio)"
                ')'
            }
            if ($Paths.ExternalAudio) {
                '--language'
                "0:$($Paths.Language)"
                '--track-name'
                ($null -ne $TrackTitle['ExternalTitle']) ? "0:$($TrackTitle['ExternalTitle'])" : "0:$($TrackTitle['StereoTitle'])"
                '('
                "$($Paths.ExternalAudio)"
                ')'
            }
            '--title'
            "$($Paths.Title)"
            '--track-order'
            $trackOrder
        )

        if ($PSBoundParameters['Verbose']) {
            mkvmerge $remuxArgs 2>&1
        }
        else {
            mkvmerge $remuxArgs >$null
        }
        
        # Ensure output exists and file size is correct before deleting and renaming
        if ((Test-Path $Paths.Output -ErrorAction SilentlyContinue) -and 
            ((Get-Item $Paths.Output).Length -ge (Get-Item $Paths.Input).Length)) {
            Write-Verbose "Muxing successful for <$($Paths.Output)>"
        }
        else { 
            Write-Host "There was a problem muxing the external audio file. Manual intervention required" @warnColors
        }

        return
    }
    elseif ($Mode -eq 'dv') {
        Write-Host "MkvMerge Detected: Merging DV HEVC stream into container" @progressColors

        $remuxArgs = 

        if (!$Paths.VideoOnly) {
            @(
                '--output'
                "$($Paths.Output)"
                '--language'
                "0:$($Paths.Language)"
                if ($TrackTitle['VideoTitle']) {
                    '--track-name'
                    "0:$($TrackTitle['VideoTitle'])"
                }
                '('
                "$($Paths.Input)"
                ')'
                if ($Paths.Chapters) {
                    '--chapter-language'
                    "$lang"
                    '--chapters'
                    "$($Paths.Temp)"
                    '--title'
                    "$($Paths.Title)"
                }
                else {
                    '--language'
                    "0:$($Paths.Language)"
                    '('
                    "$($Paths.Temp)"
                    ')'
                    '--title'
                    "$($Paths.Title)"
                    '--track-order'
                    '0:0,1:0'
                }
            )
        }
        else {
            @(
                '--output'
                "$($Paths.Output)"
                '--language'
                "0:$($Paths.Language)"
                if ($TrackTitle['VideoTitle']) {
                    '--track-name'
                    "0:$($TrackTitle['VideoTitle'])"
                }
                '('
                "$($Paths.Input)"
                ')'
                '--title'
                "$($Paths.Title)"
            )
        }

        if ($PSBoundParameters['Verbose']) {
            mkvmerge $remuxArgs 2>&1
        }
        else {
            mkvmerge $remuxArgs >$null
        }

        if ($?) {
            Write-Verbose "Last exit code for MkvMerge: $LASTEXITCODE. Removing TMP file..."
            if (Test-Path -Path $Paths.Temp -ErrorAction SilentlyContinue) { 
                Remove-Item $Paths.Temp -Force 
            }
        }
    }
    elseif ($Mode -eq 'extract') {
        if ([System.IO.File]::Exists($Paths.Output)) {
            Write-Verbose "MKVMerge: Existing external audio file found. Returning..."
            return
        }

        $remuxArgs = @(
            '--output'
            "$($Paths.Output)"
            '--audio-tracks'
            '1'
            '--no-video'
            '--no-subtitles'
            '--no-chapters'
            '--no-attachments'
            '--language'
            "1:$($Paths.Language)"
            '('
            "$($Paths.Input)"
            ')'
        )

        if ($PSBoundParameters['Verbose']) {
            mkvmerge $remuxArgs 2>&1
        }
        else {
            mkvmerge $remuxArgs >$null
        }
    }
    else {
        Write-Warning "Unknown mode used in Invoke-MkvMerge"
        return
    }
}
