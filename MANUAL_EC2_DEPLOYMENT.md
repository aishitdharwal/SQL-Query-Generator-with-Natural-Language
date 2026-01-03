# Manual EC2 Deployment Guide

Complete step-by-step guide for manually deploying the SQL Query Generator to AWS EC2.

## Overview

This guide walks you through:
1. Creating an EC2 instance
2. Configuring security groups
3. Cloning the repository
4. Running the automated setup script
5. Accessing your application

**Time required:** ~15-20 minutes

## Prerequisites

- AWS account
- SSH key pair for EC2
- Aurora PostgreSQL database already set up (from Part 1)
- Claude API key

## Step 1: Create EC2 Instance

### 1.1 Launch Instance

1. Go to **AWS Console** → **EC2** → **Launch Instance**

2. **Name and Tags:**
   - Name: `sql-query-generator`

3. **Application and OS Images:**
   - Select: **Ubuntu Server 22.04 LTS**
   - Architecture: **64-bit (x86)**

4. **Instance Type:**
   - Development: `t3.small` (2 vCPU, 2 GB RAM) - ~$15/month
   - Production: `t3.medium` (2 vCPU, 4 GB RAM) - ~$30/month
   - Select: `t3.small`

5. **Key Pair:**
   - Select existing or create new key pair
   - Download `.pem` file and save it securely
   - **Important:** You'll need this to SSH into the instance

6. **Network Settings:**
   - Click **Edit**
   - Select your VPC (or default VPC)
   - Select a public subnet
   - **Auto-assign public IP:** Enable

7. **Firewall (Security Groups):**
   - Create new security group or select existing
   - Name: `sql-query-generator-sg`
   - Add these rules:

   | Type  | Port | Source      | Description        |
   |-------|------|-------------|--------------------|
   | SSH   | 22   | My IP       | SSH access         |
   | HTTP  | 80   | 0.0.0.0/0   | Web traffic        |
   | HTTPS | 443  | 0.0.0.0/0   | Secure web traffic |

8. **Configure Storage:**
   - Size: **20 GB** (gp3)
   - This is sufficient for the application

9. **Advanced Details:**
   - Leave defaults

10. Click **Launch Instance**

### 1.2 Wait for Instance to Start

- Wait 1-2 minutes for instance to enter **Running** state
- Note down the **Public IPv4 address** - you'll need this!

### 1.3 Update Aurora Security Group

**Important:** Allow your EC2 instance to connect to Aurora database.

1. Go to **RDS** → **Databases** → Your Aurora cluster
2. Click on **VPC security groups**
3. **Edit inbound rules** → **Add rule**
   - Type: **PostgreSQL**
   - Port: **5432**
   - Source: **Custom** → Select your EC2 security group
   - OR Source: **Custom** → Enter EC2 private IP with `/32`
4. **Save rules**

## Step 2: Connect to EC2 Instance

### 2.1 Set Key Permissions (First time only)

```bash
# On your local machine
chmod 400 ~/path/to/your-key.pem
```

### 2.2 SSH into Instance

```bash
ssh -i ~/path/to/your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

Replace `YOUR_EC2_PUBLIC_IP` with the public IP from Step 1.2.

**Example:**
```bash
ssh -i ~/Downloads/my-key.pem ubuntu@54.123.45.67
```

You should see:
```
Welcome to Ubuntu 22.04.3 LTS
```

## Step 3: Clone Repository

### 3.1 Install Git (if needed)

```bash
sudo apt update
sudo apt install -y git
```

### 3.2 Clone Your Repository

**Option A: If your code is on GitHub:**
```bash
cd ~
git clone https://github.com/YOUR_USERNAME/SQL-Query-Generator-with-Natural-Language.git
cd SQL-Query-Generator-with-Natural-Language
```

**Option B: If code is on your local machine:**

On your **local machine**, upload the code:
```bash
# From your local machine (new terminal)
cd /path/to/SQL-Query-Generator-with-Natural-Language
scp -i ~/path/to/your-key.pem -r . ubuntu@YOUR_EC2_PUBLIC_IP:~/sql-query-generator/
```

Then on EC2:
```bash
cd ~/sql-query-generator
```

**Option C: Create GitHub repo and push (recommended):**

On your **local machine**:
```bash
cd "/Users/aishitdharwal/Documents/AI Classroom/SQL-Query-Generator-with-Natural-Language"

# Initialize git if not already
git init
git add .
git commit -m "Initial commit - SQL Query Generator POC"

# Create repo on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/SQL-Query-Generator.git
git push -u origin main
```

Then on EC2:
```bash
cd ~
git clone https://github.com/YOUR_USERNAME/SQL-Query-Generator.git
cd SQL-Query-Generator
```

## Step 4: Configure Environment

### 4.1 Create .env File

```bash
cd ~/SQL-Query-Generator-with-Natural-Language/phase-1
# or cd ~/sql-query-generator/phase-1
# or cd ~/SQL-Query-Generator/phase-1

nano .env
```

### 4.2 Add Your Configuration

Copy this template and fill in your values:

```bash
# AWS Configuration
AWS_REGION=ap-south-1
AWS_PROFILE=default

# Aurora PostgreSQL Configuration
DB_CLUSTER_IDENTIFIER=sql-generator-aurora-cluster
DB_INSTANCE_IDENTIFIER=sql-generator-aurora-instance
DB_MASTER_USERNAME=postgres
DB_MASTER_PASSWORD=YOUR_ACTUAL_PASSWORD
DB_PORT=5432

# Database Endpoint (from Aurora)
DB_HOST=sql-generator-aurora-cluster.cluster-XXXX.ap-south-1.rds.amazonaws.com

# Security Group (from setup)
SECURITY_GROUP_ID=sg-xxxxx

# Team Database Names
SALES_DB_NAME=sales_db
MARKETING_DB_NAME=marketing_db
OPERATIONS_DB_NAME=operations_db

# Team Credentials
SALES_TEAM_USERNAME=sales_user
SALES_TEAM_PASSWORD=sales_secure_pass_123

MARKETING_TEAM_USERNAME=marketing_user
MARKETING_TEAM_PASSWORD=marketing_secure_pass_123

OPERATIONS_TEAM_USERNAME=operations_user
OPERATIONS_TEAM_PASSWORD=operations_secure_pass_123

# Claude API Configuration
ANTHROPIC_API_KEY=YOUR_ACTUAL_CLAUDE_API_KEY
CLAUDE_MODEL=claude-sonnet-4-5-20250929

# Application Configuration
APP_SECRET_KEY=some_random_secret_key_here
```

**Important values to update:**
- `DB_MASTER_PASSWORD` - Your Aurora master password
- `DB_HOST` - Your Aurora cluster endpoint
- `ANTHROPIC_API_KEY` - Your Claude API key

Save and exit: `Ctrl+X`, then `Y`, then `Enter`

### 4.3 Verify .env File

```bash
cat .env
# Make sure all values are correct
```

## Step 5: Run Setup Script

### 5.1 Make Script Executable

```bash
cd ~/SQL-Query-Generator-with-Natural-Language
# or cd ~/sql-query-generator
# or cd ~/SQL-Query-Generator

chmod +x setup_ec2_complete.sh
```

### 5.2 Run Setup Script

```bash
./setup_ec2_complete.sh
```

This script will:
1. ✅ Update system packages
2. ✅ Install Python, PostgreSQL client, Nginx, Supervisor
3. ✅ Setup Python virtual environment
4. ✅ Install Python dependencies
5. ✅ Configure frontend for production
6. ✅ Configure Nginx as reverse proxy
7. ✅ Configure Supervisor to run backend
8. ✅ Test database connectivity
9. ✅ Start the application

**Expected output:**
```
=========================================
SQL Query Generator - Complete Setup
=========================================

Step 1: Updating system packages...
Step 2: Installing dependencies...
Step 3: Setting up backend...
Step 4: Configuring frontend for production...
Step 5: Configuring Nginx...
Step 6: Configuring Supervisor...
Step 7: Testing database connectivity...
✓ Database connection successful!

=========================================
Setup Complete!
=========================================

Your application is now running!

Access URL: http://54.123.45.67
...
```

**Time:** This takes about 5-10 minutes depending on network speed.

## Step 6: Verify Deployment

### 6.1 Check Backend Status

```bash
sudo supervisorctl status
```

Should show:
```
sql-query-generator-backend    RUNNING   pid 12345, uptime 0:00:30
```

### 6.2 Check Backend Logs

```bash
sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log
```

Should see:
```
INFO:     Started server process
INFO:     Uvicorn running on http://0.0.0.0:8080
INFO:     Application startup complete.
```

Press `Ctrl+C` to exit log view.

### 6.3 Check Nginx Status

```bash
sudo systemctl status nginx
```

Should show: `active (running)`

### 6.4 Test Health Endpoint

```bash
curl http://localhost:8080/health
```

Should return:
```json
{"status":"healthy"}
```

## Step 7: Access Your Application

### 7.1 Open in Browser

Open your web browser and go to:
```
http://YOUR_EC2_PUBLIC_IP
```

Example: `http://54.123.45.67`

### 7.2 Login

Use the demo credentials:

**Sales Team:**
- Username: `sales_user`
- Password: `sales_secure_pass_123`

**Marketing Team:**
- Username: `marketing_user`
- Password: `marketing_secure_pass_123`

**Operations Team:**
- Username: `operations_user`
- Password: `operations_secure_pass_123`

### 7.3 Test the Application

Try some example queries:

**Sales:**
- "Show me all customers"
- "How many orders were placed in December 2024?"
- "What are the top 5 products by sales?"

**Marketing:**
- "Show all active campaigns"
- "What's the email open rate?"

**Operations:**
- "Show current inventory levels"
- "Which warehouse has the most stock?"

## Troubleshooting

### Backend Not Starting

**Check logs:**
```bash
sudo tail -50 /var/log/supervisor/sql-query-generator-backend.err.log
```

**Common issues:**
1. Missing `.env` file → Create it in `phase-1/.env`
2. Wrong DB_HOST → Check Aurora endpoint
3. API key missing → Add ANTHROPIC_API_KEY to .env

**Restart backend:**
```bash
sudo supervisorctl restart sql-query-generator-backend
```

### Database Connection Failed

**Test manually:**
```bash
# Load env vars
cd ~/SQL-Query-Generator-with-Natural-Language/phase-1
source .env

# Test connection
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d postgres
```

**If connection fails:**
1. Check Aurora security group allows EC2 IP
2. Verify DB_HOST in .env is correct
3. Check Aurora is publicly accessible (if needed)

### Can't Access from Browser

**Check security group:**
1. EC2 security group allows port 80 from 0.0.0.0/0
2. Try: `curl http://localhost` from EC2 (should work)
3. If localhost works but public IP doesn't → security group issue

**Check Nginx:**
```bash
sudo nginx -t
sudo systemctl status nginx
```

### 502 Bad Gateway

This means Nginx is running but can't reach backend.

**Check backend:**
```bash
sudo supervisorctl status sql-query-generator-backend
```

If not running:
```bash
sudo supervisorctl start sql-query-generator-backend
```

## Useful Commands

### Managing Backend

```bash
# Check status
sudo supervisorctl status

# Start backend
sudo supervisorctl start sql-query-generator-backend

# Stop backend
sudo supervisorctl stop sql-query-generator-backend

# Restart backend
sudo supervisorctl restart sql-query-generator-backend

# View live logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log

# View error logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.err.log
```

### Managing Nginx

```bash
# Check status
sudo systemctl status nginx

# Restart
sudo systemctl restart nginx

# Test configuration
sudo nginx -t

# View access logs
sudo tail -f /var/log/nginx/access.log

# View error logs
sudo tail -f /var/log/nginx/error.log
```

### Updating Application

```bash
# Pull latest code (if using git)
cd ~/SQL-Query-Generator-with-Natural-Language
git pull

# Or upload new files from local
# scp -i key.pem -r ./phase-1 ubuntu@EC2_IP:~/SQL-Query-Generator-with-Natural-Language/

# Restart backend
sudo supervisorctl restart sql-query-generator-backend

# Reload Nginx (if config changed)
sudo systemctl reload nginx
```

## Adding SSL/HTTPS (Optional)

If you have a domain name:

### 1. Point Domain to EC2

Create an A record:
- Type: `A`
- Name: `sql-generator` (or `@` for root domain)
- Value: Your EC2 public IP
- TTL: `300`

### 2. Install Certbot

```bash
sudo apt install -y certbot python3-certbot-nginx
```

### 3. Update Nginx Config

```bash
sudo nano /etc/nginx/sites-available/sql-query-generator
```

Change `server_name` from IP to domain:
```nginx
server_name sql-generator.yourdomain.com;
```

Save and test:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Obtain SSL Certificate

```bash
sudo certbot --nginx -d sql-generator.yourdomain.com
```

Follow prompts. Certbot will auto-configure HTTPS!

### 5. Access via HTTPS

```
https://sql-generator.yourdomain.com
```

## Cost Summary

**AWS Costs (Monthly):**
- EC2 t3.small: ~$15
- Aurora Serverless v2: ~$40-90
- Data Transfer: ~$5
- **Total: ~$60-110/month**

**To reduce costs:**
- Stop EC2 when not in use (dev/test)
- Use Reserved Instances (save 40-70%)
- Scale down Aurora capacity

## Next Steps

1. ✅ Application is running
2. 🔒 Add SSL/HTTPS (if using domain)
3. 📊 Set up monitoring (CloudWatch)
4. 🔄 Configure automated backups
5. 📈 Monitor costs in AWS Billing

## Summary Checklist

- ✅ EC2 instance created
- ✅ Security groups configured
- ✅ Repository cloned
- ✅ Environment variables set
- ✅ Setup script executed
- ✅ Application accessible
- ✅ Database connected
- ✅ Can login and query

**You're done!** 🎉

Your SQL Query Generator is now running on AWS EC2!
