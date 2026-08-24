#!/bin/bash

set -e

# Root Check
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 1. Update & Install Dependencies
apt-get update -y -qq
apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl wget apache2-utils squid ufw

# 2. Open Port 8000 in Firewall
ufw allow 8000/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT >/dev/null 2>&1 || true

# 3. Detect Squid Config File
if [ -f /etc/squid/squid.conf ]; then
    CONF="/etc/squid/squid.conf"
elif [ -f /etc/squid3/squid.conf ]; then
    CONF="/etc/squid3/squid.conf"
else
    echo "Squid configuration not found!"
    exit 1
fi

# 4. Configure Port 8000
sed -i 's/^http_port .*/http_port 8000/' "$CONF"

PASSFILE="/etc/squid/passwd"
mkdir -p /etc/squid

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD"

# Remove Old Auth Directives if any
sed -i '/auth_param/d' "$CONF"
sed -i '/basic_ncsa_auth/d' "$CONF"

# Append New Auth Setup
cat >> "$CONF" <<EOF

auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSFILE
auth_param basic realm AK VPS Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
EOF

chown proxy:proxy "$PASSFILE" 2>/dev/null || true
chmod 640 "$PASSFILE"

# 5. Restart Squid Service
systemctl restart squid

# 6. Fetch IP & Output Result
IP=$(curl -4 -s https://api.ipify.org)

echo "FINAL_PROXY_OUTPUT:$IP:8000:$USERNAME:$PASSWORD"
