#!/bin/bash

exec > >(tee -a /var/log/setup.log) 2>&1

echo "[SETUP] Updating system packages..."
sudo apt-get update -y

echo "[SETUP] Installing required packages..."
sudo apt-get install -y git docker.io docker-compose nginx awscli jq curl

# echo "[SETUP] Configuring AWS CLI..."
# echo "Configuring AWS CLI..."
# aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
# aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
# aws configure set default.region ap-southeast-1
# aws configure set default.output json

echo "[SETUP] Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

sudo usermod -aG docker ubuntu

echo "[SETUP] Enabling and starting Nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

echo "[SETUP] Installing Certbot for Let's Encrypt..."
sudo apt-get install -y certbot python3-certbot-nginx

echo "[SETUP] Creating app directory..."
mkdir -p /home/ubuntu/app
cd /home/ubuntu/app
sudo chown -R ubuntu:ubuntu .
sudo chmod -R 755 .

echo "[SETUP] Cloning repository..."
git clone https://github.com/kyojin2311/TTDN.git .
cd TTDN
sudo chown -R ubuntu:ubuntu .
sudo chmod -R 755 .

echo "[SETUP] Fetching environment variables from AWS Secrets Manager..."
aws secretsmanager get-secret-value \
    --secret-id prod/todolist/env \
    --query SecretString \
    --output text > .env.json

echo "[SETUP] Converting env JSON to .env file..."
cat .env.json | jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' > .env

echo "[SETUP] Writing Nginx config..."
sudo tee /etc/nginx/conf.d/todo.conf > /dev/null <<EOL
server {
    listen 80;
    server_name ttdn.thachpv.id.vn;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /_next/static {
        proxy_cache STATIC;
        proxy_pass http://localhost:3000;
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        proxy_cache_valid 60m;
        proxy_cache_bypass \$http_upgrade;
        add_header X-Cache-Status \$upstream_cache_status;
    }

    location /public {
        proxy_cache STATIC;
        proxy_pass http://localhost:3000;
        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504;
        proxy_cache_valid 60m;
        proxy_cache_bypass \$http_upgrade;
        add_header X-Cache-Status \$upstream_cache_status;
    }
}
EOL

echo "[SETUP] Testing Nginx configuration..."
sudo nginx -t

echo "[SETUP] Reloading Nginx..."
sudo systemctl reload nginx

echo "[SETUP] Building and running the application with Docker Compose..."
sudo docker-compose up -d --build

echo "[SETUP] Setting up Let's Encrypt SSL..."
# sudo certbot --nginx \
#     -d ttdn.thachpv.id.vn \
#     --non-interactive \
#     --agree-tos \
#     -m phamvanthach2003@gmail.com

echo "[SETUP] Setup complete!"
