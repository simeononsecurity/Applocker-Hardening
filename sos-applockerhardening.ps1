#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Apply','Export','Restore')][string]$Mode = 'Apply',
    [ValidateSet('AuditOnly','Enabled')][string]$EnforcementMode = 'AuditOnly',
    [string]$BackupPath = (Join-Path $env:ProgramData ('SoS-AppLocker\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.json')),
    [string[]]$TestPath = @("$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe", "$env:windir\explorer.exe"),
    [string]$TestUser = 'S-1-1-0'
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'AppLockerHardening.psm1') -Force
    $confirmation = @{}
    if ($PSBoundParameters.ContainsKey('Confirm')) { $confirmation['Confirm'] = $PSBoundParameters['Confirm'] }
    Invoke-AppLockerConfiguration -Mode $Mode -EnforcementMode $EnforcementMode -BackupPath $BackupPath -TestPath $TestPath -TestUser $TestUser -WhatIf:$WhatIfPreference @confirmation
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
