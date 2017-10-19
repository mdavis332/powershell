$DocsPath = Split-Path -Path $Profile

# Posh-Git
$PoshGitPath = "$DocsPath\posh-git\src\posh-git.psd1"
If (Test-Path($PoshGitPath)) {
	Import-Module "$PoshGitPath"
}	

# Chocolatey profile
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
