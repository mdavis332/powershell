# derived from http://www.checkyourlogs.net/?p=38333
# if password is a passphrase (>=14 chars, return complexity = true)
# if password otherwise has 3 of the 4 criteria of MS AD complexity requirements, return true
# otherwise, return false
function Test-PasswordComplexity {
    param (
        [Parameter(Mandatory=$false)][string]$AccountName = "",
        [Parameter(Mandatory=$true)][string]$Password
    )

    if ($Password.Length -lt 7) {
        return $false
    }

    if (($Account) -and $Password -match $AccountName) {
        return $false
    }

    if ($Password.Length -ge 14) {
        return $true
    }

    $permittedSpecialChars = [Regex]::Escape('~!@#$%^&*_+=`|(){}[]:;"",.?/') -replace ']','\]'
    if (($Password -cmatch '[A-Z\p{Lu}]') `
        + ($Password -cmatch '[a-z\p{Ll}]') `
        + ($Password -match '\d') `
        + ($Password -match "[$permittedSpecialChars]") -ge 3 )
    {
        return $true

    } else {
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
        [Parameter(Mandatory=$false)][string]$Delimeter = ':',
        [Parameter(Mandatory=$true)][string[]]$AccountPasswordPair
    )

        
    $AccountPasswordPair | ForEach-Object { $AccoutName, $Password = $_.split($Delimeter,2); 
        try {
            if (Test-PasswordComplexity -AccountName $AccoutName -Password $Password) { 
                Write-Output $_ 
            } 
        } catch [System.Management.Automation.ParameterBindingException] {
            Write-Error 'Did you provide an incorrect delimiter?'
            Write-Error $_
        }

    }
}
