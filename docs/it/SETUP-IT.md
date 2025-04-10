# Setup manuale Docker / Stack LAMP+LAPP su Windows 11 con WSL2, servizi web nativi, VS Code e Ubuntu 24.04 (senza Microsoft Store)

> Ultimo aggiornamento: _10/04/2025_. Versione target Ubuntu: **24.04.1**

Questa guida illustrerà come installare il supporto al sottosistema Linux nativo di Windows (WSL2), installare Ubuntu 24.04 (senza dover utilizzare il Microsoft Store), creare uno stack **LAMP+LAPP** multi-PHP (con servizi nativi tramite _systemd_), installare Docker, e agganciare Visual Studio Code da Windows 11, per sviluppare e debuggare direttamente sulla macchina virtuale.

## Requisiti

1. Computer con **Windows 11**, preferibilmente aggiornato tramite Windows Update
2. 16GB di RAM
3. Almeno 50GB di spazio libero su C:\ (conterrà il disco virtuale di Ubuntu 24.04)
4. Un SSD (meglio se NVMe) come disco principale di Windows
5. Una conoscenza di _medio livello_ del terminale Linux (come usare e cosa sono comandi di base come _cd_, _cp_, _mv_, _sudo_, _nano_, etc.)
6. Il vostro computer **dovrebbe essere protetto da password, usare BitLocker, e disporre di supporto a TPM 2.0** per evitare che malintenzionati possano accedere ad informazioni sensibili, se entrassero in possesso del vostro dispositivo. **Questo è particolarmente importante se intendete maneggiare informazioni per conto terzi (lavoro)**. Le vostre politiche di sicurezza sulla rete e i dispositivi che utilizzate dovrebbero essere consone al tipo di uso del PC che intendete effettuare. In linea generale, _se usate il vostro PC per lavoro, bisogna porre massima attenzione alla protezione_. Prevenire è meglio che curare.

Lo stack **LAMP+LAPP** che andremo a configurare supporta **https** (con certificati autofirmati con scadenza a 30 anni), protocollo **http/2** e **compressione brotli**. Per quanto riguarda la parte PHP, useremo **PHP-FPM** perchè è più performante e più versatile nella configurazione delle impostazioni _per-virtualhost_. Per capire le differenze tra l'utilizzo di PHP con Apache in modalità PHP-CGI piuttosto che PHP-FPM, si rimanda a questa guida: <https://www.basezap.com/difference-php-cgi-php-fpm/>

## Installare Ubuntu 24.04 LTS su Windows in virtualizzazione WSL2

Per installare Ubuntu 24.04 su Windows 11, useremo solo la _PowerShell_ di Windows, senza ricorrere al _Microsoft Store_. Importante: **assicurarsi di avviare la powershell in modalità amministratore**.

Per prima cosa, **scaricare ed installare** <https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi>. Questo è importante. E' un pacchetto aggiuntivo che installa l'aggiornamento _Linux Kernel Update_, necessario per compatibilità con WSL2.

Dopodichè, eseguire su una _PowerShell_ **elevata a privilegi di amministratore** questi comandi:

```cmd
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
Restart-Computer -Force
```

Attendere il riavvio del PC, dopodichè eseguire su una _PowerShell_ **elevata a privilegi di amministratore** questi comandi:

```cmd
wsl --update --web-download
wsl --set-default-version 2
wsl --version
wsl --list --online
```

Il comando `wsl --version` ritornerà le informazioni sulla versione del _sottosistema linux per windows_. Qui un esempio di output aggiornato ad Agosto 2023:

```txt
Versione WSL: 1.2.5.0
Versione kernel: 5.15.90.1
Versione WSLg: 1.0.51
Versione MSRDC: 1.2.3770
Versione Direct3D: 1.608.2-61064218
Versione DXCore: 10.0.25131.1002-220531-1700.rs-onecore-base2-hyp
Versione di Windows: 10.0.22621.2134
```

Dobbiamo assicurarci che **la versione WSL sia maggiore o uguale alla 0.67.6**. Nell'esempio sopra riportato, è tutto OK.

Il comando `wsl --list --online` ritornerà le distribuzioni installabili. Qui un esempio di output aggiornato ad Agosto 2023:

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

Noi siamo interessati alla distribuzione **Ubuntu-24.04**. Quindi, eseguire questo comando su una _PowerShell_ **elevata a privilegi di amministratore**:

```cmd
wsl --install -d Ubuntu-24.04
```

Al termine dell'installazione, in assenza di errori, verrà automaticamente aperta l'istanza della macchina Ubuntu appena installata. Il sistema Ubuntu richiederà di impostare un **nome utente** _(occhio, serve sotto ed è importante)_ -- consiglio di usare una singola parola corta digitata tutta in minuscolo -- e di **specificare una password** per questo utente -- consiglio di usare una sola lettera, per comodità quando si eseguiranno comandi da `sudoer` --

## Modificare il resolver DNS di Ubuntu

Per risolvere permanentemente il problema della risoluzione nomi dominio DNS di Ubuntu via WSL2, seguire queste istruzioni. La procedura richiederà sia l'utilizzo della bash di Ubuntu, sia una _PowerShell_ **elevata a privilegi di amministratore**:

**Su Ubuntu 24.04**

```bash
sudo su -
echo "[network]" | tee /etc/wsl.conf
echo "generateResolvConf = false" | tee -a /etc/wsl.conf
```

**Su Windows, Powershell**

```cmd
wsl --terminate Ubuntu-24.04
```

**Su Ubuntu 24.04** (da avviare nuovamente, perchè il comando precedente lo avrà terminato)

```bash
sudo su -
rm -f /etc/resolv.conf
echo "nameserver 9.9.9.9" | tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | tee -a /etc/resolv.conf
echo "nameserver 216.87.84.211" | tee -a /etc/resolv.conf
echo "nameserver 208.67.222.222" | tee -a /etc/resolv.conf
chattr +i /etc/resolv.conf
```

**Su Windows, Powershell**

```cmd
wsl --terminate Ubuntu-24.04
Get-NetAdapter
```

Ora, leggere l'output del comando `Get-NetAdapter`. Questo comando listerà tutte le interfacce di rete del PC. **Noi siamo interessati alla interfacce che si collegano ad internet**.

Ecco un esempio di output:

```txt
Name                      InterfaceDescription                    ifIndex Status       MacAddress             LinkSpeed
----                      --------------------                    ------- ------       ----------             ---------
Wi-Fi                     Intel(R) Wi-Fi 6E AX210 160MHz               15 Up           4C-77-CB-79-06-03       1.7 Gbps
Connessione di rete Bl... Bluetooth Device (Personal Area Netw...      12 Disconnected 4C-77-CB-79-06-07         3 Mbps
Ethernet                  Intel(R) Ethernet Connection (14) I2...       9 Disconnected A0-29-19-0B-74-1E          0 bps
```

Nell'esempio sopra, l'intefaccia utilizzata per collegarsi ad internet è **Intel(R) Wi-Fi 6E AX210 160MHz**, il cui **ifIndex** è **15**.

Quindi, prendere nota del `ifIndex` corretto, ed eseguire una _PowerShell_ **elevata a privilegi di amministratore**:

```cmd
Set-NetIPInterface -InterfaceIndex [NUMERO_IFINDEX] -InterfaceMetric 6000
```

Con queste istruzioni la macchina Ubuntu 24.04 non dovrebbe avere nessun problema di risoluzione nomi a dominio.

## Abilitare systemd su WSL2

> Systemd è una suite di elementi costitutivi di base per un sistema Linux. Fornisce un gestore di sistema e servizi che viene eseguito come PID 1 e avvia il resto del sistema.
> Molte distribuzioni popolari eseguono systemd per impostazione predefinita, come Ubuntu e Debian. Questa modifica significa che WSL sarà ancora più simile all'utilizzo delle tue distribuzioni Linux preferite su una macchina bare metal e ti consentirà di utilizzare software che dipende dal supporto systemd.

Abilitare _systemd_ è relativamente semplice. Basterà lanciare questo comando su Ubuntu:

```bash
sudo su -
echo "[boot]" | tee -a /etc/wsl.conf
echo "systemd = true" | tee -a /etc/wsl.conf
```

**Su Windows, Powershell**

```cmd
wsl --shutdown
```

Dopodichè, riavviare la macchina Ubuntu.

## Step 0 - Installare Docker Desktop su Windows 11

> Nota: se non si intende utilizzare Docker Desktop, si può saltare questo step, e procedere con lo **Step 1** [Configurare l'ambiente LAMP+LAPP su Ubuntu](#step-1---configurare-lambiente-lamplapp-su-ubuntu)

Per poter utilizzare Docker Desktop su Windows 11, è necessario avere un processore con supporto a **Virtualizzazione** e **Hyper-V**. Se non si è sicuri di avere queste funzionalità abilitate, è possibile verificarle tramite il **Task Manager** di Windows.

Per installare Docker Desktop, scaricare il file di installazione da [https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe](https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe). Seguire le istruzioni di installazione.

> TL;DR: la cosa importante per poter usare correttamente Docker dentro WSL è **lasciare abilitata** l'opzione **Use WSL 2 based engine** durante l'installazione di Docker Desktop, e nelle impostazioni di Docker Desktop. Qui la guida completa: [https://docs.docker.com/desktop/wsl/#turn-on-docker-desktop-wsl-2](https://docs.docker.com/desktop/wsl/#turn-on-docker-desktop-wsl-2)

Al termine dell'installazione, **Riavviare il PC**.

## Step 1 - Configurare l'ambiente LAMP+LAPP su Ubuntu

> Nota: se non si intende configurare l'ambiente LAMP+LAPP, poichè il sistema Ubuntu verrà principalmente usato con Docker, si possono saltare gli step **1, 2, e 3** e procedere dallo **Step 4** [Installare una shell custom, NVM, e ottimizzare l'esperienza utente (opzionale)](#step-4---installare-una-shell-custom-nvm-e-ottimizzare-lesperienza-utente-opzionale)

Qui andremo ad installare tutti i servizi e gli eseguibili di sistema per abilitare il supporto a **PHP** versioni 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3 e 8.4. Abiliteremo anche il **web server Apache** e il server **Mysql**.

**Perchè installare tante versioni di PHP**? E' importante per due motivi:

1. avere a disposizione un **ambiente di sviluppo** che consenta, con facilità, di **testare la propria applicazione con svariate versioni di PHP**. Questo agevolerà il lavoro in caso di constraint specifici sui server di produzione dove andremo ad installare le applicazioni create.
2. in caso un Cliente o un progetto specifico vi richieda di **mantenere e/o modificare una vecchia base di codice funzionante su una specifica versione di PHP**, non avrete difficoltà a rendere funzionante l'ambiente di dev&test in locale.

> Si assume che la versione di default di PHP che si vorrà utilizzare nel sistema sia la **8.4**. Questo è modificabile tramite le righe `update-alternatives --set php***` che si troveranno nella lista qui sotto. Ad esempio, se si desidera che la versione di PHP di default (quella che verrà utilizzata digitando semplicemente il comando `php` e non la sua versione "versionata" es `php7.4`) basterà specificare `update-alternatives --set php /usr/bin/php7.4`. _(Ad ogni modo, questo comportamento verrà in ogni caso modificato con i Bash Alias che andremo a configurare più tardi)_

**IMPORTANTE**: Lanciare tutti questi comando come l'utente `root` su Ubuntu (il comando `sudo su -`). **IMPORTANTE**: Escludere le linee che iniziano con **#** in quanto servono solo a differenziare i vari blocchi.

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

Eseguiti questi comandi, saranno installati tutti i servizi e gli eseguibili necessari per realizzare uno stack LAMP+LAPP con Mysql e PostgreSQL in modalità multi-PHP (multiple versioni di PHP) con PHP-FPM per incrementare le performance.

> Nota: le query mysql relative allo **username e password** (_admin_ e _YOUR-ADMIN-PASS_) da creare come utente privilegiato possono essere modificate a piacimento.
> Nell'esempio sopra riportato viene creato un utente con username `admin` e password `YOUR-ADMIN-PASS`. C'è da dire che **stiamo configurando un ambiente di sviluppo locale**, e fintanto che questo ambiente non viene esposto in internet, non dobbiamo preoccuparci di usare policy particolari riguardanti i nomi utente e la complessità delle password.
> Tuttavia, tengo a precisare che usare nomi utente "facilmente guessabili" e password "ben note" è una **bad practice**.

## Step 2 - Configurare l'ambiente LAMP+LAPP su Ubuntu

Qui andremo a modificare le configurazioni di base di **Apache** e **Mysql** per poter lavorare localmente.

Si riporta il nome del file da modificare, e il contenuto modificato e commentato. Ogni modifica a questi file deve essere eseguita con `sudo nano NOME_FILE`. E' richiesta dimestichezza con lo strumento `nano`. In alternativa, usare l'editor di testo più comodo.

### A. Modificare gli envvars di Apache

Nome file: **/etc/apache2/envvars**

> Sintesi: modificare **APACHE_RUN_USER** e **APACHE_RUN_GROUP** settandoli, al posto che `www-data`, con il proprio **nome utente** (dove c'è scritto `IL_TUO_NOME_UTENTE`)

Contenuto:

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
export APACHE_RUN_USER=IL_TUO_NOME_UTENTE
export APACHE_RUN_GROUP=IL_TUO_NOME_UTENTE
```

### B. Modificare le Porte di Apache

Nome file: **/etc/apache2/ports.conf**

> Sintesi: modificare **ogni occorrenza** di `Listen` con `Listen 127.0.0.1` (indirizzo ip di loopback + porta: 127.0.0.1:80 127.0.0.1:443)

Contenuto:

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

### C. Modificare la configurazione di Mysql

Nome file: **/etc/mysql/mariadb.conf.d/99-custom.cnf**

> Sintesi: adattare la configurazione di Mysql in modo da usare l'autenticazione nativa, una collation di default adeguata, e una modalità di esecuzione delle query "che non dia problemi di compatibilità" (riferimento: <https://dev.mysql.com/doc/refman/8.0/en/sql-mode.html#sqlmode_no_engine_substitution>).
> Inoltre, imposteremo alcune configurazioni specifiche per aumentare le performance in lettura/scrittura (attenzione: bisogna avere un quantitativo adeguato di RAM a disposizione)

Contenuto:

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

### D. Riavviare i servizi

Una volta completate le modifiche alle configurazioni di _Apache_ e _MariaDB_, possiamo riavviare i servizi

```console
sudo su -
systemctl restart apache2.service
systemctl restart mariadb.service
```

## Step 3 - Configurare l'ambiente PHP con Composer e HTE-Cli

Adesso che abbiamo creato e configurato lo stack _LAMP+LAPP_, non ce ne facciamo nulla se non creiamo dei _VirtualHost_ per svilupare o testare applicazioni web sulle diverse versioni di PHP installate sul sistema.

Per creare dei `VirtualHost` utilizzeremo [HTE-Cli](https://github.com/mauriziofonte/hte-cli), un tool **di mia creazione** pensato per agevolare la configurazione di environment di test su nomi dominio fittizi via modifica del _file hosts di Windows_.

Il tool _HTE-Cli_ si occuperà di **auto-configurare** quello che serve sulla base di alcune informazioni basilari per il progetto che vogliamo svlippare o testare.

Inoltre, nel prosieguo del nostro lavoro avremo anche a che fare con `Composer`. In questa parte andremo a configurare Composer per sfruttarlo non solo per _HTE-Cli_, ma anche per _PHP Code Sniffer_ e _PHP CS Fixer_, che ci serviranno per lo sviluppo con _VS Code_.

> **NOTA** : per saperne di più su `HTE-Cli`, [leggere il README dedicato di HTE-Cli](https://github.com/mauriziofonte/hte-cli/blob/main/README.md)

### Installazione di Composer 2 e Composer 1

Per installare l'ultima versione stabile (2.x) di `Composer` _globalmente_, eseguire questo comando:

```bash
wget -O composer.phar https://getcomposer.org/download/latest-stable/composer.phar && sudo mkdir -p /usr/local/bin && sudo mv composer.phar /usr/local/bin/composer && sudo chmod +x /usr/local/bin/composer
```

> **ATTENZIONE** : Composer 2 **non** è compatibile con versioni di PHP minori della `7.2.5`. Per usare Composer su progetti che richiedono PHP 7.2, 7.1, 7.0 o 5.6 sarà quindi necessario utilizzare il _vecchio_ binario di Composer 1

Per installare l'ultima versione del _vecchio_ `Composer 1.x`, (compatibile su PHP 7.2, 7.1, 7.0 e 5.6), eseguire questo comando:

```bash
wget -O composer-oldstable.phar https://getcomposer.org/download/latest-1.x/composer.phar && sudo mkdir -p /usr/local/bin && sudo mv composer-oldstable.phar /usr/local/bin/composer1 && sudo chmod +x /usr/local/bin/composer1
```

> **NOTA** : per mantenere questi binari aggiornati, sarà sufficiente eseguire `sudo /usr/local/bin/composer self-update && sudo /usr/local/bin/composer1 self-update`

### Installare il supporto per HTE-Cli, PHP Code Sniffer e PHP CS Fixer

Per installare il supporto a questi tool, eseguire questi comandi:

```bash
composer global require --dev friendsofphp/php-cs-fixer
composer global require --dev "squizlabs/php_codesniffer=*"
composer global require "mfonte/hte-cli=*"
echo 'export PATH="$(composer config -g home)/vendor/bin:$PATH"' >> ~/.bashrc
```

> **NOTA** : per mantenere questi pacchetti aggiornati, sarà sufficiente eseguire `composer global update`
> **ATTENZIONE** : la directory di installazione dei pacchetti su **Ubuntu 24.04** sarà `~/.config/composer` e non `~/.composer` come ci si potrebbe aspettare: [qui la spiegazione](https://stackoverflow.com/a/38746307/1916292)

### Configurare gli Alias Bash

Ora che abbiamo installato tutto, non ci resta che creare dei _Bash Aliases_ che velocizzino il lavoro.

> Nota: se hai intenzione di utilizzare la bash `gash` come shell predefinita, puoi saltare questo passaggio. Di fatto, questi alias verranno già creati automaticamente da `gash` e non dovrai preoccupartene.

Lanciare quindi `nano .bash_aliases` (oppure `vim .bash_aliases`) e incollare questi alias:

```txt
alias hte="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli create"
alias hte-create="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli create"
alias hte-remove="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli remove"
alias hte-details="sudo /usr/bin/php8.3 -d allow_url_fopen=1 -d memory_limit=1024M ~/.config/composer/vendor/bin/hte-cli details"
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

Una volta finito l'editing del file `.bash_aliases`, eseguire

```bash
source ~/.bash_aliases
```

Con questa configurazione di `.bash_aliases` abbiamo:

1. Aliasato il tool `HTE-Cli` (che, ricordo, serve per gestire i VirtualHost sul sistema) con 4 differenti comandi: `hte`, `hte-create`, `hte-remove`, `hte-details`
2. Creato un alias per **aggiornare i binari di Composer** (installati come binari di sistema su `/usr/local/bin`) con il comando `composer-self-update`. Questo alias aggiornerà sia _Composer 2_ sia _Composer 1_ in una volta sola.
3. Creato un alias per **aggiornare i pacchetti di Composer installati globalmente** con il comando `composer-packages-update`
4. Creato svariati alias per i _flavour_ di utilizzo di `Composer` corrispondenti alle versioni target di PHP che sono installate sul sistema. In sintesi, il comando `composer` utilizzerà **PHP 8.3**, `composer82` utilizzerà **PHP 8.2**, `composer81` utilizzerà **PHP 8.1**, e così via fino a `composer72` che utilizzerà **PHP 7.2**. Parimenti, per utilizzare il **vecchio Composer 1** per sviluppare su progetti datati, basterà usare `1composer72`, oppure `1composer71`, oppure `1composer70`, oppure `1composer56`
5. Creato svariati alias per richiamare il binario di `PHP` su tutte le versioni installate sul sistema, quindi `php` utilizzerà **PHP 8.3**, `php82` utilizzerà **PHP 8.3**, e così via fino a `php56` che utilizzerà **PHP 5.6**
6. Fatto in modo che sia gli alias riguardanti `composer` sia gli alias riguardanti `php` lavorino con due configurazioni specifiche: `allow_url_fopen` settato su _1_, cioè attivo, e `memory_limit` settato su _1024M_.
7. Creato un alias per fare il reset della macchina virtuale Ubuntu con il comando `wslrestart`

> Perchè impostare un limite di memoria per gli alias di PHP e Composer? Perchè di default il limite di memoria sarebbe **"nessun limite"**. Questo è pericoloso, perchè **oscura** eventuali potenziali problematiche sul binario di `Composer` stesso, e più in generale sui comandi che lanciamo via command line. Avere un limite di memoria _non infinito_ per l'esecuzione è sempre buona prassi, perchè evita brutte sorprese poi in produzione.

### Testare la configurazione creando un VirtualHost per PhpMyAdmin

A mero titolo esemplificativo, verrà mostrata l'intera procedura di creazione di un _VirtualHost_ funzionante, che esponga l'applicativo _PhpMyAdmin_ sulla macchina locale. Questa installazione potrà essere di aiuto nel caso in cui si decida di continuare ad utilizzarla per navigare tra i _Database Mysql_ presenti sul sistema, e i dati contenuti all'interno di essi.

```bash
cd ~/
mkdir opt && cd opt/
wget https://files.phpmyadmin.net/phpMyAdmin/5.2.2/phpMyAdmin-5.2.2-all-languages.zip
unzip phpMyAdmin-5.2.2-all-languages.zip && rm -f phpMyAdmin-5.2.2-all-languages.zip && mv phpMyAdmin-5.2.2-all-languages phpmyadmin
```

Ora abbiamo creato la directory radice per l'installazione di _PhpMyAdmin_. Non resta che configurare un VirtualHost funzionante.

> **IMPORTANTE** : le istruzioni che seguono si applicano **a tutti gli ambienti di staging/test locali** che si vorranno abilitare sul sistema tramite il tool `HTE-Cli`

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

Ora, bisogna modificare **il file hosts di Windows** per inserire il puntamento locale al dominio `local.phpmyadmin.test`.

Per modificare il _file hosts_ su Windows 11, possiamo:

1. Usare i _PowerToys_. Per l'installazione e l'utilizzo, si rimanda [alla guida ufficiale di Microsoft](https://learn.microsoft.com/it-it/windows/powertoys/install)
2. Modificare il file `C:\Windows\System32\drivers\etc\hosts` (consiglio di utilizzare **Notepad++**)

Dopodichè, **aprire una command line di Windows in modalità privilegiata** e lanciare `ipconfig /flushdns`

### Finito

**Complimenti**! Se sei arrivato fino a questo punto, hai tutto quello che ti serve per lavorare, ed è possibile navigare sul proprio browser all'indirizzo <https://local.phpmyadmin.test/setup/> per proseguire il setup di PhpMyAdmin.

Per creare altri VirtualHost per altri progetti, **utilizzare sempre le stesse istruzioni seguite per il setup di PhpMyAdmin**. Basterà far puntare il VirtualHost alla directory giusta del proprio progetto, e definire un nome di dominio fittizio che sarà reindirizzato dal _file hosts_ verso `127.0.0.1`

> **NOTE** : per **eliminare** i VirtualHost creati tramite `HTE-Cli`, utilizzare il comando (Alias) `hte-remove`.
> Per **listare** tutti i VirtualHost creati tramite `HTE-Cli`, utilizzare il comando (Alias) `hte-details`

## Step 4 - Installare una shell custom, NVM, e ottimizzare l'esperienza utente (opzionale)

Questi step **sono opzionali** e servono ad ottimizzare l'esperienza utente sulla console dei comandi di Linux (secondo le mie personali preferenze), oltre che ad installare `nvm` (_Node Version Manager_, per lavorare con _Node_, _React_, etc).

Il mio consiglio per i principianti è di installare la Bash **Gash**, che è una Bash minimale e colorata che funziona bene con _git_ e ha un set completo di potenti alias che si adattano bene a questo ambiente LAMP+LAPP. Inoltre, _Gash_ è una mia creazione. Se preferite usare _ZSH_, o qualsiasi altra shell custom, o non vi interessa questo step, sentitevi liberi di saltarlo.

1. Seguire le istruzioni di installazione della Bash **Gash** qui [https://github.com/mauriziofonte/gash](https://github.com/mauriziofonte/gash) - in alternativa, installare _ZSH_, o qualunque altra shell di gradimento: io mi trovo bene con `gash` perchè è un tool che ho creato io, super minimale. Riporto un one-liner per installare _Gash_: `wget -qO- https://raw.githubusercontent.com/mauriziofonte/gash/refs/heads/main/install.sh | bash`
2. Lanciare `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash` per installare NVM (per sviluppo NodeJS/React)
3. Creare una coppia di chiavi pubblica/privata con il comando `ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/nome_chiave -C "utente@computer"` (comunicare il contenuto della chiave pubblica `~/.ssh/nome_chiave.pub`al proprio team, che la userà per esempio per abilitare l'accesso ad un repository GIT privato.)
4. Creare un collegamento alla **home directory di Ubuntu** raggiungibile dal proprio _Desktop_ per visualizzare la home di Ubuntu tramite l'Esplora risorse di Windows: per farlo, cliccare sul _Desktop_ con il tasto destro del Mouse, Selezionare `Nuovo` > `Collegamento`, e immettere nel **percorso del collegamento** la stringa `\\wsl$\Ubuntu-24.04\home\NOME_UTENTE`, dove **NOME_UTENTE** è il nome utente usato su Ubuntu. **Opzionale** : modificare l'icona del collegamento (consiglio questa: [ubuntu-drive-icon.ico](/icons/ubuntu-drive-icon.ico))
5. Creare un collegamento alla _Bash_ di Ubuntu raggiungibile dal proprio _Desktop_ per avviare un nuovo terminale: per farlo, cliccare sul _Desktop_ con il tasto destro del Mouse, Selezionare `Nuovo` > `Collegamento`, e immettere nel **percorso del collegamento** la stringa `C:\Windows\System32\wsl.exe -d Ubuntu-24.04 bash -c "cd /home/NOME_UTENTE && bash"`, dove **NOME_UTENTE** è il nome utente usato su Ubuntu. **Opzionale** : modificare l'icona del collegamento (consiglio questa: [ubuntu-icon.ico](/icons/ubuntu-icon.ico))

> Nota: se hai deciso di **non** installare la _Gash Bash_, ti consiglio di dare un'occhiata al file [confs/bash_local](/confs/bash_local), che contiene un set di utili alias e configurazioni che puoi aggiungere al tuo file `.bash_aliases` (o al tuo file di configurazione della tua shell).

## Step 5 - Installare VS Code per accedere ai file di progetto su WSL2

VS Code è totalmente integrato e compatibile con WSL2, nativamente.

Questo incrementa la produttività e semplifica tantissimo lo sviluppo.

Per installare e configurare VS Code con WSL2 è sufficiente:

1. Installare VS Code scaricandolo da `https://code.visualstudio.com/`
2. Aprire VS Code e premere la combinazione di comandi `CTRL + SHIFT + x`
3. Installare l'estensione **Remote - WSL**
4. Riavviare VS Code
5. Aprire una console di Ubuntu, e portarsi su una directory a piacere, ad esempio `~/opt/` oppure `~/.config/composer`
6. Lanciare il comando `code .` e lasciare che il sistema installi quello che gli serve
7. Fatto! Da questo momento **sarà possibile modificare i file presenti su Ubuntu direttamente da VS Code** installato su Windows.

## Step 6 - Ottimizzare, con le estensioni consigliate, lo sviluppo web su VS Code

Qui riporto un elenco di plugin e configurazioni utili per lo **sviluppo PHP su VS Code**.

> E' **molto importante** che la lista dei plugin che segue venga installata durante una **sessione WSL** all'interno di VS Code.
> Per farlo, portarsi su una directory qualsiasi di Ubuntu, ad esempio `~/opt/` oppure `~/.config/composer`, e lanciare il comando `code .`
> Così facendo, si aprirà VS Code in una sessione WSL e i plugin (e le relative configurazioni di _Environment_ di VS Code) verranno applicate a WSL2, e non su Windows.

Per ogni plugin, è sufficiente premere `CTRL + SHIFT + x` e digitare il nome del plugin da cercare.

1. Cercare **php cs fixer** e installare la versione del plugin di **junstyle** <https://github.com/junstyle/vscode-php-cs-fixer.git>
2. Cercare **GitLens** e installare la versione del plugin di **Eric Amodio** <https://github.com/eamodio/vscode-gitlens>
3. Cercare **Git History** e installare la versione del plugin di **Don Jayamanne**, <https://github.com/DonJayamanne/gitHistoryVSCode>
4. Cercare **PHP Intelephense** e installare la versione del plugin di **Ben Mewburn**, <https://github.com/bmewburn/vscode-intelephense>
5. Cercare **Prettier - Code Formatter** e installare la versione del plugin di **Prettier**, <https://github.com/prettier/prettier-vscode>
6. Cercare **PHP DocBlocker** e installare la versione del plugin di **Nail Brayfield**, <https://github.com/neild3r/vscode-php-docblocker>
7. Cercare **markdownlint** e installare la versione del plugin di **David Anson**, <https://github.com/DavidAnson/vscode-markdownlint>
8. Cercare **Material Icon Theme** e installare la versione del plugin di **Philipp Kief**, <https://github.com/PKief/vscode-material-icon-theme>

Una volta installati tutti i plugin, premere la combinazione di tasti `CTRL + SHIFT + p`, digitare **JSON**, e selezionare su **Preferenze: Apri Impostazioni Remote (JSON) (WSL: Ubuntu-24.04)** (se la lingua di VS Code è inglese, bisognerà selezionare **Preferences: Open Remote Settings (JSON) (WSL: Ubuntu-24.04)**)

A questo punto, copia-incollare la configurazione _JSON_ riportata nello snippet [vscode.json](/confs/vscode.json), modificando la variabile `##LINUX_USERNAME##` con il nome utente utilizzato su Ubuntu.

Questa configurazione contiene sia **impostazioni di mia preferenza personale**, sia impostazioni dedicate a far funzionare i vari **formattatori** e **php cs fixer**.

> **NOTA** : la configurazione consigliata su [vscode.json](/confs/vscode.json) richiede l'installazione dei font [Roboto Sans](https://fonts.google.com/specimen/Roboto) e [Source Code Pro](https://fonts.google.com/specimen/Source+Code+Pro)
> Il font **Roboto Sans** viene utilizzato per l'output sul _terminale integrato_, mentre il font **Source Code Pro** sarà il font utilizzato per il _codice sorgente_, _file markdown_, _readme_, insomma tutti gli editor di testo.
> Si omettono istruzioni precise e puntuali per l'installazione dei font su Windows. Tuttavia, è sufficiente scaricare i file `ttf` dei font, aprirli con Windows, e cliccare su `Installa`.

## Epilogo

### Personalizzazione del Proprio Ecosistema LAMP+LAPP Locale

Questa README è il mio progetto artigianale per installare e configurare un ambiente di sviluppo **locale** _LAMP+LAPP_ su Windows 11 con WSL2. È il frutto delle mie esperienze personali, sia positive che negative, per raggiungere un flusso di lavoro che **mi soddisfi**. E' chiaro che, se questa guida funziona e va bene per me, la tua esperienza o il tuo gusto personale potrebbero essere diversi.

### Contributo della Comunità

Pensi che questo progetto possa essere arricchito? I tuoi contributi possono trasformare questa guida da un lavoro individuale ad un capolavoro comunitario. Apri una issue o crea una pull request per condividere le tue intuizioni.

### Disclaimer di Responsabilità dell'Utente

Procedendo con questa guida, assumi la piena responsabilità per qualsiasi modifica o azione eseguita sul tuo dispositivo. Né l'autore né eventuali collaboratori potranno essere ritenuti responsabili per qualsiasi conseguenza, inclusa ma non limitata a perdita di dati, corruzione del sistema o guasto hardware. **Prosegui a tuo rischio e pericolo.**

### Licenza

Questo progetto è distribuito sotto la licenza MIT. Per ulteriori dettagli, fai riferimento al file [LICENSE](/LICENSE) nel repository
