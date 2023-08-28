# Setup manuale stack LAMP su Windows 11 con WSL2, servizi web nativi, VS Code e Ubuntu 22.04 (senza Microsoft Store)

> Versione
> Ultimo aggiornamento: _23/08/2023_. Versione target Ubuntu: 22.04.03

Questa guida illustrerà come installare il supporto al sottosistema Linux nativo di Windows (WSL2), installare Ubuntu 22.04 (senza dover utilizzare il Microsoft Store), creare uno stack **LAMP** multi-PHP (con servizi nativi tramite _systemd_) e agganciare Visual Studio Code da Windows 11, per sviluppare e debuggare direttamente sulla macchina virtuale.

## Requisiti

1. Computer con **Windows 11**, preferibilmente aggiornato tramite Windows Update
2. 16GB di RAM
3. Almeno 50GB di spazio libero su C:\ (conterrà il disco virtuale di Ubuntu 22.04)
4. Un SSD (meglio se NVMe) come disco principale di Windows
5. Una conoscenza di _medio livello_ del terminale Linux (come usare e cosa sono comandi di base come _cd_, _cp_, _mv_, _sudo_, _nano_, etc.)
6. Il vostro computer **dovrebbe essere protetto da password, usare BitLocker, e disporre di supporto a TPM 2.0** per evitare che malintenzionati possano accedere ad informazioni sensibili, se entrassero in possesso del vostro dispositivo. **Questo è particolarmente importante se intendete maneggiare informazioni per conto terzi (lavoro)**. Le vostre politiche di sicurezza sulla rete e i dispositivi che utilizzate dovrebbero essere consone al tipo di uso del PC che intendete effettuare. In linea generale, _se usate il vostro PC per lavoro, bisogna porre massima attenzione alla protezione_. Prevenire è meglio che curare.

Lo stack **LAMP** che andremo a configurare supporta **https** (con certificati autofirmati con scadenza a 30 anni), protocollo **http/2** e **compressione brotli**. Per quanto riguarda la parte PHP, useremo **PHP-FPM** perchè è più performante e più versatile nella configurazione delle impostazioni _per-virtualhost_. Per capire le differenze tra l'utilizzo di PHP con Apache in modalità PHP-CGI piuttosto che PHP-FPM, si rimanda a questa guida: <https://www.basezap.com/difference-php-cgi-php-fpm/>

## Installare Ubuntu 22.04 LTS su Windows in virtualizzazione WSL2

Per installare Ubuntu 22.04 su Windows 11, useremo solo la _PowerShell_ di Windows, senza ricorrere al _Microsoft Store_. Importante: **assicurarsi di avviare la powershell in modalità amministratore**.

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
Ubuntu-22.04                           Ubuntu 22.04 LTS
OracleLinux_7_9                        Oracle Linux 7.9
OracleLinux_8_7                        Oracle Linux 8.7
OracleLinux_9_1                        Oracle Linux 9.1
openSUSE-Leap-15.5                     openSUSE Leap 15.5
SUSE-Linux-Enterprise-Server-15-SP4    SUSE Linux Enterprise Server 15 SP4
SUSE-Linux-Enterprise-15-SP5           SUSE Linux Enterprise 15 SP5
openSUSE-Tumbleweed                    openSUSE Tumbleweed
```

Noi siamo interessati alla distribuzione **Ubuntu-22.04**. Quindi, eseguire questo comando su una _PowerShell_ **elevata a privilegi di amministratore**:

```cmd
wsl --install -d Ubuntu-22.04
```

Al termine dell'installazione, in assenza di errori, verrà automaticamente aperta l'istanza della macchina Ubuntu appena installata. Il sistema Ubuntu richiederà di impostare un **nome utente** _(occhio, serve sotto ed è importante)_ -- consiglio di usare una singola parola corta digitata tutta in minuscolo -- e di **specificare una password** per questo utente -- consiglio di usare una sola lettera, per comodità quando si eseguiranno comandi da `sudoer` --

## Modificare il resolver DNS di Ubuntu

Per risolvere permanentemente il problema della risoluzione nomi dominio DNS di Ubuntu via WSL2, seguire queste istruzioni. La procedura richiederà sia l'utilizzo della bash di Ubuntu, sia una _PowerShell_ **elevata a privilegi di amministratore**:

**Su Ubuntu 22.04**

```bash
sudo su -
echo "[network]" | tee /etc/wsl.conf
echo "generateResolvConf = false" | tee -a /etc/wsl.conf
```

**Su Windows, Powershell**

```cmd
wsl --terminate Ubuntu-22.04
```

**Su Ubuntu 22.04** (da avviare nuovamente, perchè il comando precedente lo avrà terminato)

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
wsl --terminate Ubuntu-22.04
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

Con queste istruzioni la macchina Ubuntu 22.04 non dovrebbe avere nessun problema di risoluzione nomi a dominio.

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

## Step 1 - Configurare l'ambiente LAMP su Ubuntu

Qui andremo ad installare tutti i servizi e gli eseguibili di sistema per abilitare il supporto a **PHP** versioni 5.6, 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1 e 8.2. Abiliteremo anche il **web server Apache** e il server **Mysql**.

**Perchè installare tante versioni di PHP**? E' importante per due motivi:

1. avere a disposizione un **ambiente di sviluppo** che consenta, con facilità, di **testare la propria applicazione con svariate versioni di PHP**. Questo agevolerà il lavoro in caso di constraint specifici sui server di produzione dove andremo ad installare le applicazioni create.
2. in caso un Cliente o un progetto specifico vi richieda di **mantenere e/o modificare una vecchia base di codice funzionante su una specifica versione di PHP**, non avrete difficoltà a rendere funzionante l'ambiente di dev&test in locale.

> Si presume che la versione di default di PHP che si vorrà utilizzare nel sistema sia la **8.2**. Questo è modificabile tramite le righe `update-alternatives --set php***` che si troveranno nella lista qui sotto. Ad esempio, se si desidera che la versione di PHP di default (quella che verrà utilizzata digitando semplicemente il comando `php` e non la sua versione "versionata" es `php7.4`) basterà specificare `update-alternatives --set php /usr/bin/php7.4`. _(Ad ogni modo, questo comportamento verrà in ogni caso modificato con i Bash Alias che andremo a configurare più tardi)_

**IMPORTANTE**: Lanciare tutti questi comando come l'utente `root` su Ubuntu (il comando `sudo su -`). **IMPORTANTE**: Escludere le linee che iniziano con **#** in quanto servono solo a differenziare i vari blocchi.

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
[digitare questa sequenza di risposte: ENTER + n + Y + "YOUR-ROOT-PASS" + "YOUR-ROOT-PASS" + Y + Y + Y + Y]
mysql -u root -p
DIGITARE "YOUR-ROOT-PASS"
> GRANT ALL ON *.* TO 'admin'@'localhost' IDENTIFIED BY 'YOUR-ADMIN-PASS' WITH GRANT OPTION;
> GRANT ALL ON *.* TO 'admin'@'127.0.0.1' IDENTIFIED BY 'YOUR-ADMIN-PASS' WITH GRANT OPTION;
> FLUSH PRIVILEGES;
> exit
```

Eseguiti questi comandi, saranno installati tutti i servizi e gli eseguibili necessari per realizzare uno stack LAMP (Linux, Apache, Mysql, PHP) in modalità multi-PHP (multiple versioni di PHP) con PHP-FPM per incrementare le performance.

> Nota: le query mysql relative allo **username e password** (_admin_ e _YOUR-ADMIN-PASS_) da creare come utente privilegiato possono essere modificate a piacimento.
> Nell'esempio sopra riportato viene creato un utente con username `admin` e password `YOUR-ADMIN-PASS`. C'è da dire che **stiamo configurando un ambiente di sviluppo locale**, e fintanto che questo ambiente non viene esposto in internet, non dobbiamo preoccuparci di usare policy particolari riguardanti i nomi utente e la complessità delle password.
> Tuttavia, tengo a precisare che usare nomi utente "facilmente guessabili" e password "ben note" è una **bad practice**.

## Step 2 - Configurare l'ambiente LAMP su Ubuntu

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

## Step 3 - Creare dei VirtualHost funzionanti sulla propria installazione locale

Per creare dei `VirtualHost` è sufficiente utilizzare questi due script che velocizzano la configurazione.

A mero titolo esemplificativo, verrà mostrata l'intera procedura di creazione di un _VirtualHost_ funzionante, che esponga l'applicativo _PhpMyAdmin_ sulla macchina locale. Questa installazione potrà essere di aiuto nel caso in cui si decida di continuare ad utilizzarla per navigare tra i _Database Mysql_ presenti sul sistema, e i dati contenuti all'interno di essi.

Prerequisiti:

1. Download del file [create-test-environment.php](/scripts/create-test-environment.php)
2. Download del file [delete-test-environment.php](/scripts/delete-test-environment.php)
3. Download del file [list-test-environments.php](/scripts/list-test-environments.php)
4. Download del file [create-selfsigned-ssl-cert.sh](/scripts/create-selfsigned-ssl-cert.sh)

**Importante:** Dopo aver scaricato i file, modificare `create-test-environment.php` rimpiazzando la stringa `##LINUX_USERNAME##` con il proprio nome utente su Ubuntu.

**Importante:** arrivati a questo punto, se ancora loggati come l'utente `root`, uscire dall'utente `root` e tornare in modalità utente.

```console
sudo mkdir /etc/apache2/certs-selfsigned/
cd ~/
mkdir utils && cd utils/ && mkdir .composer
nano create-test-environment.php ## COPIA-INCOLLARE IL CONTENUTO DEL RELATIVO FILE
nano delete-test-environment.php ## COPIA-INCOLLARE IL CONTENUTO DEL RELATIVO FILE
nano list-test-environments.php ## COPIA-INCOLLARE IL CONTENUTO DEL RELATIVO FILE
nano create-selfsigned-ssl-cert.sh ## COPIA-INCOLLARE IL CONTENUTO DEL RELATIVO FILE
chmod +x create-selfsigned-ssl-cert.sh
cd ~/
mkdir opt && cd opt/
wget https://files.phpmyadmin.net/phpMyAdmin/5.2.1/phpMyAdmin-5.2.1-all-languages.zip
unzip phpMyAdmin-5.2.1-all-languages.zip && rm -f phpMyAdmin-5.2.1-all-languages.zip && mv phpMyAdmin-5.2.1-all-languages phpmyadmin
```

Ora abbiamo creato la directory radice per l'installazione di _PhpMyAdmin_. Non resta che configurare un VirtualHost funzionante.

Lanciare quindi il comando `sudo php ~/utils/create-test-environment.php` e seguire le istruzioni. Queste istruzioni si applicano **a tutti i progetti web** che si vogliono installare sul sistema.

Nell'esempio, il virtualhost per _PhpMyAdmin_ verrà settato come `local.phpmyadmin.test`. Ovviamente, modificare le risposte seguendo il proprio nome utente. Rispondere alle domande dello script come segue:

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

Ora, bisogna modificare **il file hosts di Windows** per inserire il puntamento locale al dominio `local.phpmyadmin.test`.

Per farlo, su Windows 11, avremo bisogno dei _PowerToys_. Per l'installazione, si rimanda [alla guida ufficiale di Microsoft](https://learn.microsoft.com/it-it/windows/powertoys/install).

Una volta installato il pacchetto _Microsoft PowerToys_, usare la funzionalità **Editor dei file degli hosts** > **Avvia l'editor del file degli hosts**. Bisognerà aggiungere il mapping tra il l'_indirizzo_ `local.phpmyadmin.test` e l'_host_ `127.0.0.1`.

Dopodichè, **aprire una command line di Windows in modalità privilegiata** e lanciare `ipconfig /flushdns`

Fatto! Ora è possibile navigare sul proprio browser all'indirizzo <https://local.phpmyadmin.test/setup/> per proseguire il setup di PhpMyAdmin.

Per creare altri VirtualHost per altri progetti, **utilizzare sempre le stesse istruzioni seguite per il setup di PhpMyAdmin**. Basterà far puntare il VirtualHost alla directory giusta del proprio progetto, e definire un nome di dominio fittizio che sarà reindirizzato via _file hosts_ verso `127.0.0.1`

## Step 4 - Ottimizzare l'esperienza Linux

Per ottimizzare l'installazione LAMP e l'esperienza utente sulla console dei comandi di Linux, seguire questi passaggi:

1. Seguire le istruzioni di installazione di `https://github.com/slomkowski/bash-full-of-colors` (o installare _ZSH_, o qualunque altra shell di gradimento: io mi trovo bene con questa bash colorata super minimale, mia opinione personale è che avere meno aiuto possibile sulla bash sia un ottimo modo per non staccare la testa). Riporto un one-liner per installare _Bash full of colors_ `cd ~/ ; git clone https://github.com/slomkowski/bash-full-of-colors.git .bash-full-of-colors ; [ -f .bashrc ] && mv -v .bashrc bashrc.old ; [ -f .bash_profile ] && mv -v .bash_profile bash_profile.old ; [ -f .bash_aliases ] && mv -v .bash_aliases bash_aliases.old ; [ -f .bash_logout ] && mv -v .bash_logout bash_logout.old ; ln -s .bash-full-of-colors/bashrc.sh .bashrc ; ln -s .bash-full-of-colors/bash_profile.sh .bash_profile ; ln -s .bash-full-of-colors/bash_aliases.sh .bash_aliases ; ln -s .bash-full-of-colors/bash_logout.sh .bash_logout ; rm -f bash_logout.old ; rm -f bashrc.old ; rm -f bash_aliases.old`
2. Lanciare `wget -qO- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash` per installare NVM (per sviluppo NodeJS/React)
3. Lanciare `cd ~/utils/.composer/ && wget -O composer.phar https://getcomposer.org/download/latest-stable/composer.phar` per installare una versione locale di Composer v2 all'interno della directory `/utils/.composer/` (l'eseguibile _Composer_ **non** sarà disponibile globalmente nell'istanza Ubuntu: creeremo degli _Alias_ per farlo funzionare)
4. Lanciare `cd ~/utils/.composer/ && wget -O composer-oldstable.phar https://getcomposer.org/download/latest-1.x/composer.phar` per installare una versione locale di Composer v1 all'interno della directory `/utils/.composer/` (l'eseguibile _Composer_ **non** sarà disponibile globalmente nell'istanza Ubuntu: creeremo degli _Alias_ per farlo funzionare). **NOTA**: questa versione di Composer deprecata è utile per far funzionare **vecchi progetti** che non funzionano sulle moderne versioni di PHP.
5. Creare una coppia di chiavi pubblica/privata con il comando `ssh-keygen -o -a 100 -t ed25519 -f ~/.ssh/nome_chiave -C "utente@computer"`
6. Comunicare il contenuto della chiave pubblica al proprio team, che la userà per esempio per abilitare l'accesso ad un repository GIT privato.
7. Copia-incollare il contenuto dello snippet [.bash_local](/confs/bash_local) all'interno di `~/.bash_local` modificando la variabile `$NOME_UTENTE` con il nome dell'utente scelto
8. Creare un collegamento alla **home directory di Ubuntu** raggiungibile dal proprio _Desktop_ per visualizzare la home di Ubuntu tramite l'Esplora risorse di Windows: per farlo, cliccare sul _Desktop_ con il tasto destro del Mouse, Selezionare `Nuovo` > `Collegamento`, e immettere nel **percorso del collegamento** la stringa `\\wsl$\Ubuntu-22.04\home\NOME_UTENTE`, dove **NOME_UTENTE** è il nome utente usato su Ubuntu. **Opzionale** : modificare l'icona del collegamento. Consiglio questa: [ubuntu-drive-icon.ico](/icons/ubuntu-drive-icon.ico)
9. Creare un collegamento alla _Bash_ di Ubuntu raggiungibile dal proprio _Desktop_ per avviare un nuovo terminale: per farlo, cliccare sul _Desktop_ con il tasto destro del Mouse, Selezionare `Nuovo` > `Collegamento`, e immettere nel **percorso del collegamento** la stringa `C:\Windows\System32\wsl.exe -d Ubuntu-22.04 bash -c "cd ~ && bash"`. **Opzionale** : modificare l'icona del collegamento. Consiglio questa: [ubuntu-icon.ico](/icons/ubuntu-icon.ico)

### Note importanti sugli Alias abilitati tramite .bash_local

> Gli alias configurati precedentemente tramite creazione del file `.bash_local` contengono alcuni shortcut utili, facili da memorizzare.
> Si consiglia una lettura di questo file e si ricorda che è sempre possibile modificarlo a proprio piacimento.

1. E' possibile fare il reset della macchina virtuale Ubuntu con il comando `wslrestart`
2. Non è necessario specificare opzioni particolari per il comando `ls`, in quanto è già stato aliasato con le opzioni più consone per avere tutti i dettagli verbosi della directory
3. Il comando `composer` (di default, la versione 2) è stato declinato in svariati _flavour_ corrispondenti alle versioni target di PHP che sono installate sul sistema. In sintesi, il comando `composer` utilizzerà **PHP 8.2**, `composer81` utilizzerà **PHP 8.1**, `composer80` utilizzerà **PHP 8.0**, e così via fino a `composer72` che utilizzerà **PHP 7.2**. Se invece si desiderasse utilizzare il **vecchio e deprecato Composer 1** per sviluppare su progetti davvero datati, basterà usare `1composer72`, oppure `1composer71`, oppure `1composer70`, oppure `1composer56`. In questo caso, verrà usato dietro le quinte il _binario_ `composer-oldstable.phar` precedentemente scaricato
4. Similarmente a quanto sopra riportato, anche la _CLI_ di PHP è soggetta ad Aliasing, in quanto abbiamo installato svariate versioni di PHP durante il setup. Quindi, se si desidera utilizzare una CLI di PHP di una versione specifica, basterà digitare `php` per la versione **8.2**, `php81` per la versione **8.1**, `php80` per la versione **8.0**, e così via fino a `php56` per la versione **5.6**
5. E' possibile mantenere aggiornati i _binari_ di _Composer_ con l'alias `updatecomposer`
6. E' possibile **creare gli ambienti di test/staging** con l'alias `create-test-env`. L'alias si occuperà di richiamare lo script `~/utils/create-test-environment.php`
7. E' possibile **RIMUOVERE gli ambienti di test/staging** creati precedentemente con l'alias `remove-test-env`. L'alias si occuperà di richiamare lo script `~/utils/delete-test-environment.php`
8. E' possibile **listare** ambienti di test/staging creati precedentemente con l'alias `list-test-envs`. L'alias si occuperà di richiamare lo script `~/utils/list-test-environments.php`

## Step 5 - Installare VS Code per accedere ai file di progetto su WSL2

VS Code è totalmente integrato e compatibile con WSL2, nativamente.

Questo incrementa la produttività e semplifica tantissimo lo sviluppo.

Per installare e configurare VS Code con WSL2 è sufficiente:

1. Installare VS Code scaricandolo da `https://code.visualstudio.com/`
2. Aprire VS Code e premere la combinazione di comandi `CTRL + SHIFT + x`
3. Installare l'estensione **Remote - WSL**
4. Riavviare VS Code
5. Aprire una console di Ubuntu, e portarsi su una directory a piacere, ad esempio `~/utils/`
6. Lanciare il comando `code .` e lasciare che il sistema installi quello che gli serve
7. Voilà, **ora è possibile modificare i file presenti su Ubuntu direttamente da VS Code!**

## Step 6 - Ottimizzare, con le estensioni consigliate, lo sviluppo web su VS Code

Portarsi su una console di Ubuntu e lanciare questi comandi:

1. `cd ~/utils/`
2. `mkdir .composer && cd .composer/`
3. `nano composer.json` e inserire questo contenuto all'interno:

```json
{
    "require": {
        "squizlabs/php_codesniffer": "^3",
        "friendsofphp/php-cs-fixer": "^3"
    }
}
```

Dopodichè, lanciare questo comando: `composer install`

Da questo momento abbiamo a disposizione i binari di **php-cs-fixer** e **php codesniffer**, ci serviranno per la config di VS Code.

Quindi, ecco gli step da seguire per configurare e ottimizzare **VS Code** per lo sviluppo PHP:

1. Aprire VS Code, e portarsi su un progetto residente dentro Ubuntu per rimanere in "modalità WSL2"
2. Premere `CTRL + SHIFT + x`, cercare **php cs fixer** e installare la versione del plugin di **junstyle** (<https://github.com/junstyle/vscode-php-cs-fixer.git>)
3. Installare le seguenti estensioni: **GitLens** (Eric Amodio, <https://github.com/eamodio/vscode-gitlens>), **Git History** (Don Jayamanne, <https://github.com/DonJayamanne/gitHistoryVSCode>), **PHP Intelephense** (Ben Mewburn, <https://github.com/bmewburn/vscode-intelephense>), **Prettier - Code Formatter** (Prettier, <https://github.com/prettier/prettier-vscode>), **PHP DocBlocker** (Nail Brayfield, <https://github.com/neild3r/vscode-php-docblocker>), **Twig Language** (mblode, <https://github.com/mblode/vscode-twig-language>), **markdownlint** (David Anson, <https://github.com/DavidAnson/vscode-markdownlint>)
4. Installare il seguente pacchetto icone: **Material Icon Theme** (Philipp Kief, <https://github.com/PKief/vscode-material-icon-theme>)
5. Premere la combinazione di tasti `CTRL + SHIFT + p`, digitare **preferenze**, e cliccare su **Preferenze: Apri Impostazioni (JSON)**
6. Copia-incollare la configurazione riportata nello snippet [vscode.json](/confs/vscode.json), modificando la variabile `$NOME_UTENTE` con il nome utente utilizzato su Ubuntu.
