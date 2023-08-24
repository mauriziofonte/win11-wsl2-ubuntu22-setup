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
define('PHP_CONFIG_DIR', '/etc/php/');

message('### TEST ENVIRONMENT DELETER ###');

// 1. ask for the local domain name
$work = true;
while ($work) {
    message('Enter a valid local Domain Name you previously configured on this Machine (e.g. mydomain.test).');
    $domain = readline('  Type the Domain Name: ');
    $domain = strtolower(str_replace(['http://', 'https://', 'www.'], '', $domain));
    if (filter_var('http://' . $domain, FILTER_VALIDATE_URL)) {
        $work = false;
        define('DOMAIN', $domain);
    } else {
        message('Error. Retry.', 'e');
    }
}

// search for this domain in the available apache conf files
$apacheConfFile = searchForAppliableApacheConf(DOMAIN);
if($apacheConfFile === null) {
    message('ERROR: No Apache Conf file found for this domain. Aborting.', 'e');
    exit();
}

// disable the apache conf file and delete it
$apacheConfName = basename($apacheConfFile, '.conf');
exec("a2dissite {$apacheConfName}");
exec("rm -f " . APACHE_SITES_AVAILABLE_DIR . $apacheConfFile);

// delete the apache certs (DOMAIN.info, DOMAIN.key, DOMAIN.crt)
exec("rm -rf " . APACHE_CERTS_DIR . DOMAIN . '.info');
exec("rm -rf " . APACHE_CERTS_DIR . DOMAIN . '.key');
exec("rm -rf " . APACHE_CERTS_DIR . DOMAIN . '.crt');

// search for this domain in the available php-fpm conf files
$phpFpmConfig = searchForAppliablePhpFpmConf(DOMAIN);
if($phpFpmConfig === null) {
    message('ERROR: No PHP-FPM Conf file found for this domain. Aborting.', 'e');
    exit();
}

// delete the php-fpm conf file
list($phpVersion, $phpFpmConfFile) = $phpFpmConfig;
exec("rm -f " . PHP_CONFIG_DIR . $phpFpmConfFile);
exec("systemctl restart php{$phpVersion}-fpm.service");

// restart apache
exec("systemctl restart apache2.service");

// greet
message('Done. The Test Environment for ' . DOMAIN . ' has been deleted.', 's');

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


function searchForAppliableApacheConf(string $domain) : ?string
{
    $files = scandir(APACHE_SITES_AVAILABLE_DIR);
    foreach ($files as $file) {
        // read the file, and, if it contains the literal string "ServerName $domain" and "ServerAlias www.$domain", return the full file name
        $contents = file_get_contents(APACHE_SITES_AVAILABLE_DIR . $file);
        if (strpos($contents, "ServerName $domain") !== false && strpos($contents, "ServerAlias www.$domain") !== false) {
            return $file;
        }
    }

    return null;
}

function searchForAppliablePhpFpmConf(string $domain) : ?array
{
    // only search inside PHP_CONFIG_DIR/*/fpm/pool.d/
    $folders = scandir(PHP_CONFIG_DIR);

    foreach ($folders as $phpversion) {
        if ($phpversion === '.' || $phpversion === '..' || is_file(PHP_CONFIG_DIR . $phpversion)) {
            continue;
        }

        if (is_dir(PHP_CONFIG_DIR . "{$phpversion}/fpm/pool.d/")) {
            $confs = scandir(PHP_CONFIG_DIR . "{$phpversion}/fpm/pool.d/");
            foreach ($confs as $conf) {
                // read the conf, and, if it contains the literal string [$domain], return the file name
                $contents = file_get_contents(PHP_CONFIG_DIR . "{$phpversion}/fpm/pool.d/{$conf}");
                if (strpos($contents, "[$domain]") !== false) {
                    return [$phpversion, "{$phpversion}/fpm/pool.d/{$conf}"];
                }
            }
        }
    }

    return null;
}
