<#
    MODULE VARIABLES

    Local
        Set module/script paths
        Set ANSI escape sequences
        DEE Variables - Some can be manually set here, or dynamically generated by the script
    Export
        Console color hashes
        OSType Verification
        Banners
        Current Script Release

#>

# Setting Module Run Location
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$PSModule = $ExecutionContext.SessionState.Module
$PSModuleRoot = $PSModule.ModuleBase
$ScriptsDirectory = [System.IO.Path]::Join($(Get-Item $ScriptPath).Parent.Parent, 'scripts')

$progressColors = @{ForegroundColor = 'Green'; BackgroundColor = 'Black' }
$warnColors = @{ForegroundColor = 'Yellow'; BackgroundColor = 'Black' }
$emphasisColors = @{ForegroundColor = 'Cyan'; BackgroundColor = 'Black' }
$errColors = @{ ForegroundColor = 'Red'; BackgroundColor = 'Black' }

# Ansi colors
$aYellow = $PSStyle.Foreground.BrightYellow
$aRed = $PSStyle.Foreground.Red
$aBlue = $PSStyle.Foreground.Blue
$aBBlue = $PSStyle.Foreground.BrightBlue
$aGreen = $PSStyle.Foreground.Green
$aCyan = $PSStyle.Foreground.Cyan
$aMagenta = $PSStyle.Foreground.Magenta
$aBMagenta = $PSStyle.Foreground.BrightMagenta
$aBrightBlack = $PSStyle.Foreground.BrightBlack

# Ansi fonts
$boldOn = $PSStyle.Bold
$boldOff = $PSStyle.BoldOff

$italicOn = $PSStyle.Italic
$italicOff = $PSStyle.ItalicOff

$blinkOn = $PSStyle.Blink
$blinkOff = $PSStyle.BlinkOff

$ul = $PSStyle.Underline
$ulOff = $PSStyle.UnderlineOff

$reset = $PSStyle.Reset


# Track titles for muxing files with mkvmerge
$Script:trackTitle = @{
    AudioTitle1   = $null
    AudioTitle2   = $null
    StereoTitle   = $null
    ExternalTitle = $null
    DeeTitle      = $null
    VideoTitle    = $null
}

# Arguments for dee encoders and audio
$Script:dee = @{
    DeeArgs = @('dee_ddp', 'dee_eac3', 'dee_dd', 'dee_ac3', 'dee_thd', 'dee_ddp_51', 'dee_eac3_51')
    DeeUsed = $false
}

# Detect operating system info
if ($isMacOs) {
    $osInfo = @{
        OperatingSystem = "Mac"
        DefaultPath     = "$HOME/Movies"
    } 
}
elseif ($isLinux) {
    $osInfo = @{
        OperatingSystem = "Linux"
        DefaultPath     = "$HOME/Videos"
    }
}
elseif ($env:OS -like "*Windows*") {
    $osInfo = @{
        OperatingSystem = "Windows"
        DefaultPath     = [Environment]::GetFolderPath('MyVideos')
    }
}
else { 
    Write-Error "Failed to load module. Could not detect operating system." -ErrorAction Stop 
}

## Define Banners ##

# $banner_old = @'
# _____  _      _               _   _         _____ _____ _____                     _           
# |  ___(_)_ __(_)_ __   __ _  | | | |_ __   |  ___|  ___| ____|_ __   ___ ___   __| | ___ _ __ 
# | |_  | | '__| | '_ \ / _` | | | | | '_ \  | |_  | |_  |  _| | '_ \ / __/ _ \ / _` |/ _ \ '__|
# |  _| | | |  | | | | | (_| | | |_| | |_) | |  _| |  _| | |___| | | | (_| (_) | (_| |  __/ |   
# |_|   |_|_|  |_|_| |_|\__, |  \___/| .__/  |_|   |_|   |_____|_| |_|\___\___/ \__,_|\___|_|   
#                       |___/        |_|     
# '@

$banner1 = @'
             _____  _      _               _   _                   
             |  ___(_)_ __(_)_ __   __ _  | | | |_ __    
             | |_  | | '__| | '_ \ / _` | | | | | '_ \  
             |  _| | | |  | | | | | (_| | | |_| | |_) |    
             |_|   |_|_|  |_|_| |_|\__, |  \___/| .__/   
                                   |___/        |_|         

'@

$banner2 = @'
███████ ███████ ███████ ███    ██  ██████  ██████  ██████  ███████ ██████  
██      ██      ██      ████   ██ ██      ██    ██ ██   ██ ██      ██   ██ 
█████   █████   █████   ██ ██  ██ ██      ██    ██ ██   ██ █████   ██████  
██      ██      ██      ██  ██ ██ ██      ██    ██ ██   ██ ██      ██   ██ 
██      ██      ███████ ██   ████  ██████  ██████  ██████  ███████ ██   ██ 

'@

$exitBanner = @'
___________      .__  __  .__                 ______________________                            .___            
\_   _____/__  __|__|/  |_|__| ____    ____   \_   _____/\_   _____/___   ____   ____  ____   __| _/___________ 
 |    __)_\  \/  /  \   __\  |/    \  / ___\   |    __)   |    __)/ __ \ /    \_/ ___\/  _ \ / __ |/ __ \_  __ \
 |        \>    <|  ||  | |  |   |  \/ /_/  >  |     \    |     \\  ___/|   |  \  \__(  <_> ) /_/ \  ___/|  | \/
/_______  /__/\_ \__||__| |__|___|  /\___  /   \___  /    \___  / \___  >___|  /\___  >____/\____ |\___  >__|   
        \/      \/                \//_____/        \/         \/      \/     \/     \/           \/    \/  

                                        See ya next time  

'@

# Current script release version
[version]$release = '2.0.3'


#### End module variables ####

<#
    LOAD MODULE FUNCTIONS
#>

## region Load Public Functions ##
try {
    Get-ChildItem "$ScriptPath\Public" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} 
catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}
## region Load Private Functions ##
try {
    Get-ChildItem "$ScriptPath\Private" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
} 
catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}
## Region Load Util Functions ##
try {
    Get-ChildItem "$ScriptPath\Utils" -Filter *.ps1 | Select-Object -ExpandProperty FullName | ForEach-Object {
        $function = Split-Path $_ -Leaf
        . $_
    }
}
catch {
    Write-Warning ("{0}: {1}" -f $function, $_.Exception.Message)
    continue
}

## Setting Function Aliases ##
New-Alias -Name iffmpeg -Value Invoke-FFMpeg -Force
New-Alias -Name cropfile -Value New-CropFile -Force
New-Alias -Name cropdim -Value Measure-CropDimensions -Force

# Export module functions, aliases, and variables
$ExportModule = @{
    Alias    = @('iffmpeg', 'cropfile', 'cropdim')
    Function = @('Invoke-FFmpeg', 'Invoke-TwoPassFFmpeg', 'New-CropFile', 'Measure-CropDimensions', 'Remove-FilePrompt', 'Write-Report', 'Confirm-HDR10Plus',
                 'Confirm-DolbyVision', 'Confirm-ScaleFilter', 'Invoke-MkvMerge', 'Invoke-DeeEncoder', 'Read-TimedInput', 'Invoke-VMAF')
    Variable = @('progressColors', 'warnColors', 'emphasisColors', 'errColors', 'osInfo', 'banner1', 'banner2', 'exitBanner', 'ScriptsDirectory',
                 'release' )
}
Export-ModuleMember @ExportModule