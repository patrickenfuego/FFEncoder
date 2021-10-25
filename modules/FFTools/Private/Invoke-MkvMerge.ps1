<#
    .SYNOPSIS
        Private function to call mkvmerge for muxing when Dolby Vision is
        present
    .DESCRIPTION
        If mkvmerge is available on the system, this function is called
        to merge the elementary hevc stream back into the container with
        audio and subs. mkvmerge is preferable to other options because it
        will retain Dolby Vision metadata
    .NOTES
        Void function
#>

function Invoke-MkvMerge {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        [Parameter(Mandatory = $false)]
        [string]$Verbosity
    )

    if ($PSBoundParameters['Verbosity']) {
        $VerbosePreference = 'Continue'
    }
    else {
        $VerbosePreference = 'SilentlyContinue'
    }

    Write-Host "MkvMerge Detected: Merging DV HEVC stream into container" @progressColors

    $streams = ffprobe $Paths.InputFile -show_entries stream=index:stream_tags=language -select_streams a -v 0 -of compact=p=0:nk=1 
    [string]$lang = $streams -replace '\d\|', '' | Group-Object | Sort-Object -Property Count -Descending | 
        Select-Object -First 1 -ExpandProperty Name

    if (!$Paths.ChapterPath) {
        mkvmerge --output "$($Paths.OutputFile)" --language 0:$lang "(" "$($Paths.hevcPath)" ")" "(" "$($Paths.tmpOut)" ")" `
            --title "$($Paths.Title)" --track-order 0:0,1:0
    }
    else {
        mkvmerge --output "$($Paths.OutputFile)" --language 0:$lang "(" "$($Paths.hevcPath)" ")" `
            --chapter-language $lang --chapters "$chapterPath"
    }
    if ($?) {
        Write-Verbose "Last exit code for MkvMerge: $LASTEXITCODE. Removing TMP file..."
        if (Test-Path -Path $Paths.tmpOut -ErrorAction SilentlyContinue) { Remove-Item $Paths.tmpOut -Force }
    }
}