<#
Synopsis: Automates TLS cert renewal for PaperCut Application Server and Mobility Print Service
Coded for use with DnsMadeEasy
Date Created: 2018-September-13
Author: Michael Davis
Last Date Modified: 2018-October-03
TODO: Error Handling everywhere
#>

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

# Add module for Posh-ACME
if (-not (Get-Module Posh-ACME)) {
    Import-Module $PoshAcmePath
}

# read in DNS API Keys
if (-not (Get-Item -Path Env:Dns_ApiKey -ErrorAction SilentlyContinue)) {
    Read-Host "Enter the DNS API Key (will be saved as env variable for subsequent runs)" | Set-Item -Path Env:Dns_ApiKey
}

if (-not (Get-Item -Path Env:Dns_SecretKey -ErrorAction SilentlyContinue)) {
    Read-Host "Enter the DNS Secret Key (only needs to be done on the first run)" -AsSecureString | ConvertFrom-SecureString | 
        Set-Item -Path Env:Dns_SecretKey
}

$DMEKey = Get-Item -Path Env:Dns_ApiKey
$DMESecret = Get-Item -Path Env:Dns_SecretKey | Select-Object -ExpandProperty Value | ConvertTo-SecureString

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
$CertReturn = New-PACertificate $Fqdn @PaCertParams -DirectoryUrl LE_PROD #change LE_PROD to LE_STAGE for any script testing

if (-not $CertReturn) {
    Write-Error "Didn't return correct response from LetsEncrypt API"
    #TODO: Email someone
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