<#
    .SYNOPSIS 
        Utility function that writes important encoder data to a file
    .DESCRIPTION
        The standard log produced by this script has a lot of filler content,
        so this function is designed to pull the meaningful information from 
        the log and write it to a separate .rep file for reviewing or
        storing. Shows the following info:

        1. Start & end date and time
        2. Total encoding time in a more human readable format
        3. All output produced by x264/x265 throughout the encode (NOT ffmpeg) with key items sanitized and formatted
    .NOTES
        The report name is the same as the output file name
    .PARAMETER DateTimes
        <Datetime[]> Array containing the start time, end time objects.
    .PARAMETER Duration
        <Diagnostics.Stopwatch> Stopwatch object which contains the duration of the encode.
    .PARAMETER Paths
        <Hashtable> Object containing various paths used throughout the script.
    .PARAMETER TwoPass
        <Switch> Switch specifying whether 2-pass encoding was used.
    .PARAMETER Encoder
        <String> Encoding codec used. Output is altered depending on which one is used.
    .PARAMETER ReportType
        <String> Type of report to write. Default is html.
#>

function Write-Report {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [datetime[]]$DateTimes,

        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Stopwatch]$Duration,

        [Parameter(Mandatory = $true)]
        [hashtable]$Paths,

        [Parameter(Mandatory = $false)]
        [switch]$TwoPass,

        [Parameter(Mandatory = $true)]
        [ValidateSet('x264', 'x265')]
        [string]$Encoder,

        [Parameter(Mandatory = $false)]
        [ValidateSet('html', 'txt')]
        [string]$ReportType = 'html'
    )

    
    $outPath = $Paths.ReportPath

    if ($ReportType -eq 'txt') {
        $log = $TwoPass ? (Get-Content -ReadCount 0) : (Get-Content $Paths.LogPath -Tail 60)
        # Start of log
    
        "*-------------- ENCODING REPORT FOR: $(($Paths.Title).toUpper()) --------------*`n" >> $outPath
        'Start Time: ' + $DateTimes[0] >> $outPath
        '' >> $outPath

        if ($TwoPass) {
            '-------------- INPUT PARAMETERS: PASS 1 --------------' >> $outPath
        }
        else {
            '-------------- INPUT PARAMETERS --------------' >> $outPath
        }

        # Write contents to the report file
        if ($Encoder -eq 'x265') {
            # Loop through the log file and append relevant lines of data to the report - x265
            for ($i = 0; $i -lt $log.Length; $i++) {
                if ($log[$i] -match 'y4m' -or $log[$i] -match 'raw') { 
                    $log[$i] >> $outPath
                }
                elseif ($log[$i] -match 'x265 \[info\]\:.*') { 
                    if ($log[$i - 1] -match 'video') {
                        '' >> $outPath
                        '-------------- COMPLETION METRICS --------------' >> $outPath
                        $log[$i - 1] >> $outPath 
                    }
                    elseif ($log[$i] -match 'VES muxing') {
                        '' >> $outPath
                        '-------------- COMPLETION METRICS --------------' >> $outPath 
                    }
                    $log[$i] >> $outPath
                }
                elseif ($log[$i] -match 'encoded \d+ frames') { 
                    '' >> $outPath
                    $log[$i] >> $outPath
                    '' >> $outPath

                    if ($TwoPass) {
                        '-------------- INPUT PARAMETERS: PASS 2 --------------' >> $outPath
                        $TwoPass = $false
                    }
                }
            }
        }
        else {
            # Loop through the log file and append relevant lines of data to the report - x264
            for ($i = 0; $i -lt $log.Length; $i++) {
                if ($log[$i] -like '*libx264 @*') { 
                    if ($log[$i - 1] -like '*video*') {
                        '' >> $outPath
                        '-------------- COMPLETION METRICS --------------' >> $outPath
                        $log[$i - 1] >> $outPath 
                    }
                    $log[$i] >> $outPath

                    if ($TwoPass) {
                        '-------------- INPUT PARAMETERS: PASS 2 --------------' >> $outPath
                        $TwoPass = $false
                    }
                }
            }
        }

        '' >> $outPath
        'End Time: ' + $DateTimes[1] >> $outPath
        'Encoding Time: {0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds' -f `
            $Duration.Elapsed >> $outPath
        '' >> $outPath
    }
    # Generate HTML report
    else {
        # Count number of files with report ext in output directory
        if ([System.IO.File]::Exists($outPath)) {
            $repExt = ([System.IO.FileInfo]$outPath).Extension
            [int]$repCount = (Get-ChildItem $Paths.Root -Filter "*$repExt" -File -Recurse).Count
            $name = Split-Path $outPath -LeafBase
            $outPath = $outPath.Replace("$name.html", "$name`_$($repCount + 1).html")
        }
        $pixWidth = $Encoder -eq 'x264' ? '1250px' : '1080px'

        [string[]]$filterLog = (Get-Content $Paths.LogPath -ReadCount 0).Where({ 
            $_ -like '*x265 *:*' -or $_ -like '*encoded*frames in*' -or $_ -like '*libx264 @*' 
        })

        if ($TwoPass) {
            # Set file split point for 2-pass encoding based on encoder used
            $break = $encoder -eq 'x264' ? 'using SAR=1/1' : 'HEVC encoder version'
            $line = $filterLog.Where({ $_ -like "*$break*" }, 'Last', 1)
            # Splitting on first occurrence does not work with x264
            $break = [array]::LastIndexOf($filterLog, $line.Trim())
            $firstPass, $filterLog = $filterLog[0..($break - 1)], $filterLog[$break..($filterLog.Length - 1)]
            $firstPass = @('<------------------ PASS 1 ------------------>', '') + $firstPass
            $filterLog = @('', '<------------------ PASS 2 ------------------>', '') + $filterLog
        }

        foreach ($line in $filterLog) {
            switch -Wildcard ($line) {
                '*frame I*' {
                    $iFrames = [Regex]::Match($line, 'frame I:\s*(\d+).+(?<=Avg QP:)(\d+\.?\d*)')
                    try {
                        $iCount, $iQP = $iFrames.Groups[1].Value, $iFrames.Groups[2].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match I frame data from logs" @errColors
                        $iCount = $iQP = 'null'
                    }
                }
                '*frame P*' {
                    $pFrames = [Regex]::Match($line, 'frame P:\s*(\d+).+(?<=Avg QP:)(\d+\.?\d*)')
                    try {
                        $pCount, $pQP = $pFrames.Groups[1].Value, $pFrames.Groups[2].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match P frame data from logs" @errColors
                        $pCount = $pQP = 'null'
                    }
                }
                '*frame B*' {
                    $bFrames = [Regex]::Match($line, 'frame B:\s*(\d+).+(?<=Avg QP:)(\d+\.?\d*)')
                    try {
                        $bCount, $bQP = $bFrames.Groups[1].Value, $bFrames.Groups[2].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match B frame data from logs" @errColors
                        $bCount = $bQP = 'null'
                    }
                }
                # x264 only
                '*kb/s:*' {
                    $bitrate = [Regex]::Match($line, '(?<=kb/s:)(\d+\.?\d*)')
                    try {
                        $bitrate = $bitrate.Groups[1].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match x264 bitrate" @errColors
                        $bitrate = 'null'
                    }
                }
                # x265 only
                '*encoded*frames in*' {
                    $summary = [Regex]::Match($line, '(\d+\.\d+)(?=\sfps).+?(\d+\.?\d*)(?=\skb/s).+(?<=Avg QP:)(\d+\.?\d*)')
                    try {
                        $fps = $summary.Groups[1].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match x265 FPS" @errColors
                        $fps = 'null'
                    }
                    try {
                        $bitrate = $summary.Groups[2].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match x265 bitrate" @errColors
                        $bitrate = 0
                    }
                    try {
                        $avgQp = $summary.Groups[3].Value
                    }
                    catch {
                        Write-Host "HTML Report: Failed to match x265 Average QP" @errColors
                        $avgQp = 'null'
                    }
                }
                default { continue }
            }
        }
        # For x264 get FPS from last encoder line in log
        if ($Encoder -eq 'x264') {
            $fps = (Get-Content $Paths.LogPath -Tail 21).Where({ $_ -like '*frame=*fps=*' }) |
                Select-String -Pattern '.+(?<=fps=\s?)(?<fps>\d+\.?\d*).+' |
                    ForEach-Object { $_.Matches.Groups[1].Value }
        }

        $frameCount = ($iCount -as [int]) + ($pCount -as [int]) + ($bCount -as [int])
        $frameCount = $frameCount -eq 0 ? 'Invalid' : $frameCount

        # For x264 only as it doesn't give Avg QP
        $weightedAvgQP = '{0:N2}' -f 
                        ((($iCount / $frameCount) * $iQP) + 
                        (($pCount / $frameCount) * $pQP) + 
                        (($bCount / $frameCount) * $bQP))

        $logContent = $TwoPass ? (($firstPass + $filterLog) -join "`n") : ($filterLog -join "`n")
        $styleAndLog = ($rawStyle -replace '\{0\}', $pixWidth) + 
                       "<pre class='encode-log'>$logContent</pre>"

        # Create report elements
        $title = "<h1 class='report-title'>Encoding Report for: $($Paths.Title)</h1>"

        $timeFragment = [pscustomobject]@{
            'Start Time'    = $DateTimes[0]
            'End Time'      = $DateTimes[1]
            'Encoding Time' = '{0:dd} days, {0:hh} hours, {0:mm} minutes and {0:ss} seconds' -f $Duration.Elapsed
        } | ConvertTo-Html -Fragment -As List -PreContent '<h2>Time Statistics</h2>'

        $encoderFragment = [pscustomobject]@{
            'Encoder'           = $Encoder
            'Frame Count'       = '{0:N0}' -f $frameCount
            'Frames Per Second' = $fps ??= 'null'
            'Bitrate'           = "{0:N3} Mb/s" -f ($bitrate / 1000)
            'Average QP'        = $Encoder -eq 'x264' ? "$weightedAvgQP (Approximated)" : $avgQp
        } | ConvertTo-Html -Fragment -As List -PreContent '<h2>Encode Summary</h2>'

        # Write report to file
        $reportParams = @{
            Title       = $title
            Body        = "$title $timeFragment $encoderFragment"
            PostContent = $styleAndLog
            PreContent  = '<h2>Encoding Log</h2>'
        }
        ConvertTo-Html @reportParams | Out-File $outPath
    }
}

# Scope restricted CSS style for report. Saved down here to keep stupid here string formatting clean
$Local:rawStyle = @'
<style>
  body {
      background: linear-gradient(to bottom, #d7d2cc, #304352);
      background-repeat: no-repeat;
      background-attachment: fixed;
      background-size: cover;
      background-position: center center;
  }
  
  table {
      width: auto;
      border-collapse: collapse;
      border: 4px inset black;
      font-family: 'Arial', sans-serif;
      font-size: 16px;
  }
  
  th,
  td {
      font-weight: bold;
      padding: 10px;
      border: 2px solid #333333;
  }
  
  tbody tr:nth-child(even) {
      background-color: #dbdbdb;
  }
  tbody tr:nth-child(odd) {
      background-color: #b3b1b1;
  }
  
  tbody tr:hover {
      background-color: #e6e6e6;
  }
  
  h1 {
      font-family: 'Arial', sans-serif;
      font-size: 2rem;
      color: #333;
      text-align: center;
      text-transform: uppercase;
      letter-spacing: 2px;
      margin: 40px 0;
      padding: 10px;
      background-color: #f2f2f2cb;
      border-radius: 20px;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
  h2 {
      font-family: 'Arial', sans-serif;
      font-size: 1.5rem;
      color: #333333;
      text-align: center;
      letter-spacing: 1px;
      margin: 40px 0;
      padding: 10px;
      background-color: #f2f2f2cb;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
  }
  
  pre.encode-log {
      background-color: #000;
      color: #fff;
      padding: 10px;
      margin: 4px 0;
      border-radius: 5px;
      font-size: 16px;
      font-family: Consolas, monospace;
      inline-size: auto;
      white-space: pre;
      overflow: auto;
      width: auto;
      max-width: {0};
  }
  
  @media (max-width: {0}) {
      pre.encode-log {
        width: 100%;
    }
  }
</style>
'@
