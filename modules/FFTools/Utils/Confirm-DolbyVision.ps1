<#
    .SYNOPSIS
        Private function to confirm Dolby Vision metadata and generate RPU file if found
    .DESCRIPTION
        This function verifies Dolby Vision metadata using dovi_tool by first attempting to 
        generate an RPU file for a small number of frames. If the output size is not 0 in length
        (meaning DV metadata was found), it will then generate a full RPU file and return
        $true.
    .NOTES
        This is the best solution I could come up with for verifying DV metadata without
        using/installing other dependencies or modules. Unlike hdr10plus_tool, dovi_tool does
        not have a --verify option.

        Currently supports only profile 8.1 as it's single layer with HDR10 fallback. I plan to
        add support for profile 5 at some point
#>

function Confirm-DolbyVision {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$DolbyVisionPath,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$Verbosity
    )

    if ($PSBoundParameters['Verbosity']) {
        $VerbosePreference = 'Continue'
    }
    else {
        $VerbosePreference = 'SilentlyContinue'
    }

    #if x265 not found in PATH, cannot generate RPU
    if (!(Get-Command -Name 'x265*')) {
        Write-Verbose "x265 not found in PATH. Cannot encode Dolby Vision"
        return $false
    }

    #Check for existing RPU file. Verification based on file size, can be improved
    if (Test-Path -Path $DolbyVisionPath) {
        if ([math]::round((Get-Item $DolbyVisionPath).Length / 1MB, 2) -gt 15) {
            Write-Host "Existing Dolby Vision RPU file found" @emphasisColors
            Write-Host "If the RPU file was generated during a test encode (i.e. not a full frame count), exit the script NOW, delete the file, and regenerate" @warnColors
            return $true
        }
    }

    #Determine if file supports dolby vision
    if ($IsLinux -or $IsMacOS) {
        $parserPath = $IsLinux ?
        (Join-Path ((Get-Item $PSScriptRoot).Parent.Parent.Parent) -ChildPath "bin/linux/dovi_tool") :
        (Join-Path ((Get-Item $PSScriptRoot).Parent.Parent.Parent) -ChildPath "bin/mac/dovi_tool")

        $InputFile = [regex]::Escape($InputFile)
        $parserPath = [regex]::Escape($parserPath)
        $dvPath = [regex]::Escape($DolbyVisionPath)
        bash -c "ffmpeg -loglevel panic -i $InputFile -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | $parserPath --crop -m 2 extract-rpu - -o $dvPath"
    }
    else {
        $path = Join-Path ((Get-Item $PSScriptRoot).Parent.Parent.Parent) -ChildPath "bin\windows"
        $env:PATH += ";$path"

        cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -frames:v 5 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | dovi_tool --crop -m 2 extract-rpu - -o `"$DolbyVisionPath`""
    }
    #If size is 0, DV metadata was not found
    if ((Get-Item $DolbyVisionPath).Length -eq 0) {
        Write-Verbose "Input File does not support Dolby Vision"
        return $false
    }
    elseif ((Get-Item $DolbyVisionPath).Length -gt 0) {
        Write-Host "Dolby Vision Metadata found. Generating RPU file..." @emphasisColors
        Remove-Item -Path $DolbyVisionPath -Force

        if ($IsMacOS -or $IsLinux) {
            bash -c "ffmpeg -loglevel panic -i $InputFile -c:v copy -vbsf hevc_mp4toannexb -f hevc - | $parserPath --crop -m 2 extract-rpu - -o $dvPath"
        }
        else {
            cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | dovi_tool --crop -m 2 extract-rpu - -o `"$DolbyVisionPath`""
        }

        if ([math]::round((Get-Item $DolbyVisionPath).Length / 1MB, 2) -gt 1) {
            Write-Verbose "RPU size is greater than 1 MB. RPU was most likely generated successfully"
            return $true
        }
        else {
            Write-Host "There was an issue creating the RPU file. Verify the RPU file size" @warnColors
            return $false
        }
    }
    else {
        throw "There was an unexpected error while generating RPU file. This should be unreachable"
        exit 2
    }
}
