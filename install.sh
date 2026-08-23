#!/bin/bash

set -e

# Non-interactive execution force karein
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "=============================================================="
echo "      _    _  _  __ __     ______   _____ "
echo "     / \  | |/ /    \ \   / /  _ \ / ____"
echo "    / _ \ | ' /      \ \_/ /| |_) | (___   "
echo "   / ___ \| . \       \   / |  __/ \___ \  "
echo "  /_/   \_\_|\_\       |_|  |_|    ____) "
echo ""
echo "             AK VPS Premium Proxy Installer"
echo "=============================================================="
echo " Website : https://akvps.in"
echo " Support : https://t.me/akvpsdotin"
echo "=============================================================="
echo ""

# Root Check
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] Please run with sudo or as root."
    exit 1
fi

echo "[1/7] Updating Packages..."
apt-get update -y -qq

echo "[2/7] Installing Required Packages (curl, wget, apache2-utils)..."
apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" curl wget apache2-utils

echo "[3/7] Downloading Squid Installer..."
wget -q https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O /tmp/squid3-install.sh

echo "[4/7] Installing Squid Proxy..."
apt-get install -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" squid

# Detect Config Location
if [ -f /etc/squid/squid.conf ]; then
    CONF="/etc/squid/squid.conf"
elif [ -f /etc/squid3/squid.conf ]; then
    CONF="/etc/squid3/squid.conf"
else
    echo "[ERROR] Squid configuration file not found!"
    exit 1
fi

echo "[5/7] Configuring Proxy Credentials..."

sed -i 's/^http_port .*/http_port 8000/' "$CONF"

PASSFILE="/etc/squid/passwd"
mkdir -p /etc/squid

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD"

grep -q "basic_ncsa_auth" "$CONF" || cat >> "$CONF" <<EOF

auth_param basic program /usr/lib/squid/basic_ncsa_auth $PASSFILE
auth_param basic realm AK VPS Proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
EOF

chown proxy:proxy "$PASSFILE" 2>/dev/null || true
chmod 640 "$PASSFILE"

echo "[6/7] Restarting Squid Service..."
systemctl restart squid || service squid restart

echo "[7/7] Fetching Server Details..."
IP=$(curl -4 -s https://api.ipify.org)

echo ""
echo "=============================================================="
echo "              INSTALLATION COMPLETED SUCCESSFULLY"
echo "=============================================================="
echo " Website  : https://akvps.in"
echo " Support  : https://t.me/akvpsdotin"
echo ""
echo " Proxy IP : $IP"
echo " Port     : 8000"
echo " Username : $USERNAME"
echo " Password : $PASSWORD"
echo ""
echo " Proxy Details String -> $IP:8000:$USERNAME:$PASSWORD"
echo "=============================================================="
