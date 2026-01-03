# EC2 Deployment Guide

## Part 4: Deploying to AWS EC2

This guide covers deploying the SQL Query Generator to an AWS EC2 instance with Nginx as a reverse proxy.

## Prerequisites

- AWS account with EC2 access
- Domain name (optional, but recommended for SSL)
- SSH key pair for EC2 access
- Aurora PostgreSQL database already set up (from Part 1)

## Architecture

```
Internet → EC2 (Nginx) → FastAPI Backend → Aurora PostgreSQL
                ↓
           Static Files (Frontend)
```

**Components:**
- **Nginx**: Web server serving frontend + reverse proxy for backend API
- **Supervisor**: Process manager keeping backend running
- **FastAPI**: Backend application running on port 8080
- **Aurora PostgreSQL**: Database (already configured)

## Step 1: Launch EC2 Instance

### 1.1 Create EC2 Instance

```bash
# Using AWS CLI (or use AWS Console)
aws ec2 run-instances \
  --image-id ami-0c7217cdde317cfec \  # Ubuntu 22.04 LTS (update for your region)
  --instance-type t3.small \
  --key-name your-key-pair \
  --security-group-ids sg-xxxxx \
  --subnet-id subnet-xxxxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=sql-query-generator}]'
```

**Recommended Instance Type:**
- **Development/Testing**: t3.small (2 vCPU, 2 GB RAM) - ~$15/month
- **Production**: t3.medium (2 vCPU, 4 GB RAM) - ~$30/month

### 1.2 Configure Security Group

Allow the following inbound rules:

| Type  | Port | Source      | Description        |
|-------|------|-------------|--------------------|
| SSH   | 22   | Your IP     | SSH access         |
| HTTP  | 80   | 0.0.0.0/0   | Web traffic        |
| HTTPS | 443  | 0.0.0.0/0   | Secure web traffic |

```bash
# Add rules to security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --ip-permissions \
    IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=YOUR_IP/32}]' \
    IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0}]' \
    IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0}]'
```

### 1.3 Get EC2 Public IP

```bash
# Get instance public IP
aws ec2 describe-instances \
  --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text
```

## Step 2: Initial EC2 Setup

### 2.1 SSH into EC2

```bash
ssh -i your-key.pem ubuntu@your-ec2-public-ip
```

### 2.2 Run Setup Script

```bash
# On EC2 instance
wget https://raw.githubusercontent.com/your-repo/deployment/setup_ec2.sh
chmod +x setup_ec2.sh
./setup_ec2.sh
```

Or manually run the setup commands from `setup_ec2.sh`.

## Step 3: Deploy Application

### 3.1 Update Frontend Config for Production

Before deploying, update the frontend to use production API configuration:

```bash
# On your local machine
cd phase-1/frontend/js
cp ../../deployment/config.production.js config.js
```

This changes the API URL from `http://localhost:8080` to the same origin as the frontend (handled by Nginx).

### 3.2 Deploy Using Automated Script

```bash
# On your local machine
cd phase-1/deployment

# Edit deploy.sh and set EC2_HOST
nano deploy.sh
# Set: EC2_HOST="your-ec2-public-ip"

# Make executable and run
chmod +x deploy.sh
./deploy.sh
```

### 3.3 Manual Deployment (Alternative)

If you prefer manual deployment:

```bash
# 1. Copy files to EC2
scp -r ../backend ubuntu@your-ec2-ip:/var/www/sql-query-generator/
scp -r ../frontend ubuntu@your-ec2-ip:/var/www/sql-query-generator/
scp ../.env ubuntu@your-ec2-ip:/var/www/sql-query-generator/

# 2. SSH into EC2
ssh ubuntu@your-ec2-ip

# 3. Setup Python environment
cd /var/www/sql-query-generator/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
deactivate

# 4. Configure Nginx
sudo cp /var/www/sql-query-generator/deployment/nginx.conf \
  /etc/nginx/sites-available/sql-query-generator
sudo ln -s /etc/nginx/sites-available/sql-query-generator \
  /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx

# 5. Configure Supervisor
sudo cp /var/www/sql-query-generator/deployment/supervisor.conf \
  /etc/supervisor/conf.d/sql-query-generator.conf
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start sql-query-generator-backend
```

## Step 4: Verify Deployment

### 4.1 Check Backend Status

```bash
# On EC2
sudo supervisorctl status sql-query-generator-backend

# Should show: RUNNING

# View logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log
```

### 4.2 Check Nginx Status

```bash
sudo systemctl status nginx

# Test configuration
sudo nginx -t
```

### 4.3 Access Application

Open browser and navigate to:
```
http://your-ec2-public-ip
```

You should see the login page!

## Step 5: Domain and SSL Setup (Optional but Recommended)

### 5.1 Configure DNS

Point your domain to the EC2 public IP:

```
Type: A Record
Name: sql-generator (or @)
Value: your-ec2-public-ip
TTL: 300
```

### 5.2 Update Nginx Configuration

```bash
# Edit nginx config
sudo nano /etc/nginx/sites-available/sql-query-generator

# Change server_name from IP to domain
server_name sql-generator.yourdomain.com;

# Restart Nginx
sudo systemctl restart nginx
```

### 5.3 Setup SSL with Let's Encrypt

```bash
# On EC2
cd /var/www/sql-query-generator/deployment
chmod +x setup_ssl.sh

# Edit and set DOMAIN
nano setup_ssl.sh
# Set: DOMAIN="sql-generator.yourdomain.com"

# Run SSL setup
./setup_ssl.sh
```

Now access via: `https://sql-generator.yourdomain.com`

## Step 6: Update CORS for Production

Update backend CORS to only allow your domain:

```python
# backend/main.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://sql-generator.yourdomain.com",
        "http://your-ec2-public-ip"  # For testing
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

Then redeploy:
```bash
./deploy.sh
```

## Monitoring and Maintenance

### View Backend Logs

```bash
# Real-time logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log

# Error logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.err.log

# Nginx access logs
sudo tail -f /var/log/nginx/access.log

# Nginx error logs
sudo tail -f /var/log/nginx/error.log
```

### Restart Backend

```bash
sudo supervisorctl restart sql-query-generator-backend
```

### Restart Nginx

```bash
sudo systemctl restart nginx
```

### Update Application

```bash
# From local machine
cd phase-1/deployment
./deploy.sh

# Or manually on EC2
cd /var/www/sql-query-generator
git pull  # If using git
sudo supervisorctl restart sql-query-generator-backend
```

## Troubleshooting

### Backend Not Starting

```bash
# Check logs
sudo tail -100 /var/log/supervisor/sql-query-generator-backend.err.log

# Common issues:
# 1. Missing .env file
# 2. Incorrect Python path
# 3. Database connection issues
```

### Nginx Errors

```bash
# Test configuration
sudo nginx -t

# Check logs
sudo tail -f /var/log/nginx/error.log
```

### Database Connection Issues

```bash
# Test database connectivity from EC2
psql -h your-aurora-endpoint \
     -U sales_user \
     -d sales_db

# If fails, check:
# 1. Security group allows EC2 IP
# 2. .env has correct DB_HOST
# 3. Aurora is publicly accessible
```

### 502 Bad Gateway

This means Nginx can't reach the backend:

```bash
# Check backend is running
sudo supervisorctl status sql-query-generator-backend

# Check backend logs
sudo tail -f /var/log/supervisor/sql-query-generator-backend.out.log

# Restart backend
sudo supervisorctl restart sql-query-generator-backend
```

## Security Best Practices

1. **Use HTTPS**: Always use SSL in production
2. **Restrict SSH**: Only allow SSH from your IP
3. **Update CORS**: Remove wildcard origins in production
4. **Environment Variables**: Keep `.env` file secure (chmod 600)
5. **Regular Updates**: Keep system packages updated
6. **Database Security**: Use RDS security groups to restrict access
7. **Secrets Management**: Consider AWS Secrets Manager for production

## Cost Optimization

**Monthly Costs (Approximate):**
- EC2 t3.small: ~$15
- Aurora Serverless v2 (0.5-1 ACU): ~$40-90
- Data transfer: ~$5-10
- **Total: ~$60-115/month**

**To reduce costs:**
- Use Reserved Instances for EC2 (up to 72% savings)
- Scale Aurora down when not in use
- Use CloudFront CDN for static assets
- Stop EC2 instance when not needed (dev/test)

## Backup and Recovery

### Backup Database

Aurora has automatic backups. To create manual snapshot:

```bash
aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier sql-generator-backup-$(date +%Y%m%d) \
  --db-cluster-identifier sql-generator-aurora-cluster
```

### Backup Application

```bash
# On EC2
cd /var/www
sudo tar -czf sql-query-generator-backup.tar.gz sql-query-generator/
```

## Scaling Considerations

For higher traffic:

1. **Horizontal Scaling**: Use Application Load Balancer + multiple EC2 instances
2. **Caching**: Add Redis for session management
3. **CDN**: Use CloudFront for static assets
4. **Database**: Increase Aurora capacity
5. **Monitoring**: Add CloudWatch alarms

## Next Steps

- Set up monitoring (CloudWatch, Datadog, etc.)
- Implement logging aggregation
- Add automated backups
- Set up CI/CD pipeline
- Implement rate limiting
- Add API authentication tokens (for API access)

## Summary

You now have a production-ready deployment with:
- ✅ EC2 instance running the application
- ✅ Nginx serving frontend and proxying API
- ✅ Supervisor managing backend process
- ✅ SSL encryption (if domain configured)
- ✅ Database connectivity to Aurora
- ✅ Monitoring and logging
