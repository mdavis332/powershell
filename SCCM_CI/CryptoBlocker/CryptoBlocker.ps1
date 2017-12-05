function CryptoBlocker
{
  
  # Email Sever Settings
  $SMTPServer = "YOURSMTPSERVER"
  $SMTPFrom = "$env:COMPUTERNAME@YOURDOMAINNAME"
  $SMTPTo = "Admin@YOURDOMAINNAME"
  $AdminEmail = "Admin@YOURDOMAINNAME"
  
  # Get Ransomware Known File Types
  $CryptoExtensions = (Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters}
  
  # Import Server Manager PS Module
  Import-Module ServerManager
  
  # Install FSRM Role if required
  if ((Get-WindowsFeature -Name FS-Resource-Manager).InstallState -ne "Installed")
  {
    Install-WindowsFeature -Name FS-Resource-Manager -IncludeManagementTools | Out-Null
  }
  
  # Install Cyrpto Extension Monitoring / Blocking
  if ((Get-FSRMFileScreen).Description -notcontains "Crypto Extension Monitoring")
  {
    # Set FSRM Email Settings
    Set-FSRMSetting -AdminEmailAddress $AdminEmail -SMTPServer $SMTPServer -FromEmailAddress $SMTPFrom
    
    # Create FSRM File Group
    New-FSRMFileGroup -name "CryptoExtensions" -IncludePattern $CryptoExtensions -Description "Crypto Extension Detection" | Out-Null
    
    # Set FRSM Notification Message & Scan Interval
    $Notification = New-FSRMAction -Type Email -Subject "Crypto File Activity Detected - $env:COMPUTERNAME" -Body "User [Source IO Owner] attempted to save [Source File Path] to [File Screen Path] on the [Server] server. This file is in violation of the [Violated File Group] file group. This file could be a marker for malware infection, and should be investigated immediately." -RunLimitInterval 30 -MailTo $SMTPTo
    
    # Create FSRM Template
    New-FsrmFileScreenTemplate -Name CryptoExtensions -Description "Known CryptoLocker File Extesions" -IncludeGroup CryptoExtensions -Active: $true -Notification $Notification | Out-Null
    
    # Build Drive Lists
    $Drives = Get-WmiObject -Class Win32_LogicalDisk -Filter DriveType=3 | Select -ExpandProperty DeviceID
    
    # Apply FSRM Screen
    foreach ($Drive in $Drives)
    {
      New-FSRMFileScreen -Path $Drive -Active: $true -Description "Crypto Extension Monitoring" -Template CryptoExtensions -Notification $Notification | Out-Null
    }
  }
  
  # Update Cyrpto File Extensions 
  if ((Get-FSRMFileScreen).Description -contains "Crypto Extension Monitoring")
  {
    # Create Array For File Extensions
    $CryptoExtensionsUpdate = New-Object -TypeName System.Collections.ArrayList
    
    # Get Known Extensions
    $KnownExtensions = Get-FSRMFileGroup -Name CryptoExtensions | select -ExpandProperty IncludePattern
    
    # Add Known Extensions To $CryptoExtensions Array
    foreach ($Extension in $CryptoExtensions)
    {
      If ($Extension -notin $KnownExtensions)
      {
        $CryptoExtensionsUpdate.Add($Extension) | Out-Null
      }
    }
    
    # Update File Screen
    Set-FSRMFileGroup -Name CryptoExtensions -IncludePattern $CryptoExtensionsUpdate | Out-Null
  }
  
  # Check for FSRM File Screen
  $CryptoScreen = Get-FSRMFileScreen | Where-Object { $_.Description -eq "Crypto Extension Monitoring" }
  
  if ($CryptoScreen -gt $null)
  {
    $CryptoCICompliant = $true
  }
  else
  {
    $CryptoCICompliant = $false
  }
  Return $CryptoCICompliant
}
CryptoBlocker
