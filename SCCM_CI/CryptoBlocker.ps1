function CryptoBlocker
{
  
  # Email Sever Settings
  $SMTPServer = "mail.org.local"
  $SMTPFrom = "$env:COMPUTERNAME@org.local"
  $SMTPTo = "support@org.local"
  $AdminEmail = "support@org.local"
  
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
    
    # Define Ransomware Known File Types
    $CryptoExtensions = (Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters}
    
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
