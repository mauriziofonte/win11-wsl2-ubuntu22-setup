# Setup a LAMP Stack on Windows 11, with WSL2, Ubuntu 22.04, native systemd Services and VS Code optimizations

This project is intended to guide the developer through the installation, configuration and _workflow optimization_ of a _LAMP Stack_ that is targeted on Windows 11, with WSL2 and **Ubuntu 22.04**, with a _LAMP Stack_ implemented via _native systemd services_ instead of containers/virtualization.

## Why use Win11 in the first place, and why native systemd services instead of containers?

During my years of on-field experience, I've created _my own workflow_ that allows a developer to:

1. Use MS Windows, if he/she's comfortable with it
2. Use the _Linux Terminal_ with all the performance optimizations made possible by **WSL2**, and specifically use **Ubuntu** as its userbase is consistent: if you encounter a problem, or need a specific package, there's a good probability that you will find informations on how to fix the issue or complete the task in minutes
3. Use native _systemd services_ like **Apache** and **MariaDB** instead of relying on _Containers_ like Docker. Although, in fact, _Docker performance is nearly identical to native performance in Linux_, (references: [1](https://dominoweb.draco.res.ibm.com/reports/rc25482.pdf) and [2](https://stackoverflow.com/questions/21889053/what-is-the-runtime-performance-cost-of-a-docker-container)) my **personal opinion** is that, if a Client has its own VM or shared hosting or voodoo server where _Dockerization is technically not feasible_, then **development workflow, staging and test should be as much as possible adherent to what will the production environment be**. That said, this means having a set of tools to allow the developer _to quicky deploy_ on various types of production configurations (PHP versions, mainly).

## Installation instructions

> Automated Install

If you want to automatically install everything, open a `PowerShell` window with **elevated privileges** (_Run ad Admin_)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; $desktopPath = [Environment]::GetFolderPath('Desktop'); $url = 'https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-guide/main/install/win11.ps1'; $outputPath = Join-Path -Path $desktopPath -ChildPath 'test.ps1'; (New-Object System.Net.WebClient).DownloadFile($url, $outputPath); & $outputPath
```

The automated installer will:

- Download itself to your Desktop
- Start the installation process
- Reboot the computer after a pre-setup phase where WSL will be enabled
- Continue the installation of Ubuntu after the reboot

Tips:

1. If you want to run the automated install on **Windows 10** (not tested!), just append `-SkipWindowsVersionCheck` at the end of the one-liner install
2. If you want to test a **Dry Run** of the script (no modifications made to your PC), just append `-DryRun` at the end of the one-liner install

> Manual Install

Manual installation instuctions are provided in two languages:

- [Manual installation instructions in Italian](/docs/it/SETUP-IT.md)
- [Manual installation instructions in English](/docs/en/SETUP-EN.md)

## Uninstall

To completely remove Ubuntu 22.04 from your computer, open a `PowerShell` window and run:

```powershell
wsl --unregister Ubuntu-22.04
```

If you used the automated install method, you'll also need to remove a specific _HKCU_ Registry Key. To do so, open a `PowerShell` window with **elevated privileges** (_Run ad Admin_) and run:

```powershell
Remove-Item -Path "HKCU:\Software\WSL2Setup" -Force -ErrorAction SilentlyContinue | Out-Null
```

## Mantainers

Currently, the sole maintainer is @mauriziofonte - more maintainers are quite welcome, as the guides are lenghty, and the automated installer is quite complex and difficult to debug without having to create & destroy WSL instances every time.

## License

Released under MIT License. Refer to [LICENSE](/LICENSE) file.

## Disclaimer

The information provided in this repository is for general informational purposes only. All information is provided in good faith, however I make no representation or warranty of any kind, express or implied, regarding the accuracy, adequacy, validity, reliability, availability, or completeness of any information on this repository.

UNDER NO CIRCUMSTANCE SHALL I HAVE ANY LIABILITY TO YOU FOR ANY LOSS OR DAMAGE OF ANY KIND INCURRED AS A RESULT OF THE USE OF THE INFORMATIONS, GUIDES, HOW-TOS, AND SCRIPTS PROVIDED IN THIS REPOSITORY OR RELIANCE ON ANY INFORMATION PROVIDED ON THIS REPOSITORY. YOUR USE OF THIS WORK AND YOUR RELIANCE ON ANY INFORMATION IS SOLELY AT YOUR OWN RISK.

This repository contains links to other websites or content belonging to or originating from third parties or links to websites and features in banners or other advertising. Such external links are not investigated, monitored, or checked for accuracy, adequacy, validity, reliability, availability, or completeness.
