<#
    .SYNOPSIS  
        A script to pull movie metadata, save it as an XML file, and automatically add it to a Matroska file
    .DESCRIPTION
        This script is meant to automate the generation of Matroska tag files, which can be
        used to append additional info to the container, and is readable by MediaInfo. the 
        script uses the TMDB API to generate tag information. The tag file is then automatically
        appended to container file using mkvpropedit (if available via PATH).

        By default, the script will use the output file's name as the search query. If the file contains
        extra information other than the title, use the -Title parameter to pass a clean title - the script
        will attempt to sanitize the input, but this may not always work depending on the file
    .PARAMETER Path
        <String> Path to output file. The name of the file is used to search the API, i.e.
                 'D:\Movies\Ex Machina.mkv' will use 'Ex Machina' for the search. Most container
                 formats are accepted, but tags will only be added to mkv files automatically

                 Optionally, you may specify an XML output path as well, which will generate the
                 tag file at the destination specified but not add it to the container automatically
    .PARAMETER APIKey
        <String> API keys used to query for IMDb/TMDB information. If no key is passed, 
                 the script will attempt to use the globally defined key if present
    .PARAMETER Properties
        <String[]> Additional properties to add to the tag file (if found during the search)
    .PARAMETER SkipProperties
        <String[]> Comma separated list of properties to exclude from tag file. Accepted values:
                    - Writers
                    - Directors
                    - Cast
    .PARAMETER Title
        <String> Specify a clean title to use for the API search. Use this when the destination file title 
                 contains characters that may disrupt the search; the script will attempt to sanitize input
                 file names, but may not be successful
    .PARAMETER Year
        <int32> Specify the release year for the search title. This parameter is helpful for titles with
                multiple release years, such as remakes. This parameter should be used when the API returns
                incorrect results. It can also be helpful for titles that have a year in the name already
                (i.e. 'Blade Runner 2049 2017')
    .PARAMETER NoMux
        <Bool> Switch parameter to skip file multiplexing with mkvpropedit (but still generate the file)
    .PARAMETER AllowClobber
        <Bool> Switch parameter to force overwrite existing XML file if it exists
    .INPUTS
        <String> Path to MKV file or output destination
        <String> API key
    .OUTPUTS
        <XML> File formatted for Matroska tags, including:
              - Cast
              - Directed By
              - Written By
              - IMDb reference ID
              - TMDb reference ID
    .EXAMPLE
        # Generate only the XML file and do not mux into container
        .\MatroskaTagGenerator.ps1 -Path 'C:\Movies\Ex Machina.xml'
    .EXAMPLE
        # Pass a file and automatically mux metadata if mkvpropedit is installed (using positional parameters)
        .\MatroskaTagGenerator.ps1 'C:\Movies\Ex Machina.mkv'
    .EXAMPLE
        # Pass a custom title to use for metadata retrieval instead of the destination file name
        .\MatroskaTagGenerator.ps1 -Path '~/movies/Ex.Machina.2014.2160p.remux.mkv' -Title 'Ex Machina'
    .EXAMPLE
        #Omit the default 'Cast' metadata field from the tag file
        .\MatroskaTagGenerator.ps1 'C:\Movies\Ex Machina.mkv' -SkipProperties Cast
    .EXAMPLE
        #Add a custom metadata field to the tag file 
        .\MatroskaTagGenerator.ps1 '~/movies/Ex Machina.mkv' -Properties Overview, Budget
    .EXAMPLE
        #Force overwrite an existing XML file
        .\MatroskaTagGenerator.ps1 '~/movies/Ex Machina.xml' -AllowClobber
    .NOTES
        Requires a valid TMDB API key. Access is free, but registration is needed

        For best results, install the MkvToolNix package so that the script
        may automatically append the XML tags to your file
    .LINK
        TMDB API: https://developers.themoviedb.org/3/getting-started/introduction
    .LINK
        MKVToolNix: https://mkvtoolnix.download/index.html
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias('P', 'File')]
    [string]$Path,

    [Parameter(Mandatory = $false, Position = 1)]
    [Alias('Key')]
    [string]$APIKey,

    [Parameter(Mandatory = $false, Position = 2)]
    [Alias('T')]
    [string]$Title,

    [Parameter(Mandatory = $false)]
    [int]$Year,

    [Parameter(Mandatory = $false)]
    [Alias('Props')]
    [string[]]$Properties,

    [Parameter(Mandatory = $false)]
    [Alias('Skip')]
    [ValidateSet('Writers', 'Directors', 'Cast', 'IMDbID', 'TMDbID')]
    [string[]]$SkipProperties,

    [Parameter(Mandatory = $false)]
    [switch]$NoMux,

    [Parameter(Mandatory = $false)]
    [Alias('Overwrite')]
    [switch]$AllowClobber
)

#########################################################
# Define Variables                                      #                                           
#########################################################

$ErrorView = 'NormalView'

# Console colors
$progressColors = @{ForegroundColor = 'Green'; BackgroundColor = 'Black' }
$warnColors = @{ForegroundColor = 'Yellow'; BackgroundColor = 'Black' }
$dividerColor = @{ ForegroundColor = 'DarkMagenta'; BackgroundColor = 'Black' }

$banner2 = @'
 __  __   _  __ __   __    _____                    ___                                   _               
|  \/  | | |/ / \ \ / /   |_   _|  __ _   __ _     / __|  ___   _ _    ___   _ _   __ _  | |_   ___   _ _ 
| |\/| | | ' <   \ V /      | |   / _` | / _` |   | (_ | / -_) | ' \  / -_) | '_| / _` | |  _| / _ \ | '_|
|_|  |_| |_|\_\   \_/       |_|   \__,_| \__, |    \___| \___| |_||_| \___| |_|   \__,_|  \__| \___/ |_|  
                                         |___/                                                            
'@

# Set Window Name
$currName = $host.ui.RawUI.WindowTitle
$host.ui.RawUI.WindowTitle = 'MKV Tag Generator'

#########################################################
# Function Definitions                                  #                                           
#########################################################

# Retrieves the input file's TMDB code
function Get-ID {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$APIKey,

        [Parameter(Mandatory = $false)]
        [int]$Year
    )

    Write-Host "Requesting TMDB ID for '$Title'..."
    $query = Invoke-RestMethod -Uri "https://api.themoviedb.org/3/search/movie?api_key=$($APIKey)&query=$($Title)" -Method GET
    
    # Verify if API returned multiple objects, and warn if no year was passed
    if ($query.results.Count -gt 1 -and $Year) {
        $queryID = $query.results | Where-Object { $_.release_date -like "$Year*" } | 
            Select-Object -ExpandProperty id
    }
    elseif ($query.results.Count -gt 1 -and !$Year) {
        $msg = "Query returned more than 1 result, but a release year was not specified - " +
               "the result may be incorrect. Consider using the -Year parameter " +
               "or place the year in the file's title if needed"
        Write-Warning $msg

        $queryID = $query.results[0].id
    }
    else { $queryID = $query.results[0].id }
    
    if ($queryID) {
        Write-Host "ID successfully retrieved! ID: " -NoNewline
        Write-Host $queryID @progressColors
        if ('TMDbID' -in $SkipProperties) {
            Write-Host "Skipping TMDB ID in tag file..." @warnColors
        }
        Write-Host "---------------------------------------------" @dividerColor
    }
    
    return [int]$queryID
}

# Retrieves movie metadata for tag creation. Custom properties are NOT checked for accuracy OR existence
function Get-Metadata {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Id,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$APIKey
    )

    # Trap to prevent terminating errors from crashing the script when a property isn't returned from the API
    trap { 
        Write-Error "An error occurred. Skipping property..."
        continue
    }

    # Create base object
    if ('TMDbID' -notin $SkipProperties) {
        $obj = @{
            'TMDB' = "movie/$Id"
        }
    }
    else { $obj = @{} }

    # Pull general info including IMDb ID
    if ('IMDbID' -notin $SkipProperties) {
        Write-Host "Requesting IMDB ID..."
        $genQuery = Invoke-RestMethod -Uri "https://api.themoviedb.org/3/movie/$($id)?api_key=$($APIKey)" -Method GET
        if ($imdbID = $genQuery | Select-Object -ExpandProperty imdb_id) {
            Write-Host "IMDb ID successfully retrieved! ID: " -NoNewline
            Write-Host $imdbID @progressColors

            $obj['IMDb'] = $imdbID
        }
        else {
            Write-Warning "Failed to retrieve IMDb ID. Property will be skipped"
        }
    }
    else { Write-Host "Skipping IMDb ID..." @warnColors  }

    Write-Host "---------------------------------------------" @dividerColor

    # Pull cast/crew data
    $credits = Invoke-RestMethod -Uri "https://api.themoviedb.org/3/movie/$($Id)/credits?api_key=$($APIKey)" -Method GET

    # Get cast members
    if ('Cast' -notin $SkipProperties) {
        Write-Host "Requesting cast metadata..."
        if ($cast = $credits.cast | Select-Object -ExpandProperty name -First 5 -Unique) {
            Write-Host "Cast metadata successfully retrieved! Cast info: " -NoNewline
            Write-Host $($cast -join ', ') @progressColors

            $obj['Cast'] = $cast
        }
        else {
            Write-Warning "Failed to retrieve cast metadata. Property will be skipped"
        }
    }
    else { Write-Host "Skipping Cast..." @warnColors }

    Write-Host "---------------------------------------------" @dividerColor

    # Get writers
    if ('Writers' -notin $SkipProperties) {
        Write-Host "Requesting writers metadata..."
        $writers = $credits.crew | Where-Object { $_.department -eq "Writing" } | 
                Select-Object name, job -First 3 -Unique
        if ($writers -is [array]) {
            [array]$writerArray += $writers.ForEach({ "$($_.name) ($($_.job))" })
        }
        else { 
            $writerArray = @($("$($writers.name) ($($writers.job))"))
        }
        if ($writerArray) {
            Write-Host "Writers metadata successfully retrieved! Writers info: " -NoNewline
            Write-Host $($writerArray -join ', ') @progressColors
            
            $obj['Written By'] = $writerArray
        }
    }
    else { Write-Host "Skipping Writers..." @warnColors }
        
    Write-Host "---------------------------------------------" @dividerColor
    
    # Get directors
    if ('Directors' -notin $SkipProperties) {
        Write-Host "Requesting directors metadata..."
        $directors = $credits.crew | Where-Object { $_.department -eq "Directing" -and $_.job -eq "Director" } | 
            Select-Object -ExpandProperty name -First 2 -Unique
        if ($directors) {
            Write-Host "Directors metadata successfully retrieved! Directors info: " -NoNewline
            Write-Host $($directors -join ', ') @progressColors

            $obj['Directed By'] = $directors
        }
        else {
            Write-Warning "Failed to retrieve Directors metadata. Property will be skipped"
        }
    }
    else { Write-Host "Skipping Directors..." @warnColors }

    Write-Host "---------------------------------------------" @dividerColor
   
     # Search for custom properties and add them if found
     if ($Properties) {
        Write-Host "Searching for additional user-defined properties..."
        Write-Verbose "Property passed: $($Properties -join ', ')"
        foreach ($prop in $Properties) {
            if (![string]::IsNullOrEmpty($genQuery.$prop)) {
                $prop = (Get-Culture).TextInfo.ToTitleCase($prop)
                # check for duplicate key before adding
                if (!$obj.ContainsKey($prop)) {
                    if ($prop -like "budget") {
                        [int]$val = $genQuery.$prop
                        $fNumber = "$" + $("{0:N0}" -f $val)
                        $obj.Add($prop, $fNumber)
                    }
                    elseif ($prop -like 'genres' -or $prop -like 'production*countries' -or $prop -like 'production*companies') {
                        $val = $genQuery.$prop.name.ForEach({ $_ }) -join ', '
                        $obj.Add($prop, $val)
                    }
                    else { $obj.Add($prop, $genQuery.$prop) }
                    
                    Write-Host "---------------------------------------------" @dividerColor
                    Write-Host "$prop metadata successfully retrieved! $prop info: " -NoNewline
                    Write-Host $genQuery.$prop @progressColors
                }
                else { Write-Warning "$prop is a duplicate key. Property will be skipped"}
            }
            else { Write-Host "$prop property was not found on return object" @warnColors }

            if ($prop -eq $Properties[-1]) {
                Write-Host "---------------------------------------------" @dividerColor
            }
        }
    }

    return $obj
} 

# Generates the XML file
function New-XMLTagFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [object]$Metadata,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputFile
    )

    [xml]$doc = [System.Xml.XmlDocument]::new()
    $null = $doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'UTF-8', $null))
    $root = $doc.CreateNode('element', 'Tags', $null)
    $tag = $doc.CreateNode('element', 'Tag', $null)
    foreach ($item in $Metadata.GetEnumerator()) {
        # Create the parent Simple tag
        $simple = $doc.CreateNode('element', 'Simple', $null)
        # Create the Name element for Simple and append it
        $name = $doc.CreateElement('Name')
        $name.InnerText = $item.Name
        $simple.AppendChild($name) > $null
        # Create the String element for Simple and append it
        $string = $doc.CreateElement('String')
        $string.InnerText = $item.Value -join ', '
        $simple.AppendChild($string) > $null
        # Append the Simple node to parent Tag node
        $tag.AppendChild($simple) > $null
    }
    $root.AppendChild($tag) > $null
    $doc.AppendChild($root) > $null
    $doc.Save($OutputFile)
}


#########################################################
# Main Script Logic                                     #                                           
#########################################################

if ($Path.EndsWith('.xml')) {
    $outXML = $Path
}
else {
    $outXML = $Path -replace '^(.+)\.(.+)$', '$1.xml'
}

if ((Test-Path -Path $outXML) -and !$PSBoundParameters['AllowClobber']) {
    Write-Host "<$outXML> already exists. To proceed, delete the file or use the -AllowClobber parameter to overwrite`n" @warnColors
    exit 0
}

Write-Host "$banner2`n`n" @dividerColor

# Sanitize title/year if not passed via parameter
if (!$PSBoundParameters['Title'] -or !$PSBoundParameters['Year']) {
    $leafBase = Split-Path -Path $Path -LeafBase

    # Try to sanitize input title
    $mTitle, $mYear = switch -Regex ($leafBase) {
        '^(?<title>[^(]+(?=\d+)?).*\(?(?<year>\d{4})\)?$' {
            Write-Verbose "Match case 1"
            ($Matches.title -replace '\.|_', ' ').Trim(),
            ($Matches.year).Trim()
    
            break 
        }
        '^(?<title>.+(?=\d+)?).*(?<year>\d{4}).*\d+p' {
            Write-Verbose "Match case 2"
            ($Matches.title -replace '\.|_|\(', ' ').Trim(),
            ($Matches.year).Trim()
    
            break 
        }
        default { 'Undefined', 'Undefined' }
    }
    
    # Verify if Title was passed. Otherwise, assign to mTitle if applicable
    if ($PSBoundParameters['Title']) {
        Write-Host "Search title: " -NoNewline
        Write-Host $Title @progressColors
    }
    elseif (!$Title -and $mTitle -ne 'Undefined') {
        $Title = $mTitle
        Write-Host "Search title: " -NoNewline
        Write-Host $Title @progressColors
    }
    else {
        $msg = "Could not sanitize input title, query may fail. If incorrect results are returned " +
               "or the script fails, use the -Title parameter to specify a clean title"
        Write-Warning $msg
        $Title = $leafBase -replace '\.|_', ' '
        Write-Host "Title is: " -NoNewline
        Write-Host $Title @progressColors
    }

    # Verify if Year was passed. Otherwise, assign to mYear if applicable
    if ($PSBoundParameters['Year']) {
        if ([string]$Year -notmatch '^[0-9]{4}$') {
            $msg = "Incorrect Year format. A 4 digit integer was expected, but $Year was received. " +
                   "Value will be skipped"
            Write-Warning $msg
            $Year = $null
        }
        else {
            Write-Host "Search year: " -NoNewline
            Write-Host $Year @progressColors
        }
    }
    elseif (!$Year -and $mYear -ne 'Undefined') {
        [int]$Year = $mYear
        Write-Host "Search year: " -NoNewline
        Write-Host $Year @progressColors
    }
    else { 
        Write-Warning "Could not sanitize input year, or no year was provided"
        $Year = $null
    }
}

# Try to retrieve metadata. Catch and display a variety of potential errors
try {
    [int]$id = Get-ID -Title $Title -APIKey $APIKey -Year $Year -ErrorAction Stop
    $movieObj = Get-Metadata -Id $id -APIKey $APIKey
    
    Write-Verbose "Object output:`n`n$($movieObj | Out-String)"
}
catch {
    if (!$id) {
        try {
            $testTitle = 'Ex Machina'
            $testQuery = Get-ID -Title $testTitle -APIKey $APIKey -Year $Year -ErrorAction Stop
        }
        catch {
            $params = @{
                Message           = "API endpoint is not reachable. Verify that the API key is not empty and that the endpoint is online"
                RecommendedAction = "Verify API Key is not null or empty, and manually test API functionality"
                Category          = 'AuthenticationError'
                CategoryActivity  = "REST API Call to TMDB Failed"
                TargetObject      = $APIKey
                ErrorId           = 1
            }
            Write-Error @params -ErrorAction Stop
        }
        if ($testQuery) {
            $params = @{
                Message           = "Return ID is empty, but the API endpoint is reachable using:`n`nKey: '$APIKey'`nTest Query: '$testTitle'`n"
                RecommendedAction = "Verify that the target title is correct"
                Category          = 'InvalidArgument'
                CategoryActivity  = "TMDB Identifier Retrieval"
                TargetObject      = $title
                ErrorId           = 2
            }
            Write-Error @params -ErrorAction Stop
        }
    }
    elseif (!$movieObj) {
        $params = @{
            Message           = "REST API call returned an empty object"
            RecommendedAction = "Verify that the TMDB API is online and functioning"
            Category          = 'ResourceUnavailable'
            CategoryActivity  = "Metadata Request"
            TargetObject      = $movieObj
            ErrorId           = 3
        }
        Write-Error @params -ErrorAction Stop
    }
}

# Try to create XML file
try {
    New-XMLTagFile -Metadata $movieObj -OutputFile $outXML -ErrorAction Stop
}
catch {
    if ((Test-Path $outXML) -and (Get-Item $outXML).Length -gt 0) {
        Write-Warning "XML tag file was successfully generated, but an Exception occurred: $($_.Exception.Message)"
    }
    else {
        Write-Error "Failed to generate XML file. Exception: $($_.Exception.Message)"
        exit 1
    }
}

# Mux the tag file into the container if mkvpropedit is in PATH
if ((Get-Command 'mkvpropedit') -and !$PSBoundParameters['NoMux'] -and $Path.EndsWith('.mkv')) {
    Write-Host "Muxing tag file into container..." @progressColors
    mkvpropedit $Path -t global:$outxML
}
elseif (!(Get-Command 'mkvpropedit') -and !$PSBoundParameters['NoMux']) {
    Write-Host "mkvpropedit not found in PATH. Add the tag file to the container manually" @warnColors
}
else {
    Write-Host "Success! Exiting script" @progressColors
}

Write-Host ""
$host.ui.RawUI.WindowTitle = $currName
exit 0