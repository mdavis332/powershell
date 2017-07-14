<#
.DESCRIPTION
  Designed to return Requestor emails from your RequestTracker instance that have submitted >=4 tickets in the last 4 days
#>

# Requires PowerShell v5 or higher
# Set .NET SecurityProtocol policy to include TLS 1.2 (necessary for https)
$AllProtocols = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
# Install PowerShell RequestTracker module
#Install-Module PSRT

# Import the module
Import-Module PSRT

# Set default values and create a session
# Set-RTConfig -BaseUri 'https://rtserver.local' -Credential (Get-Credential)
$MyRTSession = New-RTSession -Credential (Get-Credential) -BaseUri "https://rtserver.local"

$RT_Results = Find-RTTicket -Query "Created > '4 days ago'" -Referer 'https://rtserver.local' -Expand -Session $MyRTSession -BaseUri 'https://rtserver.local'

# iterate through tickets looking for duplicate Requestors and only return those Requestors who've put in 4 or more tickets in this timeframe
$DuplicateRequestors = $RT_Results | Group-Object Requestors | Where-Object { $_.Count -ge 4 }

# Email if we have Requestors that meet the threshold
if ($DuplicateRequestors -ne $null -AND $DuplicateRequestors.count -gt 0)
{
    $SMTPServer = "mail.local"
    $SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
    $SMTPMessage = New-Object System.Net.Mail.MailMessage
    $SMTPMessage.from = "rt-reports@mail.local"
    $SMTPMessage.to.add("recipient@mail.local")
    $SMTPMessage.subject = "Requestor Frequency Alert"
    $SMTPMessage.IsBodyHTML = $true
    $Body = "`n`n" 
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

   # create a custom custom label out of the resulting failure array of strings. On the fly, add an Exclude label and remove it. This is to fix a known issue with the ConvertTo-HTML cmdlet
   # https://social.technet.microsoft.com/Forums/office/en-US/588275ba-1b3a-42af-b59c-20264b25ff99/converttohtml-shows-in-html-table-column-header?forum=winserverpowershell
   $Body = $DuplicateRequestors | Select Name, Count | ConvertTo-HTML -Head $head -PreContent "<H2>$($DuplicateRequestors.Count) ticket Requestors that meet the threshold</H2>`n<br />The following Requestors met the frequency threshold for tickets in the past several days:`n`n<br />" -PostContent "<h6>Scheduled Task run at $(Get-Date)</h6> from $($MyInvocation.MyCommand.Definition) on computer $($env:computername)" | Convert-HTMLEscape | Out-String
   $SMTPMessage.body = "$Body"
   $SMTPClient.Send($SMTPMessage)
}
