#!/bin/bash

# Force Non-Interactive Mode
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# 1. Update & Install Squid FIRST
apt-get update -y -qq >/dev/null 2>&1
apt-get install -y -qq apache2-utils squid ufw curl wget >/dev/null 2>&1

# 2. Open Firewall Port 8000
ufw allow 8000/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT >/dev/null 2>&1 || true

# 3. Detect Squid Config Path (After Installation)
if [ -f /etc/squid/squid.conf ]; then
    CONF="/etc/squid/squid.conf"
elif [ -f /etc/squid3/squid.conf ]; then
    CONF="/etc/squid3/squid.conf"
else
    echo "Squid configuration not found!"
    exit 1
fi

# 4. Create Passwd File & Credentials
PASSFILE="/etc/squid/passwd"
mkdir -p /etc/squid

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD" >/dev/null 2>&1
chown proxy:proxy "$PASSFILE" 2>/dev/null || true
chmod 640 "$PASSFILE"

# 5. Overwrite Clean Working Squid Config
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

# 6. Restart Squid
systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1

# 7. Get Public IP & Output Response
IP=$(curl -4 -s https://api.ipify.org)

echo "FINAL_PROXY_OUTPUT:$IP:8000:$USERNAME:$PASSWORD"
