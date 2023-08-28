# Manual LAMP Stack Setup on Windows 11 with WSL2, Native Web Services, VS Code, and Ubuntu 22.04 (without Microsoft Store)

> Version Last update: _23/08/2023_. Target Ubuntu version: 22.04.03

This guide will illustrate how to install support for the native Linux subsystem of Windows (WSL2), install Ubuntu 22.04 (without having to use the Microsoft Store), create a multi-PHP **LAMP** stack (with native services through _systemd_), and connect Visual Studio Code from Windows 11, to develop and debug directly on the virtual machine.

## System Requirements

1. Computer with **Windows 11**, preferably updated through Windows Update
2. 16GB of RAM
3. At least 50GB of free space on C:\\ (it will contain the Ubuntu 22.04 virtual disk)
4. An SSD (better if NVMe) as the main Windows disk
5. A _medium-level_ knowledge of the Linux terminal (such as how to use and what basic commands like _cd_, _cp_, _mv_, _sudo_, _nano_, etc. are)
6. Your computer **should be password protected, use BitLocker, and have support for TPM 2.0** to prevent malicious access to sensitive information, if someone were to gain possession of your device. **This is particularly important if you intend to handle information on behalf of others (work)**. Your security policies on the network and the devices you use should be appropriate for the type of PC use you intend to carry out. Generally, _if you use your PC for work, you need to pay utmost attention to protection_. Prevention is better than cure.

The **LAMP** stack we're going to configure supports **https** (with self-signed certificates expiring in 30 years), **http/2** protocol, and **brotli compression**. As for the PHP part, we'll use **PHP-FPM** because it's more performant and more versatile in configuring _per-virtualhost_ settings. To understand the differences between using PHP with Apache in PHP-CGI mode versus PHP-FPM, refer to this guide: <https://www.basezap.com/difference-php-cgi-php-fpm/>

## Installing Ubuntu 22.04 LTS on Windows in WSL2 Virtualization

To install Ubuntu 22.04 on Windows 11, we'll only use Windows' _PowerShell_, without resorting to the _Microsoft Store_. Important: **ensure to start PowerShell in administrator mode**.

First, **download and install** <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>. This is important. It's an additional package that installs the _Linux Kernel Update_, necessary for compatibility with WSL2.

Then, run these commands on a _PowerShell_ **elevated to administrator privileges**:

```cmd
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Restart-Computer -Force
```

Wait for the PC to reboot, then run these commands on a _PowerShell_ **elevated to administrator privileges**:

```cmd
wsl --update --web-download
wsl --set-default-version 2
wsl --version
wsl --list --online
```

The command `wsl --version` will return information about the version of the _Windows Linux subsystem_. Here's an example of the output updated to August 2023:

```txt
Versione WSL: 1.2.5.0
Versione kernel: 5.15.90.1
Versione WSLg: 1.0.51
Versione MSRDC: 1.2.3770
Versione Direct3D: 1.608.2-61064218
Versione DXCore: 10.0.25131.1002-220531-1700.rs-onecore-base2-hyp
Versione di Windows: 10.0.22621.2134
```

We need to ensure that **the WSL version is greater or equal to 0.67.6**. In the above example, everything is OK.

The command `wsl --list --online` will return the installable distributions. Here's an example of the output updated to August 2023:

```txt
NAME                                   FRIENDLY NAME
Ubuntu                                 Ubuntu
Debian                                 Debian GNU/Linux
kali-linux                             Kali Linux Rolling
Ubuntu-18.04                           Ubuntu 18.04 LTS
Ubuntu-20.04                           Ubuntu 20.04 LTS
Ubuntu-22.04                           Ubuntu 22.04 LTS
OracleLinux_7_9                        Oracle Linux 7.9
OracleLinux_8_7                        Oracle Linux 8.7
OracleLinux_9_1                        Oracle Linux 9.1
openSUSE-Leap-15.5                     openSUSE Leap 15.5
SUSE-Linux-Enterprise-Server-15-SP4    SUSE Linux Enterprise Server 15 SP4
SUSE-Linux-Enterprise-15-SP5           SUSE Linux Enterprise 15 SP5
openSUSE-Tumbleweed                    openSUSE Tumbleweed
```

We are interested in the **Ubuntu-22.04** distribution. So, run this command on a _PowerShell_ **elevated to administrator privileges**:

```cmd
wsl --install -d Ubuntu-22.04
```

At the end of the installation, without any errors, the newly installed Ubuntu machine instance will automatically open. The Ubuntu system will ask you to set a **username** _(be careful, it's needed below and is important)_ -- I recommend using a single short word all in lowercase -- and to **specify a password** for this user -- I recommend using a single letter, for convenience when running commands as `sudoer` --

## Modify Ubuntu DNS Resolver

To permanently resolve the issue of DNS domain name resolution on Ubuntu via WSL2, follow these instructions. The procedure will require the use of both Ubuntu's bash and a _PowerShell_ **elevated to administrator privileges**:

**On Ubuntu 22.04**

```bash
sudo su -
echo "[network]" | tee /etc/wsl.conf
echo "generateResolvConf = false" | tee -a /etc/wsl.conf
```

**On Windows, Powershell**

```cmd
wsl --terminate Ubuntu-22.04
```

**On Ubuntu 22.04** (you'll need to restart it, as the previous command will have terminated it)

```bash
sudo su -
rm -f /etc/resolv.conf
echo "nameserver 9.9.9.9" | tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | tee -a /etc/resolv.conf
echo "nameserver 216.87.84.211" | tee -a /etc/resolv.conf
echo "nameserver 208.67.222.222" | tee -a /etc/resolv.conf
chattr +i /etc/resolv.conf
```

**On Windows, Powershell**

```cmd
wsl --terminate Ubuntu-22.04
Get-NetAdapter
```

Now, read the output of the `Get-NetAdapter` command. This command will list all the network interfaces on the PC. **We are interested in the interfaces that connect to the internet**.

Here's an example of the output:

```txt
Name                      InterfaceDescription                    ifIndex Status       MacAddress             LinkSpeed
----                      --------------------                    ------- ------       ----------             ---------
Wi-Fi                     Intel(R) Wi-Fi 6E AX210 160MHz               15 Up           4C-77-CB-79-06-03       1.7 Gbps
Connessione di rete Bl... Bluetooth Device (Personal Area Netw...      12 Disconnected 4C-77-CB-79-06-07         3 Mbps
Ethernet                  Intel(R) Ethernet Connection (14) I2...       9 Disconnected A0-29-19-0B-74-1E          0 bps
```

In the above example, the interface used to connect to the internet is **Intel(R) Wi-Fi 6E AX210 160MHz**, whose **ifIndex** is **15**.

So, note down the correct `ifIndex`, and run in _PowerShell_ **elevated to administrator privileges**:

```cmd
Set-NetIPInterface -InterfaceIndex [NUMERO_IFINDEX] -InterfaceMetric 6000
```

With these instructions, the Ubuntu 22.04 machine should have no domain name resolution issues.

## Enable systemd on WSL2

> Systemd is a suite of basic building blocks for a Linux system. It provides a system and service manager that runs as PID 1 and initializes the rest of the system. Many popular distributions run systemd by default, such as Ubuntu and Debian. This change means that WSL will be even more similar to using your favorite Linux distributions on a bare metal machine, and will allow you to use software that depends on systemd support.

Enabling _systemd_ is relatively simple. Just run this command on Ubuntu:

```bash
sudo su -
echo "[boot]" | tee -a /etc/wsl.conf
echo "systemd = true" | tee -a /etc/wsl.conf
```

**On Windows, Powershell**

```cmd
wsl --shutdown
```

Then, restart the Ubuntu machine.

## Step 1 - Configure the LAMP Environment on Ubuntu

Here, we will install all the system services and executables to enable support for **PHP** versions 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1 and 8.2. We will also enable the **Apache web server** and the **MySQL server**.

**Why install so many PHP versions**? It's essential for two reasons:

1. Having a **development environment** that easily allows **testing your application with various PHP versions**. This will facilitate the work in case of specific constraints on the production servers where the created applications will be installed.
2. If a Client or a specific project requires you to **maintain and/or modify an old codebase that runs on a specific PHP version**, you won't have trouble setting up the local dev & test environment.

> It is assumed that the default PHP version to be used in the system is **8.2**. This can be changed using the lines `update-alternatives --set php***` that will be found in the list below. For example, if you want the default PHP version (the one used when simply typing the command `php`, not its "versioned" command like `php7.4`), just specify `update-alternatives --set php /usr/bin/php7.4`. _(Anyway, this behavior will be modified with the Bash Aliases that we will configure later)_

**IMPORTANT**: Run all these commands as the `root` user on Ubuntu (use the command `sudo su -`). **IMPORTANT**: Exclude the lines starting with **#** as they only serve to differentiate the various blocks.

```console
# APACHE + Multi-PHP-FPM + Redis
sudo su -
apt update && apt upgrade
apt install -y net-tools zip unzip git redis-server lsb-release ca-certificates apt-transport-https software-properties-common
LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/apache2
apt update && apt upgrade
PHPVERS="8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6"
PHPMODS="cli fpm common bcmath bz2 curl gd intl mbstring mcrypt mysql opcache sqlite3 redis xml zip"
APTPACKS=$(for VER in $PHPVERS; do echo -n "libapache2-mod-php$VER php$VER "; for MOD in $PHPMODS; do echo -n "php$VER-$MOD "; done; done)
apt install -y apache2 brotli openssl libapache2-mod-fcgid $APTPACKS
a2dismod $(for VER in $PHPVERS; do echo -n "php$VER "; done) mpm_prefork
a2enconf $(for VER in $PHPVERS; do echo -n "php$VER-fpm "; done)
a2enmod actions fcgid alias proxy_fcgi setenvif rewrite headers ssl http2 mpm_event brotli
a2dissite 000-default
systemctl enable apache2.service
systemctl restart apache2.service
systemctl enable redis-server.service
systemctl start redis-server.service
update-alternatives --set php /usr/bin/php8.2
update-alternatives --set phar /usr/bin/phar8.2
update-alternatives --set phar.phar /usr/bin/phar.phar8.2

# MYSQL
sudo su -
apt install mariadb-server
systemctl enable mariadb.service
systemctl start mariadb.service
mysql_secure_installation
[type in this sequence of answers: ENTER + n + Y + "YOUR-ROOT-PASS" + "YOUR-ROOT-PASS" + Y + Y + Y + Y]
mysql -u root -p
type in "YOUR-ROOT-PASS" (the one you choose above)
> GRANT ALL ON *.* TO 'admin'@'localhost' IDENTIFIED BY 'YOUR-ADMIN-PASS' WITH GRANT OPTION;
> GRANT ALL ON *.* TO 'admin'@'127.0.0.1' IDENTIFIED BY 'YOUR-ADMIN-PASS' WITH GRANT OPTION;
> FLUSH PRIVILEGES;
> exit
```

Once these commands are executed, all the necessary services and executables will be installed to create a LAMP (Linux, Apache, MySQL, PHP) stack in multi-PHP mode (multiple PHP versions) with PHP-FPM to enhance performance.

> Note: The MySQL queries related to the **username and password** (_admin_ and _YOUR-ADMIN-PASS_) to be created as a privileged user can be changed at will. In the example above, a user with the username `admin` and password `YOUR-ADMIN-PASS` is created. It should be noted that **we are configuring a local development environment**, and as long as this environment is not exposed on the internet, we don't have to worry about particular policies regarding usernames and password complexity. However, I want to emphasize that using "easily guessable" usernames and "well-known" passwords is a **bad practice**.

## Step 2 - Configure the LAMP Environment on Ubuntu

Here we will modify the basic configurations of **Apache** and **MySQL** to be able to work locally.

The name of the file to be modified is reported, along with the modified and commented content. Any changes to these files must be executed with `sudo nano FILE_NAME`. Familiarity with the `nano` tool is required. Alternatively, use the text editor you find most comfortable.

### A. Modify Apache's envvars

File name: **/etc/apache2/envvars**

> Summary: Modify **APACHE\_RUN\_USER** and **APACHE\_RUN\_GROUP**, setting them, instead of `www-data`, to your own **username** (where it says `YOUR_USERNAME`)

Content:

```txt
# envvars - default environment variables for apache2ctl

# this won't be correct after changing uid
unset HOME

# for supporting multiple apache2 instances
if [ "${APACHE_CONFDIR##/etc/apache2-}" != "${APACHE_CONFDIR}" ] ; then
    SUFFIX="-${APACHE_CONFDIR##/etc/apache2-}"
else
    SUFFIX=
fi

# Since there is no sane way to get the parsed apache2 config in scripts, some
# settings are defined via environment variables and then used in apache2ctl,
# /etc/init.d/apache2, /etc/logrotate.d/apache2, etc.
export APACHE_RUN_USER=YOUR_USERNAME
export APACHE_RUN_GROUP=YOUR_USERNAME
```

### B. Modify Apache's Ports

File name: **/etc/apache2/ports.conf**

> Summary: Modify **every occurrence** of `Listen` with `Listen 127.0.0.1` (loopback IP address + port: 127.0.0.1:80 127.0.0.1:443)

Content:

```txt
# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default.conf

Listen 127.0.0.1:80

<IfModule ssl_module>
    Listen 127.0.0.1:443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 127.0.0.1:443
</IfModule>
```

### C. Modify MySQL Configuration

File name: **/etc/mysql/mariadb.conf.d/99-custom.cnf**

> Summary: Adapt the MySQL configuration to use native authentication, an adequate default collation, and a query execution mode "that does not cause compatibility problems" (reference: [https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html#sqlmode\_no\_engine\_substitution](https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html#sqlmode_no_engine_substitution)). Also, we will set some specific configurations to increase read/write performance (note: an adequate amount of RAM must be available)

Content:

```txt
[mysqld]

bind-address = 127.0.0.1
skip-external-locking
skip-name-resolve
max-allowed-packet = 256M
max-connect-errors = 1000000
default-authentication-plugin=mysql_native_password
sql_mode=NO_ENGINE_SUBSTITUTION
collation-server = utf8_unicode_ci
character-set-server = utf8

# === InnoDB Settings ===
default_storage_engine          = InnoDB
innodb_buffer_pool_instances    = 4
innodb_buffer_pool_size         = 4G
innodb_file_per_table           = 1
innodb_flush_log_at_trx_commit  = 0
innodb_flush_method             = O_DIRECT
innodb_log_buffer_size          = 16M
innodb_log_file_size            = 1G
innodb_sort_buffer_size         = 4M
innodb_stats_on_metadata        = 0
innodb_read_io_threads          = 64
innodb_write_io_threads         = 64

# === MyISAM Settings ===
query_cache_limit               = 4M
query_cache_size                = 64M
query_cache_type                = 1
key_buffer_size                 = 24M
low_priority_updates            = 1
concurrent_insert               = 2

# === Connection Settings ===
max_connections                 = 20
back_log                        = 512
thread_cache_size               = 100
thread_stack                    = 192K
interactive_timeout             = 180
wait_timeout                    = 180

# === Buffer Settings ===
join_buffer_size                = 4M
read_buffer_size                = 3M
read_rnd_buffer_size            = 4M
sort_buffer_size                = 4M

# === Table Settings ===
table_definition_cache          = 40000
table_open_cache                = 40000
open_files_limit                = 60000
max_heap_table_size             = 128M 
tmp_table_size                  = 128M

# === Binary Logging ===
disable_log_bin                 = 1

[mysqldump]
quick
quote_names
max_allowed_packet              = 1024M
```

### D. Restart the Services

Once the modifications to the configurations of _Apache_ and _MariaDB_ have been completed, we can restart the services

consoleCopy code

`sudo su - systemctl restart apache2.service systemctl restart mariadb.service`

## Step 3 - Create Working VirtualHosts on Your Local Installation

To create `VirtualHosts`, it is enough to use these two scripts that speed up the configuration.

For illustrative purposes only, the entire procedure for creating a working _VirtualHost_ will be shown, which will expose the _PhpMyAdmin_ application on the local machine. This installation can be helpful if you decide to continue using it to navigate between the _MySQL Databases_ present on the system, and the data contained within them.

Prerequisites:

1. Download the file [create-test-environment.php](/scripts/create-test-environment.php)
2. Download the file [delete-test-environment.php](/scripts/delete-test-environment.php)
3. Download the file [list-test-environments.php](/scripts/list-test-environments.php)
4. Download the file [create-selfsigned-ssl-cert.sh](/scripts/create-selfsigned-ssl-cert.sh)

**Important:** After downloading the files, modify `create-test-environment.php` by replacing the string `##LINUX_USERNAME##` with your username on Ubuntu.

**Important:** At this point, if you are still logged in as the `root` user, exit from the `root` user and return to user mode.

```console
sudo mkdir /etc/apache2/certs-selfsigned/
cd ~/
mkdir utils && cd utils/ && mkdir .composer
nano create-test-environment.php ## COPY-PASTE THE RELATIVE FILE'S CONTENT
nano delete-test-environment.php ## COPY-PASTE THE RELATIVE FILE'S CONTENT
nano list-test-environments.php ## COPY-PASTE THE RELATIVE FILE'S CONTENT
nano create-selfsigned-ssl-cert.sh ## COPY-PASTE THE RELATIVE FILE'S CONTENT
chmod +x create-selfsigned-ssl-cert.sh
cd ~/
mkdir opt && cd opt/
wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip phpMyAdmin-5.2.1-all-languages.zip && rm -f phpMyAdmin-5.2.1-all-languages.zip && mv phpMyAdmin-5.2.1-all-languages phpmyadmin
```

Now we have created the root directory for the _PhpMyAdmin_ installation. All that remains is to configure a working VirtualHost.

So run the command `sudo php ~/utils/create-test-environment.php` and follow the instructions. These instructions apply **to all web projects** that you want to install on the system.

In the example, the virtual host for _PhpMyAdmin_ will be set as `local.phpmyadmin.test`. Obviously, modify the answers following your username. Answer the script's questions as follows:

```console
maurizio@FISSO:~$ cd ~/utils/
maurizio@FISSO:~/utils$ sudo php create-test-environment.php
### TEST ENVIRONMENT CREATOR ###
Enter a valid local Domain Name (suggested .test TLD, as "jane.local.test")
  Type the Domain Name: local.phpmyadmin.test
Enter a valid directory in the filesystem for the DocumentRoot
  Type the DocumentRoot: /home/maurizio/opt/phpmyadmin/
Enter a valid PHP version for PHP-FPM (5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1 or 8.2)
  Type the PHP version: 8.2
Do you need HTTPS support?
  Type "yes", "no", "y" or "n": y
```

Now, you need to modify **the Windows hosts file** to insert the local pointer to the domain `local.phpmyadmin.test`.

To do this, on Windows 11, you will need _PowerToys_. For installation, refer to [the official Microsoft guide](https://learn.microsoft.com/it-it/windows/powertoys/install).

Once the _Microsoft PowerToys_ package is installed, use the **Host File Editor** functionality > **Start the host file editor**. You will need to add the mapping between the _address_ `local.phpmyadmin.test` and the _host_ `127.0.0.1`.

Afterward, **open a privileged Windows command line** and run `ipconfig /flushdns`.

Done! You can now navigate on your browser to <https://local.phpmyadmin.test/setup/> to continue the PhpMyAdmin setup.

To create other VirtualHosts for other projects, **always use the same instructions followed for the PhpMyAdmin setup**. You just need to point the VirtualHost to the correct directory of your project and define a fictitious domain name that will be redirected via _host file_ to `127.0.0.1`.

## Step 4 - Optimize the Linux Experience

To optimize the LAMP installation and the user experience on the Linux command console, follow these steps:

1. Follow the installation instructions for `https://github.com/slomkowski/bash-full-of-colors` (or install _ZSH_, or any other shell of your liking: I'm comfortable with this super minimal colored bash, my personal opinion is that having as little help as possible on bash is a great way not to disconnect from it). Here's a one-liner to install _Bash full of colors_ `cd ~/ ; git clone https://github.com/slomkowski/bash-full-of-colors.git .bash-full-of-colors ; [ -f .bashrc ] && mv -v .bashrc bashrc.old ; [ -f .bash_profile ] && mv -v .bash_profile bash_profile.old ; [ -f .bash_aliases ] && mv -v .bash_aliases bash_aliases.old ; [ -f .bash_logout ] && mv -v .bash_logout bash_logout.old ; ln -s .bash-full-of-colors/bashrc.sh .bashrc ; ln -s .bash-full-of-colors/bash_profile.sh .bash_profile ; ln -s .bash-full-of-colors/bash_aliases.sh .bash_aliases ; ln -s .bash-full-of-colors/bash_logout.sh .bash_logout ; rm -f bash_logout.old ; rm -f bashrc.old ; rm -f bash_aliases.old`
2. Run `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash` to install NVM (for NodeJS/React development)
3. Run `cd ~/utils/.composer/ && wget -O composer.phar https://getcomposer.org/download/latest-stable/composer.phar` to install a local version of Composer v2 within the directory `/utils/.composer/` (the _Composer_ executable will **not** be available globally in the Ubuntu instance: we will create _Aliases_ to make it work)
4. Run `cd ~/utils/.composer/ && wget -O composer-oldstable.phar https://getcomposer.org/download/latest-1.x/composer.phar` to install a local version of Composer v1 within the directory `/utils/.composer/` (the _Composer_ executable will **not** be available globally in the Ubuntu instance: we will create _Aliases_ to make it work). **NOTE**: this deprecated Composer version is useful to make **old projects** work that don't run on modern PHP versions.
5. Create a public/private key pair with the command `ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/key_name -C "user@computer"`
6. Share the public key content with your team, who will use it, for example, to enable access to a private GIT repository.
7. Copy-paste the content of the snippet [.bash\_local](/confs/bash_local) into `~/.bash_local` modifying the `$USERNAME` variable with the chosen user name
8. Create a link to the **Ubuntu home directory** accessible from your _Desktop_ to view Ubuntu's home via Windows File Explorer: to do this, right-click on the _Desktop_, select `New` > `Shortcut`, and enter in the **shortcut path** the string `\\wsl$\Ubuntu-22.04\home\USERNAME`, where **USERNAME** is the username used on Ubuntu. **Optional**: change the shortcut's icon. I recommend this one: [ubuntu-drive-icon.ico](/icons/ubuntu-drive-icon.ico)
9. Create a link to _Ubuntu's Bash_ accessible from your _Desktop_ to launch a new terminal: to do this, right-click on the _Desktop_, select `New` > `Shortcut`, and enter in the **shortcut path** the string `C:\Windows\System32\wsl.exe -d Ubuntu-22.04 bash -c "cd ~ && bash"`. **Optional**: change the shortcut's icon. I recommend this one: [ubuntu-icon.ico](/icons/ubuntu-icon.ico)

### Important Notes on Aliases Enabled via .bash\_local

> The aliases previously configured by creating the `.bash_local` file contain some useful shortcuts, easy to memorize. It is recommended to read this file and remember that it is always possible to modify it to your liking.

1. You can reset the Ubuntu virtual machine with the command `wslrestart`
2. No need to specify particular options for the `ls` command, as it has already been aliased with the most suitable options to get all the verbose details of the directory
3. The `composer` command (by default, version 2) has been declined in various _flavors_ corresponding to the target PHP versions installed on the system. In summary, the `composer` command will use **PHP 8.2**, `composer81` will use **PHP 8.1**, `composer80` will use **PHP 8.0**, and so on down to `composer72` that will use **PHP 7.2**. If you wish to use the **old and deprecated Composer 1** for developing on really old projects, just use `1composer72`, or `1composer71`, or `1composer70`, or `1composer56`: these aliases will use the PHP versions accordingly.
4. Similarly to what is reported above, the PHP _CLI_ is also subject to Aliasing, as we have installed several versions of PHP during the setup. So, if you want to use a PHP CLI of a specific version, just type `php` for version **8.2**, `php81` for version **8.1**, `php80` for version **8.0**, and so on down to `php56` for version **5.6**.
5. It is possible to keep the _Composer_ _binaries_ updated with the alias `updatecomposer`.
6. You can **create test/staging environments** with the alias `create-test-env`. The alias will take care of calling the script `~/utils/create-test-environment.php`.
7. You can **REMOVE previously created test/staging environments** with the alias `remove-test-env`. The alias will take care of calling the script `~/utils/delete-test-environment.php`.
8. You can **LIST** test/staging environments created with `create-test-env` with the alias `list-test-envs`. The alias will take care of calling the script `~/utils/list-test-environments.php`.

## Step 5 - Install VS Code to Access Project Files on WSL2

VS Code is fully integrated and compatible with WSL2, natively.

This increases productivity and greatly simplifies development.

To install and configure VS Code with WSL2, just:

1. Download VS Code from `https://code.visualstudio.com/`.
2. Open VS Code and press the command combination `CTRL + SHIFT + x`.
3. Install the **Remote - WSL** extension.
4. Restart VS Code.
5. Open an Ubuntu console and go to a directory of your choice, e.g., `~/utils/`.
6. Run the command `code .` and let the system install what it needs.
7. Voilà, **you can now edit files on Ubuntu directly from VS Code!**

## Step 6 - Optimize Web Development on VS Code with Recommended Extensions

Go to an Ubuntu console and run these commands:

1. `cd ~/utils/`
2. `mkdir .composer && cd .composer/`
3. `nano composer.json` and insert this content inside:

```json
{
    "require": {
        "squizlabs/php_codesniffer": "^3",
        "friendsofphp/php-cs-fixer": "^3"
    }
}
```

Then, run this command: `composer install`

From now on, we have the binaries of **php-cs-fixer** and **php codesniffer**, which will be needed for the VS Code configuration.

So, here are the steps to configure and optimize **VS Code** for PHP development:

1. Open VS Code, and go to a project residing inside Ubuntu to stay in "WSL2 mode."
2. Press `CTRL + SHIFT + x`, search for **php cs fixer** and install the plugin version of **junstyle** ([https://github.com/junstyle/vscode-php-cs-fixer.git](https://github.com/junstyle/vscode-php-cs-fixer.git)).
3. Install the following extensions: **GitLens** (Eric Amodio, [https://github.com/eamodio/vscode-gitlens](https://github.com/eamodio/vscode-gitlens)), **Git History** (Don Jayamanne, [https://github.com/DonJayamanne/gitHistoryVSCode](https://github.com/DonJayamanne/gitHistoryVSCode)), **PHP Intelephense** (Ben Mewburn, [https://github.com/bmewburn/vscode-intelephense](https://github.com/bmewburn/vscode-intelephense)), **Prettier - Code Formatter** (Prettier, [https://github.com/prettier/prettier-vscode](https://github.com/prettier/prettier-vscode)), **PHP DocBlocker** (Neil Brayfield, [https://github.com/neild3r/vscode-php-docblocker](https://github.com/neild3r/vscode-php-docblocker)), **Twig Language** (mblode, [https://github.com/mblode/vscode-twig-language](https://github.com/mblode/vscode-twig-language)), **markdownlint** (David Anson, [https://github.com/DavidAnson/vscode-markdownlint](https://github.com/DavidAnson/vscode-markdownlint)).
4. Install the following icon pack: **Material Icon Theme** (Philipp Kief, [https://github.com/PKief/vscode-material-icon-theme](https://github.com/PKief/vscode-material-icon-theme)).
5. Press the key combination `CTRL + SHIFT + p`, type **preferences**, and click on **Preferences: Open Settings (JSON)**.
6. Copy-paste the configuration reported in the snippet [vscode.json](/confs/vscode.json), modifying the variable `$USERNAME` with the username used on Ubuntu.
