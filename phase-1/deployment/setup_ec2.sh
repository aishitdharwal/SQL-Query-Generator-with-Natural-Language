#!/bin/bash

# EC2 Instance Setup Script
# Run this script on your EC2 instance after initial launch

set -e

echo "========================================="
echo "EC2 Instance Setup for SQL Query Generator"
echo "========================================="

# Update system packages
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install Python 3 and pip
echo "Installing Python 3 and pip..."
sudo apt install -y python3 python3-pip python3-venv

# Install PostgreSQL client
echo "Installing PostgreSQL client..."
sudo apt install -y postgresql-client

# Install Nginx
echo "Installing Nginx..."
sudo apt install -y nginx

# Install Git (if needed)
echo "Installing Git..."
sudo apt install -y git

# Install system dependencies for psycopg2
echo "Installing build dependencies..."
sudo apt install -y build-essential libpq-dev

# Create application directory
echo "Creating application directory..."
sudo mkdir -p /var/www/sql-query-generator
sudo chown -R ubuntu:ubuntu /var/www/sql-query-generator

# Install supervisor for process management
echo "Installing Supervisor..."
sudo apt install -y supervisor

echo ""
echo "========================================="
echo "System Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Upload your application files to /var/www/sql-query-generator"
echo "2. Set up environment variables"
echo "3. Configure Nginx"
echo "4. Set up backend service"
echo "========================================="
