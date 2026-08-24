#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# 1. Force Install Required Packages
apt-get update -y >/dev/null 2>&1
apt-get install -y squid apache2-utils ufw curl wget >/dev/null 2>&1

# 2. Stop Service to Avoid Lock
systemctl stop squid >/dev/null 2>&1 || true

# 3. Open Port 8000 on Local Firewall
ufw allow 8000/tcp >/dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 8000 -j ACCEPT >/dev/null 2>&1 || true

# 4. Create Passwd File & Credentials
mkdir -p /etc/squid
PASSFILE="/etc/squid/passwd"
CONF="/etc/squid/squid.conf"

USERNAME="user$(tr -dc 'a-z0-9' </dev/urandom | head -c6)"
PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c12)"

htpasswd -cb "$PASSFILE" "$USERNAME" "$PASSWORD" >/dev/null 2>&1
chmod 644 "$PASSFILE"

# 5. Dynamically Locate `basic_ncsa_auth` Helper Executable
NCSA_AUTH=""
if [ -f /usr/lib/squid/basic_ncsa_auth ]; then
    NCSA_AUTH="/usr/lib/squid/basic_ncsa_auth"
elif [ -f /usr/lib64/squid/basic_ncsa_auth ]; then
    NCSA_AUTH="/usr/lib64/squid/basic_ncsa_auth"
elif [ -f /usr/libexec/squid/basic_ncsa_auth ]; then
    NCSA_AUTH="/usr/libexec/squid/basic_ncsa_auth"
fi

# 6. Overwrite Valid Working Squid Config
cat > "$CONF" <<EOF
http_port 8000

auth_param basic program $NCSA_AUTH $PASSFILE
auth_param basic realm AK VPS Proxy
auth_param basic credentialsttl 2 hours
acl authenticated proxy_auth REQUIRED
http_access allow authenticated
http_access deny all

forwarded_for off
via off
dns_v4_first on
EOF

# 7. Start & Enable Squid Service
systemctl restart squid >/dev/null 2>&1 || service squid restart >/dev/null 2>&1
systemctl enable squid >/dev/null 2>&1 || true

IP=$(curl -4 -s https://api.ipify.org)

echo "FINAL_PROXY_OUTPUT:$IP:8000:$USERNAME:$PASSWORD"
