<#
Synopsis: Automates TLS cert renewal for PaperCut Application Server and Mobility Print Service
Date Created: 2018-September-13
Author: Michael Davis
Last Date Modified: 2019-January-30
TODO: Error Handling everywhere

#>
[cmdletbinding()]
$VerbosePreference = 'Continue'

#region configuration
$Fqdn = 'printserver.domain.local' # fqdn of the server
$KeystorePass = 'P@ssw0rd' # java keystore password
$MobilityPrintPath = 'C:\Program Files (x86)\PaperCut Mobility Print\data' # Path to store cert files for PaperCut Mobility Print
$KeystorePath = 'C:\Program Files\PaperCut NG\server\custom\my-ssl-keystore2' # Path for Java Key Store that will be used by PaperCut
$OpenSslBin = 'C:\OpenSSL-Win32\bin\openssl.exe' # Path to OpenSSL binary
$KeytoolBin = 'C:\Program Files\PaperCut NG\client\win\runtime\jre\bin\keytool.exe' # Path to Java Keytool binary
$PoshAcmePath = 'C:\Posh-ACME-2.8.0\Posh-ACME' # Path to Posh-ACME PowerShell Module
$ContactEmail = 'admin@domain.local' # Email address to use as a contact for the LetsEncrypt certificate
$DnsAliasSite = 'domain-acme.net' # Domain against which to issue DNS Challenges
$TempFolder = 'C:\temp'
$ServicesToRestart = @(
    'PCAppServer',
    'pc-mobility-print'
) # list of services to restart upon completion (for example, web servers)
$LogFile = "$PSScriptRoot\certrenew.log"
#endregion

<################################################################
# Don't Edit anything below this line unless you know what's up #
################################################################>
Start-Transcript -Path $LogFile -Append
Write-Verbose "Starting renewal check at $((Get-Date -format 'yyyy-MM-dd hh:mm:ss').ToString())"
# Add module for Posh-ACME
if (-not (Get-Module Posh-ACME)) {
    Import-Module $PoshAcmePath
}

# read in DNS API Keys, or create them on first-run if they don't exist
if (-not ([System.Environment]::GetEnvironmentVariable('DMEasy_ApiKey', 'Machine'))) {
    $ApiKey = Read-Host 'Enter the DNS Made Easy API Key (will be saved as env variable for subsequent runs)'
    [Environment]::SetEnvironmentVariable('DMEasy_ApiKey', $ApiKey, 'Machine')
}

# Prepare to read in SecretKey and save an encryption key to a file so we can decrypt the secretkey across users on this same machine
$KeyFile = "$PSScriptRoot\CertRenewalAES.key"
if (-not ([System.Environment]::GetEnvironmentVariable('DMEasy_SecretKey', 'Machine'))) {
    $Key = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
    $Key | Out-File $KeyFile
    $SecretKey = Read-Host 'Enter the DNS Made Easy Secret Key (only needs to be done on the first run)' -AsSecureString | ConvertFrom-SecureString -Key $Key
    [Environment]::SetEnvironmentVariable('DMEasy_SecretKey', $SecretKey, 'Machine')
}

$DMEKey = [System.Environment]::GetEnvironmentVariable('DMEasy_ApiKey', 'Machine')
$Key = Get-Content $KeyFile
$DMESecret = [System.Environment]::GetEnvironmentVariable('DMEasy_SecretKey', 'Machine') | ConvertTo-SecureString -Key $Key

$DMEParams = @{DMEKey = $DMEKey; DMESecret = $DMESecret}

$Hostname = $Fqdn.Split('.')[0]

# At the time of writing, I use DnsMadeEasy as the external DNS provider. Use the plugin for that service to add a new TXT Record
# Setup splat for parameters to be fed to New-PACertificate function
$PaCertParams = @{
    AcceptTOS  = $true
    Contact    = $ContactEmail
    DnsPlugin  = 'DMEasy'
    PluginArgs = $DMEParams
    DnsAlias   = "_acme-challenge.${Hostname}.${DnsAliasSite}"
}

try {
    $CertReturn = New-PACertificate $Fqdn @PaCertParams -DirectoryUrl LE_PROD #change LE_PROD to LE_STAGE for any script testing
}
catch {
    #TODO: Email someone $_.Exception.ErrorMessage
    throw
}


if (-not $CertReturn) {
    Write-Verbose "Not time to renew or didn't get correct response from LetsEncrypt API"
    Write-Verbose "Finishing renewal check at $((Get-Date -format 'yyyy-MM-dd hh:mm:ss').ToString())"
    Exit
}

Write-Verbose "Cert Info object returned: $CertReturn"

# The following lines were adding for testing. Remove when in production.
#Add-Content C:\scripts\renewcert.txt "We should not have gotten here."
#Exit

#Get path to where Posh-Acme/LetsEncrypt stored the certs
$CertPath = $CertReturn.CertFile | Split-Path -Parent
$Leaf = $CertPath | Split-Path -Leaf

# Copy files to temp folder since cmd execution of openssl and keytool can't handle awesomely long system paths
Copy-Item $CertPath -Destination $TempFolder -Recurse

# Use OpenSSL to convert the LetsEncrypt cert files to pkcs12
Write-Verbose "Preparing to run: $OpenSslBin pkcs12 -export -in $TempFolder\$Leaf\fullchain.cer -inkey $TempFolder\$Leaf\cert.key -out $TempFolder\$Leaf\$Fqdn.p12 -password pass:$KeystorePass"
& $OpenSslBin pkcs12 -export -in "$TempFolder\$Leaf\fullchain.cer" -inkey "$TempFolder\$Leaf\cert.key" -out "$TempFolder\$Leaf\$Fqdn.p12" -password "pass:$KeystorePass"
# Use the Java keytool binary to import the pkcs12 cert files into the keystore
Write-Verbose "Preparing to run: $KeytoolBin -importkeystore -srckeystore $TempFolder\$Leaf\$Fqdn.p12 -srcstoretype pkcs12 -srcstorepass $KeystorePass -destkeystore $KeystorePath -deststoretype jks -deststorepass $KeystorePass -noprompt"
& $KeytoolBin -importkeystore -srckeystore "$TempFolder\$Leaf\$Fqdn.p12" -srcstoretype pkcs12 -srcstorepass $KeystorePass -destkeystore $KeystorePath -deststoretype jks -deststorepass $KeystorePass -noprompt

#region Custom section for app-specific code
# Copy private key for PaperCut Mobility Print
Write-Verbose "Copying $MobilityPrintPath\tls.pem to $MobilityPrintPath\tls.pem.old"
Move-Item -Path "$MobilityPrintPath\tls.pem" -Destination "$MobilityPrintPath\tls.pem.old" -Force
& $OpenSslBin pkcs12 -in "$TempFolder\$Leaf\$Fqdn.p12" -nocerts -out "$MobilityPrintPath\tls.pem" -passin "pass:$KeystorePass" -passout "pass:''"
# Remove header from private key that causes PaperCut not to recognize the file
(Get-Content -Path "$MobilityPrintPath\tls.pem").Where( { $_ -eq '-----BEGIN ENCRYPTED PRIVATE KEY-----'}, 'SkipUntil' ) | 
    Set-Content "$MobilityPrintPath\tls.pem"

# Copy cert for PaperCut Mobility Print
Move-Item -Path "$MobilityPrintPath\tls.cer" -Destination "$MobilityPrintPath\tls.cer.old" -Force
& $OpenSslBin pkcs12 -in "$TempFolder\$Leaf\$Fqdn.p12" -nokeys -out "$MobilityPrintPath\tls.cer" -passin "pass:$KeystorePass" -passout "pass:''"

#endregion

# cleanup temp area
Remove-Item $TempFolder\$Leaf -Force -Recurse

# Restart Services
$ServicesToRestart | Restart-Service -Force
Write-Verbose "Finishing renewal check at $((Get-Date -format 'yyyy-MM-dd hh:mm:ss').ToString())"
Stop-Transcript
