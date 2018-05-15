<#
.SYNOPSIS
   Remove bundled App store packages
.DESCRIPTION
   Script designed to be run during an OSD TS to remove unwanted pre-provisioned Windows App Store packages from the base image. 
.PARAMETER <paramName>
   Script does not accept parameters
.EXAMPLE
   ./Remove-Win10-ProvisionedApps.ps1
#>

$AppsList = 		"9E2F88E3.Twitter",					# Remove
			"king.com.candycrushsodasaga",				# Remove
			"Microsoft.3DBuilder",					# No longer included as of 1709
			#"Microsoft.BingWeather",				Keep
			#"Microsoft.DesktopAppInstaller",			Keep
			"Microsoft.GetHelp",					# Remove - Introduced in 1709
			"Microsoft.Getstarted",					# Remove
			#"Microsoft.Messaging",					Keep			
			#"Microsoft.Microsoft3DViwer",				Keep - Introduced in 1703
			"Microsoft.MicrosoftOfficeHub",				# Remove "Get Office" app
			"Microsoft.MicrosoftSolitaireCollection",		# Remove
			#"Microsoft.MicrosoftStickyNotes",			Keep
			#"Microsoft.MSPaint",					Keep
			#"Microsoft.Office.OneNote",				Keep since MS is removing OneNote from Win32
			"Microsoft.OneConnect",					# Remove
			#"Microsoft.People",					# Keep - Required for My People Pins introduced in 1709
			Microsoft.Print3D,					# Remove - Introduced in 1709
			"Microsoft.SkypeApp",					# Remove
			#"Microsoft.StorePurchaseApp",				Keep
			"Microsoft.Wallet",					# Remove
			#"Microsoft.WebMediaExtensions",			Keep - Introduced in 1803
			#"Microsoft.Windows.Photos",				Keep
			#"Microsoft.WindowsAlarms",				Keep
			#"Microsoft.WindowsCalculator",				Keep
			#"Microsoft.WindowsCamera",				Keep
			"microsoft.windowscommunicationsapps",			# Remove
			"Microsoft.WindowsFeedbackHub",				# Remove
			#"Microsoft.WindowsMaps",				Keep
			"Microsoft.Windows.ParentalControls",			# Remove
			#"Microsoft.WindowsSoundRecorder",			Keep
			#"Microsoft.WindowsStore",				Keep
			"Microsoft.XboxApp",					# Remove
			"Microsoft.XboxGameOverlay",				# Remove
			"Microsoft.XboxGamingOverlay",				# Remove - Introduced in 1803
			"Microsoft.XboxIdentityProvider",			# Remove
			"Microsoft.XboxSpeechToTextOverlay",			# Remove
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
