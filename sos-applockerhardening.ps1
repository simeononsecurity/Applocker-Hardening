#Continue on error
$ErrorActionPreference= 'silentlycontinue'

#Require elivation for script run
#Requires -RunAsAdministrator
Write-Output "Elevating priviledges for this process"
do {} until (Elevate-Privileges SeTakeOwnershipPrivilege)

ForEach ($Policy in (Get-ChildItem ./Files/).FullName){
   Set-AppLockerPolicy -XMLPolicy "$Policy" -Merge
}