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

$AppsList = "Microsoft.BingWeather",				# Remove
			#"Microsoft.DesktopAppInstaller",		Keep
			"Microsoft.GetHelp",					# Remove - Introduced in 1709
			"Microsoft.Getstarted",					# Remove
			"Microsoft.Messaging",					# Remove			
			#"Microsoft.Microsoft3DViwer",			Keep - Introduced in 1703
			"Microsoft.MicrosoftOfficeHub",			# Remove
			"Microsoft.MicrosoftSolitaireCollection",		# Remove
			"Microsoft.MicrosoftStickyNotes",		# Remove
			#"Microsoft.MSPaint",					Keep
			#"Microsoft.Office.OneNote",			Keep since MS has announced they're killing Win32 OneNote
			"Microsoft.OneConnect",					# Remove
			"Microsoft.People",						# Remove
			"Microsoft.Print3D",					# Remove - Introduced in 1709
			"Microsoft.SkypeApp",					# Remove
			#"Microsoft.StorePurchaseApp",			Keep
			"Microsoft.Wallet",						# Remove
			#"Microsoft.WebMediaExtensions",		Keep - Introduced in 1803
			#"Microsoft.Windows.Photos",			Keep
			"Microsoft.WindowsAlarms",				# Remove
			#"Microsoft.WindowsCalculator",			Keep
			"Microsoft.WindowsCamera",				# Remove 
			"microsoft.windowscommunicationsapps",	# Remove
			"Microsoft.WindowsFeedbackHub",			# Remove
			"Microsoft.WindowsMaps",				# Remove
			"Microsoft.WindowsSoundRecorder",		# Remove
			#"Microsoft.WindowsStore",				Keep
			"Microsoft.XboxApp",					# Remove
			"Microsoft.XboxGameOverlay",			# Remove
			"Microsoft.XboxGamingOverlay",			# Remove - Introduced in 1803
			"Microsoft.XboxIdentityProvider",		# Remove
			"Microsoft.XboxSpeechToTextOverlay",	# Remove
			"Microsoft.Xbox.TCUI",					# Remove
			"Microsoft.ZuneMusic",					# Remove
			"Microsoft.ZuneVideo"					# Remove
			#"Windows.ContactSupport"				# Removed in 1803
			
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
