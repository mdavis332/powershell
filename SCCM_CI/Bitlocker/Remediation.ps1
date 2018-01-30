param( [string]$compliance )
$AES256 = 4
$EncryptionNamespace = "root\cimv2\Security\MicrosoftVolumeEncryption"
$EncryptableVolume = gwmi -Query "SELECT * FROM Win32_EncryptableVolume WHERE DriveLetter='C:'" -Namespace $EncryptionNamespace
if(![System.Diagnostics.EventLog]::SourceExists('ComplianceEncryptionRemediation')) { New-EventLog -LogName Application -Source ComplianceEncryptionRemediation }
$ProtectionStatus = ($EncryptableVolume.GetProtectionStatus()).ProtectionStatus
Switch($ProtectionStatus) {
    0 {
        $ConversionStatus = ($EncryptableVolume.GetConversionStatus()).ConversionStatus
	    Switch($ConversionStatus) {
            0 {
                $return = $EncryptableVolume.ProtectKeyWithTPM("TPM Protection", $null)
                if($return.ReturnValue -eq 0) {
                    $return = $EncryptableVolume.ProtectKeyWithNumericalPassword()
                    $version = [version](gwmi win32_operatingsystem).version					
                    # Windows 7
                    if($version -lt [version]"6.3") { $return = $EncryptableVolume.Encrypt($AES256) }
                    # Windows 8
                    if($version -ge [version]"6.3") { $return = $EncryptableVolume.Encrypt($AES256, 1) }
                    if($return.ReturnValue -eq 0) { 
                        Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Information -EventID 501 -Message "Return Value: $($return.ReturnValue)`r`nSuccessfully enabled encryption."
                        $state = "COMPLIANT" 
                    }
                    else {  
                        Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Error -EventID 502 -Message "Return Value: $($return.ReturnValue)`r`nUnable to enable encryption on this device, clearing protectors."
                        [void]$EncryptableVolume.DeleteKeyProtectors()
                        $state = "NON-COMPLIANT"
                    }
                }
                else { 
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Error -EventID 502 -Message "Return Value: $($return.ReturnValue)`r`nUnable to add TPM protector, clearing protectors."
                    [void]$EncryptableVolume.DeleteKeyProtectors()
                    $state = "NON-COMPLIANT"
                }                
            }   
            1 { 
                $return = $EncryptableVolume.EnableKeyProtectors()
                if($return.ReturnValue -eq 0) { 
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Information -EventID 503 -Message "Return Value: $($return.ReturnValue)`r`nSuccessfully enabled protection."
                    $state = "COMPLIANT"
                }
                else {
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Error -EventID 504 -Message "Return Value: $($return.ReturnValue)`r`nUnable to enable protection."
                    $state = "NON-COMPLIANT" 
                }
            }
            { ($_ -eq 3) -or ($_ -eq 5) } {
                $version = [version](gwmi win32_operatingsystem).version
                # Windows 7
                if($version -lt [version]"6.3") { $return = $EncryptableVolume.Encrypt($AES256) }
                # Windows 8
                if($version -ge [version]"6.3") { $return = $EncryptableVolume.Encrypt($AES256, 1) }
                if($return.ReturnValue -eq 0) { 
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Information -EventID 505 -Message "Return Value: $($return.ReturnValue)`r`nSuccessfully enabled encryption."
                    $state = "COMPLIANT" 
                }
                else { 
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Error -EventID 506 -Message "Return Value: $($return.ReturnValue)`r`nUnable to enable encryption."
                    $state = "NON-COMPLIANT" 
                }
            }
            4 { 
                $return = $EncryptableVolume.ResumeConversion()
                if($return.ReturnValue -eq 0) { 
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Information -EventID 507 -Message "Return Value: $($return.ReturnValue)`r`nSuccessfully resumed conversion."
                    $state = "COMPLIANT"
                }
                else {
                    Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Error -EventID 508 -Message "Return Value: $($return.ReturnValue)`r`nUnable to resume conversion."
                    $state = "NON-COMPLIANT"
                }
            }
        }
    }
    1 {
        Write-EventLog -LogName Application -Source ComplianceEncryptionRemediation -EntryType Information -EventID 500 -Message "Return Value: $($return.ReturnValue)`r`nProtection already enabled."
        $state = "COMPLIANT" 
    }
}
return $state
