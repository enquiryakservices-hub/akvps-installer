#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Update package list & install required packages
apt-get update -y >/dev/null 2>&1
apt-get install -y squid apache2-utils ufw curl wget >/dev/null 2>&1

# Stop Squid to update config safely
systemctl stop squid >/dev/null 2>&1 || service squid stop >/dev/null 2>&1

# Open Port 8000 in System Firewall
ufw allow 8000/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT >/dev/null 2>&1 || true

# Config Directories & Auth File
mkdir -p /etc/squid
PASSFILE="/etc/squid/passwd"
CONF="/etc/squid/squid.conf"

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

# Create Password File
htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD" >/dev/null 2>&1
chmod 644 "$PASSFILE"

# Detect dynamic path for basic_ncsa_auth module across different OS versions
AUTH_EXEC=""
if [ -f /usr/lib/squid/basic_ncsa_auth ]; then
    AUTH_EXEC="/usr/lib/squid/basic_ncsa_auth"
elif [ -f /usr/lib64/squid/basic_ncsa_auth ]; then
    AUTH_EXEC="/usr/lib64/squid/basic_ncsa_auth"
elif [ -f /usr/libexec/squid/basic_ncsa_auth ]; then
    AUTH_EXEC="/usr/libexec/squid/basic_ncsa_auth"
fi

# Write Clean Squid Configuration
cat > "$CONF" <<EOF
http_port 8000

auth_param basic program $AUTH_EXEC $PASSFILE
auth_param basic realm AK VPS Proxy
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

forwarded_for off
via off
dns_v4_first on
EOF

# Restart Squid Service
systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1

IP=$(curl -4 -s https://api.ipify.org)

# Output String for WHMCS parsing
echo "FINAL_PROXY_OUTPUT:$IP:8000:$USERNAME:$PASSWORD"
