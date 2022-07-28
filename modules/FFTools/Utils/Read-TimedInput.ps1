<#
    .SYNOPSIS
        An implementation of Read-Host with a timeout prompt
    .DESCRIPTION
        Accepts a custom prompt with a timeout field, so input prompts don't break
        automation for non-interactive sessions
    .PARAMETER Prompt
        A custom prompt for the user to interact with
    .PARAMETER Timeout
        The number of milliseconds to wait before exiting the prompt
    .NOTES
        This could probably be achieved via a custom type in a .ps1xml file, but this
        seemed easier to load from a module in the short term.

        This prompt only works with binary options like yes/no, true/false, etc.

#>
function Read-TimedInput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Prompt,

        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateScript({
                if ($_ -lt 1000) {
                    Write-Warning "Timeout value is in milliseconds"
                    $true
                }
                elseif ($_ -le 0) {
                    Write-Error "Timeout value must be positive"
                    $false
                }
                else { $true }
            })]
        [int]$Timeout = 50000,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Yes/No', 'Integer', 'Select')]
        [string]$Mode,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 4)]
        [int]$Count,

        [Parameter(Mandatory = $false)]
        [object]$InputObject
    )

    # Load the custom type if not already loaded
    if (!([System.Management.Automation.PSTypeName]'TimedInputField').Type) {
        Add-Type -TypeDefinition $TimedInputField
    }

    # Show the prompt
    try {
        if ($psReq) {
            Write-Host "$($boldOn+$blinkOn)$prompt$($reset)" -NoNewline
        }
        else {
            Write-Host $prompt -NoNewline
        }
        
        $response = [TimedInputField]::ReadLine($Timeout)
    }
    # If the user fails to enter anything in the timeout period, catch the exception and return false
    catch [System.TimeoutException] {
        Write-Host "`n"
        Write-Error -Exception $_.Exception
        $response = $null
    }

    # Check response based on mode. If it does not match, recurse until $Count is 0
    if ($response) {
        $retVal = switch ($Mode) {
            'Yes/No' {
                switch -Regex ($response) {
                    'y[es]?' { $true }
                    'n[o]?'  { $false }
                    default  { $null }
                }
            }
            'Integer' {
                (($response -as [int]) -is [int] -and $response -gt 0) ? [int]$response : $null
            }
            'Select' {
                if ($response -match '^e[xit]?' -or $response -match '^q[uit]?') {
                    Write-Host $exitBanner @errColors -ErrorAction Stop
                }
                ($response -in $InputObject -xor $response -like 'custom=*') ? $response : $null
            }
        }

        # If input doesn't match expected, perform a recursive call until count is 0
        if ($null -ne $retVal) { return $retVal }
        else {
            Write-Host "`u{274C} Invalid response" @errColors
            if ($Count -gt 0) {
                $Count--

                $params = @{
                    Prompt      = $Prompt
                    Mode        = $Mode
                    Timeout     = $Timeout
                    Count       = $Count
                    InputObject = $InputObject
                }
                Read-TimedInput @params
            }
            else {
                $params = @{
                    RecommendedAction = 'Enter a valid argument. Re-run the script if needed.'
                    Category          = 'InvalidArgument'
                    Exception         = [System.ArgumentException]::new("Invalid argument. The number of input attempts has been exceeded.")
                    TargetObject      = $retVal
                    CategoryActivity  = "$Mode Input Prompt"
                    ErrorId           = 89
                }
                Write-Error @params -ErrorAction Stop
            }
        }
    }
    # If timeout occurs, return $null
    else {
        return $null
    }
}

# C# binary code to create custom type
$Script:TimedInputField = @"

using System;
using System.Threading;
using System.Diagnostics;

public class TimedInputField
{
    private static string inputLast;
    private static Thread inputThread = new Thread(inputThreadAction) { IsBackground = true };
    private static AutoResetEvent inputGet = new AutoResetEvent(false);
    private static AutoResetEvent inputGot = new AutoResetEvent(false);

    static TimedInputField()
    {
        inputThread.Start();
    }

    private static void inputThreadAction()
    {
        while (true)
        {
            inputGet.WaitOne();
            inputLast = Console.ReadLine();
            inputGot.Set();
        }
    }

    // omit the parameter to read a line without a timeout
    public static string ReadLine(int timeout = Timeout.Infinite)
    {
        if (timeout == Timeout.Infinite)
        {
            return Console.ReadLine();
        }
        else
        {
            var stopwatch = new Stopwatch();
            stopwatch.Start();

            while (stopwatch.ElapsedMilliseconds < timeout && !Console.KeyAvailable) ;

            if (Console.KeyAvailable)
            {
                inputGet.Set();
                inputGot.WaitOne();
                return inputLast;
            }
            else
            {
                throw new TimeoutException("Failed to provide input within the time limit.");
            }
        }
    }
}
"@
