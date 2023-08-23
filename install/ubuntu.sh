#!/usr/bin/env bash

{ # this ensures the entire script is downloaded #

    ubwsl_has() {
        type "$1" >/dev/null 2>&1
    }

    ubwsl_echo() {
        command printf %s\\n "$*" 2>/dev/null
    }

    if [ -z "${BASH_VERSION}" ] || [ -n "${ZSH_VERSION}" ]; then
        # shellcheck disable=SC2016
        ubwsl_echo >&2 'Error: the install instructions explicitly say to pipe the install script to `bash`; please follow them'
        exit 1
    fi

    ubwsl_grep() {
        GREP_OPTIONS='' command grep "$@"
    }

    ubwsl_profile_is_bash_or_zsh() {
        local TEST_PROFILE
        TEST_PROFILE="${1-}"
        case "${TEST_PROFILE-}" in
        *"/.bashrc" | *"/.bash_profile" | *"/.zshrc" | *"/.zprofile")
            return
            ;;
        *)
            return 1
            ;;
        esac
    }

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

    ubwsl_try_profile() {
        if [ -z "${1-}" ] || [ ! -f "${1}" ]; then
            return 1
        fi
        ubwsl_echo "${1}"
    }

    #
    # Detect profile file if not specified as environment variable
    # (eg: PROFILE=~/.myprofile)
    # The echo'ed path is guaranteed to be an existing file
    # Otherwise, an empty string is returned
    #
    ubwsl_detect_profile() {
        if [ "${PROFILE-}" = '/dev/null' ]; then
            # the user has specifically requested NOT to have nvm touch their profile
            return
        fi

        if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
            ubwsl_echo "${PROFILE}"
            return
        fi

        local DETECTED_PROFILE
        DETECTED_PROFILE=''

        if [ "${SHELL#*bash}" != "$SHELL" ]; then
            if [ -f "$HOME/.bashrc" ]; then
                DETECTED_PROFILE="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                DETECTED_PROFILE="$HOME/.bash_profile"
            fi
        elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
            if [ -f "$HOME/.zshrc" ]; then
                DETECTED_PROFILE="$HOME/.zshrc"
            elif [ -f "$HOME/.zprofile" ]; then
                DETECTED_PROFILE="$HOME/.zprofile"
            fi
        fi

        if [ -z "$DETECTED_PROFILE" ]; then
            for EACH_PROFILE in ".profile" ".bashrc" ".bash_profile" ".zprofile" ".zshrc"; do
                if DETECTED_PROFILE="$(ubwsl_try_profile "${HOME}/${EACH_PROFILE}")"; then
                    break
                fi
            done
        fi

        if [ -n "$DETECTED_PROFILE" ]; then
            ubwsl_echo "$DETECTED_PROFILE"
        fi
    }

    ubwsl_do_install() {

        # save the username of the user that ran the script
        USERNAME=$(whoami | awk '{print $1}')
        MACHINENAME=$(hostname)
        ubwsl_echo "=> Installing LAMP stack as $USERNAME on machine $MACHINENAME"

        # echo that we're going to ask dor the sudo password
        ubwsl_echo "=> We're going to ask for the sudo password below:"
        ubwsl_echo

        # login as sudo
        sudo su - root

        # check we're running as root
        if [ "$(id -u)" != "0" ]; then
            ubwsl_echo "=> Cannot switch to root user. Please run this script as root."
            ubwsl_echo
            exit 1
        fi

        # check we've got APT installed
        if ! ubwsl_has "apt-get"; then
            ubwsl_echo "=> Cannot find apt-get. Please install it and try again."
            ubwsl_echo
            exit 1
        fi

        # install apache + php + redis + mysql
        ubwsl_echo "=> Installing Apache + PHP + Redis + MySQL"
        apt update -y && apt upgrade -y
        apt install -y mktemp net-tools expect zip unzip git redis-server lsb-release ca-certificates apt-transport-https software-properties-common
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php
        LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/apache2
        apt update -y && apt upgrade -y
        PHPVERS="8.2 8.1 8.0 7.4 7.3 7.2 7.1 7.0 5.6"
        PHPMODS="cli fpm common bcmath bz2 curl gd intl mbstring mcrypt mysql opcache sqlite3 redis xml zip"
        APTPACKS=$(for VER in $PHPVERS; do
            echo -n "libapache2-mod-php$VER php$VER "
            for MOD in $PHPMODS; do echo -n "php$VER-$MOD "; done
        done)
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

        apt install mariadb-server
        systemctl enable mariadb.service
        systemctl start mariadb.service

        # create Root passwords for user "root" and "admin"
        PASS_MYSQL_ROOT=$(openssl rand -base64 64 | sed 's/[^a-zA-Z0-9]//g' | head -c 32)
        PASS_MYSQL_ADMIN=$(openssl rand -base64 64 | sed 's/[^a-zA-Z0-9]//g' | head -c 32)

        SECURE_MYSQL=$(expect -c "
set timeout 3
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"root password?\"
send \"y\r\"
expect \"New password:\"
send \"$PASS_MYSQL_ROOT\r\"
expect \"Re-enter new password:\"
send \"$PASS_MYSQL_ROOT\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

        # Execute mysql_secure_installation
        ubwsl_echo "=> Executing mysql_secure_installation"
        echo "${SECURE_MYSQL}"

        # create user "admin" with password "admin"
        NEW_MYSQL_USER=$(expect -c "
set timeout 3
spawn mysql -u root -p
expect \"Enter password:\"
send \"$PASS_MYSQL_ROOT\r\"
expect \"mysql>\"
send \"GRANT ALL ON *.* TO 'admin'@'localhost' IDENTIFIED BY '$PASS_MYSQL_ADMIN' WITH GRANT OPTION;\"
expect \"mysql>\"
send \"GRANT ALL ON *.* TO 'admin'@'127.0.0.1' IDENTIFIED BY '$PASS_MYSQL_ADMIN' WITH GRANT OPTION;\"
expect \"mysql>\"
send \"FLUSH PRIVILEGES;\"
expect \"mysql>\"
send \"exit\r\"
expect eof
")

        # execute mysql commands
        ubwsl_echo "=> Creating a mysql \"admin\" user"
        echo "${NEW_MYSQL_USER}"

        # save both passwords to /home/$USERNAME/.mysql-pass
        ubwsl_echo "=> Saving mysql passwords to /home/$USERNAME/.mysql-pass"
        ubwsl_echo "=> Your mysql root password is: $PASS_MYSQL_ROOT"
        ubwsl_echo "=> Your mysql admin password is: $PASS_MYSQL_ADMIN"
        echo "root:$PASS_MYSQL_ROOT" >/home/$USERNAME/.mysql-pass
        echo "admin:$PASS_MYSQL_ADMIN" >>/home/$USERNAME/.mysql-pass
        chown $USERNAME:$USERNAME /home/$USERNAME/.mysql-pass
        chmod 600 /home/$USERNAME/.mysql-pass

        # modify /etc/apache2/envvars so that APACHE_RUN_USER=$USERNAME and APACHE_RUN_GROUP=$USERNAME
        ubwsl_echo "=> Modifying /etc/apache2/envvars"
        sed -i "s/APACHE_RUN_USER=www-data/APACHE_RUN_USER=$USERNAME/g" /etc/apache2/envvars
        sed -i "s/APACHE_RUN_GROUP=www-data/APACHE_RUN_GROUP=$USERNAME/g" /etc/apache2/envvars

        # modify /etc/apache2/ports.conf so that Listen 80 is Listen 127.0.0.1:80 and Listen 443 is Listen 127.0.0.1:443
        ubwsl_echo "=> Modifying /etc/apache2/ports.conf"
        sed -i "s/Listen 80/Listen 127.0.0.1:80/g" /etc/apache2/ports.conf
        sed -i "s/Listen 443/Listen 127.0.0.1:443/g" /etc/apache2/ports.conf

        # create a new /etc/mysql/mariadb.conf.d/99-custom.cnf file
        ubwsl_echo "=> Creating a new /etc/mysql/mariadb.conf.d/99-custom.cnf file"
        read -r -d '' MYSQL_CONFIG <<-'EOF'
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

        echo "$MYSQL_CONFIG" >/etc/mysql/mariadb.conf.d/99-custom.cnf

        # restart services
        ubwsl_echo "=> Restarting Apache and Mysql services"
        systemctl restart apache2.service
        systemctl restart mariadb.service

        # create the /etc/apache2/certs-selfsigned/ directory
        ubwsl_echo "=> Creating the /etc/apache2/certs-selfsigned/ directory"
        mkdir -p /etc/apache2/certs-selfsigned/

        # exit from the root session
        exit

        # create the utils folder
        ubwsl_echo "=> Creating the ~/utils/ folder"
        cd ~/ && mkdir utils && cd utils/

        # download the "create-test-environment.php" script
        ubwsl_echo "=> Downloading the create-test-environment.php script"
        TEMPFILE=$(mktemp)
        ubwsl_download -s "https://gist.githubusercontent.com/mauriziofonte/299c39485f7d598984ec32106f710cae/raw/50c5bce1ab6ca728a918fbd8273e3048dc29281a/test.ps1" -o "$TEMPFILE"
        sed -i "s/##LINUX_USERNAME##/$USERNAME/g" "$TEMPFILE"
        mv "$TEMPFILE" ~/utils/create-test-environment.php

        # download the "create-selfsigned-ssl-cert.sh" script
        ubwsl_echo "=> Downloading the create-selfsigned-ssl-cert.sh script"
        TEMPFILE=$(mktemp)
        ubwsl_download -s "https://gist.githubusercontent.com/mauriziofonte/299c39485f7d598984ec32106f710cae/raw/50c5bce1ab6ca728a918fbd8273e3048dc29281a/test.ps1" -o "$TEMPFILE"
        sed -i "s/##LINUX_USERNAME##/$USERNAME/g" "$TEMPFILE"
        mv "$TEMPFILE" ~/utils/create-selfsigned-ssl-cert.sh
        chmod +x ~/utils/create-selfsigned-ssl-cert.sh

        # initialize Composer setup
        ubwsl_echo "=> Initializing Composer stuff in ~/utils/.composer"
        mkdir -p ~/utils/.composer && cd ~/utils/.composer
        wget -O composer.phar https://getcomposer.org/download/latest-stable/composer.phar && chmod +x composer.phar
        wget -O composer-oldstable.phar https://getcomposer.org/download/latest-1.x/composer.phar && chmod +x composer-oldstable.phar

        # create the composer.json config file
        read -r -d '' COMPOSER_CONFIG <<-'EOF'
{
	"require": {
		"squizlabs/php_codesniffer": "^3.5",
		"friendsofphp/php-cs-fixer": "^2.16"
	}
}
EOF

        echo "$COMPOSER_CONFIG" >composer.json

        # install composer dependencies
        php -d allow_url_fopen=1 -d memory_limit=-1 composer.phar install

        # create the .ssh folder and generate a secure ssh key
        ubwsl_echo "=> Creating the ~/.ssh/ folder and generating a secure ssh key"
        mkdir -p ~/.ssh
        ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/defaultkey -C "$USERNAME@$MACHINENAME"

        # create the .bash_local file with some useful aliases
        ubwsl_echo "=> Creating the ~/.bash_local file with some useful aliases"
        read -r -d '' BASHLOCAL_FILE <<-'EOF'
alias testenv="sudo /usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/create-test-environment.php"
alias removetestenv="sudo /usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/delete-test-environment.php"
alias updatecomposer="/usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar self-update && /usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer-oldstable.phar self-update"
alias composer="/usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar"
alias composer81="/usr/bin/php8.1 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar"
alias composer80="/usr/bin/php8.0 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar"
alias composer74="/usr/bin/php7.4 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar"
alias composer73="/usr/bin/php7.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar"
alias composer72="/usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer.phar"
alias 1composer72="/usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer-oldstable.phar"
alias 1composer71="/usr/bin/php7.1 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer-oldstable.phar"
alias 1composer70="/usr/bin/php7.0 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer-oldstable.phar"
alias 1composer56="/usr/bin/php5.6 -d allow_url_fopen=1 -d memory_limit=1024M ~/utils/.composer/composer-oldstable.phar"
alias php="/usr/bin/php8.2 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php81="/usr/bin/php8.1 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php80="/usr/bin/php8.0 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php74="/usr/bin/php7.4 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php73="/usr/bin/php7.3 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php72="/usr/bin/php7.2 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php71="/usr/bin/php7.1 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php70="/usr/bin/php7.0 -d allow_url_fopen=1 -d memory_limit=1024M"
alias php56="/usr/bin/php5.6 -d allow_url_fopen=1 -d memory_limit=1024M"
alias apt="sudo apt-get"
alias ls="ls -lash --color=auto --group-directories-first"
alias cd..="cd .."
alias ..="cd ../../"
alias ...="cd ../../../"
alias ....="cd ../../../../"
alias .....="cd ../../../../"
alias .4="cd ../../../../"
alias .5="cd ../../../../.."
alias ports="sudo netstat -tulanp"
alias wslrestart="history -a && cmd.exe /C wsl --shutdown"
EOF

        echo "$BASHLOCAL_FILE" >~/.bash_local

        ubwsl_reset
    }

    #
    # Unsets the various functions defined
    # during the execution of the install script
    ubwsl_reset() {
        unset -f ubwsl_has ubwsl_echo ubwsl_grep ubwsl_profile_is_bash_or_zsh ubwsl_download ubwsl_try_profile ubwsl_detect_profile ubwsl_do_install ubwsl_reset
    }

    #
    # Runs the installer
    ubwsl_do_install

} # this ensures the entire script is downloaded #
