<#
DELL Warrenty Info - v1.0
Scott Keiffer, 2011 (skeiffer_A_T_cm_D_O_T_utexas_D_O_T_edu)
Michael Davis, 2016 (@mdavis332 on Twitter)
	-Adjusted for compatibility with Dell's new web API v4

License: GPL v2 or later

Notes:
This part of the script is contained in its own function so that it can be added to your powershell profile or script to be used for whatever you want to code. 

Disclaimer:
I am not responsible with any problems this script may cause you. 
#>

# API URL from Dell
# $sandboxURL = "https://sandbox.api.dell.com/support/assetinfo/v4/getassetwarranty"
$URL = "https://api.dell.com/support/assetinfo/v4/getassetwarranty"

$today = Get-Date

function get-DellWarranty {
	<#
		.Synopsis
		Returns Dell warranty information for given computers.
	
		.Description
		This command returns dell warrenty information based on information given. Input is pipeable and can be servicetags or computernames (.
		
		.Parameter Comptuer
		The computer or servicetag to be looked up
		
		.Parameter ServiceTagInput
		This is used to tell the function that $Computer contains service tags and not computer names.
		
		.Parameter LogFilePath
		If specified output will be appended to this file.
		
		.Parameter ApiKey
		The API Key for the Dell Asset Info API. Must contact Dell to get one of these. https://techdirect.dell.com/portal/AboutAPIs.aspx 
	
		.Example
		Get-DellWarranty MyComputerName
		Returns the warranty information for MyComputerName
		
		.Example
		Get-Content .\servicetags.txt | Get-Profiles -ServiceTagInput
		Returns the warranty information for the service tags listed in servicetags.txt
		
		.Link
		Author:    Scott Keiffer
		Date:      05/04/11
		Website:   http://www.cm.utexas.edu
		#Requires -Version 2.0
	#>
	[CmdletBinding()]
	param (
		[parameter(ValueFromPipeLine=$true)][String]$computer, 
		[String]$logFilePath, 
		[switch]$ServiceTagInput,
		[string]$ApiKey
	)
	begin {
		$ErrorActionPreference = "SilentlyContinue"
		
		# -------- Helper functions --------
		# Writes verbose output to the scree and logfile if specified globaly
		function Write-OutputLog {
			param ([parameter(mandatory=$true,ValueFromPipeLine=$true)][String]$outString,[switch]$warning,[switch]$toHost)
			if ($warning) { Write-Warning $outString; $outString = "WARNING: " + $outString }
			elseif ($toHost) { Write-Host $outString }
			else { Write-Verbose $outString }
			if ($logFilePath) { Write-Output "[$(get-date -format 'dd/MM/yyyy-HH:mm:ss')] $outString" | Out-File -FilePath $logFilePath -Append -Force }
		}
		
		# Tests connectivity to the WMI port rather than ping. Faster and more reliable than Test-Connection. (Found on the web, not mine.)
		function Test-Host
		{
		    <#
		        .Synopsis
		            Test a host for connectivity using either WMI ping or TCP port
		        .Description
		            Allows you to test a host for connectivity before further processing
		        .Parameter Server
		            Name of the Server to Process.
		        .Parameter TCPPort
		            TCP Port to connect to. (default 135)
		        .Parameter Timeout
		            Timeout for the TCP connection (default 1 sec)
		        .Parameter Property
		            Name of the Property that contains the value to test.
		        .Example
		            # To test a list of hosts.
		            cat ServerFile.txt | Test-Host | Invoke-DoSomething
		        .Example
		            # To test a list of hosts against port 80.
		            cat ServerFile.txt | Test-Host -tcp 80 | Invoke-DoSomething   
		        .Example
		            # To test the output of Get-ADComputer using the dnshostname property
		            Get-ADComputer | Test-Host -property dnsHostname | Invoke-DoSomething    
		        .OUTPUTS
		            Object
		        .INPUTS
		            object
		        .Link
		            N/A
				NAME:      Test-Host
				AUTHOR:    YetiCentral\bshell
				Website:   www.bsonposh.com
				LASTEDIT:  02/04/2009 18:25:15
		        #Requires -Version 2.0
		    #>
		    [CmdletBinding()]
		    
		    Param(
		        [Parameter(ValueFromPipeline=$true,Mandatory=$True)]
		        $ComputerName,
		        [Parameter()]
		        [int]$TCPPort,
		        [Parameter()]
		        [int]$timeout=500,
		        [Parameter()]
		        [string]$property
		        )
		    Begin
		    {
		        function TestPort {
		            Param($srv,$tport,$tmOut)
		            Write-Verbose " [TestPort] :: Start"
		            Write-Verbose " [TestPort] :: Setting Error state = 0"
		            $ErrorActionPreference = "SilentlyContinue"
		            
		            Write-Verbose " [TestPort] :: Creating [system.Net.Sockets.TcpClient] instance"
		            $tcpclient = New-Object system.Net.Sockets.TcpClient
		            
		            Write-Verbose " [TestPort] :: Calling BeginConnect($srv,$tport,$null,$null)"
		            $iar = $tcpclient.BeginConnect($srv,$tport,$null,$null)
		            
		            Write-Verbose " [TestPort] :: Waiting for timeout [$timeout]"
		            $wait = $iar.AsyncWaitHandle.WaitOne($tmOut,$false)
		            # Traps     
		            trap 
		            {
		                Write-Verbose " [TestPort] :: General Exception"
		                Write-Verbose " [TestPort] :: End"
		                return $false
		            }
		            trap [System.Net.Sockets.SocketException]
		            {
		                Write-Verbose " [TestPort] :: Exception: $($_.exception.message)"
		                Write-Verbose " [TestPort] :: End"
		                return $false
		            }
		            if(!$wait)
		            {
		                $tcpclient.Close()
		                Write-Verbose " [TestPort] :: Connection Timeout"
		                Write-Verbose " [TestPort] :: End"
		                return $false
		            }
		            else
		            {
		                Write-Verbose " [TestPort] :: Closing TCP Sockett"
		                $tcpclient.EndConnect($iar) | out-Null
		                $tcpclient.Close()
		            }
		            if($?){Write-Verbose " [TestPort] :: End";return $true}
		        }
		        function PingServer {
		            Param($MyHost)
		            Write-Verbose " [PingServer] :: Pinging $MyHost"
		            $pingresult = Get-WmiObject win32_pingstatus -f "address='$MyHost'"
		            Write-Verbose " [PingServer] :: Ping returned $($pingresult.statuscode)"
		            if($pingresult.statuscode -eq 0) {$true} else {$false}
		        }
		    }
		    Process
		    {
		        Write-Verbose ""
		        Write-Verbose " Server   : $ComputerName"
		        if($TCPPort)
		        {
		            Write-Verbose " Timeout  : $timeout"
		            Write-Verbose " Port     : $TCPPort"
		            if($property)
		            {
		                Write-Verbose " Property : $Property"
		                if(TestPort $ComputerName.$property -tport $TCPPort -tmOut $timeout){$ComputerName}
		            }
		            else
		            {
		                if(TestPort $ComputerName -tport $TCPPort -tmOut $timeout){$ComputerName} 
		            }
		        }
		        else
		        {
		            if($property)
		            {
		                Write-Verbose " Property : $Property"
		                if(PingServer $ComputerName.$property){$ComputerName} 
		            }
		            else
		            {
		                Write-Verbose " Simple Ping"
		                if(PingServer $ComputerName){$ComputerName}
		            }
		        }
		        Write-Verbose ""
		    }
		}
	}
	Process {
		$currentServiceTag = $null
		# handle piped service tags
		if ($ServiceTagInput) {
			if($_) { $currentServiceTag = $_ }
			elseif ($computer) { $currentServiceTag = $computer; $computer=$null }
			else { $currentServiceTag = (Get-WmiObject Win32_bios).SerialNumber } 
		}
		# handle piped computer names and get service tag
		else {
			$origInput = $computer
			if ($_.Name) { $computer = $_.Name | Test-Host -TCPPort 135 }
			elseif ($_) { $computer = $_ | Test-Host -TCPPort 135 }
			elseif ($computer) { $computer = Test-Host -TCPPort 135 $computer }
			else { $computer = Test-Host -TCPPort 135 'localhost' }
			
			if ($computer) {
				$currentServiceTag = (Get-WmiObject Win32_bios -computerName $computer).SerialNumber
				if (!$?) { Write-OutputLog "Unable to communicate with - $computer" -Warning; $commerror = $true }
			}
			else { Write-OutputLog "Unable to communicate with $origInput" -Warning; $commerror = $true }
		}
		
		#check to makesure there were no comm errors. if not setup the webservice and attempt to get the information.
		if(!$commerror) { 
			#Setup webservice
			Write-OutputLog "Connecting to dell webservice..."
			$URL = "$URL/$currentServiceTag"
			$Request = Invoke-RestMethod -URI $URL -Method GET -Headers @{ "APIKey" = $apiKey }
			if (!$?) { Write-OutputLog "Problem accessing webservice at: $URL" -warning; continue }
			
			#get comptuer information
			Write-OutputLog "Getting asset information for $currentServiceTag from Dell webservice..."
			$assetInformation = $Request.AssetWarrantyResponse
			if ($assetInformation) { 
				Write-OutputLog "Warranty information for $currentServiceTag obtained."
				
				$assetHeaderData = $assetInformation.AssetHeaderData
				$assetServiceTag = $assetHeaderData.ServiceTag
				$systemType = $assetHeaderData.MachineDescription
				$shipDate = $assetHeaderData.ShipDate
				$region = $assetHeaderData.CountryLookupCode
				$orderNumber = $assetHeaderData.OrderNumber

				#Get warranty information
				$provider = ""
				$startDate = ""
				$endDate = get-date -Year 1980
				$daysLeft = 0
				$WarrantyExtended = $false
				$description = ""
				$warranties = $assetInformation | Select-Object -ExpandProperty AssetEntitlementData
				if ($warranties) {
					$WarrantyExtended = $true
					$activeWarranties = $warranties | Where-Object { $_.ServiceLevelDescription -ne "Dell Digital Delivery" -and $_.ServiceLevelDescription -ne "Dell Digitial Delivery" } | Sort-Object EndDate -descending
					#If there are active warranties we shall use info with the most daysleft
					if($activeWarranties) {
						if ($activeWarranties -isnot [system.array]) {
							$provider = $activeWarranties.ServiceProvider
							$startDate = $activeWarranties.StartDate
							$endDate = $activeWarranties.EndDate
							$description = $activeWarranties.ServiceLevelDescription
							$realDaysLeft = ([DateTime]$activeWarranties.EndDate - $today).Days
							if ($realDaysLeft -gt $daysLeft) {
								#$daysLeft = $daysLeft + $realDaysLeft
								$daysLeft = $realDaysLeft
							}
							else {
								$daysLeft = 0
							}
						}
						else {
							$provider = $activeWarranties[0].ServiceProvider
							$startDate = $activeWarranties[-1].StartDate
							$endDate = $activeWarranties[0].EndDate
							$description = $activeWarranties[0].ServiceLevelDescription
							$realDaysLeft = ([DateTime]$activeWarranties[0].EndDate - $today).Days
							if ($realDaysLeft -gt $daysLeft) {
								#$daysLeft = $daysLeft + $realDaysLeft
								$daysLeft = $realDaysLeft
							}
							else {
								$daysLeft = 0
							}
						}
					}
					
					#create output
					$Output = New-Object PSObject
					if($computer) { $Output | Add-Member NoteProperty ComputerName $computer }
					$Output | Add-Member NoteProperty ServiceTag $assetServiceTag
					$Output | Add-Member NoteProperty SystemType $systemType
					$Output | Add-Member NoteProperty Region $region 
					$Output | Add-Member NoteProperty Provider $provider
					$Output | Add-Member NoteProperty ShipDate $shipDate 
					$Output | Add-Member NoteProperty StartDate $startDate
					$Output | Add-Member NoteProperty EndDate $endDate
					$Output | Add-Member NoteProperty DaysLeft $daysLeft
					$Output | Add-Member NoteProperty description $description
					$Output | Add-Member NoteProperty WarrantyExtended $WarrantyExtended
					$Output | Add-Member NoteProperty OrderNumber $orderNumber
					Write-Output $Output
				}
				else { Write-OutputLog "Dell returned incomplete warranty information for Tag: $currentServiceTag" -warning }
			}
			else { Write-OutputLog "Error accessing asset Information for Tag: $currentServiceTag" -warning }
		}
	}
	end {
		Write-OutputLog "All Input has been processed"
	}
}

Export-ModuleMember get-DellWarranty
