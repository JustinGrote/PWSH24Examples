#requires -version 5
$showPromptCheckpoint = $false

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -MaximumHistoryCount 32767 #-HistorySavePath "$([environment]::GetFolderPath('ApplicationData'))\Microsoft\Windows\PowerShell\PSReadLine\history.txt"
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
# Set-PSReadLineKeyHandler -Key "Ctrl+f" -Function ForwardWord


function Checkpoint ($CheckpointName, [Switch]$AsWriteHost,[Switch]$Reset) {
    if ($Reset) {
        $SCRIPT:checkpointStartTime = [datetime]::now
    }
    if (-not $SCRIPT:processStartTime) {
        $SCRIPT:processStartTime = (get-process -id $pid).starttime
        $SCRIPT:checkpointStartTime = [datetime]::now
        [int]$cp = ($checkpointStartTime - $processStartTime).totalmilliseconds
    } else {
        [int]$cp = ([datetime]::now - $checkpointStartTime).totalmilliseconds
    }

    if ($showPromptCheckpoint) {
        $debugpreference = 'Continue'
        $message = "$([char]27)[95m${cp}ms: $CheckpointName$([char]27)[0m"
        if ($AsWriteHost) {
            Write-Host -Fore Magenta $Message
        } else {
            Write-Debug $Message -verbose
        }
    }
}


#VSCode Specific Theming
if ($env:TERM_PROGRAM -eq 'VSCode' -or $env:WT_SESSION) {
    if ($psedition -eq 'core') {
        $e = "`e"
    } else {
        $e = [char]0x1b
    }

    if ($PSEdition -eq 'Core') {
        Set-PSReadlineOption -Colors @{
            Command            = "$e[93m"
            Comment            = "$e[32m"
            ContinuationPrompt = "$e[37m"
            Default            = "$e[37m"
            Emphasis           = "$e[96m"
            Error              = "$e[31m"
            Keyword            = "$e[35m"
            Member             = "$e[96m"
            Number             = "$e[35m"
            Operator           = "$e[37m"
            Parameter          = "$e[37m"
            Selection          = "$e[37;46m"
            String             = "$e[33m"
            Type               = "$e[34m"
            Variable           = "$e[96m"
        }
    }

    #Verbose Text should be distinguishable, some hosts set this to yellow
    $host.PrivateData.DebugBackgroundColor    = 'Black'
    $host.PrivateData.DebugForegroundColor    = 'Magenta'
    $host.PrivateData.ErrorBackgroundColor    = 'Black'
    $host.PrivateData.ErrorForegroundColor    = 'Red'
    $host.PrivateData.ProgressBackgroundColor = 'DarkCyan'
    $host.PrivateData.ProgressForegroundColor = 'Yellow'
    $host.PrivateData.VerboseBackgroundColor  = 'Black'
    $host.PrivateData.VerboseForegroundColor  = 'Cyan'
    $host.PrivateData.WarningBackgroundColor  = 'Black'
    $host.PrivateData.WarningForegroundColor  = 'DarkYellow'
}
checkpoint vscode

#Set Window Title to icon-only for Windows Terminal, otherwise display Powershell version
if ($env:WT_SESSION) {
    [Console]::Title = ''
} else {
    [Console]::Title = "Powershell $($PSVersionTable.PSVersion.Major)"
}
checkpoint WTSession

#region Aliases and Shortcuts
Set-Alias tf (command terraform -all -ErrorAction SilentlyContinue | where {$PSItem -notmatch 'ps1'})
Set-Alias pul (command pulumi -all -ErrorAction SilentlyContinue | where {$PSItem -notmatch 'ps1'})
Function cicommit {git commit --amend --no-edit;git push -f}

function bounceCode {get-process code* | stop-process;code}

function debugOn {$GLOBAL:VerbosePreference='Continue';$GLOBAL:DebugPreference='Continue'}

function testprompt {
    Import-Module "$HOME\Projects\PowerPrompt\PowerPrompt\PowerPrompt.psd1" -force
    Get-PowerPromptDefaultTheme
}

Set-PSReadLineKeyHandler -Description 'Edit current directory with Visual Studio Code' -Chord Ctrl+Shift+e  -ScriptBlock {
    if (command code-insiders -ErrorAction SilentlyContinue) {code-insiders .} else {
        code .
    }

}

#Persist Stored Credentials on local machine
if (!$PSDefaultParameterValues."Parameters:Processed") {
    $PSDefaultParameterValues.add("New-StoredCredential:Persist", "LocalMachine")

    #Install all modules in currentuser scope, to avoid admin rights being required
    $PSDefaultParameterValues.add("Install-Module:Scope", "CurrentUser")
    $PSDefaultParameterValues.add("Install-Script:Scope", "CurrentUser")

    $PSDefaultParameterValues.add("Parameters:Processed", $true)
}

#Force TLS 1.2 for all connections
if ($PSEdition -eq 'Desktop') {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

#Enable concise errorview for PS7 and up
if ($psversiontable.psversion.major -ge 7) {
    $ErrorView = 'ConciseView'
}

#region Helpers
function Invoke-WebScript {
    param (
        [string]$uri,
        [Parameter(ValueFromRemainingArguments)]$myargs
    )
    Invoke-Expression "& {$(Invoke-WebRequest $uri)} $myargs"
}
#endregion Helpers
