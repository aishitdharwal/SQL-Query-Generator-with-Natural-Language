#!/bin/bash

# SSL Setup using Let's Encrypt (Certbot)
# Run this on your EC2 instance after DNS is configured

set -e

DOMAIN=""  # Set your domain name

echo "========================================="
echo "SSL Setup with Let's Encrypt"
echo "========================================="

if [ -z "$DOMAIN" ]; then
    echo "Error: Please set DOMAIN variable in this script"
    echo "Example: DOMAIN=sql-generator.yourdomain.com"
    exit 1
fi

# Install Certbot
echo "Installing Certbot..."
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate
echo "Obtaining SSL certificate for $DOMAIN..."
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email your-email@example.com

# Setup auto-renewal
echo "Setting up auto-renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

echo ""
echo "========================================="
echo "SSL Setup Complete!"
echo "========================================="
echo ""
echo "Your site is now available at: https://$DOMAIN"
echo ""
echo "Certificate will auto-renew. To test renewal:"
echo "  sudo certbot renew --dry-run"
echo "========================================="
