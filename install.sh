#!/bin/bash
# =============================================
# RG-AIO VPS Auto Installer
# Created by: Rahamat Gazi (RG)
# GitHub: https://github.com/RahamatGazi/RG-AIO
# OS Support: Ubuntu 24.04
# =============================================

# ✅ Install menu script
wget -O /usr/bin/menu https://raw.githubusercontent.com/RahamatGazi/RG-AIO/main/menu
chmod +x /usr/bin/menu

clear
echo -e "\e[92m=============================================="
echo -e "  🛡️ RG-AIO VPN TUNNELING AUTO INSTALLER"
echo -e "  📦 Created by: Rahamat Gazi (RG)"
echo -e "==============================================\e[0m"
sleep 2

# ✅ Root check
if [ "$(id -u)" != "0" ]; then
   echo "⛔ This script must be run as root"
   exit 1
fi

# ✅ Detect IP
MYIP=$(curl -s ipv4.icanhazip.com)

# ✅ Update system & install packages
apt update -y && apt upgrade -y
apt install -y curl wget screen net-tools unzip nginx dropbear openssh-server socat cron lsof

# ✅ Enable OpenSSH
systemctl enable ssh
systemctl restart ssh

# ✅ Configure Dropbear
sed -i 's/NO_START=1/NO_START=0/' /etc/default/dropbear
sed -i 's/DROPBEAR_PORT=22/DROPBEAR_PORT=443/' /etc/default/dropbear
echo "/bin/false" >> /etc/shells
systemctl enable dropbear
systemctl restart dropbear

# ✅ Ask for domain
read -p "🌐 Enter your domain for SSL (example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "⛔ Domain required for SSL WebSocket. Exiting."
    exit 1
fi

# ✅ Generate fake SSL cert (for future use)
mkdir -p /etc/ssl/rg
openssl req -newkey rsa:2048 -x509 -days 365 -nodes \
  -out /etc/ssl/rg/cert.crt \
  -keyout /etc/ssl/rg/private.key \
  -subj "/CN=$DOMAIN"

# ✅ Setup nginx reverse proxy for WebSocket TLS (443)
cat > /etc/nginx/sites-enabled/rg-ws.conf << EOF
server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate     /etc/ssl/rg/cert.crt;
    ssl_certificate_key /etc/ssl/rg/private.key;

    location /sshws {
        proxy_pass http://127.0.0.1:8880;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }
}
EOF

systemctl restart nginx

# ✅ Install websocketd for stable WebSocket server
wget -O websocketd.zip https://github.com/joewalnes/websocketd/releases/download/v0.4.1/websocketd-0.4.1-linux_amd64.zip
unzip websocketd.zip
mv websocketd /usr/bin/
chmod +x /usr/bin/websocketd

# ✅ Create sshws.service using websocketd
cat > /etc/systemd/system/sshws.service << 'EOF'
[Unit]
Description=SSH over WebSocket - Rahamat Gazi (RG)
After=network.target

[Service]
ExecStart=/usr/bin/websocketd --port=8880 /bin/login
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# ✅ Enable and start sshws service
systemctl daemon-reload
systemctl enable sshws
systemctl restart sshws

# ✅ Clean up temp files
rm -f websocketd.zip

# ✅ Final Success Message
clear
echo -e "\e[92m=============================================="
echo -e " ✅ RG-AIO VPN Installed Successfully!"
echo -e " 🔐 IP Address    : $MYIP"
echo -e " 🔐 SSH Port      : 22"
echo -e " 🔐 Dropbear Port : 443"
echo -e " 🔌 WebSocket     : ws://$MYIP:8880"
echo -e " 🔐 WebSocket TLS : wss://$DOMAIN/sshws"
echo -e " 📦 Created by: Rahamat Gazi (RG)"
echo -e "==============================================\e[0m"
