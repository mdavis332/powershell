# derived from http://www.checkyourlogs.net/?p=38333
# if password is a passphrase (>=14 chars, return complexity = true)
# if password otherwise has 3 of the 4 criteria of MS AD complexity requirements, return true
# otherwise, return false
function Test-PasswordComplexity {
    param (
        [Parameter(Mandatory = $false)][string]$AccountName = '',
        [Parameter(Mandatory = $true)][string]$Password
    )

    if ($Password.Length -lt 7) {
        return $false
    }

    if (($AccountName) -and ($AccountName -match $Password)) {
        return $false
    }

    if ($Password.Length -ge 14) {
        return $true
    }

    $permittedSpecialChars = [Regex]::Escape('~!@#$%^&*_+=`|(){}[]:;"",.?/') -replace ']', '\]'
    if (($Password -cmatch '[A-Z\p{Lu}]') `
            + ($Password -cmatch '[a-z\p{Ll}]') `
            + ($Password -match '\d') `
            + ($Password -match "[$permittedSpecialChars]") -ge 3 ) {
        return $true

    }
    else {
        return $false
    }
}

# function to provide a set of creds and return only ones that have complex passwords
# Example input: 
# username1:password1
# username2:Password2
# username3:reallylongpasswordwithnospecialcharacters

# Example output:
# username2:Password2
# username3:reallylongpasswordwithnospecialcharacters
function Select-AccountWithComplexPassword {
    param (
        [Parameter(Mandatory = $false)][string]$Delimeter = ':',
        [Parameter(Mandatory = $true)][string[]]$AccountPasswordPair
    )
	
	# define regex to match an email address followed by a delimiter, then a password, before another delimiter
	# we do this so if we read in a line filled with other content, we can narrow to just the email addr/password
	[regex]$regex = "(([a-zA-Z0-9\.\-_]+@(?:[a-zA-Z0-9\.\-_]+))(?:(?:([${Delimeter}])(.+?(?=\3|\s|$)))))"
	$result = $AccountPasswordPair | Select-String -Pattern $regex -AllMatches
	$CredPair = $result.Matches.Groups.Captures | Where-Object { $_.Name -eq '0' } | Select-Object -ExpandProperty Value
	# if we don't have anything, assume there were no email matches, just account names
	if ($CredPair -ne $null -and $CredPair -ne '') { $AccountPasswordPair = $CredPair }

    # Split on the delimiter 3 times in case there's a trailing delimiter at the end of the password    
    $AccountPasswordPair | ForEach-Object { $AccountName, $Password, $Unused = $_.split($Delimeter, 3); 
        try {
            if (Test-PasswordComplexity -AccountName $AccountName.trim() -Password $Password.trim()) { 
                Write-Output ${AccountName}:${Password}
            } 
        }
        catch [System.Management.Automation.ParameterBindingException] {
            Write-Error 'Did you provide an incorrect delimiter?'
            Write-Error $_
        }

    }
}
