# Select-AccountWithComplexPassword

## Description

Function that takes in one account/password pair per line, separated by some delimeter.
Returns only the account/password pairs that meet MS AD complexity requirements

Default delimiter is the colon (:)

## Examples

```powershell

Select-AccountWithComplexPassword -AccountPasswordPair 'username1@domain.tld:password1'

Select-AccountWithComplexPassword -AccountPasswordPair 'username1@domain.tld|Testpassword1' -Delimeter '|'

Select-AccountWithComplexPassword -AccountPasswordPair (Get-Content ./FileWithManyPairsOnePerLine.txt)

Select-AccountWithComplexPassword -AccountPasswordPair (Get-Content ./FileWithManyPairsOnePerLine.txt) | Out-File ./Pruned.txt

```
