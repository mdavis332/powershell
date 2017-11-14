# ---- Config ----
$threshold = "6" # number of print jobs in a single queue at which or above you want to get alerts
$SMTPServer = "smtp.host.local"
$SMTPfrom = "printing@host.local"
$SMTPto = "support@host.local"
$SMTPsubject = "Numerous print jobs alert"
$PrintServer = "printers.host.local"

# ---- Main ----
# Get all print queues on print server that meet a certain threshold for number of jobs, then save the name of the printer and the # of jobs to an array
$Jobs = @(Get-CimInstance -ClassName Win32_PerfFormattedData_Spooler_PrintQueue -ComputerName $PrintServer | where { $_.Jobs -ge $threshold -and $_.Name -ne '_Total' } | select Name, Jobs)

# ---- Function ----
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

# If any queue has that many jobs in it, assume there may be an error we should look at
If ($Jobs.count -ge $threshold) {

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
	
	# create a custom custom label out of the resulting array of strings. On the fly, add an Exclude label and remove it. This is to fix a known issue with the ConvertTo-HTML cmdlet
	# https://social.technet.microsoft.com/Forums/office/en-US/588275ba-1b3a-42af-b59c-20264b25ff99/converttohtml-shows-in-html-table-column-header?forum=winserverpowershell
	$Body = $Jobs | Select @{Name='Name';Expression={$_.Name}}, @{Name='Jobs';Expression={$_.Jobs}} | ConvertTo-HTML -Head $head -PreContent "<H2>$($Jobs.Count) printers with numerous jobs</H2>`n<br />The following print queues have met the threshold for concurrent jobs:`n`n<br />" -PostContent "<h6>Scheduled Task run at $(Get-Date)</h6> from $($MyInvocation.MyCommand.Definition) on computer $($env:computername)" | Convert-HTMLEscape | Out-String
	Send-MailMessage -To $SMTPto -From $SMTPfrom -Subject $SMTPsubject -Body $Body -SmtpServer $SMTPServer -BodyAsHtml
}
