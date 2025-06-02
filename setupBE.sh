#!/bin/bash
set -e

# Log start
echo "=== SETUP SCRIPT START: $(date) ==="

# Update & install dependencies
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common jq unzip git

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
sudo unzip awscliv2.zip
sudo ./aws/install

# Install Nginx and Certbot
sudo apt-get install -y nginx certbot python3-certbot-nginx

# Configure Nginx
sudo tee /etc/nginx/sites-available/ttdn-apis.thachpv.id.vn > /dev/null << 'NGINX'
server {
    listen 80;
    server_name ttdn-apis.thachpv.id.vn;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX

sudo ln -sf /etc/nginx/sites-available/ttdn-apis.thachpv.id.vn /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# (Tùy chọn) Lấy SSL certificate từ Let's Encrypt (bỏ comment nếu muốn tự động)
# sudo certbot --nginx -d ttdn-apis.thachpv.id.vn --non-interactive --agree-tos --email your-email@example.com

# Clone repository
cd /home/ubuntu
sudo rm -rf TTDN-BE
git clone https://github.com/kyojin2311/TTDN-BE.git
cd TTDN-BE
sudo chown -R ubuntu:ubuntu .
sudo chmod -R 755 .

# Lấy env từ AWS Secrets Manager (yêu cầu đã cài jq và AWS CLI, và instance có quyền truy cập)
aws secretsmanager get-secret-value --secret-id prod/todolist-be/env --query SecretString --output text > .env.json
cat .env.json | jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' > .env

# Build & run app bằng Docker Compose
sudo docker-compose up -d --build

echo "=== SETUP SCRIPT END: $(date) ==="