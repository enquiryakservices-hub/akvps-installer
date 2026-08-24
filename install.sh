#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Direct install without update delay
apt-get install -y apache2-utils squid ufw curl wget >/dev/null 2>&1

mkdir -p /etc/squid
PASSFILE="/etc/squid/passwd"
CONF="/etc/squid/squid.conf"

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD" >/dev/null 2>&1
chmod 640 "$PASSFILE"

cat > "$CONF" <<EOF
http_port 8000

auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSFILE
auth_param basic realm AK VPS Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

forwarded_for off
via off
EOF

systemctl restart squid >/dev/null 2>&1

IP=$(curl -4 -s https://api.ipify.org)

echo "FINAL_PROXY_OUTPUT:$IP:8000:$USERNAME:$PASSWORD"
