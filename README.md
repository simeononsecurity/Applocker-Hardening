# AppLocker Hardening

Apply packaged AppLocker rules in audit mode, verify the local and effective policies, and retain a recovery snapshot.

## Requirements

- Elevated Windows PowerShell 5.1 or PowerShell 7 with AppLocker commands available.
- A Windows edition and build supporting the required AppLocker behavior and Application Identity service.
- A disposable test system matching the target workload before deployment.

The script requires administrator privileges directly. It no longer relies on an external elevation helper. Domain policy might override local settings and trigger effective-policy verification failures.

## Preview and apply

```powershell
.\sos-applockerhardening.ps1 -WhatIf
.\sos-applockerhardening.ps1 -BackupPath C:\Recovery\applocker-before.json
```

The default uses `AuditOnly` for each packaged collection. Existing enforced collections cause audit application to stop before changes, preventing an accidental downgrade. Existing rules are merged with the supplied rules.

After checking audit events and application compatibility, explicitly select enforcement:

```powershell
.\sos-applockerhardening.ps1 -EnforcementMode Enabled -BackupPath C:\Recovery\applocker-before-enforcement.json
```

The default backup location is a timestamped JSON file under `%ProgramData%\SoS-AppLocker`. Choose a fresh backup path for each application. Existing backups are never overwritten.

## Policy tests

The script calls `Test-AppLockerPolicy` before deployment and against effective policy afterward. Default paths cover Windows PowerShell and Explorer. Supply your workload and user or SID:

```powershell
.\sos-applockerhardening.ps1 -TestPath C:\Apps\Example.exe -TestUser 'S-1-1-0' -BackupPath C:\Recovery\app-test.json
```

Review the returned allow/deny decisions. Sample paths do not establish compatibility for all applications. Completion requires matching rule content, collection modes, and the expected service state.

## Export and restore

```powershell
.\sos-applockerhardening.ps1 -Mode Export -BackupPath C:\Recovery\applocker-export.json
.\sos-applockerhardening.ps1 -Mode Restore -BackupPath C:\Recovery\applocker-before.json -WhatIf
.\sos-applockerhardening.ps1 -Mode Restore -BackupPath C:\Recovery\applocker-before.json
```

The snapshot stores local policy XML and the Application Identity service's startup type and running state. Restore replaces the local policy with the snapshot, then restores and verifies service state. Domain policy is outside this snapshot. A failure retains the backup and returns a nonzero exit code.

Recovery replaces local changes made after the snapshot. Keep backups local to the source machine. Older installations have no snapshot from this version. Exporting now captures the current policy, not the policy before an older script ran.

## Validation

```powershell
pwsh -NoProfile -File tests/Regression.ps1
```

Tests use mocked AppLocker and service commands. They cover audit defaults, backups, restoration, policy test calls, existing enforcement conflicts, WhatIf, and ignored policy writes. CI runs Windows PowerShell 5.1 and PowerShell 7. Native policy normalization, service permissions, reboot behavior, and domain precedence require a Windows VM acceptance pass before release.
