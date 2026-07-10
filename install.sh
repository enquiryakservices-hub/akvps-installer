#!/bin/bash

set -e

clear

echo "=============================================================="
echo "      _    _  _  __ __     ______   _____  _____ "
echo "     / \  | |/ // / \ \   / /  _ \ / ____|/ ____|"
echo "    / _ \ | ' // /   \ \_/ /| |_) | (___ | (___  "
echo "   / ___ \| . \| |    \   / |  __/ \___ \ \___ \ "
echo "  /_/   \_\_|\_\\_\     |_|  |_|    ____) |____) |"
echo ""
echo "             AK VPS Premium Proxy Installer"
echo "=============================================================="
echo " Website : https://akvps.store"
echo " Support : https://t.me/akvps"
echo "=============================================================="
echo ""

# Root Check
if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo."
    exit 1
fi

echo "[1/7] Updating Packages..."
apt update -y

echo "[2/7] Installing Required Packages..."
apt install -y curl wget apache2-utils

echo "[3/7] Downloading Squid Installer..."
wget -q https://raw.githubusercontent.com/serverok/squid-proxy-installer/master/squid3-install.sh -O /tmp/squid3-install.sh

echo "[4/7] Installing Squid..."
bash /tmp/squid3-install.sh

# Detect Config
if [ -f /etc/squid/squid.conf ]; then
    CONF="/etc/squid/squid.conf"
elif [ -f /etc/squid3/squid.conf ]; then
    CONF="/etc/squid3/squid.conf"
else
    echo "Squid configuration not found!"
    exit 1
fi

echo "[5/7] Configuring Squid..."

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

echo "[6/7] Restarting Squid..."
systemctl restart squid

echo "[7/7] Fetching Server Information..."

IP=$(curl -4 -s https://api.ipify.org)

clear

echo "=============================================================="
echo "      _    _  _  __ __     ______   _____  _____ "
echo "     / \  | |/ // / \ \   / /  _ \ / ____|/ ____|"
echo "    / _ \ | ' // /   \ \_/ /| |_) | (___ | (___  "
echo "   / ___ \| . \| |    \   / |  __/ \___ \ \___ \ "
echo "  /_/   \_\_|\_\\_\     |_|  |_|    ____) |____) |"
echo ""
echo "             AK VPS Premium Proxy Installer"
echo "=============================================================="
echo "              INSTALLATION COMPLETED"
echo "=============================================================="
echo ""
echo " Website  : https://akvps.store"
echo " Support  : https://t.me/akvps"
echo ""
echo " Proxy IP : $IP"
echo " Port     : 8000"
echo " Username : $USERNAME"
echo " Password : $PASSWORD"
echo ""
echo " Proxy    : $IP:8000:$USERNAME:$PASSWORD"
echo ""
echo " Thank you for choosing AK VPS!"
echo "=============================================================="
