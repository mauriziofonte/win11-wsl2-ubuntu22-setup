# Manual Docker / LAMP Stack Setup on Windows 11 with WSL2, Native Web Services, VS Code, and Ubuntu 24.04 (without Microsoft Store)

> Last updated at: _2024-10-25_. Target Ubuntu version: **24.04.1**

This guide will illustrate how to install support for the native Linux subsystem of Windows (WSL2), install Ubuntu 24.04 (without having to use the Microsoft Store), create a multi-PHP **LAMP** stack (with native services through _systemd_), install Docker, and connect Visual Studio Code from Windows 11, to develop and debug directly on the virtual machine.

## System Requirements

1. Computer with **Windows 11**, preferably updated through Windows Update
2. 16GB of RAM
3. At least 50GB of free space on C:\\ (it will contain the Ubuntu 24.04 virtual disk)
4. An SSD (better if NVMe) as the main Windows disk
5. A _medium-level_ knowledge of the Linux terminal (such as how to use and what basic commands like _cd_, _cp_, _mv_, _sudo_, _nano_, etc.)
6. Your computer **should be password protected, use BitLocker, and have support for TPM 2.0** to prevent malicious access to sensitive information, if someone were to gain possession of your device. **This is particularly important if you intend to handle information on behalf of others (work)**. Your security policies on the network and the devices you use should be appropriate for the type of PC use you intend to carry out. Generally, _if you use your PC for work, you need to pay utmost attention to protection_. Prevention is better than cure.

The **LAMP** stack we're going to configure supports **https** (with self-signed certificates expiring in 30 years), **http/2** protocol, and **brotli compression**. As for the PHP part, we'll use **PHP-FPM** because it's more performant and more versatile in configuring _per-virtualhost_ settings. To understand the differences between using PHP with Apache in PHP-CGI mode versus PHP-FPM, refer to this guide: <https://www.basezap.com/difference-php-cgi-php-fpm/>

## Installing Ubuntu 24.04 LTS on Windows in WSL2 Virtualization

To install Ubuntu 24.04 on Windows 11, we'll only use Windows' _PowerShell_, without resorting to the _Microsoft Store_. Important: **ensure to start PowerShell in administrator mode**.

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
Ubuntu-24.04                           Ubuntu 24.04 LTS
OracleLinux_7_9                        Oracle Linux 7.9
OracleLinux_8_7                        Oracle Linux 8.7
OracleLinux_9_1                        Oracle Linux 9.1
openSUSE-Leap-15.5                     openSUSE Leap 15.5
SUSE-Linux-Enterprise-Server-15-SP4    SUSE Linux Enterprise Server 15 SP4
SUSE-Linux-Enterprise-15-SP5           SUSE Linux Enterprise 15 SP5
openSUSE-Tumbleweed                    openSUSE Tumbleweed
```

We are interested in the **Ubuntu-24.04** distribution. So, run this command on a _PowerShell_ **elevated to administrator privileges**:

```cmd
wsl --install -d Ubuntu-24.04
```

At the end of the installation, without any errors, the newly installed Ubuntu machine instance will automatically open. The Ubuntu system will ask you to set a **username** _(be careful, it's needed below and is important)_ -- I recommend using a single short word all in lowercase -- and to **specify a password** for this user -- I recommend using a single letter, for convenience when running commands as `sudoer` --

## Modify Ubuntu DNS Resolver

To permanently resolve the issue of DNS domain name resolution on Ubuntu via WSL2, follow these instructions. The procedure will require the use of both Ubuntu's bash and a _PowerShell_ **elevated to administrator privileges**:

**On Ubuntu 24.04**

```bash
sudo su -
echo "[network]" | tee /etc/wsl.conf
echo "generateResolvConf = false" | tee -a /etc/wsl.conf
```

**On Windows, Powershell**

```cmd
wsl --terminate Ubuntu-24.04
```

**On Ubuntu 24.04** (you'll need to restart it, as the previous command will have terminated it)

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
wsl --terminate Ubuntu-24.04
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

With these instructions, the Ubuntu 24.04 machine should have no domain name resolution issues.

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

## Step 0 - Installing Docker Desktop on Windows 11

> Note: If you do not plan to use Docker Desktop, you can skip this step and proceed to **Step 1** [Configure the LAMP Environment on Ubuntu](#step-1---configure-the-lamp-environment-on-ubuntu)

To use Docker Desktop on Windows 11, your processor must support **Virtualization** and **Hyper-V**. If you're not sure whether these features are enabled, you can check through Windows' **Task Manager**.

To install Docker Desktop, download the installation file from [https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe) and follow the installation instructions.

> TL;DR: the important thing to use Docker inside WSL is **leave enabled** the option **Use WSL 2 based engine** in the Docker Setup, and in the Docker Desktop settings. Here's the full guide: [https://docs.docker.com/desktop/wsl/#turn-on-docker-desktop-wsl-2](https://docs.docker.com/desktop/wsl/#turn-on-docker-desktop-wsl-2)

After installation, **Restart your PC**.

## Step 1 - Configure the LAMP Environment on Ubuntu

> Note: If you do not intend to set up the LAMP environment, as the Ubuntu system will mainly be used with Docker, you can skip steps **1, 2, and 3** and proceed to **Step 4** [Install a Custom Shell, NVM, and Optimize User Experience (Optional)](#step-4---install-a-custom-shell-nvm-and-optimize-user-experience-optional)

Here, we will install all the system services and executables to enable support for **PHP** versions 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3 and 8.4. We will also enable the **Apache web server** and the **MySQL server**.

**Why install so many PHP versions**? It's essential for two reasons:

1. Having a **development environment** that easily allows **testing your application with various PHP versions**. This will facilitate the work in case of specific constraints on the production servers where the created applications will be installed.
2. If a Client or a specific project requires you to **maintain and/or modify an old codebase that runs on a specific PHP version**, you won't have trouble setting up the local dev & test environment.

> It is assumed that the default PHP version to be used in the system is **8.4**. This can be changed using the lines `update-alternatives --set php***` that will be found in the list below. For example, if you want the default PHP version (the one used when simply typing the command `php`, not its "versioned" command like `php7.4`), just specify `update-alternatives --set php /usr/bin/php7.4`. _(Anyway, this behavior will be modified with the Bash Aliases that we will configure later)_

**IMPORTANT**: Run all these commands as the `root` user on Ubuntu (use the command `sudo su -`). **IMPORTANT**: Exclude the lines starting with **#** as they only serve to differentiate the various blocks.

```console
# APACHE + Multi-PHP-FPM + Redis
sudo su -
apt update && apt upgrade
apt install -y curl net-tools zip unzip git redis-server lsb-release ca-certificates apt-transport-https software-properties-common
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-11.4"
sudo install -d /usr/share/postgresql-common/pgdg
curl -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc --fail https://www.postgresql.org/media/keys/ACCC4CF8.asc
sh -c 'echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/apache2
apt update && apt upgrade
PHPVERS="8.4 8.3 8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6"
PHPMODS="cli bcmath bz2 curl fpm gd gmp igbinary imagick imap intl mbstring mcrypt memcached msgpack mysql readline redis soap sqlite3 xsl zip"
APTPACKS=$(for VER in $PHPVERS; do echo -n "libapache2-mod-php$VER php$VER "; for MOD in $PHPMODS; do if [[ "$MOD" == "mcrypt" && "${VER/./}" -ge 83 ]]; then continue; fi; echo -n "php$VER-$MOD "; done; done)
apt install -y apache2 brotli openssl libapache2-mod-fcgid $APTPACKS
a2dismod $(for VER in $PHPVERS; do echo -n "php$VER "; done) mpm_prefork
a2enconf $(for VER in $PHPVERS; do echo -n "php$VER-fpm "; done)
a2enmod actions fcgid alias proxy_fcgi setenvif rewrite headers ssl http2 mpm_event brotli
a2dissite 000-default
systemctl enable apache2.service
systemctl restart apache2.service
systemctl enable redis-server.service
systemctl start redis-server.service
update-alternatives --set php /usr/bin/php8.4
update-alternatives --set phar /usr/bin/phar8.4
update-alternatives --set phar.phar /usr/bin/phar.phar8.4

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

# POSTGRESQL
sudo su postgres
psql
> ALTER USER postgres WITH PASSWORD 'YOUR-POSTGRES-PASS';
> CREATE USER admin WITH PASSWORD 'YOUR-ADMIN-PASS';
> ALTER USER admin WITH SUPERUSER;
> \q
exit
```

Once these commands are executed, all the necessary services and executables will be installed to create a LAMP stack with MySQL and PostgreSQL in multi-PHP mode (multiple PHP versions) with PHP-FPM to enhance performance.

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

## Step 3 - Setting up the PHP Environment with Composer and HTE-Cli

Now that we've set up the LAMP stack, it's useless unless we create some _VirtualHosts_ to develop or test web applications on different versions of PHP installed on the system.

To create `VirtualHosts`, we'll use [HTE-Cli](https://github.com/mauriziofonte/hte-cli), a tool **of my own creation** designed to facilitate the configuration of test environments on fictitious domain names by modifying the _Windows hosts file_.

_HTE-Cli_ will **auto-configure** what is needed based on some basic information for the project we want to develop or test.

We'll also deal with `Composer` as we go. In this section, we'll configure Composer not just for _HTE-Cli_, but also for _PHP Code Sniffer_ and _PHP CS Fixer_, which will be useful for development with _VS Code_.

> **NOTE**: To learn more about `HTE-Cli`, [read the dedicated README of HTE-Cli](https://github.com/mauriziofonte/hte-cli/blob/main/README.md).

### Installing Composer 2 and Composer 1

To install the latest stable version (2.x) of `Composer` _globally_, run this command:

```bash
wget -O composer.phar https://getcomposer.org/download/latest-stable/composer.phar && sudo mkdir -p /usr/local/bin && sudo mv composer.phar /usr/local/bin/composer && sudo chmod +x /usr/local/bin/composer
```

> **WARNING**: Composer 2 is **not** compatible with PHP versions below `7.2.5`. To use Composer on projects requiring PHP 7.2, 7.1, 7.0, or 5.6, you will need to use the _old_ Composer 1 binary

To install the latest version of the _old_ `Composer 1.x` (compatible with PHP 7.2, 7.1, 7.0, and 5.6), run this command:

```bash
wget -O composer-oldstable.phar https://getcomposer.org/download/latest-1.x/composer.phar && sudo mkdir -p /usr/local/bin && sudo mv composer-oldstable.phar /usr/local/bin/composer1 && sudo chmod +x /usr/local/bin/composer1
```

> **NOTE**: To keep these binaries updated, simply run `sudo /usr/local/bin/composer self-update && sudo /usr/local/bin/composer1 self-update`

### Installing support for HTE-Cli, PHP Code Sniffer, and PHP CS Fixer

To install support for these tools, run these commands:

```bash
composer global require --dev friendsofphp/php-cs-fixer
composer global require --dev "squizlabs/php_codesniffer=*"
composer global require "mfonte/hte-cli=*"
echo 'export PATH="$(composer config -g home)/vendor/bin:$PATH"' >> ~/.bashrc
```

> **NOTE**: To keep these packages updated, simply run `composer global update`
> **WARNING**: The installation directory for packages on **Ubuntu 24.04** will be `~/.config/composer`, not `~/.composer` as one might expect: [here's the explanation](https://stackoverflow.com/a/38746307/1916292).

### Configuring Bash Aliases

Now that we have everything installed, all that remains is to create some _Bash Aliases_ to speed up the work.

Launch `nano .bash_aliases` (or `vim .bash_aliases`) and paste these aliases:

```txt
alias hte="sudo /usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli create"
alias hte-create="sudo /usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli create"
alias hte-remove="sudo /usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli remove"
alias hte-details="sudo /usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli details"
alias composer-self-update="sudo /usr/local/bin/composer self-update && sudo /usr/local/bin/composer1 self-update"
alias composer-packages-update="composer global update"
alias composer="/usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer84="/usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer83="/usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer82="/usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer81="/usr/bin/php8.1 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer80="/usr/bin/php8.0 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer74="/usr/bin/php7.4 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer73="/usr/bin/php7.3 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias composer72="/usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
alias 1composer72="/usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer1"
alias 1composer71="/usr/bin/php7.1 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer1"
alias 1composer70="/usr/bin/php7.0 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer1"
alias 1composer56="/usr/bin/php5.6 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer1"
alias php="/usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php84="/usr/bin/php8.4 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php83="/usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php82="/usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php81="/usr/bin/php8.1 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php80="/usr/bin/php8.0 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php74="/usr/bin/php7.4 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php73="/usr/bin/php7.3 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php72="/usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php71="/usr/bin/php7.1 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php70="/usr/bin/php7.0 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php56="/usr/bin/php5.6 -d allow_url_fopen=1 -d memory_limit=1024M"
alias wslrestart="history -a && cmd.exe /C wsl --shutdown"
```

Once done editing the `.bash_aliases` file, execute:

```bash
source ~/.bash_aliases
```

With this `.bash_aliases` configuration, we have:

1. Aliased the `HTE-Cli` tool (which, remember, manages the VirtualHosts on the system) with 4 different commands: `hte`, `hte-create`, `hte-remove`, `hte-details`.
2. Created an alias to **update the Composer binaries** (installed as system binaries on `/usr/local/bin`) with the command `composer-self-update`. This alias will update both _Composer 2_ and _Composer 1_ at once.
3. Created an alias to **update globally installed Composer packages** with the command `composer-packages-update`.
4. Created various aliases for the _flavors_ of `Composer` usage corresponding to the target PHP versions installed on the system. In short, the `composer` command will use **PHP 8.4**, `composer83` will use **PHP 8.3**, `composer82` will use **PHP 8.2**, and so on, down to `composer72` using **PHP 7.2**. Similarly, to use the **old Composer 1** for legacy projects, just use `1composer72`, `1composer71`, `1composer70`, or `1composer56`.
5. Created various aliases to call the `PHP` binary on all versions installed on the system, so `php` will use **PHP 8.4**, `php83` will use **PHP 8.3**, and so on down to `php56` using **PHP 5.6**.
6. Ensured that both `composer` and `php` aliases work with two specific configurations: `allow_url_fopen` set to _1_, or active, and `memory_limit` set to _1024M_.
7. Created an alias to reset the Ubuntu virtual machine with the command `wslrestart`.

> Why set a memory limit for PHP and Composer aliases? Because by default the memory limit would be **"no limit"**. This is risky, as it **obscures** any potential issues with the Composer binary itself and, more generally, with PHP. For this reason, we set a _high_ but _finite_ memory limit of 1024 MB.

### Test the Configuration by Creating a VirtualHost for PhpMyAdmin

For illustration purposes, this section will show the complete process of creating a functional _VirtualHost_ that exposes the _PhpMyAdmin_ application on the local machine. This setup may come in handy if you decide to continue using it to navigate through the _MySQL Databases_ present on the system, and the data contained within them.

```bash
cd ~/
mkdir opt && cd opt/
wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip phpMyAdmin-5.2.1-all-languages.zip && rm -f phpMyAdmin-5.2.1-all-languages.zip && mv phpMyAdmin-5.2.1-all-languages phpmyadmin
```

Now, we've created the root directory for the _PhpMyAdmin_ installation. All that's left is to configure a working VirtualHost.

> **IMPORTANT**: The following instructions apply to **all local staging/test environments** that you wish to enable on the system via the `HTE-Cli` tool

```bash
maurizio:~ $ hte-create
[sudo] password for maurizio:
   __ __ ______ ____      _____ __ _
  / // //_  __// __/____ / ___// /(_)
 / _  /  / /  / _/ /___// /__ / // /
/_//_/  /_/  /___/      \___//_//_/

[H]andle [T]est [E]nvironment Cli Tool version 1.0.5 by Maurizio Fonte
WARNING: THIS TOOL IS *NOT* INTENDED FOR LIVE SERVERS. Use it only on local/firewalled networks.

 💡 Enter a valid local Domain Name (suggested .test TLD, as "jane.local.test") []:
 > local.phpmyadmin.test

 💡 Enter a valid directory in the filesystem for the DocumentRoot [/home/maurizio]:
 > /home/maurizio/opt/phpmyadmin/

 💡 Enter a valid PHP version for PHP-FPM (5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, 8.4) [8.4]:
 > 8.3

 💡 Do you need HTTPS support? ["yes", "no", "y" or "n"] [y]:
 > y

 💡 Do you want to force HTTPS? ["yes", "no", "y" or "n"] [y]:
 > y

⏳ VirtualHost configuration for local.phpmyadmin.test created at /etc/apache2/sites-available/008-local.phpmyadmin.test.conf
⏳ PHP8.3-FPM configuration for local.phpmyadmin.test created at /etc/php/8.3/fpm/pool.d/local.phpmyadmin.test.conf
⏳ Self-signed SSL certificate script for local.phpmyadmin.test created at /tmp/sscert_local.phpmyadmin.testnPwhL6
🔐️ Executing the self-signed SSL certificate script for local.phpmyadmin.test...
 > Removing existing previous self-signed certs with pattern local.phpmyadmin.test.*
 > Generating certs for local.phpmyadmin.test
 > Generating RSA private key, 2048 bit long modulus
 > Writing info to /etc/apache2/certs-selfsigned/local.phpmyadmin.test.info
 > Protecting the key with chmod 400 /etc/apache2/certs-selfsigned/local.phpmyadmin.test.key
 > Removing the temporary config file /tmp/openssl.cnf.r60k8l
⏳ Enabling local.phpmyadmin.test on config 008-local.phpmyadmin.test...
⚡ Restarting Apache2...
⚡ Restarting PHP8.3-FPM...
✅ VirtualHost local.phpmyadmin.test created successfully!
```

Next, you'll need to modify **the Windows hosts file** to point locally to the domain `local.phpmyadmin.test`.

To edit the _hosts file_ on Windows 11, you can:

1. Use _PowerToys_. For installation and usage, refer to [Microsoft's official guide](https://learn.microsoft.com/en-us/windows/powertoys/install).
2. Edit the file `C:\Windows\System32\drivers\etc\hosts` (it's recommended to use **Notepad++**).

Afterward, **open a privileged Windows command line** and run `ipconfig /flushdns`.

### Done!

**Congratulations**! If you've reached this point, you have everything you need to get to work, and you can navigate to [https://local.phpmyadmin.test/setup/](https://local.phpmyadmin.test/setup/) in your browser to proceed with the PhpMyAdmin setup.

To create additional VirtualHosts for other projects, **always use the same instructions followed for the PhpMyAdmin setup**. Just point the VirtualHost to the correct directory of your own project, and define a fictitious domain name that will be redirected by the _hosts file_ to `127.0.0.1`.

> **NOTE**: To **remove** VirtualHosts created via `HTE-Cli`, use the command (Alias) `hte-remove`
> To **list** all VirtualHosts created via `HTE-Cli`, use the command (Alias) `hte-details`.

## Step 4 - Install a Custom Shell, NVM, and Optimize User Experience (Optional)

These steps **are optional** and aim to optimize the user experience on the Linux Bash (according to my personal preferences), as well as install `nvm` (_Node Version Manager_, for working with _Node_, _React_, etc.).

My recommendation for beginners is to install the **Gash** Bash, which is a minimal, colored Bash that works well with _git_ and has a full set of powerful aliases that suit well for this exact LAMP environment. Plus, _Gash_ it's a creation of mine. If you prefer to use _ZSH_, or any other custom shell, or don't bother with this step, feel free to skip it.

1. Follow the installation instructions to install the **Gash** Bash at [https://github.com/mauriziofonte/gash](https://github.com/mauriziofonte/gash) (or install _ZSH_, or any other shell of your preference: I find this super minimal colored bash very suitable, and my personal opinion is that having less help on the bash is a great way to keep focused). Here's a one-liner to install _Gash_: `wget -qO- https://raw.githubusercontent.com/mauriziofonte/gash/refs/heads/main/install.sh | bash`
2. Run `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash` to install NVM (for NodeJS/React development).
3. Create a public/private key pair with the command `ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/key_name -C "user@computer"` (share the content of the public key `~/.ssh/key_name.pub` with your team, which will use it, for example, to enable access to a private GIT repository).
4. Create a link to the **Ubuntu home directory** accessible from your _Desktop_ to view Ubuntu's home via Windows Explorer: to do this, right-click on the _Desktop_, Select `New` > `Shortcut`, and enter in the **shortcut path** the string `\\wsl$\Ubuntu-24.04\home\USERNAME`, where **USERNAME** is the username used on Ubuntu. **Optional**: change the shortcut icon (recommend this: [ubuntu-drive-icon.ico](/icons/ubuntu-drive-icon.ico)).
5. Create a link to Ubuntu's _Bash_ accessible from your _Desktop_ to launch a new terminal: to do this, right-click on the _Desktop_, Select `New` > `Shortcut`, and enter in the **shortcut path** the string `C:\Windows\System32\wsl.exe -d Ubuntu-24.04 bash -c "cd /home/USERNAME && bash"`, where **USERNAME** is the username used on Ubuntu. **Optional**: change the shortcut icon (recommend this: [ubuntu-icon.ico](/icons/ubuntu-icon.ico)).

> Note: if you decided **not** to install the _Gash Bash_, I suggest to have a look at the [confs/bash_local](/confs/bash_local) file, which contains a set of useful aliases and configurations you can add to your `.bash_aliases` file (or to your own preferred shell configuration file).

### Step 5 - Install VS Code to Access Project Files on WSL2

VS Code is fully integrated and compatible with WSL2, natively.

This enhances productivity and greatly simplifies development.

To install and configure VS Code with WSL2:

1. Download VS Code from `https://code.visualstudio.com/`
2. Open VS Code and press `CTRL + SHIFT + x`
3. Install the **Remote - WSL** extension
4. Restart VS Code
5. Open an Ubuntu terminal, navigate to any directory, for example `~/opt/` or `~/.config/composer`
6. Run the command `code .` and let the system install what it needs
7. Done! Now, you can **edit files on Ubuntu directly from VS Code** installed on Windows.

### Step 6 - Optimize Web Development on VS Code with Recommended Extensions

Below is a list of useful plugins and configurations for **PHP development on VS Code**.

> It is **very important** to install the following plugins during a **WSL session** in VS Code. To do this, navigate to any Ubuntu directory, like `~/opt/` or `~/.config/composer`, and run `code .` This will open VS Code in a WSL session, and plugins (and their related environment settings) will apply to WSL2, not Windows.

To install each plugin, press `CTRL + SHIFT + x` and search for the plugin name.

1. Search for **php cs fixer** and install the plugin by **junstyle** [https://github.com/junstyle/vscode-php-cs-fixer.git](https://github.com/junstyle/vscode-php-cs-fixer.git)
2. Search for **GitLens** and install the plugin by **Eric Amodio** [https://github.com/eamodio/vscode-gitlens](https://github.com/eamodio/vscode-gitlens)
3. Search for **Git History** and install the plugin by **Don Jayamanne**, [https://github.com/DonJayamanne/gitHistoryVSCode](https://github.com/DonJayamanne/gitHistoryVSCode)
4. Search for **PHP Intelephense** and install the plugin by **Ben Mewburn**, [https://github.com/bmewburn/vscode-intelephense](https://github.com/bmewburn/vscode-intelephense)
5. Search for **Prettier - Code Formatter** and install the plugin by **Prettier**, [https://github.com/prettier/prettier-vscode](https://github.com/prettier/prettier-vscode)
6. Search for **PHP DocBlocker** and install the plugin by **Neil Brayfield**, [https://github.com/neild3r/vscode-php-docblocker](https://github.com/neild3r/vscode-php-docblocker)
7. Search for **markdownlint** and install the plugin by **David Anson**, [https://github.com/DavidAnson/vscode-markdownlint](https://github.com/DavidAnson/vscode-markdownlint)
8. Search for **Material Icon Theme** and install the plugin by **Philipp Kief**, [https://github.com/PKief/vscode-material-icon-theme](https://github.com/PKief/vscode-material-icon-theme)

After installing all the plugins, press `CTRL + SHIFT + p`, type **JSON**, and select **Preferences: Open Remote Settings (JSON) (WSL: Ubuntu-24.04)**

Then, copy-paste the JSON configuration shown in [vscode.json](/confs/vscode.json), replacing `##LINUX_USERNAME##` with your Ubuntu username.

This configuration contains both **my personal preferences** and settings specific to formatters and **php cs fixer**.

> **NOTE**: The recommended configuration in [vscode.json](/confs/vscode.json) requires installing [Roboto Sans](https://fonts.google.com/specimen/Roboto) and [Source Code Pro](https://fonts.google.com/specimen/Source+Code+Pro) fonts. 
> **Roboto Sans** is used for terminal output, while **Source Code Pro** is used for source code, markdown files, readmes, basically all text editors.
> Detailed installation instructions for the fonts on Windows are omitted. However, simply download the `ttf` font files, open them with Windows, and click `Install`

## Epilogue

### Tailoring Your Own Local LAMP Ecosystem

This README is my artisan blueprint for installing and configuring a **local** _LAMP_ development environment on Windows 11 with WSL2. It's the culmination of my own trial, error, and success in achieving a workflow that **suits me**. Understand that while this guide works for me, your experience and mileage may vary.

### Community Input

Feel that the blueprint can be enriched? Your contributions can turn this from a one-man show to a community masterpiece. Open an issue or create a pull request to share your insights.

### User Responsibility Disclaimer

By proceeding with this guide, you assume full responsibility for any modifications or actions executed on your computing environment. Neither the author nor any contributors shall be held liable for any repercussions, including but not limited to data loss, system corruption, or hardware failure. **Proceed at your own risk.**

### License

This blueprint is laid out under the MIT License. For more details, refer to the [LICENSE](/LICENSE) file in the repository
