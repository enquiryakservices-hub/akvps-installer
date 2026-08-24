#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Fast package install without full upgrade delay
apt-get install -y apache2-utils squid ufw curl wget >/dev/null 2>&1

# Port Open
ufw allow 8000/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT >/dev/null 2>&1 || true

# Directories & Credentials
mkdir -p /etc/squid
PASSFILE="/etc/squid/passwd"
CONF="/etc/squid/squid.conf"

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD" >/dev/null 2>&1
chown proxy:proxy "$PASSFILE" 2>/dev/null || true
chmod 640 "$PASSFILE"

# Config Setup
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

# Restart Service
systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1

IP=$(curl -4 -s https://api.ipify.org)

echo "FINAL_PROXY_OUTPUT:$IP:8000:$USERNAME:$PASSWORD"
