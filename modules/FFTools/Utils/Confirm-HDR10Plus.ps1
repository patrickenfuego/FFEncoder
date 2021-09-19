<#
    .SYNOPSIS 
        Utility function to check for HDR10+ metadata and generate a json file if found
    .PARAMETER InputFile
        Path to the input file (file to be encoded)
    .PARAMETER HDR10PlusPath
        Output path to the json metadata file. Path is generated dynamically based on input path
    .OUTPUTS
        Boolean (if hdr10plus_parser is present)
#>

function Confirm-HDR10Plus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$InputFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$HDR10PlusPath
    )


    #Load parser path for UNIX systems
    if ($IsLinux -or $IsMacOS) {
        $parserPath = $IsLinux ?
        (Join-Path ((Get-Item $PSScriptRoot).Parent.Parent.Parent) -ChildPath "bin/linux/hdr10plus_tool") :
        (Join-Path ((Get-Item $PSScriptRoot).Parent.Parent.Parent) -ChildPath "bin/mac/hdr10plus_tool")
        
        #Verify that the parser path exists
        if (!(Test-Path -Path $parserPath)) {
            Write-Warning "Could not verify path to hdr10plus_parser. Metadata will be skipped"
            return $false
        }
        #Change permissions and escape UNIX path
        bash -c "chmod u+x '$parserPath'"
        $parserPath = [regex]::Escape($parserPath)
    }
    #Add parser to PATH on Windows systems
    else {
        $path = Join-Path ((Get-Item $PSScriptRoot).Parent.Parent.Parent) -ChildPath "bin\windows"
        $env:PATH += ";$path"

        #Verify that the parser is available via PATH
        if (!(Get-Command 'hdr10plus_tool' -ErrorAction Ignore)) {
            Write-Warning "hdr10plus_parser parser not found in PATH. Metadata will be skipped"
            return $false
        }
    }

    #UNIX platforms. Escape meta characters for bash shell
    #Verifies if the source is HDR10 compatible
    if ($IsLinux -or $IsMacOS) {
        $InputFile = [regex]::Escape($InputFile)
        $res = bash -c "ffmpeg -loglevel panic -i $InputFile -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | $parserPath extract -"
    }
    #Windows platform. Requires cmd
    #Verifies if the source is HDR10 compatible
    else {
        $res = cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_tool extract -"
    }
    #If last command completed successfully and found metadata, generate json file
    if ($? -and $res -eq "Dynamic HDR10+ metadata detected.") {
        Write-Host "HDR10+ SEI metadata found..." -NoNewline
        if (Test-Path -Path $HDR10PlusPath) { Write-Host "JSON metadata file already exists" @warnColors }
        else {
            Write-Host "Generating JSON file" @emphasisColors
            if ($IsLinux -or $IsMacOS) {
                $HDR10PlusPath = [regex]::Escape($HDR10PlusPath)
                bash -c "ffmpeg -loglevel panic -i $InputFile -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | $parserPath extract -o $HDR10PlusPath -"
            }
            else {
                cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -map 0:v:0 -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_tool extract -o `"$HDR10PlusPath`" -"
            }
        }
        return $true
    }
    else { return $false }
}