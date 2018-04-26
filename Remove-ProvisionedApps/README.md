Regular 'Remove-Win10-ProvisionedApps.ps1' is run during OS Deployment to remove unnecessary Windows 10 provisioned apps from a computer
that will be dedicated to a single user.

The 'Remove-Win10-ProvisionedApps-SharedPC.ps1' is run during OS Deployment to remove provisioned apps from a shared PC like that in a lab
or classroom. Because these computers generally have profiles removed after a certain period and are subject to more "first logons" where
provisioned apps can add quite a bit of initial logon time, liberty is taken with removing more provisioned apps in this script to create
a better first-use experience. 
