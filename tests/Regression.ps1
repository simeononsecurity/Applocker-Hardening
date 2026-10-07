$ErrorActionPreference = 'Stop'
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Throws([scriptblock]$Action) { $failed=$false; try { & $Action } catch { $failed=$true }; Assert $failed 'Expected failure' }
$global:policy='<AppLockerPolicy Version="1" />'
$global:service=[pscustomobject]@{ StartType='Manual'; Status='Stopped' }
$global:writes=0
$global:ignorePolicy=$false
$global:testCalls=0
function global:Get-AppLockerPolicy { [CmdletBinding()]param([switch]$Local,[switch]$Effective,[switch]$Xml); return $global:policy }
function global:Set-AppLockerPolicy { [CmdletBinding()]param([string]$XmlPolicy,[switch]$Merge); $global:writes++; if (-not $global:ignorePolicy) { $global:policy=[IO.File]::ReadAllText($XmlPolicy) } }
function global:Test-AppLockerPolicy { [CmdletBinding()]param([Parameter(ValueFromPipeline)]$PolicyObject,[string]$XmlPolicy,[string[]]$Path,[string]$User); process { $global:testCalls++; [pscustomobject]@{PolicyDecision='Allowed';FilePath=$Path} } }
function global:Get-Service { [CmdletBinding()]param([string]$Name); return $global:service }
function global:Set-Service { [CmdletBinding()]param([string]$Name,[string]$StartupType); $global:service.StartType=$StartupType }
function global:Start-Service { [CmdletBinding()]param([string]$Name); $global:service.Status='Running' }
function global:Stop-Service { [CmdletBinding()]param([string]$Name); $global:service.Status='Stopped' }
Import-Module (Join-Path $PSScriptRoot '../AppLockerHardening.psm1') -Force
$root=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
$null=New-Item -ItemType Directory $root
try {
    $backup=Join-Path $root 'original.json'
    Invoke-AppLockerConfiguration -BackupPath $backup -WhatIf
    Assert ($global:writes -eq 0 -and -not (Test-Path $backup)) 'WhatIf changed policy'
    Invoke-AppLockerConfiguration -BackupPath $backup -TestPath @('fixture.exe')
    Assert ($global:testCalls -eq 2) 'Pre/post policy tests did not run'
    Assert ($global:policy.Contains('AuditOnly')) 'Default should audit'
    Assert ($global:service.Status -eq 'Running') 'Service did not start'
    Invoke-AppLockerConfiguration -BackupPath $backup -Mode Restore
    Assert (([xml]$global:policy).SelectNodes('//RuleCollection').Count -eq 0) 'Original policy not restored'
    Assert ($global:service.Status -eq 'Stopped' -and $global:service.StartType -eq 'Manual') 'Service not restored'
    $global:policy='<AppLockerPolicy Version="1"><RuleCollection Type="Exe" EnforcementMode="Enabled" /></AppLockerPolicy>'
    Throws { Invoke-AppLockerConfiguration -BackupPath (Join-Path $root 'conflict.json') }
    Assert (-not (Test-Path (Join-Path $root 'conflict.json'))) 'Enforcement conflict wrote backup'
    $global:policy='<AppLockerPolicy Version="1" />'
    $global:ignorePolicy=$true
    Throws { Invoke-AppLockerConfiguration -BackupPath (Join-Path $root 'failed.json') }
    Assert (Test-Path (Join-Path $root 'failed.json')) 'Failure lost backup'
    Write-Output 'PASS: audit default, backup/restore, service restore, policy tests, conflicts, WhatIf and ignored writes'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force
    Remove-Module AppLockerHardening
    foreach ($name in @('Get-AppLockerPolicy','Set-AppLockerPolicy','Test-AppLockerPolicy','Get-Service','Set-Service','Start-Service','Stop-Service')) { Remove-Item "Function:\$name" }
}
