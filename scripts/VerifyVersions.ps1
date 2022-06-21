<#
    .SYNOPSIS
        Utility function to retrieve current FFencoder or Pwsh version from GitHub
    .DESCRIPTION
        Pulls down the latest version of Pwsh or FFEncoder from GitHub, and notifies the user
        if there are any updates
    .NOTES
        Uses GitHub REST API
#>
function Get-ReleaseVersion ([string]$Repository) {
    $repo = switch ($Repository) {
        'PowerShell' { 'PowerShell/PowerShell' }
        'Pwsh' { 'PowerShell/PowerShell' }
        'FFEncoder' { 'patrickenfuego/FFEncoder' }
    }

    $uri = "https://api.github.com/repos/$repo/releases"

    return (Invoke-RestMethod -Uri $uri).tag_name |
        Where-Object { $_.SubString(1) -as [version] } | 
            Sort-Object { [version]$_.SubString(1) } -Descending |
                Select-Object -First 1
}

<#
    .SYNOPSIS
        Utility functions to verify the system version of Pwsh
    .DESCRIPTION
        Verifies that the current Pwsh execution context meets the minimum requirements of
        FFEncoder. It also warns the user if they are not running the latest version of Pwsh
#>
function Confirm-PoshVersion {
    if (!(Get-Command 'pwsh') -or (Get-Command 'pwsh').Version -lt [version]'7.0.0.0') {
        $ErrorView = 'NormalView'

        $params = @{
            RecommendedAction = 'Update PowerShell to version 7.0 or greater'
            Category          = "NotInstalled"
            Exception         = [System.ExecutionEngineException]::new("The script requires PowerShell 7.0 or greater")
            TargetObject      = $PSVersionTable.PSVersion
            ErrorId           = 51
        }
        Write-Error @params -ErrorAction Stop
    }
    # If pwsh 7 is installed, but currently running from Windows PowerShell context
    elseif ($PSVersionTable.PSVersion -lt [version]'7.0.0.0') {
        $ErrorView = 'NormalView'

        $msg = "Currently running with PowerShell $($PSVersionTable.PSVersion.Major). Switch to PowerShell 7"
        $params = @{
            RecommendedAction = 'Switch PowerShell interpreter to 7.0 or greater'
            Category          = "InvalidOperation"
            Exception         = [System.ExecutionEngineException]::new($msg)
            TargetObject      = $PSVersionTable.PSVersion
            ErrorId           = 52
        }
        Write-Error @params -ErrorAction Stop
    }
    elseif (($PSVersionTable.PSVersion -lt [version]'7.2.0.0')) {
        $latestRelease = Get-ReleaseVersion -Repository Pwsh
        
        Write-Host "You are not running the latest version of PowerShell 7:" @warnColors
        Write-Host "  - Current Version:`tv$($PSVersionTable.PSVersion)" @errColors
        Write-Host "  - Latest Version:`t$latestRelease" @progressColors
        Write-Host "Consider upgrading to the latest version for additional features" @warnColors

        return $false
    }
    else {
        Write-Verbose "PowerShell version requirement met"
        return $true
    }
}

<#
    .SYNOPSIS
        Check for updates to FFEncoder and pull the latest
    .DESCRIPTION
        Function to compare the internal release of FFEncoder against the release version in GitHub.
        If a newer version is available, the user is prompted to clone the latest repo and exit the
        current PowerShell session
    .PARAMETER CurrentRelease
        Current version of script. Pulled from the module manifest
#>
function Update-FFEncoder ([version]$CurrentRelease, [switch]$Verbose) {
    if ($Verbose) { $VerbosePreference = 'Continue' }

    $latest = Get-ReleaseVersion -Repository FFEncoder
    Write-Verbose "Latest release of FFEncoder: $latest"

    if ($CurrentRelease -ge [version]$latest.SubString(1)) {
        Write-Verbose "Using the latest version of FFEncoder: $CurrentRelease"
        return
    }
    
    Write-Host ""
    $yn = $psReq ? ("($($PSStyle.Foreground.BrightGreen+$PSStyle.Bold)Y$($PSStyle.Reset) / $($PSStyle.Foreground.BrightRed+$PSStyle.Bold)N$($PSStyle.Reset))") : '(Y / N)' 
    $params = @{
        Prompt  = "There is an update available for FFEncoder. Would you like to pull the latest release? $yn`: "
        Timeout = 20000
        Mode    = 'Yes/No'
        Count   = 3
    }

    try {
        $response = Read-TimedInput @params
    }
    catch {
        Write-Host "`u{203C} $($_.Exception.Message). Returning..." @errColors
        return
    }

    if ($response) {
        Write-Host "The updated repository will be cloned with the suffix '-latest' inside the parent directory" @progressColors

        if (Get-Command 'git') {
            Push-Location (Get-Location).Path && Push-Location ((Get-Item (Get-Location)).Parent).FullName
            $repoPath = ([System.IO.Path]::Join((Get-Location).Path, 'FFEncoder-latest')).ToString()

            if ([System.IO.Directory]::Exists($repoPath)) {
                Write-Host "Repository directory already exists. Rename or delete the old one before pulling the update" @warnColors
                Pop-Location
                return
            }
            # Clone the repo and save it with the -latest suffix in the same parent directory
            git clone https://github.com/patrickenfuego/FFEncoder.git $repoPath
            Pop-Location

            if ([System.IO.Directory]::Exists($repoPath)) {
                $params = @{
                    Prompt  = "Repository successfully cloned. Would you like to exit this script and use the new release? $yn`: "
                    Timeout = 15000
                    Mode    = 'Yes/No'
                    Count   = 3
                }

                try {
                    $response = Read-TimedInput @params
                }
                catch {
                    Write-Host "`u{203C} $($_.Exception.Message). Returning..." @errColors
                    return
                }

                if ($response) {
                    Write-Host "Yes was selected. Exiting script" @successColors
                    exit 0
                }
                else { return }
            }
        }
        else {
            Write-Error "git could not be found. Ensure it is available via PATH. Repository will not be cloned"
            return
        }
    }
    else {
        Write-Verbose "No was selected - skipping release update. Returning..."
        return
    }
}