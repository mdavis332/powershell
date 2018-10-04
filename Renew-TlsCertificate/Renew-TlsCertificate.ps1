<#
Synopsis: Automates TLS cert renewal for PaperCut Application Server and Mobility Print Service
Coded for use with DnsMadeEasy
Date Created: 2018-September-13
Author: Michael Davis
Last Date Modified: 2018-October-03
TODO: Error Handling everywhere
#>
[cmdletbinding()]
$VerbosePreference = 'Continue'
#region configuration
$Fqdn = 'printserver.domain.com' # fqdn of the server
$KeystorePass = 'Mycoolkeystore-pass22' # java keystore password
$MobilityPrintPath = 'C:\Program Files (x86)\PaperCut Mobility Print\data' # Path to store cert files for PaperCut Mobility Print
$KeystorePath = 'C:\Program Files\PaperCut NG\server\custom\my-ssl-keystore2' # Path for Java Key Store that will be used by PaperCut
$OpenSslBin = 'C:\OpenSSL-Win32\bin\openssl.exe' # Path to OpenSSL binary
$KeytoolBin = 'C:\Program Files\PaperCut NG\client\win\runtime\jre\bin\keytool.exe' # Path to Java Keytool binary
$PoshAcmePath = 'C:\Posh-ACME-2.8.0\Posh-ACME' # Path to Posh-ACME PowerShell Module
$ContactEmail = 'firstlast@domain.com' # Email address to use as a contact for the LetsEncrypt certificate
$DnsAliasSite = 'acmedomain.com' # Domain against which to issue advanced DNS Challenges
$ServicesToRestart = @(
    'PCAppServer',
    'pc-mobility-print'
) # list of services to restart upon completion (for example, web servers)

#endregion

<################################################################
# Don't Edit anything below this line unless you know what's up #
################################################################>
Write-Verbose "Starting renewal check at $((Get-Date -format 'yyyy-MM-dd hh:mm:ss').ToString())"
# Add module for Posh-ACME
if (-not (Get-Module Posh-ACME)) {
    Import-Module $PoshAcmePath
}

# read in DNS API Keys
if (-not ([System.Environment]::GetEnvironmentVariable('Dns_ApiKey', 'Machine'))) {
    $ApiKey = Read-Host 'Enter the DNS API Key (will be saved as env variable for subsequent runs)'
    [Environment]::SetEnvironmentVariable('Dns_ApiKey', $ApiKey, 'Machine')
}

# Prepare to read in SecretKey and save an encryption key to a file so we can decrypt the secretkey across users on this same machine
$KeyFile = "$PSScriptRoot\CertRenewalAES.key"
if (-not ([System.Environment]::GetEnvironmentVariable('Dns_SecretKey', 'Machine'))) {
    $Key = New-Object Byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($Key)
    $Key | Out-File $KeyFile
    $SecretKey = Read-Host 'Enter the DNS Secret Key (only needs to be done on the first run)' -AsSecureString | ConvertFrom-SecureString -Key $Key
    [Environment]::SetEnvironmentVariable('Dns_SecretKey', $SecretKey, 'Machine')
}

$DMEKey = [System.Environment]::GetEnvironmentVariable('Dns_ApiKey', 'Machine')
$Key = Get-Content $KeyFile
$DMESecret = [System.Environment]::GetEnvironmentVariable('Dns_SecretKey', 'Machine') | ConvertTo-SecureString -Key $Key

$DMEParams = @{DMEKey = $DMEKey.Value; DMESecret = $DMESecret}

$Hostname = $Fqdn.Split('.')[0]

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

#Get path to where Posh-Acme/LetsEncrypt stored the certs
$CertPath = $CertReturn.CertFile | Split-Path -Parent

# Use OpenSSL to convert the LetsEncrypt cert files to pkcs12
& $OpenSslBin pkcs12 -export -in "$($CertReturn.FullChainFile)" -inkey "$($CertReturn.KeyFile)" -out "$CertPath\$Fqdn.p12" -password "pass:$KeystorePass"
# Use the Java keytool binary to import the pkcs12 cert files into the keystore
& $KeytoolBin -importkeystore -srckeystore "$CertPath\$Fqdn.p12" -srcstoretype pkcs12 -srcstorepass $KeystorePass -destkeystore $KeystorePath -deststoretype jks -deststorepass $KeystorePass -noprompt

#region Custom section for app-specific code
# Copy private key for PaperCut Mobility Print
Move-Item -Path "$MobilityPrintPath\tls.pem" -Destination "$MobilityPrintPath\tls.pem.old" -Force
& $OpenSslBin pkcs12 -in "$CertPath\$Fqdn.p12" -nocerts -out "$MobilityPrintPath\tls.pem" -passin "pass:$KeystorePass" -passout "pass:''"
# Remove header from private key that causes PaperCut not to recognize the file
(Get-Content -Path "$MobilityPrintPath\tls.pem").Where( { $_ -eq '-----BEGIN ENCRYPTED PRIVATE KEY-----'}, 'SkipUntil' ) | 
    Set-Content "$MobilityPrintPath\tls.pem"

# Copy cert for PaperCut Mobility Print
Move-Item -Path "$MobilityPrintPath\tls.cer" -Destination "$MobilityPrintPath\tls.cer.old" -Force
& $OpenSslBin pkcs12 -in "$CertPath\$Fqdn.p12" -nokeys -out "$MobilityPrintPath\tls.cer" -passin "pass:$KeystorePass" -passout "pass:''"

#endregion

# Restart Services
$ServicesToRestart | Restart-Service -Force
Write-Verbose "Finishing renewal check at $((Get-Date -format 'yyyy-MM-dd hh:mm:ss').ToString())"
