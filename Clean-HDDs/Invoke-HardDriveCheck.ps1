<#
Hard Drive space alert script - v1.0
Originally inspired by user joeg1ff's reply to http://serverfault.com/questions/612442/custom-alert-in-sccm-2012-r2
Michael Davis, 04/27/2015
    Refactored all code to not require declared $user and $pwd in the script

License: GPL v2 or later

Notes:

Disclaimer:
I am not responsible with any problems this script may cause you. 
#>
param(
	[parameter(Mandatory=$true)] [String]$SQLServer, 
	[parameter(Mandatory=$true)][String]$SiteCode
)


# SQL function, 1 connection per command, may want to break that up but too lazy.
function Invoke-SqlQuery
{
    param(
    [Parameter(Mandatory=$true)] [string]$ServerInstance,
    [string]$Database,
    [Parameter(Mandatory=$true)] [string]$Query,
    [Int32]$QueryTimeout=600,
    [Int32]$ConnectionTimeout=15
    )

    try {
        $ConnectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;Connect Timeout=$ConnectionTimeout"
        $conn=new-object System.Data.SqlClient.SQLConnection
        $conn.ConnectionString=$ConnectionString
        $conn.Open()
        $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
        $cmd.CommandTimeout=$QueryTimeout
        $ds=New-Object system.Data.DataSet
        $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$da.fill($ds)
        Write-Output ($ds.Tables[0])
    }
    finally {
        $conn.Dispose()
    }
}
# function to handle HTML escaping so the HTML comes out correctly formatted for rich-text emails
Function Convert-HTMLEscape {
<#
convert &lt; and &gt; to < and > It is assumed that these will be in pairs
#>
 
[cmdletbinding()]
 
Param (
[Parameter(Position=0,ValueFromPipeline=$True)]
[string[]]$Text
)
 
Process {
foreach ($item in $text) {
    if ($item -match "&lt;") {
         
        (($item.Replace("&lt;","<")).Replace("&gt;",">")).Replace("&quot;",'"')
     }
     else {
        #otherwise just write the line to the pipeline
        $item
     }
 }
} #close process
 
} #close function


# ---- Main ----
$threshold = "7" # percentage of hdd space at which or below you want to get alerts
$SMTPServer = "mail.domain.local"
$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
$SMTPMessage = New-Object System.Net.Mail.MailMessage
$SMTPMessage.from = "configmgr@domain.local"
$SMTPMessage.to.add("support@domain.local")
$SMTPMessage.subject = "Low Disk Space Alert"
$SMTPMessage.IsBodyHTML = $true
$Body = "`n`n" 
$ConfigMgrDatabase = "CM_$SiteCode"
$scriptPath=Split-Path -parent $MyInvocation.MyCommand.Definition
$head=@"
<style>
@charset "UTF-8";

table
{
font-family:"Trebuchet MS", Arial, Helvetica, sans-serif;
border-collapse:collapse;
}
td 
{
font-size:1em;
border:1px solid #98bf21;
padding:5px 5px 5px 5px;
}
th 
{
font-size:1.1em;
text-align:center;
padding-top:5px;
padding-bottom:5px;
padding-right:7px;
padding-left:7px;
background-color:#A7C942;
color:#ffffff;
}
name tr
{
color:#F00000;
background-color:#EAF2D3;
}
</style>
"@

Write-Output "--- Client Hard Drive space alert script ---"

# get a list of dell computers in the site
Write-Output "Obtaining list of systems with low hdd space..."


$LowSpaceQuery = @"
SELECT 
SYS.Name0 as [Computer],
LDISK.DeviceID0 as [Drive],
LDISK.FreeSpace0*100/LDISK.Size0 as [Percentage Free]
FROM v_R_System as SYS
join v_GS_LOGICAL_DISK LDISK on SYS.ResourceID = LDISK.ResourceID
WHERE
LDISK.DriveType0 =3 AND --DriveType(3) = Local Disk
LDISK.Size0 > 0 AND
LDISK.DeviceID0 = 'C:' AND
LDISK.FreeSpace0*100/LDISK.Size0 < $threshold --less than 20% free space left on drive
--ORDER BY SYS.Name0, LDISK.DeviceID0
ORDER BY LDISK.FreeSpace0*100/LDISK.Size0
"@


$LowSpaceSystems = Invoke-SqlQuery -ServerInstance $SQLServer -Database $ConfigMgrDatabase -Query $LowSpaceQuery
if(!$? -or !$LowSpaceSystems) { Write-Error "There was a problem receiving the list of systems with low hard drive space." }

#progressbar variables
$length = $LowSpaceSystems.count / 100
if ($length -eq 0) { $length=1/100 }
$count=1

#if array is of length 0 the foreach clause still runs with a null value. If check to fix.
if($LowSpaceSystems.Count -gt 0 -OR $LowSpaceSystems -ne $null)
{
	# Take the resulting low space systems and send them to the Clean-TempFiles script
	$Results = @(& ((Split-Path $MyInvocation.InvocationName) + "\Clean-TempFiles.ps1") -TargetComputers ($LowSpaceSystems | Select -Expand Computer))
}

# if we have results of failures
if ($Results -ne $null -AND $Results.count -ge 1)
{
   # create a custom custom label out of the resulting failure array of strings. On the fly, add an Exclude label and remove it. This is to fix a known issue with the ConvertTo-HTML cmdlet
   # https://social.technet.microsoft.com/Forums/office/en-US/588275ba-1b3a-42af-b59c-20264b25ff99/converttohtml-shows-in-html-table-column-header?forum=winserverpowershell
   $Body = $Results | Select @{Name='Computer';Expression={$_}}, @{Name='CleanSuccess';Expression={'False'}} -ExcludeProperty Success | ConvertTo-HTML -Head $head -PreContent "<H2>$($LowSpaceSystems.Count) computers with low space</H2>`n<br />The following results failed when attempting automatic cleanup:`n`n<br />" -PostContent "<h6>Scheduled Task run at $(Get-Date)</h6> from $($MyInvocation.MyCommand.Definition) on computer $($env:computername)" | Convert-HTMLEscape | Out-String
   $SMTPMessage.body = "$Body"
   $SMTPClient.Send($SMTPMessage)
}
Write-Output "Script Complete."
