#!/usr/bin/env bash

# This script installs a LAMP stack on Ubuntu 22.04 LTS (Jammy Jellyfish)
# with Apache + PHP + Redis + MySQL and multi-PHP versions support
# Apache will be configured to work with PHP-FPM
#
# Author: Maurizio Fonte (https://www.mauriziofonte.it)
# Version: 1.1.0
# Release Date: 2023-09-04
# License: MIT License
#
# If you find any issue, please report it on GitHub: https://github.com/mauriziofonte/win11-wsl2-ubuntu22-setup/issues
#

{ # this ensures the entire script is downloaded #

    ubwsl_has() {
        type "$1" >/dev/null 2>&1
    }

    ubwsl_echo() {
        local color="\e[1;97m"  # Default (Bold White)

        case "$1" in
            "info"|"highlight"|"log"|"warning"|"error")
                case "$1" in
                    "info") color="\e[1;92m" ;;      # Bold Light Green
                    "highlight") color="\e[1;94m" ;; # Bold Light Blue
                    "log") color="\e[36m" ;;         # Cyan
                    "warning") color="\e[33m" ;;     # Yellow
                    "error") color="\e[31m" ;;       # Red
                esac
                shift  # Remove the first argument only if it was a color parameter
            ;;
        esac

        command printf "${color}%s\e[0m\\n" "$*" 2>/dev/null
    }

    if [ -z "${BASH_VERSION}" ] || [ -n "${ZSH_VERSION}" ]; then
        # shellcheck disable=SC2016
        ubwsl_echo >&2 error 'Error: the install instructions explicitly say to pipe the install script to `bash`; please follow them'
        exit 1
    fi

    ubwsl_download() {
        if ubwsl_has "curl"; then
            curl --fail --compressed -q "$@"
        elif ubwsl_has "wget"; then
            # Emulate curl with wget
            ARGS=$(ubwsl_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                -e 's/--compressed //' \
                -e 's/--fail //' \
                -e 's/-L //' \
                -e 's/-I /--server-response /' \
                -e 's/-s /-q /' \
                -e 's/-sS /-nv /' \
                -e 's/-o /-O /' \
                -e 's/-C - /-c /')
            # shellcheck disable=SC2086
            eval wget $ARGS
        fi
    }

    ubwsl_do_install() {

        # echo the header of the script
        ubwsl_echo info "*============================================================================*"
        ubwsl_echo info "*  Ubuntu 22.04 LTS (Jammy Jellyfish) LAMP stack installer                   *"
        ubwsl_echo info "*                                                                            *"
        ubwsl_echo info "*  Copyright (c) 2023 Maurizio Fonte https://www.mauriziofonte.it            *"
        ubwsl_echo info "*  Report bugs to github.com/mauriziofonte/win11-wsl2-ubuntu22-setup/issues  *"
        ubwsl_echo info "*============================================================================*"

        # save the username of the user that ran the script
        USERNAME=$(whoami | awk '{print $1}')
        MACHINENAME=$(hostname)
        ubwsl_echo "Hello, $USERNAME! We're going to install your fresh new LAMP stack as on your \"$MACHINENAME\" machine"
        ubwsl_echo
        ubwsl_echo warning "Please note that the installation may take a while, depending on your internet connection speed and on your machine's specs."
        ubwsl_echo warning "Also note that the system will ask you for the SUDO password multiple times during the installation."
        ubwsl_echo
        ubwsl_echo log "If for any reason this script stops or fails, try and re-run it with:"
        ubwsl_echo log " > wget -qO- https://raw.githubusercontent.com/mauriziofonte/win11-wsl2-ubuntu22-setup/main/install/lamp-stack.sh | bash"
        ubwsl_echo
        ubwsl_echo info "Are you ready? Press any key to continue or CTRL+C to abort."
        read -n 1 -s </dev/tty

        # echo that we're going to ask dor the sudo password
        ubwsl_echo highlight "We're going to ask for the sudo password, to check if you can run the commands as root:"
        ubwsl_echo

        # check if we can run a command with sudo to verify that the user has sudo access
        if ! sudo true; then
            ubwsl_echo >&2 error "Cannot \"sudo\" with user \"$USERNAME\". Cannot continue."
            ubwsl_echo
            exit 1
        fi

        # check we've got APT installed
        if ! ubwsl_has "apt-get"; then
            ubwsl_echo >&2 error "Cannot find apt-get. Please install it and try again."
            ubwsl_echo
            exit 1
        fi

        # ask for the sudo password, we'll need it later
        ubwsl_echo highlight "We're going to ask you again for the sudo password (we'll need it later):"
        read -s -p "[sudo] password for $USERNAME: " SUDO_PASSWORD </dev/tty
        ubwsl_echo

        # modify the APT config so that we are more lax on retries and timeouts
        echo -e "Acquire::Retries \"50\";\nAcquire::https::Timeout \"240\";\nAcquire::http::Timeout \"240\";\n" | sudo tee /etc/apt/apt.conf.d/99-custom.conf >/dev/null

        # install apache + php + redis + mysql
        ubwsl_echo info "Installing Apache + PHP + Redis + MySQL"
        sudo apt-get --assume-yes --quiet update && sudo apt-get --assume-yes --quiet upgrade
        sudo apt-get --assume-yes --quiet install net-tools expect zip unzip git redis-server lsb-release ca-certificates apt-transport-https software-properties-common
        LC_ALL=C.UTF-8 sudo add-apt-repository --yes ppa:ondrej/php
        LC_ALL=C.UTF-8 sudo add-apt-repository --yes ppa:ondrej/apache2
        sudo apt-get --assume-yes --quiet update && sudo apt-get --assume-yes --quiet upgrade
        PHPVERS="8.3 8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6"
        PHPMODS="cli bcmath bz2 curl fpm gd gmp igbinary imagick imap intl mbstring mcrypt memcached msgpack mysql readline redis soap sqlite3 xsl zip"
        APTPACKS=""
        for VER in $PHPVERS; do
            APTPACKS+="libapache2-mod-php$VER php$VER "
            for MOD in $PHPMODS; do
                # mcrypt is not available for PHP 8.3
                if [ "$VER" = "8.3" ] && [ "$MOD" = "mcrypt" ]; then
                    continue
                fi
                APTPACKS+="php$VER-$MOD "
            done
        done
        sudo apt-get --assume-yes --quiet install apache2 brotli openssl libapache2-mod-fcgid $APTPACKS
        sudo a2dismod $(for VER in $PHPVERS; do echo -n "php$VER "; done) mpm_prefork
        sudo a2enconf $(for VER in $PHPVERS; do echo -n "php$VER-fpm "; done)
        sudo a2enmod actions fcgid alias proxy_fcgi setenvif rewrite headers ssl http2 mpm_event brotli
        sudo a2dissite 000-default
        sudo systemctl enable apache2.service
        sudo systemctl restart apache2.service
        sudo systemctl enable redis-server.service
        sudo systemctl start redis-server.service
        sudo update-alternatives --set php /usr/bin/php8.3
        sudo update-alternatives --set phar /usr/bin/phar8.3
        sudo update-alternatives --set phar.phar /usr/bin/phar.phar8.3

        sudo apt-get --assume-yes --quiet install mariadb-server
        sudo systemctl enable mariadb.service
        sudo systemctl start mariadb.service

        # modify /etc/apache2/envvars so that APACHE_RUN_USER=$USERNAME and APACHE_RUN_GROUP=$USERNAME
        ubwsl_echo info "Modifying /etc/apache2/envvars"
        sudo sed -i "s/APACHE_RUN_USER=www-data/APACHE_RUN_USER=$USERNAME/g" /etc/apache2/envvars
        sudo sed -i "s/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=$USERNAME/g" /etc/apache2/envvars

        # modify /etc/apache2/ports.conf so that Listen 80 is Listen 127.0.0.1:80 and Listen 443 is Listen 127.0.0.1:443
        ubwsl_echo info "Modifying /etc/apache2/ports.conf"
        sudo sed -i "s/Listen 80/Listen 127.0.0.1:80/g" /etc/apache2/ports.conf
        sudo sed -i "s/Listen 443/Listen 127.0.0.1:443/g" /etc/apache2/ports.conf

        # if the file /home/$USERNAME/.mysql-pass does not exist, then execute the mysql_secure_installation script
        if [ ! -f /home/$USERNAME/.mysql-pass ]; then
            # create Root passwords for user "root" and "admin"
            PASS_MYSQL_ROOT=$(openssl rand -base64 64 | sed 's/[^a-z0-9]//g' | head -c 8)
            PASS_MYSQL_DEFAULT=$(openssl rand -base64 64 | sed 's/[^a-z0-9]//g' | head -c 8)

            # create the expect script for mysql_secure_installation
            EXPECT_SCRIPT="
set timeout 2
spawn sudo mysql_secure_installation
expect \"\\[sudo\\] password for*\"
send \"$SUDO_PASSWORD\r\"
expect \"Enter current password for root (enter for none)\"
send \"\r\"
expect \"Switch to unix_socket authentication\"
send \"n\r\"
expect \"Change the root password?\"
send \"Y\r\"
expect \"New password:\"
send \"$PASS_MYSQL_ROOT\r\"
expect \"Re-enter new password:\"
send \"$PASS_MYSQL_ROOT\r\"
expect \"Remove anonymous users?\"
send \"Y\r\"
expect \"Disallow root login remotely?\"
send \"Y\r\"
expect \"Remove test database and access to it?\"
send \"Y\r\"
expect \"Reload privilege tables now?\"
send \"Y\r\"
expect eof"

            # Execute mysql_secure_installation
            ubwsl_echo info "Executing mysql_secure_installation"
            ubwsl_echo warning "IMPORTANT: Do not type anything, the installer will reply to the prompts automatically"
            echo "$EXPECT_SCRIPT" | expect

            # create a new Mysql user "default" with password $PASS_MYSQL_DEFAULT
            EXPECT_SCRIPT="
set timeout 2
spawn mysql -u root -p
expect \"Enter password:\"
send \"$PASS_MYSQL_ROOT\r\"
expect \"MariaDB \\[(none)\\]>\"
send \"GRANT ALL ON *.* TO 'default'@'localhost' IDENTIFIED BY '$PASS_MYSQL_DEFAULT' WITH GRANT OPTION;\r\"
expect \"MariaDB \\[(none)\\]>\"
send \"GRANT ALL ON *.* TO 'default'@'127.0.0.1' IDENTIFIED BY '$PASS_MYSQL_DEFAULT' WITH GRANT OPTION;\r\"
expect \"MariaDB \\[(none)\\]>\"
send \"FLUSH PRIVILEGES;\r\"
expect \"MariaDB \\[(none)\\]>\"
send \"exit\r\"
expect eof"

            # execute mysql commands
            ubwsl_echo info "Creating a new Mysql \"default\" user"
            ubwsl_echo warning "IMPORTANT: Do not type anything, the installer will reply to the prompts automatically"
            echo "${EXPECT_SCRIPT}" | expect

            # save both passwords to /home/$USERNAME/.mysql-pass
            ubwsl_echo info "Saving mysql passwords to /home/$USERNAME/.mysql-pass"
            ubwsl_echo log "Your mysql \"root\" user's password is: $PASS_MYSQL_ROOT"
            ubwsl_echo log "Your mysql \"default\" user's password is: $PASS_MYSQL_DEFAULT"
            echo "root:$PASS_MYSQL_ROOT" >/home/$USERNAME/.mysql-pass
            echo "default:$PASS_MYSQL_DEFAULT" >>/home/$USERNAME/.mysql-pass
            chown $USERNAME:$USERNAME /home/$USERNAME/.mysql-pass
            chmod 600 /home/$USERNAME/.mysql-pass
        else
            # if the file /home/$USERNAME/.mysql-pass exists, then read the passwords from it
            ubwsl_echo warning "Skipping mysql_secure_installation and creating a new Mysql \"default\" user"
            ubwsl_echo
            ubwsl_echo info "Reading mysql passwords from /home/$USERNAME/.mysql-pass"
            PASS_MYSQL_ROOT=$(grep root /home/$USERNAME/.mysql-pass | awk -F: '{print $2}')
            PASS_MYSQL_DEFAULT=$(grep default /home/$USERNAME/.mysql-pass | awk -F: '{print $2}')
            ubwsl_echo log "Your mysql \"root\" user's password is: $PASS_MYSQL_ROOT"
            ubwsl_echo log "Your mysql \"default\" user's password is: $PASS_MYSQL_DEFAULT"
        fi

        # create a new /etc/mysql/mariadb.conf.d/99-custom.cnf file (if it does not exist)
        if [ ! -f /etc/mysql/mariadb.conf.d/99-custom.cnf ]; then
            ubwsl_echo info "Creating a new /etc/mysql/mariadb.conf.d/99-custom.cnf file"
            
            MYSQL_CONFIG=$(
            cat <<EOF
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
EOF
        )

            echo "$MYSQL_CONFIG" | sudo tee /etc/mysql/mariadb.conf.d/99-custom.cnf >/dev/null
        else
            ubwsl_echo warning "Skipping the creation of a new /etc/mysql/mariadb.conf.d/99-custom.cnf file"
        fi

        # restart services
        ubwsl_echo info "Restarting Apache and Mysql services"
        sudo systemctl restart apache2.service
        sudo systemctl restart mariadb.service

        # create the /etc/apache2/certs-selfsigned/ directory (if it does not exist)
        if [ ! -d /etc/apache2/certs-selfsigned/ ]; then
            ubwsl_echo info "Creating the /etc/apache2/certs-selfsigned/ directory"
            sudo mkdir -p /etc/apache2/certs-selfsigned/
        else
            ubwsl_echo warning "Skipping the creation of the /etc/apache2/certs-selfsigned/ directory"
        fi

        # Install Composer Binaries (if they do not exist)
        if [ ! -f /usr/local/bin/composer ]; then
            ubwsl_echo info "Installing Composer Binaries"
            sudo mkdir -p /usr/local/bin
            cd ~/
            wget -O composer.phar https://getcomposer.org/download/latest-stable/composer.phar
            sudo mv composer.phar /usr/local/bin/composer
            sudo chmod +x /usr/local/bin/composer
            wget -O composer-oldstable.phar https://getcomposer.org/download/latest-1.x/composer.phar
            sudo mv composer-oldstable.phar /usr/local/bin/composer1
            sudo chmod +x /usr/local/bin/composer1
        else
            ubwsl_echo warning "Skipping the installation of Composer Binaries"
        fi

        # globally install HTE-Cli, PHP CS Fixer and PHP Code Sniffer (if directory ~/.config/composer does not exist)
        if [ ! -d ~/.config/composer ]; then
            ubwsl_echo info "Globally installing Composer packages HTE-Cli, PHP CS Fixer and PHP Code Sniffer"
            cd ~/
            composer global require --dev friendsofphp/php-cs-fixer
            composer global require --dev "squizlabs/php_codesniffer=*"
            composer global require "mfonte/hte-cli=*"
            echo 'export PATH="$(composer config -g home)/vendor/bin:$PATH"' >> ~/.bashrc
        else
            ubwsl_echo warning "Skipping the global installation of Composer packages HTE-Cli, PHP CS Fixer and PHP Code Sniffer"
        fi

        # create the .ssh folder and generate a secure ssh key named "defaultkey" (if it does not exist)
        if [ ! -f ~/.ssh/defaultkey ]; then

            ubwsl_echo info "Creating the ~/.ssh/ folder and generating a secure ssh key"
            ubwsl_echo warning "IMPORTANT: Do not type anything, the installer will reply to the prompts automatically"
            mkdir -p ~/.ssh && cd ~/.ssh

            # create the expect script
            EXPECT_SCRIPT="
set timeout 2
spawn ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/defaultkey -C "$USERNAME@$MACHINENAME"
expect \"Enter passphrase (empty for no passphrase):\"
send "\r"
expect eof"

            # execute the expect script
            echo "${EXPECT_SCRIPT}" | expect
        else
            ubwsl_echo warning "Skipping the creation of the ~/.ssh/ folder and the generation of a secure ssh key"
        fi

        # ask the user if he wants to set up NVM and Bash Aliases
        ubwsl_echo
        ubwsl_echo highlight "We're almost done. The required stuff has been installed."
        ubwsl_echo
        read -p "Do you want to set up NVM, Node, Yarn, and Bash Aliases? (y/n): " -n 1 -r </dev/tty
        ubwsl_echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # install NVM
            ubwsl_echo info "Installing NVM"
            wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

            # install NodeJS
            ubwsl_echo info "Installing NodeJS"
            nvm install --lts

            # install Yarn
            ubwsl_echo info "Installing Yarn"
            npm install -g yarn

            # install the Aliases
            # create the .bash_aliases file with some useful aliases
            ubwsl_echo info "Creating the ~/.bash_aliases file with some useful aliases"
            BASHLOCAL_FILE=$(
                cat <<EOF
alias hte="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli create"
alias hte-create="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli create"
alias hte-remove="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli remove"
alias hte-details="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli details"
alias composer-self-update="sudo /usr/local/bin/composer self-update && sudo /usr/local/bin/composer1 self-update"
alias composer-packages-update="composer global update"
alias composer="/usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M /usr/local/bin/composer"
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
alias php="/usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M"
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
EOF
            )

            echo "$BASHLOCAL_FILE" >~/.bash_local
            source ~/.bash_local
        else
            ubwsl_echo warning "Skipping the Bash Env, NVM and Aliases setup"
        fi

        # echo the footer of the script
        ubwsl_echo info "Installation completed! You can now start using your new LAMP stack!"

        ubwsl_reset
    }

    #
    # Unsets the various functions defined
    # during the execution of the install script
    ubwsl_reset() {
        unset -f ubwsl_has ubwsl_echo ubwsl_download ubwsl_do_install ubwsl_reset
    }

    #
    # Runs the installer
    ubwsl_do_install

} # this ensures the entire script is downloaded #
