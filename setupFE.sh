#!/bin/bash

exec > >(tee -a /var/log/setup.log) 2>&1

echo "[SETUP] Updating system packages..."
sudo apt-get update -y

echo "[SETUP] Installing required packages..."
sudo apt-get install -y git nginx awscli jq curl


# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
# echo "[SETUP] Configuring AWS CLI..."
# echo "Configuring AWS CLI..."
# aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
# aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region ap-southeast-1
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

cd /home/ubuntu

echo "[SETUP] Cloning repository..."
git clone https://github.com/kyojin2311/TTDN.git
cd TTDN
sudo chown -R ubuntu:ubuntu .
sudo chmod -R 755 .

echo "[SETUP] Fetching environment variables from AWS Secrets Manager..."
aws secretsmanager get-secret-value \
    --secret-id prod/fe/env \
    --query SecretString \
    --output text > .env.json

echo "[SETUP] Converting env JSON to .env file..."
cat .env.json | jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' > .env

echo "[SETUP] Writing Nginx config..."
sudo tee /etc/nginx/sites-available/ttdn.thachpv.id.vn > /dev/null << 'NGINX'
server {
    listen 80;
    server_name ttdn.thachpv.id.vn;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

}
NGINX

echo "[SETUP] Testing Nginx configuration..."
sudo ln -sf /etc/nginx/sites-available/ttdn.thachpv.id.vn /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
echo "[SETUP] Reloading Nginx..."
sudo systemctl restart nginx

echo "[SETUP] Building and running the application with Docker Compose..."
sudo docker-compose up -d --build

echo "[SETUP] Setting up Let's Encrypt SSL..."
sudo certbot --nginx \
    -d ttdn.thachpv.id.vn \
    --non-interactive \
    --agree-tos \
    -m phamvanthach2003@gmail.com

echo "[SETUP] Setup complete!"
