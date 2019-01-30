Script to automate the renewal of https certs for PaperCut with LetsEncrypt using Posh-ACME module and PowerShell.

Because PaperCut uses tomcat/jks, you must download the Win32 binary of OpenSSL and edit the PowerShell script to tell the script where the binary is at. Further, the script is currently configured to use DNSMadeEasy as the DNS provider to automate LetsEncrypt renewals. Adjust the script as necessary if you use Route53 or something else for external DNS.

Use with a Scheduled Task that runs daily with the following action:

Program/script: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
Arguments: -noninteractive -noprofile -command "powershell -noninter -nop -c C:\scripts\Renew-TlsCertificate.ps1 > c:\scripts\certrenew.log 2>&1"
STart in: C:\Scripts
