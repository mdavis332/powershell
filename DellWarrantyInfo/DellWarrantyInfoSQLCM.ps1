<#
DELL Warrenty Info - v1.0
Scott Keiffer, 2011 (skeiffer_A_T_cm_D_O_T_utexas_D_O_T_edu)
Marcus C. Oh, 8/10/2011 (marcus.oh_at_g_mail_dot_com)
    A few minor changes for the script to work in update mode
Michael Davis, 04/27/2015 (@mdavis332 on Twitter)
    Adjusted SMS_$Sitecode to CM_$SiteCode for our CM2012/16 site and removed grant select to webapp_report role since it's no longer used in CM2012
Michael Davis, 05/18/2018 (@mdavis332 on Twitter)
    Parameterized ApiKey
    
License: GPL v2 or later

Notes:
This script uses the get-dellwarranty function and SQL to get and store the warranty information for all dell systems in a specified ConfigMgr site. 

Usage: Put this script and DellWarrantyInfoFunction.psm1 in the same folder. 
Run this script as a scheduled task once a day, e.g.: .\DellWarrantyInfoSQLCM.ps1 -SqlServer localhost -SiteCode AA1 -ApiKey 'fb1c59643dd0186500000000'
The first time the script runs, it will try to create a new DellWarrantyInfo table in the SCCM database. It will then use that table to populate warranty info henceforth.

Disclaimer:
I am not responsible with any problems this script may cause you. 
#>
param (
	[parameter(Mandatory=$true)][String]$SQLServer, 
	[parameter(Mandatory=$true)][String]$SiteCode,
	[parameter(Mandatory=$true)][string]$ApiKey
)


# SQL function, 1 connection per command, may want to break that up but too lazy.
function Invoke-SqlQuery
{
    param(
    [Parameter(Mandatory=$true)] [string]$ServerInstance,
    [string]$Database,
    [Parameter(Mandatory=$true)] [string]$Query,
    [Int32]$QueryTimeout=600,
    [Int32]$ConnectionTimeout=15
    )

    try {
        $ConnectionString = "Server=$ServerInstance;Database=$Database;Integrated Security=True;Connect Timeout=$ConnectionTimeout"
        $conn=new-object System.Data.SqlClient.SQLConnection
        $conn.ConnectionString=$ConnectionString
        $conn.Open()
        $cmd=new-object system.Data.SqlClient.SqlCommand($Query,$conn)
        $cmd.CommandTimeout=$QueryTimeout
        $ds=New-Object system.Data.DataSet
        $da=New-Object system.Data.SqlClient.SqlDataAdapter($cmd)
        [void]$da.fill($ds)
        Write-Output ($ds.Tables[0])
    }
    finally {
        $conn.Dispose()
    }
}


# ---- Main ----

$ConfigMgrDatabase = "CM_$SiteCode"
$warrantyDatabase = "DellWarrantyInfo"
$tableName = "DellWarrantyInfo"
$scriptPath=Split-Path -parent $MyInvocation.MyCommand.Definition

#Import warranty function
Import-Module "$scriptPath\DellWarrantyInfoFunction.psm1"

Write-Host "--- Dell Warranty Info SQL population script ---"

# create or recreate main table
Write-Verbose "Recreating main table..."


$TableQuery = @"
IF 
    Not Exists ( select * from sys.tables where name = 'DellWarrantyInfo' )     
BEGIN
    create table DellWarrantyInfo ( ResourceID int, ComputerName varchar(40), 
    DateScriptRan datetime, DaysLeft int, DellIBU varchar(16), 
    [Description] varchar(40), EndDate datetime, Provider varchar(16), 
    ServiceTag varchar(16), ShipDate datetime, StartDate datetime, 
    SystemType varchar(40), WarrantyExtended int, OrderNumber varchar(16)); 
    grant select on DellWarrantyInfo to smsschm_users
END
"@

Invoke-SqlQuery -ServerInstance $SQLServer -Database $ConfigMgrDatabase -Query $TableQuery
if(!$?) { Write-Error "There was a problem creating or recreating the main table" }

# get a list of dell computers in the site
Write-Host "Obtaining list of Dell systems..."


$DellQuery = @"
SELECT DISTINCT sys.netbios_name0 as ComputerName, 
    sys.ResourceID, bios.SerialNumber0 as ServiceTag
FROM v_R_System sys 
    LEFT OUTER JOIN DellWarrantyInfo as dw on sys.ResourceID = dw.resourceid    
    INNER JOIN v_GS_PC_BIOS as bios on bios.ResourceID = sys.ResourceID 
WHERE bios.Manufacturer0 like 'Dell%'
AND    ( dw.EndDate IS NULL
      OR dw.EndDate = '' 
      OR dw.DateScriptRan < DateAdd(dd, -(Round((407-322) * RAND() + 322,0)), GetDate()) )
"@


$dellSystems = Invoke-SqlQuery -ServerInstance $SQLServer -Database $ConfigMgrDatabase -Query $DellQuery
if(!$? -or !$dellSystems) { Write-Error "There was a problem receiving the list of Dell systems." }

#progressbar variables
$length = $dellSystems.count / 100
if ($length -eq 0) { $length=1/100 }
$count=1

#if array is of length 0 the foreach clause still runs with a null value. If check to fix.
if($dellSystems.count -gt 0 -OR $dellSystems.IsNull("ServiceTag") -eq $false -OR $dellSystems -ne $null)
{
    Write-Host "Gathering warranty information..."
    foreach ($dellSystem in $dellSystems)
    {
        #draws the progressbar based on the current count / (length/100)
        Write-Progress "Processing..." "$($dellSystem.ComputerName)" -perc ([Int]$count++/$length) 
        $WarrantyInfo = Get-DellWarranty $dellSystem.ServiceTag -ServiceTagInput -ApiKey $ApiKey #-LogFilePath C:\scripts\log.log
        #insert info into database
        if ($WarrantyInfo) {
        Write-Verbose "Issuing update on $($dellSystem.ComputerName)..."
        Invoke-SqlQuery -ServerInstance $SQLServer -Database $ConfigMgrDatabase -Query "
		SET ANSI_WARNINGS OFF;
        IF
            Not Exists (select ResourceID from DellWarrantyInfo 
            where ResourceID = '$($dellSystem.ResourceID)')
        BEGIN
            INSERT INTO $tableName VALUES (
            '$($dellSystem.ResourceID)',
            '$($dellSystem.ComputerName)', 
            '$(Get-Date)',
            '$($WarrantyInfo.DaysLeft)',
            '$($WarrantyInfo.Region)',
            '$($WarrantyInfo.Description)',
            '$($WarrantyInfo.EndDate)',
            '$($WarrantyInfo.Provider)',
            '$($WarrantyInfo.ServiceTag)',
            '$($WarrantyInfo.ShipDate)',
            '$($WarrantyInfo.StartDate)',
            '$($WarrantyInfo.SystemType)',
            '$(if($WarrantyInfo.WarrantyExtended){1}else{0})',
			'$($WarrantyInfo.OrderNumber)')

        END
        ELSE
            UPDATE $tableName
            SET [ComputerName] = '$($dellSystem.ComputerName)', 
                [DateScriptRan] = '$(Get-Date)',
                [DaysLeft] = '$($WarrantyInfo.DaysLeft)',
                [DellIBU] = '$($WarrantyInfo.Region)',
                [Description] = '$($WarrantyInfo.Description)',
                [EndDate] = '$($WarrantyInfo.EndDate)',
                [Provider] = '$($WarrantyInfo.Provider)',
                [ServiceTag] = '$($WarrantyInfo.ServiceTag)',
                [ShipDate] = '$($WarrantyInfo.ShipDate)',
                [StartDate] = '$($WarrantyInfo.StartDate)',
                [SystemType] = '$($WarrantyInfo.SystemType)',
                [WarrantyExtended] = '$(if($WarrantyInfo.WarrantyExtended){1}else{0})',
				[OrderNumber] = '$($WarrantyInfo.OrderNumber)'
            WHERE [ResourceID] = '$($dellSystem.ResourceID)'"
        if(!$?) { Write-Error "There was a problem adding $($dellSystem.ComputerName) to the database" }
		}
    }
}
Write-Host "Script Complete."
