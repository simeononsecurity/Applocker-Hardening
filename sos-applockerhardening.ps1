#Continue on error
$ErrorActionPreference= 'silentlycontinue'

#Require elivation for script run
#Requires -RunAsAdministrator
Write-Output "Elevating priviledges for this process"
do {} until (Elevate-Privileges SeTakeOwnershipPrivilege)

ForEach ($Policy in (Get-ChildItem ./Files/).FullName){
   Set-AppLockerPolicy -XMLPolicy "$Policy" -Merge
}

# Appplocker service running?
Set-Service -Name AppIdsvc -StartupType Automatic
Start-Service AppIdsvc
Get-Service -Name AppIdsvc | fl St*

#Print Conf
Get-AppLockerPolicy -Local
