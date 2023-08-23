#!/usr/bin/env bash

# Check that we're running as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root"
  exit 1
fi

# Check for required commands
command -v openssl >/dev/null 2>&1 || { echo >&2 "openssl is required but it's not installed. Aborting."; exit 1; }

# Ask for the base domain
BASE_DOMAIN="$1"
if [ -z "$BASE_DOMAIN" ]; then
  echo "Usage: $(basename $0) <domain>"
  exit 11
fi

fail_if_error() {
  [ $1 != 0 ] && {
    unset PASSPHRASE
    exit 10
  }
}

# Generate a passphrase
export PASSPHRASE=$(head -c 500 /dev/urandom | tr -dc a-z0-9A-Z | head -c 128; echo)

# Days for the cert to live
DAYS=10950

# Generated configuration file
CONFIG_FILE="config.txt"

cat > $CONFIG_FILE <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
x509_extensions = v3_req
distinguished_name = dn

[dn]
C = IT
ST = Italy
L = Italy
O = Acme Corp
OU = The Dev Team
emailAddress = webmaster@$BASE_DOMAIN
CN = $BASE_DOMAIN

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.$BASE_DOMAIN
DNS.2 = $BASE_DOMAIN
EOF

# The file name can be anything
FILE_NAME="$BASE_DOMAIN"

# Remove previous keys
echo "Removing existing certs like $FILE_NAME.*"
if ls /etc/apache2/certs-selfsigned/$FILE_NAME.* 1> /dev/null 2>&1; then
  rm -rf /etc/apache2/certs-selfsigned/$FILE_NAME.*
fi

echo "Generating certs for $BASE_DOMAIN"

# Generate our Private Key, CSR and Certificate
# Use SHA-2 as SHA-1 is unsupported from Jan 1, 2017

openssl req -new -x509 -newkey rsa:2048 -sha256 -nodes -keyout "/etc/apache2/certs-selfsigned/$FILE_NAME.key" -days $DAYS -out "/etc/apache2/certs-selfsigned/$FILE_NAME.crt" -passin pass:$PASSPHRASE -config "$CONFIG_FILE"

# OPTIONAL - write an info to see the details of the generated crt
openssl x509 -noout -fingerprint -text < "/etc/apache2/certs-selfsigned/$FILE_NAME.crt" > "/etc/apache2/certs-selfsigned/$FILE_NAME.info"

# Protect the key
chmod 400 "/etc/apache2/certs-selfsigned/$FILE_NAME.key"

# Remove the config file
rm -f $CONFIG_FILE