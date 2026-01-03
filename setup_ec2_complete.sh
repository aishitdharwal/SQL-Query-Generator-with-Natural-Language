#!/bin/bash

# Complete Setup Script for SQL Query Generator on EC2
# Run this script after cloning the repo on EC2

set -e

echo "========================================="
echo "SQL Query Generator - Complete Setup"
echo "========================================="
echo ""

# Get the script directory (where the repo is cloned)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_DIR="$SCRIPT_DIR/phase-1"

echo "Application directory: $APP_DIR"
echo ""

# Check if .env exists
if [ ! -f "$APP_DIR/.env" ]; then
    echo "Error: .env file not found at $APP_DIR/.env"
    echo "Please create .env file from .env.example and configure it"
    exit 1
fi

# Step 1: Update system packages
echo "Step 1: Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Step 2: Install dependencies
echo "Step 2: Installing dependencies..."
sudo apt install -y python3 python3-pip python3-venv
sudo apt install -y postgresql-client
sudo apt install -y nginx
sudo apt install -y supervisor
sudo apt install -y build-essential libpq-dev

# Step 3: Setup backend
echo "Step 3: Setting up backend..."
cd "$APP_DIR/backend"

# Create virtual environment
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

# Install Python packages
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
deactivate

echo "Backend setup complete!"

# Step 4: Update frontend config for production
echo "Step 4: Configuring frontend for production..."
cat > "$APP_DIR/frontend/js/config.js" << 'EOF'
// Production API Configuration
const API_BASE_URL = window.location.origin;

const API_ENDPOINTS = {
    LOGIN: `${API_BASE_URL}/api/login`,
    LOGOUT: `${API_BASE_URL}/api/logout`,
    SESSION: `${API_BASE_URL}/api/session`,
    SCHEMA: `${API_BASE_URL}/api/schema`,
    TABLES: `${API_BASE_URL}/api/tables`,
    TABLE: `${API_BASE_URL}/api/table`,
    GENERATE_SQL: `${API_BASE_URL}/api/generate-sql`,
    EXECUTE_QUERY: `${API_BASE_URL}/api/execute-query`,
    QUERY: `${API_BASE_URL}/api/query`,
};
EOF

echo "Frontend configured for production!"

# Step 5: Configure Nginx
echo "Step 5: Configuring Nginx..."

# Get EC2 public IP
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo "localhost")

# Create Nginx config
sudo tee /etc/nginx/sites-available/sql-query-generator > /dev/null << EOF
server {
    listen 80;
    server_name $EC2_PUBLIC_IP;

    # Frontend - Serve static files
    location / {
        root $APP_DIR/frontend;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # Backend API - Proxy to FastAPI
    location /api/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:8080/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }

    # API docs
    location /docs {
        proxy_pass http://127.0.0.1:8080/docs;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }

    location /redoc {
        proxy_pass http://127.0.0.1:8080/redoc;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/json application/javascript;
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/sql-query-generator /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test and restart Nginx
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "Nginx configured and running!"

# Step 6: Configure Supervisor
echo "Step 6: Configuring Supervisor..."

sudo tee /etc/supervisor/conf.d/sql-query-generator.conf > /dev/null << EOF
[program:sql-query-generator-backend]
directory=$APP_DIR/backend
command=$APP_DIR/backend/venv/bin/python main.py
user=ubuntu
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stderr_logfile=/var/log/supervisor/sql-query-generator-backend.err.log
stdout_logfile=/var/log/supervisor/sql-query-generator-backend.out.log
environment=PATH="$APP_DIR/backend/venv/bin"
EOF

# Load environment variables into supervisor
sudo tee -a /etc/supervisor/conf.d/sql-query-generator.conf > /dev/null << EOF
EOF

# Read .env and add to supervisor config
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    
    # Remove quotes from value if present
    value=$(echo "$value" | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    
    # Append to environment line (comma-separated)
    if [ -n "$key" ] && [ -n "$value" ]; then
        sudo sed -i "/^environment=/ s/$/,$key=\"$value\"/" /etc/supervisor/conf.d/sql-query-generator.conf
    fi
done < "$APP_DIR/.env"

# Reload supervisor
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start sql-query-generator-backend

echo "Supervisor configured and backend started!"

# Step 7: Test database connectivity
echo "Step 7: Testing database connectivity..."

# Source environment variables
set -a
source "$APP_DIR/.env"
set +a

# Test connection
if PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d postgres -p $DB_PORT -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✓ Database connection successful!"
else
    echo "✗ Warning: Could not connect to database. Please check:"
    echo "  - DB_HOST in .env"
    echo "  - Aurora security group allows this EC2 IP"
    echo "  - Aurora is publicly accessible"
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Your application is now running!"
echo ""
echo "Access URL: http://$EC2_PUBLIC_IP"
echo ""
echo "Useful commands:"
echo "  - Check backend status: sudo supervisorctl status"
echo "  - View backend logs: sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log"
echo "  - Restart backend: sudo supervisorctl restart sql-query-generator-backend"
echo "  - Check Nginx status: sudo systemctl status nginx"
echo "  - Restart Nginx: sudo systemctl restart nginx"
echo ""
echo "Login credentials:"
echo "  Sales: sales_user / sales_secure_pass_123"
echo "  Marketing: marketing_user / marketing_secure_pass_123"
echo "  Operations: operations_user / operations_secure_pass_123"
echo ""
echo "========================================="
