#Import-Module ActiveDirectory

function prompt {
	$time = (Get-DAte).ToShortTimeString()
	"$time [$env:COMPUTERNAME] $(Get-Location)> "
}

cd c:\

Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
