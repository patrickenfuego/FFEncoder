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
    #Verify if HDR10+ parser is available via PATH. If not, return from function call
    if (!(Get-Command 'hdr10plus_parser' -ErrorAction Ignore)) {
        Write-Verbose "HDR10+ parser not found in PATH"
        return
    }
    #UNIX platforms. Escape meta characters for bash shell
    #Verifies if the source is HDR10 compatible
    if ($IsLinux -or $IsMacOS) {
        $InputFile = [regex]::Escape($InputFile)
        $res = bash -c "ffmpeg -loglevel panic -i $InputFile -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_parser --verify -"
    }
    #Windows platform. Requires cmd
    ##Verifies if the source is HDR10 compatible
    else {
        $res = cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_parser --verify -"
    }
    #If last command completed successfully and found metadata, generate json file
    if ($? -and ($res[1] -like "*HDR10+*" -or $res -like "*HDR10+*")) {
        Write-Host "HDR10+ SEI metadata found..." -NoNewline
        if (Test-Path -Path $HDR10PlusPath) { Write-Host "JSON metadata file already exists" @warnColors }
        else {
            Write-Host "Generating JSON file" @emphasisColors
            if ($IsLinux -or $IsMacOS) {
                $HDR10PlusPath = [regex]::Escape($HDR10PlusPath)
                bash -c "ffmpeg -loglevel panic -i $InputFile -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_parser -o $HDR10PlusPath -"
            }
            else {
                cmd.exe /c "ffmpeg -loglevel panic -i `"$InputFile`" -c:v copy -vbsf hevc_mp4toannexb -f hevc - | hdr10plus_parser -o `"$HDR10PlusPath`" -"
            }
        }
        return $true
    }
    else { return $false }
}