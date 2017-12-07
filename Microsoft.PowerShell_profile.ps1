# adjust Posh-Git profile a la https://github.com/dahlbyk/posh-git/wiki/Customizing-Your-PowerShell-Prompt
function prompt {
    $maxPathLength = 40
    $origLastExitCode = $LASTEXITCODE
    $time = (Get-DAte).ToShortTimeString()
    #"$time [$env:COMPUTERNAME] $(Get-Location)> "
    $curPath = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    if ($curPath.ToLower().StartsWith($Home.ToLower())) {
        $curPath = "~" + $curPath.SubString($Home.Length)
    }

    if ($curPath.Length -gt $maxPathLength) {
        $curPath = '...' + $curPath.SubString($curPath.Length - $maxPathLength + 3)
    }

    Write-Host "$time [$env:COMPUTERNAME] $curPath" -NoNewline
    Write-VcsStatus
    $LASTEXITCODE = $origLastExitCode
    "$('>' * ($nestedPromptLevel + 1)) "

}

# Import the posh-git module, first via installed posh-git module.
# If the module isn't installed, then attempt to load it from the cloned posh-git Git repo.
$poshGitModule = Get-Module posh-git -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
if ($poshGitModule) {
    $poshGitModule | Import-Module
}
elseif (Test-Path -LiteralPath ($modulePath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) (Join-Path src 'posh-git.psd1'))) {
    Import-Module $modulePath
}
else {
    #throw "Failed to import posh-git."
    Install-PackageProvider -Name NuGet -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name posh-git -Scope CurrentUser
    Import-Module -Name posh-git
}

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

<#
function prompt {
	$time = (Get-DAte).ToShortTimeString()
	"$time [$env:COMPUTERNAME] $(Get-Location)> "
}

#>

$global:GitPromptSettings.BeforeText = '['
$global:GitPromptSettings.AfterText = ']'
$global:GitPromptSettings.DefaultPromptAbbreviateHomeDirectory = $true


cd c:\

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
