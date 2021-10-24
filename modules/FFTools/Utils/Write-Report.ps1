<#
    .SYNOPSIS 
        Utility function that writes important encoder data to a file
    .DESCRIPTION
        The standard log produced by this script has a lot of filler content,
        so this function is designed to pull the meaningful information from 
        the log and write it to a separate .rep file for reviewing or
        storing. Shows the following info:

        1. Start & end date and time
        2. All output produced by x265 throughout the encode 
        2. Total encoding time in a more human readable format
    .NOTES
        The report name is the same as the output file name
    .PARAMETER DateTimes
        Array containing the startTime, endTime objects
    .PARAMETER Duration
        Stopwatch object which contains the duration of the encode
    .PARAMETER Paths
        Object containing various paths used throughout the script
#>
function Write-Report {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [datetime[]]$DateTimes,

        [Parameter(Mandatory = $true, Position = 1)]
        [system.object]$Duration,

        [Parameter(Mandatory = $true, Position = 2)]
        [hashtable]$Paths,

        [Parameter(Mandatory = $true, Position = 3)]
        [bool]$TwoPass
    )

    $log = Get-Content $Paths.LogPath
    $outPath = $Paths.ReportPath

    #Write contents to the report file
    "*-------------- ENCODING REPORT FOR: $(($Paths.Title).toUpper()) --------------*`n" > $outPath
    "Start Time: " + $DateTimes[0] >> $outPath
    "" >> $outPath
    if ($TwoPass) {
        "-------------- INPUT PARAMETERS: PASS 1 --------------" >> $outPath
    }
    else {
        "-------------- INPUT PARAMETERS --------------" >> $outPath
    }
    #Loop through the log file and append relevant lines of data to the report
    for ($i = 0; $i -lt $log.Length; $i++) {
        if ($log[$i] -match 'y4m' -or $log[$i] -match 'raw') { 
            $log[$i] >> $outPath
        }
        elseif ($log[$i] -match "x265 \[info\]\:.*") { 
            Write-host "Matched x265 info line:" $log[$i]
            if ($log[$i - 1] -match "video") {
                "" >> $outPath
                "-------------- COMPLETION METRICS --------------" >> $outPath
                $log[$i - 1] >> $outPath 
            }
            elseif ($log[$i] -match "VES muxing") {
                "" >> $outPath
                "-------------- COMPLETION METRICS --------------" >> $outPath 
            }
            $log[$i] >> $outPath
        }
        elseif ($log[$i] -match "encoded \d+ frames") { 
            "" >> $outPath
            $log[$i] >> $outPath
            "" >> $outPath

            if ($TwoPass) {
                "-------------- INPUT PARAMETERS: PASS 2 --------------" >> $outPath
                $TwoPass = $false
            }
        }
    }
    "" >> $outPath
    "End Time: " + $DateTimes[1] >> $outPath
    "Encoding Time: {0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds" -f `
        $Duration.Elapsed >> $outPath
}

