#!/bin/bash

# Deploy application to EC2
# Run this script from your local machine

set -e

# Configuration
EC2_USER="ubuntu"
EC2_HOST="15.206.94.222"  # Set your EC2 public IP or hostname
APP_DIR="/var/www/sql-query-generator"
LOCAL_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"

echo "========================================="
echo "Deploying to EC2: $EC2_HOST"
echo "========================================="

if [ -z "$EC2_HOST" ]; then
    echo "Error: Please set EC2_HOST in this script"
    exit 1
fi

# Create remote directory
echo "Creating remote directory..."
ssh ${EC2_USER}@${EC2_HOST} "sudo mkdir -p $APP_DIR && sudo chown -R ubuntu:ubuntu $APP_DIR"

# Copy backend files
echo "Copying backend files..."
rsync -avz --exclude='venv' --exclude='__pycache__' \
    ${LOCAL_DIR}/backend/ ${EC2_USER}@${EC2_HOST}:${APP_DIR}/backend/

# Copy frontend files
echo "Copying frontend files..."
rsync -avz \
    ${LOCAL_DIR}/frontend/ ${EC2_USER}@${EC2_HOST}:${APP_DIR}/frontend/

# Copy .env file
echo "Copying .env file..."
scp ${LOCAL_DIR}/.env ${EC2_USER}@${EC2_HOST}:${APP_DIR}/

# Copy deployment configs
echo "Copying deployment configs..."
scp ${LOCAL_DIR}/deployment/nginx.conf ${EC2_USER}@${EC2_HOST}:${APP_DIR}/
scp ${LOCAL_DIR}/deployment/supervisor.conf ${EC2_USER}@${EC2_HOST}:${APP_DIR}/

# Setup backend on remote
echo "Setting up backend environment..."
ssh ${EC2_USER}@${EC2_HOST} << 'EOF'
cd /var/www/sql-query-generator/backend
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate
EOF

# Configure Nginx
echo "Configuring Nginx..."
ssh ${EC2_USER}@${EC2_HOST} << 'EOF'
sudo cp /var/www/sql-query-generator/nginx.conf /etc/nginx/sites-available/sql-query-generator
sudo ln -sf /etc/nginx/sites-available/sql-query-generator /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
EOF

# Configure Supervisor
echo "Configuring Supervisor..."
ssh ${EC2_USER}@${EC2_HOST} << 'EOF'
sudo cp /var/www/sql-query-generator/supervisor.conf /etc/supervisor/conf.d/sql-query-generator.conf
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl restart sql-query-generator-backend
EOF

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Application URL: http://${EC2_HOST}"
echo ""
echo "To check status:"
echo "  ssh ${EC2_USER}@${EC2_HOST} 'sudo supervisorctl status'"
echo ""
echo "To view logs:"
echo "  ssh ${EC2_USER}@${EC2_HOST} 'sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log'"
echo "========================================="
