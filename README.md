# Applocker-Hardening

[![VirusTotal Scan](https://github.com/simeononsecurity/Applocker-Hardening/actions/workflows/virustotal.yml/badge.svg)](https://github.com/simeononsecurity/Applocker-Hardening/actions/workflows/virustotal.yml)

The following script is an automation process for installing AppLocker policies in a Windows environment using PowerShell. The script first sets the error handling preference to "silently continue" and elevates the privileges of the current process. It then sets the directory to the location of the script and installs the policies from the Files directory. The AppLocker service is then enabled and started, and the status of the service is checked. Finally, the active AppLocker rule categories are printed and the script tests the block rules for executables in the C:\Windows\System32 directory for the user "Everyone".

## What does this script do?
- Locks down system resources to bare minimum needed for basic OS functionality

## Recommended reading:
- [api0cradle/UltimateAppLockerByPassList)](https://github.com/api0cradle/UltimateAppLockerByPassList)
- [Microsoft Recommended Block Rules](https://docs.microsoft.com/en-us/windows/security/threat-protection/windows-defender-application-control/microsoft-recommended-block-rules)
- [MotiBa/AppLocker](https://github.com/MotiBa/AppLocker)
- [NSA Cyber Bitlocker Guidance](https://github.com/nsacyber/AppLocker-Guidance)

## How to run the script:
### Manual Install:
If manually downloaded, the script must be launched from an administrative powershell in the directory containing all the files from the [GitHub Repository](https://github.com/simeononsecurity/Applocker-Hardening)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force
Get-ChildItem -Recurse *.ps1 | Unblock-File
.\sos-applockerhardening.ps1
```
### Automated Install:
The script may be launched from the extracted GitHub download like this:
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://simeononsecurity.ch/scripts/sosapplocker.ps1'))
```
<a href="https://simeononsecurity.ch" target="_blank" rel="noopener noreferrer">
  <h2>Explore the World of Cybersecurity</h2>
</a>
<a href="https://simeononsecurity.ch" target="_blank" rel="noopener noreferrer">
  <img src="https://simeononsecurity.ch/img/banner.png" alt="SimeonOnSecurity Logo" width="300" height="300">
</a>

### Links:
- #### [github.com/simeononsecurity](https://github.com/simeononsecurity)
- #### [simeononsecurity.ch](https://simeononsecurity.ch)
