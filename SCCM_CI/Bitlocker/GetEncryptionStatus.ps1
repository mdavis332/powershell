<#
*********************************************************************************************************
*                                                                                                       *
*** This Powershell Script is used to get the Bitlocker protection status                             ***
*                                                                                                       *
*********************************************************************************************************
* Created by Ioan Popovici, 13/11/2015  | Requirements Powershell 3.0                                   *
* https://sccmzone.ro/create-bitlocker-encryption-compliance-reports-for-c-drive-in-sccm-764dc097bc9c#.abo7d2yb8
======================================================================================================*
* Modified by   |    Date    | Revision |                            Comments                           *
*_______________________________________________________________________________________________________*
* Michael Davis | 30/01/2018 | v1.1     | Cleaned up query and forced it to look only at C: drive       *
*_______________________________________________________________________________________________________*
* Ioan Popovici | 13/11/2015 | v1.0     | First version                                                 *
*-------------------------------------------------------------------------------------------------------*
*                                                                                                       *
*********************************************************************************************************
    .SYNOPSIS
        This Powershell Script is used to get the Bitlocker protection status.
    .DESCRIPTION
	This Powershell Script is used to get the Bitlocker protection status for C drive.
#>

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Get the Bitlocker Encryption Status for C drive
Try {

  #  Read the status from wmi
  Get-WmiObject -Namespace "root\CIMV2\Security\MicrosoftVolumeEncryption" -Class Win32_EncryptableVolume -ErrorAction Stop | Where-Object { $_.DriveLetter -eq 'C:' } | `
    ForEach-Object {

      #  Make it more report friendly
      Switch ($_.GetProtectionStatus().ProtectionStatus) {
        0 { $State = "PROTECTION OFF" } 1 { $State = "PROTECTION ON"} 2 { $State = "PROTECTION UNKNOWN"}
      }

      #  Check if protection is on for C drive
      If ($State -eq "PROTECTION ON") {
        $Protection = $true
      }
    }
}

## Catch any script errors
Catch {
  $ScriptError = $true
}

## Write protection status to console
If ($Protection) {
  return "COMPLIANT"
} ElseIf ($ScriptError -ne $true) {
    return "NON-COMPLIANT"
  } Else {
      return "SCRIPT EXECUTION ERROR!"
    }

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
