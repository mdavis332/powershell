Using with a Scheduled Task that runs daily with the following action:

Program/script: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
Arguments: -noninteractive -noprofile -command "powershell -noninter -nop -c C:\scripts\Renew-TlsCertificate.ps1 > c:\scripts\certrenew.log 2>&1"
STart in: C:\Scripts
