#!/bin/bash

# SQL Query Generator - Phase 1 POC
# AWS Aurora PostgreSQL Serverless v2 Setup Script

set -e

echo "=========================================="
echo "SQL Query Generator - Database Setup"
echo "=========================================="
echo ""

# Configuration
CLUSTER_IDENTIFIER="sql-query-gen-cluster"
DB_NAME="postgres"
MASTER_USERNAME="postgres"
MASTER_PASSWORD="SQLQueryGen2024!"
ENGINE="aurora-postgresql"
ENGINE_VERSION="15.4"
DB_SUBNET_GROUP_NAME="sql-query-gen-subnet-group"
SECURITY_GROUP_NAME="sql-query-gen-sg"
REGION="us-east-1"

echo "Step 1: Creating VPC Security Group..."
# Get default VPC ID
DEFAULT_VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text --region $REGION)

if [ "$DEFAULT_VPC_ID" == "None" ] || [ -z "$DEFAULT_VPC_ID" ]; then
    echo "Error: No default VPC found. Please create a VPC first."
    exit 1
fi

echo "Using VPC: $DEFAULT_VPC_ID"

# Create security group
SG_ID=$(aws ec2 create-security-group \
    --group-name $SECURITY_GROUP_NAME \
    --description "Security group for SQL Query Generator Aurora cluster" \
    --vpc-id $DEFAULT_VPC_ID \
    --region $REGION \
    --query 'GroupId' \
    --output text 2>/dev/null || aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text \
    --region $REGION)

echo "Security Group ID: $SG_ID"

# Add inbound rule for PostgreSQL (publicly accessible)
aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID \
    --protocol tcp \
    --port 5432 \
    --cidr 0.0.0.0/0 \
    --region $REGION 2>/dev/null || echo "Security group rule already exists"

echo ""
echo "Step 2: Creating DB Subnet Group..."
# Get default subnets
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$DEFAULT_VPC_ID" \
    --query "Subnets[*].SubnetId" \
    --output text \
    --region $REGION)

SUBNET_ARRAY=($SUBNET_IDS)

if [ ${#SUBNET_ARRAY[@]} -lt 2 ]; then
    echo "Error: Need at least 2 subnets in different availability zones"
    exit 1
fi

# Create DB subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --db-subnet-group-description "Subnet group for SQL Query Generator" \
    --subnet-ids ${SUBNET_ARRAY[@]} \
    --region $REGION 2>/dev/null || echo "DB Subnet group already exists"

echo ""
echo "Step 3: Creating Aurora Serverless v2 Cluster..."
aws rds create-db-cluster \
    --db-cluster-identifier $CLUSTER_IDENTIFIER \
    --engine $ENGINE \
    --engine-version $ENGINE_VERSION \
    --master-username $MASTER_USERNAME \
    --master-user-password $MASTER_PASSWORD \
    --database-name $DB_NAME \
    --db-subnet-group-name $DB_SUBNET_GROUP_NAME \
    --vpc-security-group-ids $SG_ID \
    --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=1 \
    --engine-mode provisioned \
    --publicly-accessible \
    --region $REGION

echo ""
echo "Step 4: Creating Aurora Serverless v2 Instance..."
aws rds create-db-instance \
    --db-instance-identifier "${CLUSTER_IDENTIFIER}-instance-1" \
    --db-cluster-identifier $CLUSTER_IDENTIFIER \
    --db-instance-class db.serverless \
    --engine $ENGINE \
    --publicly-accessible \
    --region $REGION

echo ""
echo "=========================================="
echo "Database cluster creation initiated!"
echo "=========================================="
echo ""
echo "Waiting for cluster to become available (this may take 5-10 minutes)..."
aws rds wait db-cluster-available --db-cluster-identifier $CLUSTER_IDENTIFIER --region $REGION

echo ""
echo "Cluster is now available!"
echo ""

# Get cluster endpoint
CLUSTER_ENDPOINT=$(aws rds describe-db-clusters \
    --db-cluster-identifier $CLUSTER_IDENTIFIER \
    --query "DBClusters[0].Endpoint" \
    --output text \
    --region $REGION)

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Cluster Endpoint: $CLUSTER_ENDPOINT"
echo "Port: 5432"
echo "Master Username: $MASTER_USERNAME"
echo "Master Password: $MASTER_PASSWORD"
echo ""
echo "Update your .env file with:"
echo "DB_HOST=$CLUSTER_ENDPOINT"
echo "DB_PORT=5432"
echo "DB_USER=$MASTER_USERNAME"
echo "DB_PASSWORD=$MASTER_PASSWORD"
echo ""
echo "Next step: Run './scripts/init_databases.sh' to create databases and tables"
echo ""
