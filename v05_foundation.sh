#!/bin/bash
set -e

cd /opt/lexpilot-ovh

echo "=== 1. Stop anciennes API ==="
pkill -f "LexPilot.Api" || true
pkill -f "dotnet run" || true

echo "=== 2. Build / publish API ==="
dotnet build
dotnet publish src/LexPilot.Api/LexPilot.Api.csproj -c Release -o /opt/lexpilot-ovh/publish/api

echo "=== 3. Service systemd API ==="
sudo tee /etc/systemd/system/lexpilot-api.service > /dev/null <<SERVICE
[Unit]
Description=LexPilot API
After=network.target docker.service

[Service]
WorkingDirectory=/opt/lexpilot-ovh/publish/api
ExecStart=/usr/bin/dotnet /opt/lexpilot-ovh/publish/api/LexPilot.Api.dll --urls http://0.0.0.0:5128
Restart=always
RestartSec=5
User=microward
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reload
sudo systemctl enable lexpilot-api
sudo systemctl restart lexpilot-api

echo "=== 4. Correction interface API same-origin ==="
if [ -f web/index.html ]; then
  sed -i 's|const API = "http://51.255.161.205:5128";|const API = "";|' web/index.html
fi

echo "=== 5. Installation Nginx ==="
sudo apt update
sudo apt install -y nginx

echo "=== 6. Configuration Nginx LexPilot ==="
sudo tee /etc/nginx/sites-available/lexpilot > /dev/null <<NGINX
server {
    listen 80;
    server_name _;

    root /opt/lexpilot-ovh/web;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5128/api/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /health {
        proxy_pass http://127.0.0.1:5128/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/lexpilot /etc/nginx/sites-enabled/lexpilot
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

echo "=== 7. Tests ==="
sleep 5
curl http://localhost/health
echo ""
curl http://localhost/api/dashboard
echo ""

echo "=== 8. Git v0.5 ==="
git add .
git commit -m "v0.5 Foundation - systemd nginx same-origin web" || true
git tag -f v0.5-foundation
git push || true
git push origin v0.5-foundation --force || true

echo ""
echo "V0.5 TERMINE"
echo "Interface : http://51.255.161.205"
echo "API health : http://51.255.161.205/health"
