#requires -version 3.0
[CmdletBinding(SupportsShouldProcess)]

Param(
    [Parameter(Position = 0, Mandatory, HelpMessage = 'Enter the name of your new virtual machine')]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Position = 1, Mandatory, HelpMessage = 'Enter the path to store your VMs (e.g.: C:\VMs)')]
    [ValidateNotNullOrEmpty()]
    [string]$VmPath
)

$SwitchName = 'ExternalSwitch'
$VmCpuCount = 2
$IsoPath = '\\sccmServer.domain.local\deploymentshare$\Boot\LiteTouchPE_x64.iso'

$ExternalSwitchNamed = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
$ExternalSwitch = Get-VMSwitch -SwitchType External -ErrorAction SilentlyContinue

if (-not $ExternalSwitchNamed) {
    if (-not $ExternalSwitch) {
        $NetAdapter = Get-NetAdapter -Name Ethernet
        if ($NetAdapter) {
            try {
                New-VMSwitch -Name $SwitchName -NetAdapterName $NetAdapter.Name -AllowManagementOS $true
            }
            catch {
                Write-Error 'Failed creating new virtual switch.'
                Exit
            }
        }
        else {
            Write-Error "Can't find Ethernet NIC. Quitting."
            Exit
        }
    }
    else {
        $SwitchName = $ExternalSwitch.Name
    }
}

$NewVmParams = @{
    Name               = $VMName
    Path               = $VmPath
    NewVHDPath         = "$VmPath\$VMName\$VMName.vhdx"
    NewVHDSizeBytes    = 50GB
    Generation         = 2
    MemoryStartupBytes = 4GB
    SwitchName         = $SwitchName
    ErrorAction        = 'Stop'
}

$SetVmParams = @{
    ProcessorCount     = $VmCpuCount
    CheckpointType     = 'Disabled'
    DynamicMemory      = $True
    MemoryMinimumBytes = 1GB
    MemoryMaximumBytes = 4GB
    Passthru           = $true
    ErrorAction        = 'Stop'
}

try {
    Write-Verbose 'Creating new VM with the following params:'
    Write-Verbose ($NewVmParams | Out-String)
    $NewVmResult = New-VM @NewVmParams
}
catch {
    Write-Error 'Failed to Create VM'
    Write-Error $_.Exception.Message
    Exit
}

if ($NewVmResult) {
    try {
        Write-Verbose 'Mounting ISO'
        Add-VMDvdDrive -VMName  $NewVmResult.Name -Path $IsoPath -ErrorAction Stop
        $DVD = Get-VMDvdDrive -VMName $NewVmResult.Name
        Set-VMFirmware -VM $NewVmResult -FirstBootDevice $DVD
    }
    catch {
        Write-Warning 'Failed to mount ISO'
        Write-Warning $_.Exception.Message
    }

    try {
        Write-Verbose 'Configuring new VM with the following params:'
        Write-Verbose ($SetVmParams | Out-String)
        $NewVmResult | Set-VM @SetVmParams
    }
    catch {
        Write-Error 'Failed to configure VM'
        Write-Error $_.Exception.Message
        Exit
    }

}
