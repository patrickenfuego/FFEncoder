<#
    .SYNOPSIS  
        A script to pull movie metadata and save it in a Matroska compatible XML file
    .DESCRIPTION
        This script is meant to automate the generation of Matroska tag files, which can be
        used to append additional info to the container, and is readable by MediaInfo. the 
        script uses the IMDb API to generate tag information. the tag file is then automatically
        appended to container file using mkvpropedit (if available)
    .PARAMETER Path
        <String> Path to output file. The name of the file is used to search the API, i.e.
        'D:\Movies\Ex Machina 2014.mkv' will use 'Ex Machina 2014' for the search.
        Accepts most popular container formats (but will only add metadata to MKV files).
        Optionally, you may specify the XML output path as well
    .PARAMETER APIKey
        <String> API key used to query for IMDb information
    .PARAMETER Properties
        <Hashtable > Additional properties to add to the tag file,
        in the format: @{'Display Descriptor' = Property}
    .PARAMETER NoMux
        Switch parameter to skip file multiplexing with mkvpropedit (but still generate the file)
    .INPUTS
        <String> Path to MKV file or output destination
        <String> API key
    .OUTPUTS
        <XML> File formatted for Matroska tags, including:
            - Cast
            - Directed By
            - Written By
            - IMDb reference key
    .NOTES
        Requires a valid IMDb API key. Access is free, but registration is needed

        For best results, install the MkvToolNix package so that the script
        may automatically append the XML to your file 
    .LINK
        IMDb API: https://imdb-api.com/API
    .LINK
        MKVToolNix: https://mkvtoolnix.download/index.html
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [Parameter(Mandatory = $false, Position = 1)]
    [string]$APIKey,

    [Parameter(Mandatory = $false)]
    [hashtable]$Properties,

    [Parameter(Mandatory = $false)]
    [switch]$NoMux
)

#########################################################
# Global Variables                                      #                                           
#########################################################

#Save API key for use as a global variable if not passed
if (!$PSBoundParameters['APIKey']) {
    $APIKey = ''  #put API key here
}
$title = Split-Path -Path $Path -LeafBase
$progressColors = @{ForegroundColor = 'Green'; BackgroundColor = 'Black' }
$warnColors = @{ForegroundColor = 'Yellow'; BackgroundColor = 'Black' }

#########################################################
# Function Definitions                                  #                                           
#########################################################

#Retrieves the input file's IMDb code
function Get-MovieID {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$APIKey
    )

    $query = Invoke-RestMethod -Uri "https://imdb-api.com/en/API/Search/$APIKey/$Title" -Method Get
    $id = $query.results[0].id
    return $id
}

#Retrieves movie metadata for tag creation. Custom properties are NOT checked for accuracy OR existence
function Get-MovieMetadata {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Id,

        [Parameter(Mandatory = $false)]
        [string]$APIKey,

        [Parameter(Mandatory = $false)]
        [hashtable]$Properties
    )
    
    $query = Invoke-RestMethod -Uri "https://imdb-api.com/en/API/FullCast/$APIKey/$Id" -Method Get
    $cast = $query.actors.name | Select-Object -First 5
    $director = $query.directors.items.name
    $writers = $query.writers.items.name | Select-Object -Unique

    if ($PSBoundParameters['Properties']) {
        $obj2 = [ordered]@{}
        foreach ($prop in $Properties.GetEnumerator()) {
            #Verify that property returns a value
            if ($res = $query.$($prop.Value).items.name) {
                $obj2[$prop.Name] = $res
            }
        }
    }

    $obj = [ordered]@{
        'IMDb'        = $Id
        'Cast'        = $cast 
        'Directed By' = $director 
        'Written By'  = $writers 
    }

    #If custom properties were passed, ensure no duplicate keys exist
    if ($obj2) {
        foreach ($k in $obj2.Keys) {
            if ($obj.ContainsKey($k)) {
                Write-Warning "Duplicate key found. Value will be skipped"
            }
            else {
                $obj[$k] = $obj2.$k
            }
        }
    }

    return $obj
}

#Generates the XML file
function New-XMLFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [object]$Metadata,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$OutputFile
    )

    [xml]$doc = New-Object System.Xml.XmlDocument
    $null = $doc.AppendChild($doc.CreateXmlDeclaration('1.0', 'UTF-8', $null))
    $root = $doc.CreateNode('element', 'Tags', $null)
    $tag = $doc.CreateNode('element', 'Tag', $null)
    foreach ($item in $Metadata.GetEnumerator()) {
        #Create the parent Simple tag
        $simple = $doc.CreateNode('element', 'Simple', $null)
        #Create the Name element for Simple and append it
        $name = $doc.CreateElement('Name')
        $name.InnerText = $item.Name
        $simple.AppendChild($name) > $null
        #Create the String element for Simple and append it
        $string = $doc.CreateElement('String')
        $string.InnerText = $item.Value -join ", "
        $simple.AppendChild($string) > $null
        #Append the Simple node to parent Tag node
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

if (Test-Path -Path $outXML) {
    Write-Host "file already exists. Skipping creation`n" @warnColors
    exit 0
}

#Try to retrieve metadata. Catch and display a variety of potential errors
try {
    $id = Get-MovieID -Title $title -APIKey $APIKey -ErrorAction Stop
    $movieObj = Get-MovieMetadata -Id $id -APIKey $APIKey -ErrorAction Stop
}
catch {
    if (!$id) {
        $testTitle = 'Ex Machina'
        $testQuery = Get-MovieID -Title $testTitle -APIKey $APIKey
        if ($testQuery) {
            $params = @{
                Message           = "Return ID is empty, but the API endpoint is reachable using:`n`nKey:`t`t'$APIKey'`nTest Query:`t'$testTitle'"
                RecommendedAction = "Verify that the target title is correct"
                Category          = 'InvalidArgument'
                CategoryActivity  = "IMDb Identifier Retrieval"
                TargetObject      = $title
                ErrorId           = 1
            }
            Write-Error @params
        }
        else {
            $params = @{
                Message           = "API endpoint isn't reachable using:`n`nKey: $APIKey"
                RecommendedAction = "Verify that the API key is correct and the endpoint is reachable"
                Category          = 'AuthenticationError'
                CategoryActivity  = "REST API Call to IMDb Failed"
                TargetObject      = $APIKey
                ErrorId           = 2
            }
            Write-Error @params
        }
    }
    elseif (!$movieObj) {
        $params = @{
            Message           = "REST API call returned an empty object"
            RecommendedAction = "Verify that the IMDb API is online and functioning"
            Category          = 'ResourceUnavailable'
            CategoryActivity  = "Metadata Request"
            TargetObject      = $movieObj
            ErrorId           = 3
        }
        Write-Error @params
    }
    Write-Host
    throw "Failed to retrieve metadata. Exiting script"
}

#Try to create XML file
try {
    #Generate XML file
    New-XMLFile -Metadata $movieObj -OutputFile $outXML
}
catch {
    if (Test-Path $outXML -and (Get-Item $outXML).Length -gt 0) {
        Write-Warning "XML tag file was successfully generated, but an exception occurred: $($_.Exception.Message)"
    }
    else {
        throw "Failed to generate XML file. Exception: $($_.Exception.Message)"
    }
}

#Mux the tag file into the container if mkvpropedit is in PATH
if ((Get-Command 'mkvpropedit') -and !$PSBoundParameters['NoMux'] -and $Path.EndsWith('.mkv')) {
    Write-Host "Muxing tag file into container..." @progressColors
    mkvpropedit $Path -t global:$outxML
}
elseif (!(Get-Command 'mkvpropedit') -and !$PSBoundParameters['NoMux']) {
    Write-Host "mkvpropedit not found in PATH. Add the tag file to the container manually" @warnColors
    exit 0
}
