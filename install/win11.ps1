# Windows WSL2 Ubuntu 24.04 Setup Script for Windows 11
# 
# Author: Maurizio Fonte (https://www.mauriziofonte.it)
# Version: 1.2.1
# Release Date: 2023-09-04
# Last Update: 2025-04-10
# License: MIT License
# 
# If you find any issue, please report it on GitHub: https://github.com/mauriziofonte/win11-wsl2-ubuntu22-setup/issues
# 

# Set the target distribution name (global variable)
$targetDistro = "Ubuntu-24.04"

# Get the "DryRun" flag from the command line: if specified, the script will not actually install anything, but will only simulate the installation
$dryRun = $false
if ($args -contains "-DryRun") {
    $dryRun = $true
    Write-Host "####                        TEST MODE                                ####"
    Write-Host "#### This is a dry run. No modifications will be done to the system. ####"
}

# Get the "SkipWindowsVersionCheck" flag from the command line: if specified, the script will not check for Windows 11
$skipWindowsVersionCheck = $false
if ($args -contains "-SkipWindowsVersionCheck") {
    $skipWindowsVersionCheck = $true
}

# Get the "Force" flag from the command line
# if specified, the script will reset the registry values so that it will run again from the beginning
# also, if specified, the script will continue anyway even if $targetDistro is already installed
$force = $false
if ($args -contains "-Force") {
    # remove the registry key
    Remove-Item -Path "HKCU:\Software\WSL2Setup" -Force -ErrorAction SilentlyContinue
    $force = $true
}

# Get current Windows Display language, to know how to display messages
$cultureName = (Get-Culture).Name

# normalize the Display Language so that, if we are in Italian, the language will be "it" and "default" 
# if we are in any other language (only parse the first two characters of the language)
$langCode = $cultureName.Substring(0,2).ToLower()

if ($langCode -eq "it") {
    $language = "it"
}
else {
    $language = "default"
}

# Initialize a set of localized messages
$defaultMessages = @{
    "exit" = "Press Enter to exit"
    "invalid_answer" = "Invalid answer. Please type y or n and press Enter."
    "win11_only" = "This script is designed for Windows 11 only."
    "win11_ok" = "Windows 11 detected. Continuing..."
    "distro_already_installed" = "$targetDistro is already installed. Aborting installation."
    "distro_needs_install" = "$targetDistro is now being installed. The system will reboot itself after the WSL2 subsystem is setup."
    "run_as_admin" = "Please run this script as an Administrator!"
    "no_internet_connection" = "No active internet connection found. Please check your connection and press Enter to retry."
    "internet_ok" = "Internet connection OK, proceeding..."
    "kernel_update_needed" = "We need to install the Windows Subsystem for Linux KERNEL Update."
    "kernel_update_already_installed" = "Windows Subsystem for Linux Update KERNEL update is already installed. Skipping..."
    "downloaded_file_does_not_exist" = "Downloaded file does not exist on the expected path."
    "downloaded_file_has_zero_length" = "Downloaded file has zero length."
    "exception" = "Exception:"
    "enabling_wsl_subsystem" = "Enabling WSL and Virtual Machine Platform..."
    "cant_move_script" = "Couldn't create the auto-start CMD batch file and save it to the Startup folder."
    "restart_needed" = "Restart is needed. Save your current work, then press Enter to exit and restart the computer."
    "postreboot_batch_message_1" = "$targetDistro - WSL2 Support has been installed successfully on your machine."
    "postreboot_batch_message_2" = "In the next step, we're going to install $targetDistro. But, we'll need SuperUser privileges to do that."
    "postreboot_batch_message_3" = "Please, press ENTER, then confirm the next UAC prompt by clicking OK, then press ENTER to continue."
    "wsl_initing" = "Initializing WSL..."
    "wsl_init_wait_for_enter" = "Press Enter to continue..."
    "wsl_version_not_found" = "Couldn't determine the WSL version. Cannot continue execution..."
    "wsl_version_below_required" = "WSL version is below the required version. Cannot continue execution..."
    "target_distro_not_found" = "Couldn't find $targetDistro as installable distro from https://raw.githubusercontent.com/microsoft/WSL/master/distributions/DistributionInfo.json."
    "presetup_1" = "$targetDistro installation should start in a few seconds. Afterwards, Linux will ask you to specify a new username and password."
    "presetup_2" = "IMPORTANT: After you've specified the username and password, and can see the message `"Installation successful!`", please type `"exit`" and press Enter to temporarily exit Linux."
    "config_1" = "Modifying DNS resolver settings and enabling systemd support..."
    "ask_for_docker" = "Do you want to install Docker? (y/n/Y/N/yes/no)"
    "docker_already_installed" = "Docker Desktop is already installed. Skipping..."
    "docker_install_warning" = "IMPORTANT: the installation will take a while, please be patient. Press ENTER to continue"
    "docker_postinstall_message" = "Docker Desktop has been installed successfully. IMPORTANT: you will need to logoff your current session at the end of the installation to let Docker Desktop finish its setup. Press Enter to continue."
    "ask_for_lamp" = "Do you want to install the full-fledged optimized LAMP+LAPP stack? (y/n/Y/N/yes/no)"
    "lamp_install_warning" = "IMPORTANT: the installation will take a while, and you will see a lot of output. Please be patient. Press ENTER to continue"
    "lamp_installation_skipped" = "LAMP+LAPP stack installation skipped."
    "config_2" = "Running the automated LAMP+LAPP installer inside the $targetDistro distribution..."
    "config_3" = "Creating Desktop Icons..."
    "setup_completed" = "Setup completed! Press Enter to exit."
}

$italianMessages = @{
    "exit" = "Premi Invio per uscire"
    "invalid_answer" = "Risposta non valida. Per favore, digita y o n e premi Invio."
    "win11_only" = "Questo script e' progettato solo per Windows 11."
    "win11_ok" = "Windows 11 rilevato. Continuo l'installazione..."
    "distro_already_installed" = "$targetDistro e' gia' installato. Installazione annullata."
    "distro_needs_install" = "$targetDistro e' ora in fase di installazione. Il sistema si riavviera' dopo l'installazione del sottosistema WSL2."
    "run_as_admin" = "E' necessario eseguire questo script come amministratore!"
    "no_internet_connection" = "Non e' stata rilevata alcuna connessione Internet attiva. Controlla la tua connessione e premi Invio per riprovare."
    "internet_ok" = "Connessione Internet funzionante, procedo..."
    "kernel_update_needed" = "E' necessario installare l'aggiornamento del KERNEL di Windows Subsystem for Linux."
    "kernel_update_already_installed" = "L'aggiornamento del KERNEL di Windows Subsystem for Linux e' gia' installato. Procedo oltre..."
    "downloaded_file_does_not_exist" = "Il file scaricato non esiste nel percorso previsto."
    "downloaded_file_has_zero_length" = "Il file scaricato ha una lunghezza pari a zero."
    "exception" = "Eccezione:"
    "enabling_wsl_subsystem" = "Abilitazione di WSL e della piattaforma di macchine virtuali..."
    "cant_move_script" = "Impossibile creare il file batch CMD di avvio automatico e salvarlo nella cartella di avvio."
    "restart_needed" = "E' necessario riavviare il computer. Salva il tuo lavoro, quindi premi Invio per uscire e riavviare il computer."
    "postreboot_batch_message_1" = "$targetDistro - WSL2 Support e' stato installato correttamente sul tuo computer."
    "postreboot_batch_message_2" = "Nel prossimo passaggio, installeremo $targetDistro. Ma, avremo bisogno dei privilegi di Amministrazione per farlo."
    "postreboot_batch_message_3" = "Premi INVIO, quindi conferma il prossimo prompt UAC cliccando su OK, quindi premi INVIO per continuare."
    "wsl_initing" = "Inizializzazione di WSL..."
    "wsl_init_wait_for_enter" = "Premi Invio per continuare..."
    "wsl_version_not_found" = "Impossibile determinare l'attuale versione di WSL. Impossibile procedere..."
    "wsl_version_below_required" = "La versione di WSL e' inferiore a quella richiesta. Impossibile procedere..."
    "target_distro_not_found" = "Impossibile trovare $targetDistro come distribuzione installabile da https://raw.githubusercontent.com/microsoft/WSL/master/distributions/DistributionInfo.json."
    "presetup_1" = "L'installazione di $targetDistro dovrebbe iniziare tra pochi secondi. Successivamente, Linux ti chiedera' di specificare un nuovo nome utente e una nuova password."
    "presetup_2" = "IMPORTANTE: Dopo aver specificato il nome utente e la password, e aver visualizzato il messaggio `"Installation successful!`", digita `"exit`" e premi Invio per uscire temporaneamente da Linux."
    "config_1" = "Modifica delle impostazioni del resolver DNS e abilitazione del supporto a systemd..."
    "ask_for_docker" = "Vuoi installare Docker? (y/n/Y/N/yes/no)"
    "docker_already_installed" = "Docker Desktop e' gia' installato. Procedo oltre..."
    "docker_install_warning" = "IMPORTANTE: l'installazione richiedera' un po' di tempo, per favore sii paziente. Premi INVIO per continuare"
    "docker_postinstall_message" = "Docker Desktop e' stato installato con successo. IMPORTANTE: dovrai disconnettere la sessione corrente alla fine dell'installazione per consentire a Docker Desktop di completare la sua configurazione. Premi Invio per continuare."
    "ask_for_lamp" = "Vuoi installare lo LAMP+LAPP stack completo e ottimizzato? (y/n/Y/N/yes/no)"
    "lamp_install_warning" = "IMPORTANTE: l'installazione richiedera' un po' di tempo, e vedrai un sacco di output. Per favore, sii paziente. Premi INVIO per continuare"
    "lamp_installation_skipped" = "Installazione dello stack LAMP+LAPP saltata."
    "config_2" = "Esecuzione dell'installer LAMP+LAPP automatico all'interno della distribuzione $targetDistro..."
    "config_3" = "Creazione delle icone sul Desktop..."
    "setup_completed" = "Installazione completata! Premi Invio per uscire."
}

$messages = @{
    "default" = $defaultMessages
    "it" = $italianMessages
}

function Check-Distro {
	param (
		[Parameter(Mandatory=$true)]  [String]$Distro,
		[Parameter(Mandatory=$false)] [Bool]$Online = $false
	)
	
	if ($online) {
        $distributions = wsl --list --online
    }
    else {
        $distributions = wsl --list --quiet
    }

    $found = $false

    $distributions | ForEach-Object { 
        $line = $_.Trim().Split(' ')[0] -replace "`r|`n","";
        if ($line -eq $Distro) {
            $found = $true
        }
    }

    return $found
}

function Remote-Download {
    param (
        [Parameter(Mandatory=$true)]  [String]$Url,
        [Parameter(Mandatory=$true)]  [String]$Output
    )

    try {
        Invoke-WebRequest -Uri $Url -OutFile $Output -ErrorAction Stop

        # Check if the file exists
        if (-not (Test-Path $Output)) {
            throw $messages[$language]["downloaded_file_does_not_exist"]
        }

        # Check if the file has content (non-zero length)
        $fileInfo = Get-Item $Output
        if ($fileInfo.Length -eq 0) {
            throw $messages[$language]["downloaded_file_has_zero_length"]
        }
        
    } catch {
        Write-Host $messages[$language]["exception"] $_.Exception.Message -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"]
        Read-Host
        exit
    }
}

function Test-InternetConnection {
    try {
        Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Wait-For-InternetConnection {
    while (-not (Test-InternetConnection)) {
        Write-Host $messages[$language]["no_internet_connection"] -ForegroundColor White -BackgroundColor Red
        Read-Host
    }

    Write-Host $messages[$language]["internet_ok"] -ForegroundColor Cyan
}

function Create-Desktop-Shortcut {
    param (
        [Parameter(Mandatory=$true)]  [String]$ShortcutLinkName,
        [Parameter(Mandatory=$true)]  [String]$TargetPath,
        [Parameter(Mandatory=$false)] [String]$Arguments,
        [Parameter(Mandatory=$false)] [String]$IconLocation,
        [Parameter(Mandatory=$false)] [String]$Description
    )

    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $desktopIcon = "$desktopPath\$ShortcutLinkName.lnk"

    # Create the Desktop Icon
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($desktopIcon)
    $shortcut.TargetPath = $TargetPath
    if($Arguments) { $shortcut.Arguments = $Arguments }
    if($IconLocation) { $shortcut.IconLocation = $IconLocation }
    if($Description) { $shortcut.Description = $Description }
    $shortcut.Save()
}

function Get-RegistryKey {
    param (
        [Parameter(Mandatory=$true)] [String]$Key
    )

    return (Get-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name $Key -ErrorAction SilentlyContinue).$Key
}

function Get-Username {
    # return the username of the current logged user, even if the script is called via "Run as Admin" (in that case, the $env:USERNAME variable would return "SYSTEM")
    return ([Security.Principal.WindowsIdentity]::GetCurrent()).Name
}

function Ask-Question {
    param (
        [Parameter(Mandatory=$true)] [String]$Question
    )

    Write-Host $Question -ForegroundColor Cyan

    # continuously ask the question until the user answers "y" or "n" or "Y" or "N" or "yes" or "no"
    $maxTries = 10
    while ($true) {

        if ($maxTries -eq 0) {
            Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
            Read-Host
            exit
        }

        $answer = Read-Host
        if ($answer -eq "y" -or $answer -eq "Y" -or $answer -eq "yes" -or $answer -eq "Yes") {
            return $true
        }
        elseif ($answer -eq "n" -or $answer -eq "N" -or $answer -eq "no" -or $answer -eq "No") {
            return $false
        }
        else {
            Write-Host $messages[$language]["invalid_answer"] -ForegroundColor White -BackgroundColor Red
            $maxTries--
        }
    }
}

# Verify Internet Connection
Wait-For-InternetConnection

# Verify Windows 11
if (-not $skipWindowsVersionCheck) {
    $osVersion = [System.Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10 -or $osVersion.Build -lt 22000) {
        Write-Host $messages[$language]["win11_only"] -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
        Read-Host
        exit
    }
    else {
        Write-Host $messages[$language]["win11_ok"]
    }
}

# Registry Values coming from pre-setup phase (if already run)
$wslSetupStep = Get-RegistryKey -Key "Step"
$wslSetupUser = Get-RegistryKey -Key "CurrentUser"
$wslSupportEnabled = Get-RegistryKey -Key "WSL2SupportEnabled"

# if we have not run before, or step is below 2, we need to run the pre-setup phase
if (-not $wslSetupStep -or $wslSetupStep -lt 2 -or -not $wslSupportEnabled) {
    # Step 1: Pre-setup phase (WSL and Virtual Machine Platform installation)

    # Check if $targetDistro is already installed
    if (-not $dryRun) {
        $alreadyInstalled = Check-Distro -Distro $targetDistro
        if ($alreadyInstalled -and -not $force) {
            Write-Host $messages[$language]["distro_already_installed"] -ForegroundColor White -BackgroundColor Red
            Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
            Read-Host
            exit
        }
        else {
            Write-Host $messages[$language]["distro_needs_install"]
        }
    }

    # Ensure the script is run with elevated privileges
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host $messages[$language]["run_as_admin"] -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
        Read-Host
        exit
    }

    # Enable WSL and Virtual Machine Platform
    if (-not $dryRun) {
        Write-Host $messages[$language]["enabling_wsl_subsystem"]
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
    }
    else {
        Write-Host "#LOG: WSL and Virtual Machine Platform would be enabled here."
    }

    # Setup registry to determine step and schedule a Batch File to run after restart via the Startup folder
    New-Item -Path "HKCU:\Software" -Name "WSL2Setup" -Force | Out-Null
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "Step" -Value 2

    # Setup registry so that we know that we've already setup the WSL2 subsystem
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "WSL2SupportEnabled" -Value 1

    # Move this script to the Startup folder, so that it will be run after reboot
    $user = Get-Username
    $scriptPath = $MyInvocation.MyCommand.Path
    $startupPath = [System.Environment]::GetFolderPath('Startup')
    try {
        # Contents of the CMD file : optionally pass -DryRun and -SkipWindowsVersionCheck flags to the script
        $flags = ""
        if ($dryRun) {
            $flags += " -DryRun"
        }
        if ($skipWindowsVersionCheck) {
            $flags += " -SkipWindowsVersionCheck"
        }

        # create the contents of a batchfile that echoes postreboot_batch_message_1, postreboot_batch_message_2 and postreboot_batch_message_3
        # this will be written into the CMD file that will be run after reboot
        $pdr = "*******************************************************************************************"
        $prm1 = $messages[$language]["postreboot_batch_message_1"]
        $prm2 = $messages[$language]["postreboot_batch_message_2"]
        $prm3 = $messages[$language]["postreboot_batch_message_3"]
        $cmdContents = "@echo off`r`n"
        $cmdContents += "echo $pdr`r`n"
        $cmdContents += "echo $prm1`r`n"
        $cmdContents += "echo $prm2`r`n"
        $cmdContents += "echo $prm3`r`n"
        $cmdContents += "echo $pdr`r`n"
        $cmdContents += ":: Pause the script until the user presses ENTER`r`n"
        $cmdContents += "pause > nul`r`n"
        $cmdContents += ":: Run the script with `"Run as Admin`" privileges`r`n"
        $cmdContents += "start powershell.exe -ExecutionPolicy Bypass -Command `"Start-Process -Verb RunAs powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \`"$scriptPath\`" $flags'`"`r`n"
        $cmdContents += ":: Exit the script`r`n"
        $cmdContents += "exit`r`n"

        # Create the CMD file
        $cmdFile = "$startupPath\PostRebootWSL2Setup.cmd"
        Set-Content -Path $cmdFile -Value $cmdContents -Force

        # Check that the script exists in the Startup folder
        if (-not (Test-Path "$startupPath\PostRebootWSL2Setup.cmd")) {
            throw $messages[$language]["cant_move_script"]
        }

        # Check that the script has content (non-zero length)
        $fileInfo = Get-Item "$startupPath\PostRebootWSL2Setup.cmd"
        if ($fileInfo.Length -eq 0) {
            throw $messages[$language]["cant_move_script"]
        }
    } catch {
        Write-Host $messages[$language]["exception"] $_.Exception.Message -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"]
        Read-Host
        exit
    }
    
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "CurrentUser" -Value $user
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "ScriptPath" -Value $scriptPath
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "BatchPath" -Value "$startupPath\PostRebootWSL2Setup.cmd"
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "DryRun" -Value $dryRun -Type DWord
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "SkipWindowsVersionCheck" -Value $skipWindowsVersionCheck -Type DWord

    # Restart the computer now
    Write-Host $messages[$language]["restart_needed"] -ForegroundColor Cyan
    Read-Host
    Restart-Computer -Force
    exit
}

# if the step is exactly 2, and the user who originally started the script is the same as the current user, we need to run the post-reboot phase
if ($wslSetupStep -eq 2 -and $wslSetupUser -eq (Get-Username)) {
    # Update Registry value InstallStartedAt
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "InstallStartedAt" -Value (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    # Check for "Windows Subsystem for Linux Update" installation
    $wslUpdateInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*Windows Subsystem for Linux Update*" }

    if (-not $wslUpdateInstalled) {
        # Download the Linux Kernel Update
        Write-Host $messages[$language]["kernel_update_needed"]
        $url = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
        $output = "$env:TEMP\wsl_update_x64.msi"

        # Call the Remote-Download function (automatically checks for errors, and exits if any)
        Remote-Download -Url $url -Output $output

        # Install the downloaded MSI in silent mode
        if (-not $dryRun) {
            Start-Process -Wait -FilePath "msiexec.exe" -ArgumentList "/i $output /qn"
        }
        else {
            Write-Host "#LOG: msiexec.exe /i $output /qn"
        }

        # Remove the downloaded MSI
        Remove-Item -Path $output -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host $messages[$language]["kernel_update_already_installed"]
    }

    # Get some registry values needed for the post-reboot phase
    $wslScriptPath = Get-RegistryKey -Key "ScriptPath"
    $wslBatchPath = Get-RegistryKey -Key "BatchPath"
    $dryRun = Get-RegistryKey -Key "DryRun"

    # Remove $wslBatchPath from the Startup folder, so that it won't be run again after reboot
    Remove-Item -Path $wslBatchPath -Force -ErrorAction SilentlyContinue

    # Post-reboot tasks. Update WSL, set default WSL version to 2, and install $targetDistro
    Write-Host $messages[$language]["wsl_initing"]
    Write-Host $messages[$language]["wsl_init_wait_for_enter"] -ForegroundColor Cyan
    Read-Host
    if (-not $dryRun) {
        wsl --update --web-download
        wsl --set-default-version 2
    }
    else {
        Write-Host "#LOG: WSL would be updated here."
    }

    # Verify WSL Version (Localization-agnostic)
    $wslVersion = (wsl --version | Select-Object -Index 0).Split(':')[1] -replace '[^0-9\.]', ''
    $kernelVersion = (wsl --version | Select-Object -Index 2).Split(':')[1] -replace '[^0-9\.]', ''

    if (-not $wslVersion) {
        Write-Host $messages[$language]["wsl_version_not_found"] -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
        Remove-Item -Path $wslScriptPath -Force -ErrorAction SilentlyContinue
        Read-Host
        exit
    }

    if ([Version]$wslVersion -lt [Version]"0.67.6") {
        Write-Host $messages[$language]["wsl_version_below_required"] -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
        Remove-Item -Path $wslScriptPath -Force -ErrorAction SilentlyContinue
        Read-Host
        exit
    }

    # Check if $targetDistro is already installed: if so, exit
    # this is a failsafe, because the script *may* have been called in "Force" mode on step 1, and we don't want
    # to install the distribution again if it's already installed
    if (-not $dryRun) {
        $alreadyInstalled = Check-Distro -Distro $targetDistro
        if ($alreadyInstalled) {
            Write-Host $messages[$language]["distro_already_installed"] -ForegroundColor White -BackgroundColor Red
            Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
            Read-Host
            exit
        }
    }

    # Check that $targetDistro is available in the list of installable distributions
    $distroIsAvailable = Check-Distro -Distro $targetDistro -Online $true
    if (-not $distroIsAvailable) {
        Write-Host $messages[$language]["target_distro_not_found"] -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
        Remove-Item -Path $wslScriptPath -Force -ErrorAction SilentlyContinue
        Read-Host
        exit
    }

    # Install $targetDistro and set it as the default distribution
    Write-Host "WSL version: $wslVersion - Kernel version: $kernelVersion. Installing $targetDistro..."
    Write-Host $messages[$language]["presetup_1"] -ForegroundColor Cyan
    Write-Host $messages[$language]["presetup_2"] -ForegroundColor White -BackgroundColor Green
    if (-not $dryRun) {
        wsl --install -d $targetDistro
        wsl --set-default $targetDistro
    }
    else {
        Write-Host "#LOG: $targetDistro would be installed here."
    }

    # Cleanup
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "Step" -Value 3
    Set-ItemProperty -Path "HKCU:\Software\WSL2Setup" -Name "InstallCompletedAt" -Value (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Remove-Item -Path $wslScriptPath -Force -ErrorAction SilentlyContinue

    # setup the variable containing the linuxHomeFolder
    $linuxHomeFolder = (wsl -d $targetDistro --exec bash -c "cd ~ ; pwd ; exit").Trim()

    # Collect the actual Linux username the user has specified during the $targetDistro installation
    $linuxUsername = (wsl -d $targetDistro --exec bash -c "sudo tail -1 /etc/passwd | cut -d: -f1 | tr -d '\n'").Trim()
    $linuxWhoami = (wsl -d $targetDistro --exec bash -c "cd ~ ; whoami ; exit").Trim()

    # Check that the Linux username is the same as Linux whoami
    if ($linuxUsername -ne $linuxWhoami) {
        Write-Host "Linux username: $linuxUsername - Linux whoami: $linuxWhoami" -ForegroundColor White -BackgroundColor Red
        Write-Host "CRITICAL: it seems that there is a problem with the Linux username. Cannot continue execution." -ForegroundColor White -BackgroundColor Red
        Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
        Read-Host
        exit
    }

    # Modify the $targetDistro wsl.conf so that we disable resolv.conf and enable native systemd support
    if (-not $dryRun) {
        Write-Host $messages[$language]["config_1"] -ForegroundColor Cyan
        wsl -d $targetDistro --exec bash -c "sudo rm -f /etc/wsl.conf && echo -e '[boot]\nsystemd = true\n\n[network]\ngenerateResolvConf = false' | sudo tee /etc/wsl.conf > /dev/null"
        wsl -d $targetDistro --exec bash -c "sudo rm -f /etc/resolv.conf && echo -e 'nameserver 9.9.9.9\nnameserver 1.1.1.1\nnameserver 216.87.84.211\nnameserver 208.67.222.222' | sudo tee /etc/resolv.conf > /dev/null && sudo chattr +i /etc/resolv.conf"
        wsl --terminate $targetDistro

        # re-start the $targetDistro distribution
        wsl -d $targetDistro --exec bash -c "cd ~ ; exit"
    }
    else {
        Write-Host "#LOG: $targetDistro wsl.conf and resolv.conf would be modified here."
    }

    # Ask the user if he/she wants to install the full-fledged optimized LAMP+LAPP stack
    if (-not $dryRun) {
        $installLampStack = (Ask-Question -Question $messages[$language]["ask_for_lamp"])
        if ($installLampStack) {
            # Politely warn the user that the installation will take a while
            Write-Host $messages[$language]["lamp_install_warning"] -ForegroundColor White -BackgroundColor Green
            Read-Host # wait for the user to press ENTER
            Write-Host $messages[$language]["config_2"] -ForegroundColor Cyan

            # Run the automated LAMP+LAPP installer command
            wsl -d $targetDistro --exec bash -c "cd $linuxHomeFolder ; wget -qO- https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-setup/main/install/lamp-lapp-stack.sh | bash"
        }
        else {
            Write-Host $messages[$language]["lamp_installation_skipped"] -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "#LOG: The automated LAMP+LAPP installer command would be run here."
    }

    # Ask the user if he/she wants to install Docker
    if (-not $dryRun) {
        $installDocker = (Ask-Question -Question $messages[$language]["ask_for_docker"])
        if ($installDocker) {
            # Check if Docker has already been installed, via reading the Registry
            $dockerInstalled = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Get-ItemProperty | Where-Object { $_.DisplayName -like "*Docker Desktop*" }

            if (-not $dockerInstalled) {
                # Politely warn the user that the installation will take a while
                Write-Host $messages[$language]["docker_install_warning"] -ForegroundColor White -BackgroundColor Green
                Read-Host # wait for the user to press ENTER

                # Download the Docker Desktop Installer
                $url = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
                $dockerInstallerPath = "$env:TEMP\docker_desktop_installer.exe"

                # Call the Remote-Download function (automatically checks for errors, and exits if any)
                Remote-Download -Url $url -Output $dockerInstallerPath

                # Install the downloaded Docker Desktop Installer
                Start-Process -Wait -FilePath $dockerInstallerPath -ArgumentList 'install', '--accept-license', '--quiet'

                # Remove the downloaded Docker Desktop Installer
                Remove-Item -Path $dockerInstallerPath -Force -ErrorAction SilentlyContinue

                # Inform the user that the installation has been completed
                Write-Host $messages[$language]["docker_postinstall_message"] -ForegroundColor White -BackgroundColor Green
                Read-Host # wait for the user to press ENTER
            }
            else {
                Write-Host $messages[$language]["docker_already_installed"] -ForegroundColor White -BackgroundColor Green
            }
        }
    }
    else {
        Write-Host "#LOG: Docker Desktop would be installed here."
    }

    # Create fancy-looking Desktop Icons
    if (-not $dryRun) {
        # Create the "$env:USERPROFILE\Pictures\UbuntuIcons\" folder
        $iconsFolder = "$env:USERPROFILE\Pictures\UbuntuIcons"
        if (-not (Test-Path $iconsFolder)) {
            New-Item -Path $iconsFolder -ItemType Directory -Force | Out-Null
        }

        # Set up Icons
        Write-Host $messages[$language]["config_3"] -ForegroundColor Cyan

        # Download the "ubuntu-drive-icon.ico"
        $iconUrl = "https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-setup/main/icons/ubuntu-drive-icon.ico"
        $distroDriveIcon = "$iconsFolder\ubuntu-drive-icon.ico"
        Remote-Download -Url $iconUrl -Output $distroDriveIcon

        # Download the "ubuntu-icon.ico"
        $iconUrl = "https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-setup/main/icons/ubuntu-icon.ico"
        $distroIcon = "$iconsFolder\ubuntu-icon.ico"
        Remote-Download -Url $iconUrl -Output $distroIcon

        # Create the Desktop Icon for the Ubuntu-24.04 terminal
        $wslPath = "$env:windir\System32\wsl.exe"
        $wslArgs = "-d $targetDistro --exec bash -c `"cd $linuxHomeFolder && bash`""
        Create-Desktop-Shortcut -ShortcutLinkName $targetDistro -TargetPath $wslPath -Arguments $wslArgs -IconLocation $distroIcon -Description $targetDistro

        # Create the Desktop Icon for the Ubuntu-24.04 home folder
        $wslPath = "\\wsl$\$targetDistro\home\$linuxUsername"
        Create-Desktop-Shortcut -ShortcutLinkName "$targetDistro Home" -TargetPath $wslPath -IconLocation $distroDriveIcon -Description "$targetDistro Home"

        # Completed!
        Write-Host $messages[$language]["setup_completed"] -ForegroundColor White -BackgroundColor Green
    }
    else {
        Write-Host "#LOG: Desktop Icons would be created here."

        # Completed!
        Write-Host "#LOG: Dry Run Setup completed! Press Enter to exit." -ForegroundColor White -BackgroundColor Green
    }
    
    Read-Host
    exit
}

# in any other case, we should not be here
Write-Host $messages[$language]["distro_already_installed"] -ForegroundColor White -BackgroundColor Red
Write-Host $messages[$language]["exit"] -ForegroundColor Cyan
Read-Host
exit