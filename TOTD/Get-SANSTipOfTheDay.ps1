<#
.SYNOPSIS
Retrieve SANS Tip of the Day and set it in Group Policy to show up at login.

.DESCRIPTION
Retrieve SANS Tip of the Day and set it in Group Policy to show up at login.

.PARAMETER Guid Specifies the GUID of the Group Policy Object to which you want to add the Tip

.BUGS
None known.

.INPUTS
None. You cannot pipe objects to this cmdlet.

.OUTPUTS
Returns any Microsoft.GroupPolicy.Gpo objects from GPOs that had GPP items removed from or added to

.EXAMPLE
Get-SANSTipOfTheDay -Guid E899AD87-8B2F-4F93-B181-37B915D368FA
#>

[CmdletBinding()]
param (
    [parameter(Mandatory=$True)]
    [string]$Guid
)

# uri of Sans TOTD
$uri = 'https://www.sans.org/tip-of-the-day'
$page = Invoke-WebRequest $uri

# find the HTML Div that matches 'well' in which the TOTD text is stored, then save the text
$TipOfTheDayRaw = $page.AllElements | Where { $_.Class -eq 'well' } | Select -ExpandProperty InnerText

$TipOfTheDay = $null

# create a regex pattern to match everything up to but not including the text, "To learn more"
[regex]$rx = "(?s).+?(?=To learn more)"

# strip out and keep only the text we want
$TipOfTheDay = $rx.Match($TipOfTheDayRaw).Value

# split the header and body into separate variables to be used independently later
$TipOfTheDayHeader, $TipOfTheDayBody = $TipOfTheDay -split "`n", 2

# Remove any whitespace at beginning or end of strings
$TipOfTheDayHeader = $TipOfTheDayHeader.Trim()
$TipOfTheDayBody = $TipOfTheDayBody.Trim()

# Splat parameters to pass to Set-GPPrefRegistryValue cmdlet
$parmsForSet = @{
    Guid = "$Guid"
    Context = 'Computer'
    Action = 'Update'
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    ValueName = 'LegalNoticeCaption'
    Value = "$TipOfTheDayHeader"
    Type = 'String'
}

# Splat parameters for Remove cmdlet
$parmsForRemove = @{
    Guid = "$Guid"
    Context = 'Computer'
    Key = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    ValueName = 'LegalNoticeCaption'
    ErrorAction = 'SilentlyContinue'
}

# Remove existing GPP if it's there so we don't create multiple, identical GPP items
Remove-GPPrefRegistryValue @parmsForRemove
# Now add the new stuff
Set-GPPrefRegistryValue @parmsForSet

# Adjust splatted parameters for only the values that are different
$parmsForSet.ValueName = 'LegalNoticeText'
$parmsForSet.Value = "$TipOfTheDayBody"
$parmsForRemove.ValueName = 'LegalNoticeText'

# Remove existing GPP if it's there so we don't create multiple, identical GPP items
Remove-GPPrefRegistryValue @parmsForRemove
Set-GPPrefRegistryValue @parmsForSet
