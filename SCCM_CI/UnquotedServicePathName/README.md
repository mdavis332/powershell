Baseline compliance item meant for SCCM that returns compliant ($True) if script finds zero unquoted PathNames for services, and 
non-compliant ($False) otherwise. 

Services set to Automatic startup type with unquoted pathNames (e.g.: C:\Program Files\Vendor\Service.exe) can be scanned for by bad
actors and, if discovered, can be disrupted by placing a malicious executable in the path (e.g., C:\Program.exe) that would be executed 
instead of the service due to the way Windows handles binary path execution.

The remediation script attempts to add double-quotes around unquoted path names it finds to get the machine back into compliance.
