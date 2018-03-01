$SearchBase = 'OU=ComputerAccounts,DC=contoso,DC=com'
$SecurityGroup = 'SG-GroupPolicy-ComputerAccounts-FullControl'

Import-Module ActiveDirectory
Import-Module GroupPolicy

$OUs = Get-ADOrganizationalUnit -SearchBase $SearchBase -SearchScope Subtree -Filter * | Select-Object -Property *,@{l='FriendlyGPODisplayName';e={$_.LinkedGroupPolicyObjects | ForEach-Object {([adsi]"LDAP://$_").displayName -join ''} } }
$GpoList = Get-GPO -All | Where-Object { $_.DisplayName -in $($OUs.FriendlyGPODisplayName) }

$Group = $(Get-AdGroup $SecurityGroup).sAMAccountName

$GpoList | ForEach-Object { Set-GpPermissions -Guid $_.Id -Targetname $Group -TargetType Group -PermissionLevel GpoEditDeleteModifySecurity}
