Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-AppLockerRules([xml]$Expected, [xml]$Actual, [switch]$Exact) {
    $expectedRules = @($Expected.SelectNodes('/AppLockerPolicy/RuleCollection/*[@Id]'))
    $actualRules = @($Actual.SelectNodes('/AppLockerPolicy/RuleCollection/*[@Id]'))
    if ($Exact -and $expectedRules.Count -ne $actualRules.Count) { throw 'Restored rule count differs from backup.' }
    foreach ($collection in $Expected.SelectNodes('/AppLockerPolicy/RuleCollection')) {
        $match = @($Actual.SelectNodes('/AppLockerPolicy/RuleCollection') | Where-Object { $_.Type -eq $collection.Type })
        if ($match.Count -ne 1 -or $match[0].EnforcementMode -ne $collection.EnforcementMode) {
            throw "Collection mode verification failed: $($collection.Type)"
        }
    }
    foreach ($rule in $expectedRules) {
        $found = @($actualRules | Where-Object { $_.Id -eq $rule.Id })
        if ($found.Count -ne 1 -or $found[0].OuterXml -ne $rule.OuterXml) { throw "Rule verification failed: $($rule.Id)" }
    }
}

function Invoke-AppLockerConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateSet('Apply','Export','Restore')][string]$Mode = 'Apply',
        [ValidateSet('AuditOnly','Enabled')][string]$EnforcementMode = 'AuditOnly',
        [Parameter(Mandatory)][string]$BackupPath,
        [string]$PolicyDirectory = (Join-Path $PSScriptRoot 'Files'),
        [string[]]$TestPath = @(),
        [string]$TestUser = 'S-1-1-0'
    )
    foreach ($name in @('Get-AppLockerPolicy','Set-AppLockerPolicy','Test-AppLockerPolicy')) {
        $null = Get-Command $name -ErrorAction Stop
    }
    [xml]$before = Get-AppLockerPolicy -Local -Xml -ErrorAction Stop
    $service = Get-Service -Name AppIDSvc -ErrorAction Stop
    $policies = @()
    $saved = $null
    if ($Mode -eq 'Restore') {
        $saved = Get-Content -LiteralPath $BackupPath -Raw | ConvertFrom-Json
        if ($saved.Version -ne 1 -or $saved.StartType -notin @('Automatic','Manual','Disabled') -or $saved.Status -notin @('Running','Stopped')) {
            throw 'Invalid AppLocker backup.'
        }
        [xml]$policy = $saved.Policy
        if ($policy.DocumentElement.Name -ne 'AppLockerPolicy') { throw 'Invalid policy root.' }
        $policies = @($policy)
    } else {
        if (Test-Path -LiteralPath $BackupPath) { throw 'Backup exists. Choose a new path to preserve recovery data.' }
        if ($Mode -eq 'Apply') {
            foreach ($file in Get-ChildItem -LiteralPath $PolicyDirectory -Filter '*.xml' -File) {
                [xml]$policy = Get-Content -LiteralPath $file.FullName -Raw
                if ($policy.DocumentElement.Name -ne 'AppLockerPolicy') { throw 'Invalid policy root.' }
                foreach ($collection in $policy.SelectNodes('/AppLockerPolicy/RuleCollection')) {
                    $existing = @($before.SelectNodes('/AppLockerPolicy/RuleCollection') | Where-Object { $_.Type -eq $collection.Type })
                    if ($EnforcementMode -eq 'AuditOnly' -and @($existing | Where-Object { $_.EnforcementMode -eq 'Enabled' }).Count) {
                        throw 'Existing enforced collection detected. Audit application would weaken its policy.'
                    }
                    $collection.EnforcementMode = $EnforcementMode
                }
                $policies += $policy
            }
            if (-not $policies.Count) { throw 'No XML policies found.' }
        }
    }
    if ($Mode -ne 'Restore') {
        if (-not $PSCmdlet.ShouldProcess($BackupPath, 'Export local policy and service state')) { return }
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent ([IO.Path]::GetFullPath($BackupPath))) -Force
        @{ Version = 1; Policy = $before.OuterXml; StartType = [string]$service.StartType; Status = [string]$service.Status } |
            ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $BackupPath -Encoding UTF8
    }
    if ($Mode -eq 'Export') { return }
    if ($PSCmdlet.ShouldProcess('Local AppLocker policy', "$Mode configuration ($EnforcementMode)")) {
        foreach ($policy in $policies) {
            $temp = [IO.Path]::GetTempFileName()
            try {
                $policy.Save($temp)
                if ($TestPath.Count) {
                    Test-AppLockerPolicy -XmlPolicy $temp -Path $TestPath -User $TestUser -ErrorAction Stop | Write-Output
                }
                if ($Mode -eq 'Restore') { Set-AppLockerPolicy -XmlPolicy $temp -ErrorAction Stop }
                else { Set-AppLockerPolicy -XmlPolicy $temp -Merge -ErrorAction Stop }
            } finally { Remove-Item -LiteralPath $temp -Force }
        }
        if ($Mode -eq 'Restore') {
            Set-Service -Name AppIDSvc -StartupType $saved.StartType -ErrorAction Stop
            if ($saved.Status -eq 'Running') { Start-Service -Name AppIDSvc -ErrorAction Stop }
            else { Stop-Service -Name AppIDSvc -ErrorAction Stop }
        } else {
            Set-Service -Name AppIDSvc -StartupType Automatic -ErrorAction Stop
            Start-Service -Name AppIDSvc -ErrorAction Stop
        }
        [xml]$local = Get-AppLockerPolicy -Local -Xml -ErrorAction Stop
        foreach ($policy in $policies) { Assert-AppLockerRules $policy $local -Exact:($Mode -eq 'Restore') }
        $actualService = Get-Service -Name AppIDSvc -ErrorAction Stop
        $expectedStatus = 'Running'
        $expectedStart = 'Automatic'
        if ($Mode -eq 'Restore') { $expectedStatus = $saved.Status; $expectedStart = $saved.StartType }
        if ([string]$actualService.Status -ne $expectedStatus -or [string]$actualService.StartType -ne $expectedStart) { throw 'Service verification failed.' }
        [xml]$effective = Get-AppLockerPolicy -Effective -Xml -ErrorAction Stop
        if ($Mode -eq 'Apply') { foreach ($policy in $policies) { Assert-AppLockerRules $policy $effective } }
        if ($TestPath.Count) {
            Get-AppLockerPolicy -Effective | Test-AppLockerPolicy -Path $TestPath -User $TestUser -ErrorAction Stop | Write-Output
        }
        Write-Output "$Mode completed. Local policy and service state verified. Backup: $BackupPath"
    }
}
Export-ModuleMember -Function Invoke-AppLockerConfiguration
