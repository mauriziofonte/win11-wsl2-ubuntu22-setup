# Setup a LAMP/LAPP Stack on Windows 11, with WSL2, Ubuntu 24.04, native systemd Services and VS Code optimizations

This project is intended to guide the developer through the installation, configuration and _workflow optimization_ of a _LAMP/LAPP Stack_ that is targeted on Windows 11 (and also on Windows 10, see below), with _WSL2_ and **Ubuntu 24.04**, with a _LAMP/LAPP Stack_ implemented via _native systemd services_ instead of containers/virtualization.

In a hurry? Skip to the [Automated Installation instructions](#automated-install)!

## What is a LAMP/LAPP Stack?

The acronym `LAMP` stands for **L**inux, **A**pache, **M**ySQL, and **P**HP.
The acronym `LAPP` stands for **L**inux, **A**pache, **P**ostgreSQL, and **P**HP.

LAMP and LAPP stacks are well-known and widely used _web development environments_ that rely on open-source software to deliver dynamic web applications on a wide range of use cases and application scenarios.

## Why use WIN11 in the first place, and why native systemd services instead of containers?

During my years of on-field experience, I've created _my own workflow_ that allows a developer to:

1. Use MS Windows, if he/she's comfortable with it
2. Use the _Linux Terminal_ with all the performance optimizations made possible by **WSL2**, and specifically use **Ubuntu** as its userbase is consistent: if you encounter a problem, or need a specific package, there's a good probability that you will find informations on how to fix the issue or complete the task in a matter of minutes
3. Use native _systemd services_ like **Apache** and **MariaDB** instead of relying on _Containers_ like Docker. Although, in fact, _Docker performance is nearly identical to native performance in Linux_, (references: [1](https://dominoweb.draco.res.ibm.com/reports/rc25482.pdf) and [2](https://stackoverflow.com/questions/21889053/what-is-the-runtime-performance-cost-of-a-docker-container)) my **personal opinion** is that, if a Client has its own VM or shared hosting or voodoo server where _Dockerization is technically not feasible_, then **development workflow, staging and test should be as much as possible adherent to what will the production environment be**. That said, this means having a set of tools to allow the developer _to quicky deploy, test and benchmark_ on various types of _PHP versions and configurations_ that will be available in the production server.

Anyways, this guide is **not** intended to _force you_ to use native WSL Ubuntu systemd services. **If you want to use Docker, you can** ([see here](#can-i-use-docker-instead-of-native-systemd-services)). The automated installer will ask you if you want to install Docker, and if you agree, it will install Docker Desktop for Windows, and you'll be able to use Docker as you would, with all the benefits of using it inside the _WSL2_ subsystem. In fact, as stated on the official Docker Documentation:

> Docker Desktop WSL 2 backend on Windows
> Windows Subsystem for Linux (WSL) 2 is a full Linux kernel built by Microsoft, which lets Linux distributions run without managing virtual machines. With Docker Desktop running on WSL2, users can leverage Linux workspaces and avoid maintaining both Linux and Windows build scripts. In addition, WSL2 provides improvements to file system sharing and boot time.
> Docker Desktop uses the dynamic memory allocation feature in WSL2 to improve the resource consumption. This means Docker Desktop only uses the required amount of CPU and memory resources it needs, while allowing CPU and memory-intensive tasks such as building a container, to run much faster.
> Additionally, with WSL2, the time required to start a Docker daemon after a cold start is significantly faster.

## What will the LAMP/LAPP stack be?

> TL;DR : PHP 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, **8.4** Apache 2.4, MariaDB 11.4, and PostgreSQL 16

The _LAMP/LAPP Stack_ will be configured in this way:

1. Use the `ppa:ondrej/php` PHP repo, that allows to install PHP versions from _5.6_ from up to _8.4_ (at the time of writing)
2. Use the `ppa:ondrej/apache2` Apache repo
3. Use the [`mfonte/hte-cli`](https://github.com/mauriziofonte/hte-cli) tool to handle _Apache Virtualhosts_. This tool can be used to **create, delete and list** virtualhosts that are specifically optimized for **local/test development**.
4. Make _Apache Virtualhosts_ work via _PHP-FPM_ and enable the developer to use quick _deploy_ commands to setup a native local VirtualHost located in the Ubuntu machine
5. Let the developer choose the target PHP version of the deployed VirtualHost ([see here](/docs/en/SETUP-EN.md#test-the-configuration-by-creating-a-virtualHost-for-phpmyadmin))
6. Use `MariaDB 11.4` (EOL 29 May 2029) and optimize Mysql so that it will not create headaches ([see here](/docs/en/SETUP-EN.md#c-modify-mysql-configuration))
7. Use `PostgreSQL 16` (EOL 09 Nov 2028) as an alternative to MariaDB, if the developer wants to use it

## Can I use Docker instead of native systemd services?

Yes, you can. **The automated installer will ask you if you want to install Docker**. If you agree, it will install Docker Desktop for Windows, and you'll be able to use Docker as you would on a Linux machine.

As both the **LAMP/LAPP Stack** and **Docker** installations are _optional_, you can decide whether to:

1. Install the **LAMP/LAPP Stack** and **Docker**
2. Install only the **LAMP/LAPP Stack**
3. Install only **Docker**
4. Don't install anything - after all, you will still have a fully working WSL2 Ubuntu 24.04 machine. _Then, it's all about you and the terminal_!

## Installation instructions

Installation instructions are the same for both **Windows 11** and **Windows 10**.

Specifically, For _Windows 10_, it is _required_ to have a minimum version 1903, and build 18362 or later. Check your Windows version by pressing the Windows logo key + R, type `winver`, and press OK. You should see a number greater than _1903.18362_. If that's the case, then this script will work (tested!)

### Automated Install

If you want to automatically install everything, open a `PowerShell` window with **elevated privileges** (_Run as Admin_)

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; $desktopPath = [Environment]::GetFolderPath('Desktop'); $url = 'https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-setup/main/install/win11.ps1'; $outputPath = Join-Path -Path $desktopPath -ChildPath 'install-ubuntu22-wsl2.ps1'; (New-Object System.Net.WebClient).DownloadFile($url, $outputPath); & $outputPath
```

The **Automated Installer** will do everything for you. Here's a comprehensive list of all the steps that the installer will do:

1. **Verifies Internet Connection**: Automatically checks and waits for an active internet connection before proceeding.
2. **Verifies if you're actually running on Windows 11**: Ensures the script is running on Windows 11, with an option to skip this check (run the script with `-SkipWindowsVersionCheck` if you want to run it on _Windows 10_ aswell).
3. **Pre-Setup Checks and Operations**:
    * Checks if the target distribution (_Ubuntu-24.04_) is already installed. Exits if found and not in force mode.
    * Enables _WSL_ and _Virtual Machine Platform_ Windows features.
    * Schedules the script for auto-run after reboot by creating a CMD batch file in the Startup folder.
4. **Automated Reboot**: If necessary, initiates an automatic system restart to continue the setup after enabling _WSL_ and _Virtual Machine Platform_ features.
    * **Post-Reboot Operations**:
    * Downloads and installs the **Linux Kernel Update** if not already installed, in silent mode.
    * Updates **WSL** and sets the default version to **2**.
    * Installs the target WSL distribution (hardcoded to _Ubuntu-24.04_) if not already present on the system.
5. **User Interaction**:
    * **Docker Installation**:
        * Asks the user if he/she wants to install _Docker_.
        * Downloads and installs _Docker Desktop_ in quiet mode if the user agrees.
        * Informs the user to log off at the end of the automated installer to let the Docker Setup complete its tasks.
    * **LAMP/LAPP Stack Installation**:
        * Asks the user if he/she wants to install a full-fledged **LAMP/LAPP stack**.
        * Proceeds with the installation if the user agrees.
6. **Desktop Icons Creation**: Automatically creates desktop icons for the Ubuntu terminal and home folder.

Tips:

1. If you want to run the automated install on **Windows 10**, just append `-SkipWindowsVersionCheck` at the end of the one-liner install
2. If you want to test a **Dry Run** of the script (no modifications made to your PC), just append `-DryRun` at the end of the one-liner install

#### The LAMP/LAPP Stack installer can also be run on a pre-existing Ubuntu or Debian machine

The **automated install Powershell script** will execute a specific [_Bash Script_](/install/lamp-lapp-stack.sh) that takes care of configuring the **Ubuntu** machine, after the WSL2 VM has been installed.

Anyway, **if you already have a working Ubuntu/Debian** WSL2 VM, in order to install and configure the _LAMP/LAPP Stack_, you can run the following command in the terminal:

```bash
wget -qO- https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-setup/main/install/lamp-lapp-stack.sh | bash
```

The same command can be lauched on a **Ubuntu/Debian VM hosted on a Cloud Service**, but, you'll need to adjust the _Apache Configuration_ so that:

1. it binds to _non-localhost_ ports (`/etc/apache2/ports.conf`)
2. it runs with the correct _User_ and _Group_ (`/etc/apache2/envvars`)
3. if you intend to expose the Apache Webserver to the whole internet: **HARDEN THE SECURITY**. This applies to both _Apache_ and _PHP_ configs.

### Manual Install

Manual installation instuctions are provided in two languages:

* [Manual installation instructions in **English**](/docs/en/SETUP-EN.md)
* [Manual installation instructions in **Italian**](/docs/it/SETUP-IT.md)

## Uninstall

To completely remove Ubuntu 24.04 from your computer, open a `PowerShell` window and run:

```powershell
wsl --unregister Ubuntu-24.04
```

If you used the automated install method, you'll also need to remove a specific _HKCU_ Registry Key. To do so, open a `PowerShell` window with **elevated privileges** (_Run as Admin_) and run:

```powershell
Remove-Item -Path "HKCU:\Software\WSL2Setup" -Force -ErrorAction SilentlyContinue | Out-Null
```

## Keeping the Ubuntu's VHDX image small

The **Ubuntu** image will **grow fast** as you install packages and create files, and Windows will not shrink it automatically. This will lead, over time, to a **huge VHDX file** that will take up a lot of space on your hard drive, even if the _actual_ space used by the Ubuntu installation is much smaller.

In order to keep things clean & tidy, you can use this utility: [wsl2-compact](https://github.com/okibcn/wslcompact)

I suggest to use the **installation option 1: As a PowerShell module**. This will allow you to run the `wslcompact` command from the PowerShell window, and it will also allow you to run the `wslcompact` command from the **Windows Terminal**.

> Attention: always refer to the [latest version of the _README_](https://github.com/okibcn/wslcompact/blob/main/README.md) file of the `wsl2-compact` repository, as the installation method may change over time.

## Mantainers

Currently, the sole maintainer is @mauriziofonte - more maintainers are quite welcome, as the guides are lenghty, and the automated installer is quite complex!

## License

Released under MIT License. Refer to [LICENSE](/LICENSE) file.

## Disclaimer

The information provided in this repository is for general informational purposes only. All information is provided in good faith, however I make no representation or warranty of any kind, express or implied, regarding the accuracy, adequacy, validity, reliability, availability, or completeness of any information on this repository.

UNDER NO CIRCUMSTANCE SHALL I HAVE ANY LIABILITY TO YOU FOR ANY LOSS OR DAMAGE OF ANY KIND INCURRED AS A RESULT OF THE USE OF THE INFORMATIONS, GUIDES, HOW-TOS, AND SCRIPTS PROVIDED IN THIS REPOSITORY OR RELIANCE ON ANY INFORMATION PROVIDED ON THIS REPOSITORY. YOUR USE OF THIS WORK AND YOUR RELIANCE ON ANY INFORMATION IS SOLELY AT YOUR OWN RISK.

This repository contains links to other websites or content belonging to or originating from third parties or links to websites and features in banners or other advertising. Such external links are not investigated, monitored, or checked for accuracy, adequacy, validity, reliability, availability, or completeness.
