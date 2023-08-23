<?php

if (php_sapi_name() !== "cli") {
    message('ERROR: This script can only be run from the CLI.', 'e');
    exit();
}

if (posix_getuid() !== 0) {
    message('ERROR: This script can only be run as ROOT or with sudo, if your user is a Sudoer.', 'e');
    exit();
}

if (!is_dir('/etc/apache2/certs-selfsigned/')) {
    message('ERROR: You need to create the directory /etc/apache2/certs-selfsigned/ as root prior of executing this script.', 'e');
    exit();
}

define('APACHE_SITES_AVAILABLE_DIR', '/etc/apache2/sites-available/');
define('APACHE_CERTS_DIR', '/etc/apache2/certs-selfsigned/');
define('APACHE_CERT_SELFSIGNED_SCRIPT', './create-selfsigned-ssl-cert.sh');
define('PHP_FPM_CONFIG_DIR', '/etc/php/#VER#/fpm/pool.d/');
define('APACHE_MAX_CONF_INDEX', getApacheSitesAvailableMaxIndex());

message('### TEST ENVIRONMENT CREATOR ###');

// 1. ask for the local domain name
$work = true;
while ($work) {
    message('Enter a valid local Domain Name (suggested .test TLD, as "jane.local.test")');
    $domain = readline('  Type the Domain Name: ');
    $domain = strtolower(str_replace(['http://', 'https://', 'www.'], '', $domain));
    if (filter_var('http://' . $domain, FILTER_VALIDATE_URL)) {
        $work = false;
        define('DOMAIN', $domain);
    } else {
        message('  Error. Retry.', 'e');
    }
}

// 2. ask for the local directory that will be served as the DocumentRoot
$work = true;
while ($work) {
    message('Enter a valid directory in the filesystem for the DocumentRoot');
    $document_root = readline('  Type the DocumentRoot: ');
    if (is_dir($document_root)) {
        $work = false;
        define('DOCUMENT_ROOT', rtrim($document_root, '/'));
    } else {
        message('  Error. Retry.', 'e');
    }
}

// 3. ask for the PHP version for PHP-FPM
$work = true;
while ($work) {
    message('Enter a valid PHP version for PHP-FPM (5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1 or 8.2)');
    $php_version = readline('  Type the PHP version: ');
    if (in_array($php_version, ['5.6', '7.0', '7.1', '7.2', '7.3', '7.4', '8.0', '8.1', '8.2'])) {
        $work = false;
        define('PHPVER', $php_version);
    } else {
        message('  Error. Retry.', 'e');
    }
}

// 4. ask for HTTPS support
$work = true;
while ($work) {
    message('Do you need HTTPS support?');
    $https_support = readline('  Type "yes", "no", "y" or "n": ');
    if (in_array(strtolower($https_support), ['yes', 'no', 'y', 'n'])) {
        $work = false;
        if (in_array(strtolower($https_support), ['yes', 'y'])) {
            define('HTTPS_SUPPORT', true);
        } else {
            define('HTTPS_SUPPORT', false);
        }
    } else {
        message('  Error. Retry.', 'e');
    }
}

// 5. perform actions
$apache_conf_stream = getApacheConf();
$php_fpm_conf_stream = getPhpFpmConf();
$apache_conf_file = APACHE_SITES_AVAILABLE_DIR . APACHE_MAX_CONF_INDEX . '-' . DOMAIN . '.conf';
$php_fpm_conf_file = str_replace('#VER#', PHPVER, PHP_FPM_CONFIG_DIR) . DOMAIN . '.conf';

if (file_put_contents($apache_conf_file, $apache_conf_stream)) {
    message('> Apache configuration written correctly, going to enable the website', 's');
    exec('a2ensite ' . basename($apache_conf_file));

    if (file_put_contents($php_fpm_conf_file, $php_fpm_conf_stream)) {
        message('PHP-FPM configuration written successfully', 's');

        if (HTTPS_SUPPORT) {
            message('Going to CD into ' . APACHE_CERTS_DIR);
            exec('cd ' . APACHE_CERTS_DIR);
            message('Going to call the self-signed cert script ' . APACHE_CERT_SELFSIGNED_SCRIPT . ' with domain "' . DOMAIN . '"');
            exec(APACHE_CERT_SELFSIGNED_SCRIPT . ' ' . DOMAIN);
        }

        message('Going to exec "service apache2 force-reload"');
        exec('service apache2 force-reload');
        message('Going to exec "service php' . PHPVER . '-fpm restart"');
        exec('service php' . PHPVER . '-fpm restart');

        message('### TEST ENVIRONMENT CREATED ###', 's');
    } else {
        message('Cannot write PHP-FPM configuration', 'e');
    }
} else {
    message('Cannot write Apache configuration', 'e');
}

function message(string $string, string $type = 'i')
{
    switch ($type) {
        case 'e': //error
            echo "\033[31m$string \033[0m\n";
            break;
        case 's': //success
            echo "\033[32m$string \033[0m\n";
            break;
        case 'w': //warning
            echo "\033[33m$string \033[0m\n";
            break;
        case 'i': //info
            echo "\033[36m$string \033[0m\n";
            break;
        default:
            echo "$string\n";
            break;
    }
}

function getApacheSitesAvailableMaxIndex() : string
{
    $files = glob(APACHE_SITES_AVAILABLE_DIR . '*.conf');
    if ($files && count($files) > 0) {
        $max_index = 0;
        foreach ($files as $file) {
            $file = basename($file);
            if (preg_match('/^([0-9]+).*\.conf$/ui', $file, $matches)) {
                $index = intval($matches[1]);
                if ($index >= $max_index) {
                    $max_index = $index;
                }
            }
        }

        return str_pad($max_index + 1, 3, '0', STR_PAD_LEFT);
    }

    return '001';
}

function getApacheConf()
{
    $domain = DOMAIN;
    $document_root = DOCUMENT_ROOT;
    $phpver = PHPVER;
    $newline = "\\n";

    $conf_http = <<<HTML
<VirtualHost 127.0.0.1:80>
    ServerName $domain
    ServerAlias www.$domain
    DocumentRoot $document_root
    ServerAdmin admin@localhost.net
    UseCanonicalName Off
    Options -ExecCGI -Includes
    RemoveHandler cgi-script .cgi .pl .plx .ppl .perl
    CustomLog \${APACHE_LOG_DIR}/$domain combined
    CustomLog \${APACHE_LOG_DIR}/$domain-bytes_log "%{%s}t %I .$newline%{%s}t %O ."

    # Enable HTTP2
    Protocols h2 http/1.1

    <FilesMatch \.php$>
        # Apache 2.4.10+ can proxy to unix socket
        SetHandler "proxy:unix:/var/run/php/php$phpver-fpm-$domain.sock|fcgi://localhost/"
    </FilesMatch>

    <IfModule mod_brotli.c>
        AddOutputFilterByType BROTLI_COMPRESS text/html text/plain text/xml text/css text/javascript application/x-javascript application/javascript application/json application/x-font-ttf application/vnd.ms-fontobject image/x-icon
    </IfModule>

    <Directory $document_root/>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        order allow,deny
        allow from all
        Require all granted
    </Directory>

    ##AUTOREWRITE##
</VirtualHost>

HTML;

    $conf_https = <<<HTML
<IfModule mod_ssl.c>
    <VirtualHost 127.0.0.1:443>
        ServerName $domain
        ServerAlias www.$domain
        DocumentRoot $document_root
        ServerAdmin admin@localhost.net
        UseCanonicalName Off
        Options -ExecCGI -Includes
        RemoveHandler cgi-script .cgi .pl .plx .ppl .perl
        CustomLog \${APACHE_LOG_DIR}/ssl-$domain combined
        CustomLog \${APACHE_LOG_DIR}/ssl-$domain-bytes_log "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"

        # Enable HTTP2
        Protocols h2 http/1.1

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
            SSLOptions +StdEnvVars
        </FilesMatch>

        <Directory $document_root/>
            Options -Indexes +FollowSymLinks
            AllowOverride All
            order allow,deny
            allow from all
            Require all granted
        </Directory>

        <IfModule mod_brotli.c>
            AddOutputFilterByType BROTLI_COMPRESS text/html text/plain text/xml text/css text/javascript application/x-javascript application/javascript application/json application/x-font-ttf application/vnd.ms-fontobject image/x-icon
        </IfModule>

        <FilesMatch \.php$>
            # Apache 2.4.10+ can proxy to unix socket
            SetHandler "proxy:unix:/var/run/php/php$phpver-fpm-$domain.sock|fcgi://localhost/"
        </FilesMatch>

        SSLEngine on
        SSLCipherSuite ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv2:+EXP
        SSLCertificateFile "/etc/apache2/certs-selfsigned/$domain.crt"
        SSLCertificateKeyFile "/etc/apache2/certs-selfsigned/$domain.key"
    </VirtualHost>
</IfModule>

HTML;

    if (HTTPS_SUPPORT) {
        return str_replace(
            '##AUTOREWRITE##',
            'RewriteEngine On
            RewriteCond %{HTTPS} off
            RewriteRule ^/(.*) https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]',
            $conf_http
        ) . chr(10) . chr(10) . $conf_https;
    } else {
        return str_replace('##AUTOREWRITE##', '', $conf_http);
    }
}

function getPhpFpmConf()
{
    $domain = DOMAIN;
    $document_root = DOCUMENT_ROOT;
    $phpver = PHPVER;

    $php_fpm_conf = <<<HTML
[$domain]
user = ##LINUX_USERNAME##
group = ##LINUX_USERNAME##
listen = /var/run/php/php$phpver-fpm-$domain.sock
listen.owner = ##LINUX_USERNAME##
listen.group = ##LINUX_USERNAME##
listen.mode = 0660
php_admin_value[disable_functions] = apache_child_terminate,apache_get_modules,apache_getenv,apache_note,apache_setenv,define_syslog_variables,disk_free_space,diskfreespace,dl,fpassthru,get_current_user,getmyuid,highlight_file,passthru,pclose,pcntl_exec,pfsockopen,php_uname,pcntl_alarm,pcntl_fork,pcntl_get_last_error,pcntl_signal,pcntl_getpriority,pcntl_setpriority,pcntl_strerror,pcntl_signal_dispatch,pcntl_sigprocmask,pcntl_waitpid,pcntl_wait,pcntl_sigwaitinfo,pcntl_sigtimedwait,pcntl_wexitstatus,pcntl_wifexited,pcntl_wifsignaled,pcntl_wifstopped,pcntl_wstopsig,pcntl_wtermsig,popen,show_source,socket_select,socket_strerror,stream_select,syslog,symlink
php_admin_flag[allow_url_fopen] = off
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
chdir = /

catch_workers_output = yes
request_terminate_timeout = 180s
slowlog = $document_root/php$phpver-fpm-slow.log
php_flag[display_errors] = off
php_admin_value[error_log] = $document_root/php$phpver-fpm-errors.log
php_admin_flag[log_errors] = on
php_admin_value[post_max_size] = 128M
php_admin_value[upload_max_filesize] = 128M
php_admin_value[memory_limit] = 1024M
php_value[memory_limit] = 1024M
php_value[short_open_tag] =  On

HTML;

    return $php_fpm_conf;
}
