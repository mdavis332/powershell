<#
.SYNOPSIS
   Remove bundled App store packages
.DESCRIPTION
   Script designed to be run during an OSD TS to remove additional unwanted pre-provisioned Windows App Store packages from images used for Labs/Classrooms AppSets. 
.PARAMETER <paramName>
   Script does not accept parameters
.EXAMPLE
   ./Remove-Win10-ProvisionedApps.ps1
#>

$AppsList = "9E2F88E3.Twitter",							# Remove
			"king.com.candycrushsodasaga",				# Remove
			"Microsoft.3DBuilder",						# Remove
			#"Microsoft.Appconnector", 					No longer included as of 1607
			#"Microsoft.BingFinance", 					No longer included as of 1607
			#"Microsoft.BingNews",						No longer included as of 1607
			#"Microsoft.BingSports",					No longer included as of 1607
			"Microsoft.BingWeather",					# Remove
			#"Microsoft.DesktopAppInstaller",			Keep
			"Microsoft.Getstarted",						# Remove
			"Microsoft.Messaging",						# Remove			
			#"Microsoft.Microsoft3DViwer",				Keep - Introduced in 1703
			"Microsoft.MicrosoftOfficeHub",				# Remove
			"Microsoft.MicrosoftSolitaireCollection",	# Remove
			"Microsoft.MicrosoftStickyNotes",			# Remove
			#"Microsoft.MSPaint",						Keep
			"Microsoft.Office.OneNote",					# Remove
			"Microsoft.OneConnect",						# Remove
			"Microsoft.People",							# Remove
			"Microsoft.SkypeApp",						# Remove
			#"Microsoft.StorePurchaseApp",				Keep
			"Microsoft.Wallet",							# Remove
			#"Microsoft.Windows.Photos",				Keep
			"Microsoft.WindowsAlarms",					# Remove
			#"Microsoft.WindowsCalculator",				Keep
			"Microsoft.WindowsCamera",					# Remove 
			"microsoft.windowscommunicationsapps",		# Remove
			"Microsoft.WindowsFeedbackHub",				# Remove
			"Microsoft.WindowsMaps",					# Remove
			"Microsoft.Windows.ParentalControls",		# Remove
			#"Microsoft.WindowsPhone",					No longer included as of 1607
			"Microsoft.WindowsSoundRecorder",			# Remove
			#"Microsoft.WindowsStore",					Keep
			"Microsoft.XboxApp",						# Remove
			"Microsoft.XboxGameOverlay",				# Remove
			"Microsoft.XboxIdentityProvider",			# Remove
			"Microsoft.XboxSpeechToTextOverlay",		# Remove
			"Microsoft.Xbox.TCUI",						# Remove
			"Microsoft.ZuneMusic",						# Remove
			"Microsoft.ZuneVideo",						# Remove
			"Windows.ContactSupport"					# Remove
			
ForEach ($App in $AppsList) 
{ 
    $PackageFullName = (Get-AppxPackage $App).PackageFullName
    $ProPackageFullName = (Get-AppxProvisionedPackage -online | where {$_.Displayname -eq $App}).PackageName
        write-host $PackageFullName
        Write-Host $ProPackageFullName 
    if ($PackageFullName) 
    { 
        Write-Host "Removing Package: $App"
        remove-AppxPackage -package $PackageFullName 
    } 
    else 
    { 
        Write-Host "Unable to find package: $App" 
    } 
    if ($ProPackageFullName) 
    { 
        Write-Host "Removing Provisioned Package: $ProPackageFullName"
        Remove-AppxProvisionedPackage -online -packagename $ProPackageFullName 
    } 
    else 
    { 
        Write-Host "Unable to find provisioned package: $App" 
    } 

}
