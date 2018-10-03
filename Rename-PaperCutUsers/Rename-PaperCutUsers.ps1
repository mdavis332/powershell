Function Rename-PaperCutUser {
    <#
    .SYNOPSIS
        Renames a user in PaperCut db
    .DESCRIPTION
        Renames a user in PaperCut db (usually because of name change)
    .PARAMETER Id
        The user's current employee/student ID used as the primary key by PaperCut
    .PARAMETER NewFirstName
        (Optional) The user's current AD first name (whatever PaperCut should now reflect)
    .PARAMETER NewLastName
        (Optional) The user's current AD last name (whatever PaperCut should now reflect)
    .PARAMETER NewUserName
        The user's current AD SAMaccountName (whatever username PaperCut should now reflect)
    .OUTPUTS
        
    .EXAMPLE
        Rename-PaperCutUser -Id 1110005 -NewUserName SallyJones
    .FUNCTIONALITY
        PaperCut Management
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $false)]
        [string]$NewFirstName,
        [Parameter(Mandatory = $false)]
        [string]$NewLastName,
        [Parameter(Mandatory = $true)]
        [string]$NewUserName
    )

    # Requires PowerShell v4 or higher
    # Use Tls 1.2
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
    # Import PaperCut Management module from https://github.com/robp2175/PapercutManagementModule
    Import-Module "\\path\to\PapercutManagementModule\PapercutManagement\bin\Release\PapercutManagement.dll"

    # Set default values and create a session to PaperCutServer (must use https)
    Connect-PcutServer -ComputerName printing.local -Port 9192 -authToken 2wVpxLeY4NjQz7VvMvaCAWcQunW1r0zk

    $OldUserName = (Get-PcutUserByIdNo -Id $Id).Username

    # Find/rename the auto-created new stuff (right username, but we need to get rid of it to rename the old account to the new stuff)
    $NewUser = Get-PcutUser -UserName $NewUserName
    if ($NewUser) {
        # new username already exists, so get some info from it to store into old account so that old account reflects new info
        $NewFullname = $NewUser.Fullname
        $NewEmailAddress = $NewUser.Email
        # email is almost like a primary key - PaperCut won't let you have two accounts that use same email, so set to something diff
        #$tempEmail = $NewEmailAddress + ".notused"
        #Set-PcutUserProperty -Username $NewUserName -PropertyName email -PropertyValue $tempEmail
        # let's delete new account now so old account can be renamed to new account's name
        Write-Verbose "Removing $NewUserName"
        Remove-PcutUser -UserName $NewUserName
    }
    else {
        # user didn't exist, so shouldn't be a problem to just rename old username to new username
        Write-Verbose "$NewUserName doesn't currently exist in PaperCut database."
    }

    # Rename old name to new name
    Write-Verbose "Renaming $OldUsername to $NewUserName"
    Rename-PcutUser -currentUserName $OldUserName -newUsername $NewUserName

    # Update fullname of renamed account to have correct name
    If (!$NewFullname) {
        # make sure NewLastName and NewFirstName params were supplied at runtime
        If ($NewLastName -ne $null -and $NewLastName -ne $null) {
            Write-Verbose "New user did not exist. Guestimating Fullname."
            $NewFullname = "$NewLastName" + ", " + "$NewFirstName"   
        }
        Else {
            Write-Error "Name info not complete. Manually check $NewUserName for accuracy"
        }
    
    }
    Set-PcutUserProperty -Username $NewUserName -PropertyName full-name -PropertyValue $NewFullname

    # Update email of renamed account to have correct email address
    If (!$NewEmailAddress) {
        Write-Verbose "New user did not exist. Guestimating Email."
        $NewEmailAddress = "$NewUserName" + "@domain.local"
    }
    Set-PcutUserProperty -Username $NewUserName -PropertyName email -PropertyValue $NewEmailAddress

    # Close connection to PaperCut Server
    Disconnect-PcutServer
}

Function Find-PcutUsersToRename {
    <#
    .SYNOPSIS
        Reads in a PaperCut log file looking for a specific date
    .DESCRIPTION
        Reads in a PaperCut log file looking for a specific date
    .PARAMETER Path
        The path to the PaperCut server.log file
    .PARAMETER Lines
        (Optional) The number of lines, from the end of the log file, to read in. Default is 70
    .OUTPUTS
        A PSCustomObject hash of all new usernames and associated ID numbers that can be passed to Rename-PcutUser
    .EXAMPLE
        Find-PcutUsersToRename -Path \\papercut.local\share$\server.log
    .FUNCTIONALITY
        PaperCut Management
    #>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [int]$Lines = 70
    )

    # Get today's date in the format that server.log records it
    $Today = "{0:yyyy-MM-dd}" -f (Get-Date)

    # read server.log content into var
    $Content = Get-Content $Path | Select-Object -Last $Lines

    # filter out any logfile lines that don't match today's date, then just save those
    $TodaysContent = $Content.Where( { $_ -like ("$Today*") }, 'SkipUntil')

    # iterate through today's log entries and find the ones that correspond to username sync issues 
    # indicating a username rename in the past
    $SyncErrors = $TodaysContent -match "The user's card number will not be updated."

    # define regex to match only text inside the double quotes within the string - that should be the username
    $rx1 = [regex]'(?<=")(.+)(?=")'
    # define regex to match only text inside the parentheses within the string - that should be the ID num
    $rx2 = [regex]'\(([^\)]+)\)'
    # create array to hold Custom PSobject used later
    $Output = @()
    # SyncErrors is an array of strings. Iterate through each element performing the PaperCut management actions
    ForEach ($string in $SyncErrors) {
        # the username in the log file in the only thing on that line surrounded by double quotes
        $Username = $rx1.Match($string).Groups[0].Value
        # the ID number is the only thing in each log line entry that's contained within parentheses
        $IdNum = $rx2.Match($string).Groups[1].Value

        # Prepare Custom PowerShell Object for output with the info later on
        $OutputInfo = New-Object PSObject

        $OutputInfo | Add-Member NoteProperty Username $Username
        $OutputInfo | Add-Member NoteProperty IdNumber $IdNum

        $Output += $OutputInfo
    }

    Return $Output
}

$UsersToRename = Find-PcutUsersToRename -Path "\\printers.domain.local\c$\Program Files\PaperCut NG\server\logs\server.log"

If ($UsersToRename.count -gt 0) {
    # there were sync errors in the log file, indicating usernames needing to be renamed. Process those now
    ForEach ($User in $UsersToRename) {
        Rename-PaperCutUser -Id $User.IdNumber -NewUserName $User.Username
    }
}
Else {
    # there were no sync errors, so no usernames need to be renamed at this time
}
