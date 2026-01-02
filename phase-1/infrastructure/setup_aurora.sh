#!/bin/bash

# AWS Aurora PostgreSQL Serverless v2 Setup Script
# This script creates an Aurora PostgreSQL Serverless v2 cluster for the SQL Query Generator POC

set -e

echo "========================================="
echo "Aurora PostgreSQL Serverless v2 Setup"
echo "========================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found. Please copy .env.example to .env and configure it."
    exit 1
fi

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

echo "Using AWS Region: $AWS_REGION"
echo "Using AWS Profile: $AWS_PROFILE"

# Get default VPC ID
echo "Finding default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "Error: No default VPC found. Please create a VPC first."
    exit 1
fi

echo "Using VPC: $VPC_ID"

# Create Security Group
echo "Creating security group..."
EXISTING_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=sql-generator-aurora-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null)

if [ "$EXISTING_SG" != "None" ] && [ ! -z "$EXISTING_SG" ]; then
    echo "Security group already exists: $EXISTING_SG"
    SECURITY_GROUP_ID=$EXISTING_SG
else
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name sql-generator-aurora-sg \
        --description "Security group for SQL Generator Aurora cluster" \
        --vpc-id $VPC_ID \
        --region $AWS_REGION \
        --profile $AWS_PROFILE \
        --query 'GroupId' \
        --output text)
    echo "Created security group: $SECURITY_GROUP_ID"
fi

# Allow PostgreSQL access from anywhere (for POC - restrict in production)
echo "Configuring security group rules..."
aws ec2 authorize-security-group-ingress \
    --group-id $SECURITY_GROUP_ID \
    --protocol tcp \
    --port $DB_PORT \
    --cidr 0.0.0.0/0 \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null || echo "Security group rule already exists"

# Create DB Subnet Group
echo "Creating DB subnet group..."
SUBNET_IDS=$(aws ec2 describe-subnets \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'Subnets[*].SubnetId' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE)

# Check if subnet group exists
EXISTING_SUBNET_GROUP=$(aws rds describe-db-subnet-groups \
    --db-subnet-group-name sql-generator-subnet-group \
    --query 'DBSubnetGroups[0].DBSubnetGroupName' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null)

if [ "$EXISTING_SUBNET_GROUP" != "None" ] && [ ! -z "$EXISTING_SUBNET_GROUP" ]; then
    echo "DB subnet group already exists"
else
    aws rds create-db-subnet-group \
        --db-subnet-group-name sql-generator-subnet-group \
        --db-subnet-group-description "Subnet group for SQL Generator Aurora" \
        --subnet-ids $SUBNET_IDS \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
    echo "Created DB subnet group"
fi

# Check if cluster already exists
echo "Checking if cluster exists..."
EXISTING_CLUSTER=$(aws rds describe-db-clusters \
    --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
    --query 'DBClusters[0].DBClusterIdentifier' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null)

if [ "$EXISTING_CLUSTER" != "None" ] && [ ! -z "$EXISTING_CLUSTER" ]; then
    echo "Cluster already exists: $EXISTING_CLUSTER"
    CLUSTER_STATUS=$(aws rds describe-db-clusters \
        --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
        --query 'DBClusters[0].Status' \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    echo "Cluster status: $CLUSTER_STATUS"
else
    # Create Aurora PostgreSQL Serverless v2 Cluster
    echo "Creating Aurora PostgreSQL Serverless v2 cluster..."
    echo "This may take a few minutes..."
    
    aws rds create-db-cluster \
        --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
        --engine aurora-postgresql \
        --engine-version 17.7 \
        --master-username $DB_MASTER_USERNAME \
        --master-user-password "$DB_MASTER_PASSWORD" \
        --database-name postgres \
        --db-subnet-group-name sql-generator-subnet-group \
        --vpc-security-group-ids $SECURITY_GROUP_ID \
        --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=1.0 \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
    
    echo "Cluster creation initiated successfully"
fi

echo "Waiting for cluster to be available..."
aws rds wait db-cluster-available \
    --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
    --region $AWS_REGION \
    --profile $AWS_PROFILE

echo "Cluster is now available!"

# Check if instance already exists
echo "Checking if instance exists..."
EXISTING_INSTANCE=$(aws rds describe-db-instances \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --query 'DBInstances[0].DBInstanceIdentifier' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE 2>/dev/null)

if [ "$EXISTING_INSTANCE" != "None" ] && [ ! -z "$EXISTING_INSTANCE" ]; then
    echo "Instance already exists: $EXISTING_INSTANCE"
    INSTANCE_STATUS=$(aws rds describe-db-instances \
        --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text \
        --region $AWS_REGION \
        --profile $AWS_PROFILE)
    echo "Instance status: $INSTANCE_STATUS"
else
    # Create Aurora PostgreSQL Serverless v2 Instance
    echo "Creating Aurora PostgreSQL Serverless v2 instance..."
    echo "This may take 5-10 minutes..."
    
    aws rds create-db-instance \
        --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
        --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
        --engine aurora-postgresql \
        --db-instance-class db.serverless \
        --region $AWS_REGION \
        --profile $AWS_PROFILE
    
    echo "Instance creation initiated successfully"
fi

echo "Waiting for instance to be available (this may take several minutes)..."
aws rds wait db-instance-available \
    --db-instance-identifier $DB_INSTANCE_IDENTIFIER \
    --region $AWS_REGION \
    --profile $AWS_PROFILE

echo "Instance is now available!"

# Get Cluster Endpoint
DB_ENDPOINT=$(aws rds describe-db-clusters \
    --db-cluster-identifier $DB_CLUSTER_IDENTIFIER \
    --query 'DBClusters[0].Endpoint' \
    --output text \
    --region $AWS_REGION \
    --profile $AWS_PROFILE)

echo ""
echo "========================================="
echo "Aurora PostgreSQL Setup Complete!"
echo "========================================="
echo "Cluster Endpoint: $DB_ENDPOINT"
echo "Port: $DB_PORT"
echo "Master Username: $DB_MASTER_USERNAME"
echo ""
echo "Update your .env file with:"
echo "SECURITY_GROUP_ID=$SECURITY_GROUP_ID"
echo "DB_HOST=$DB_ENDPOINT"
echo ""
echo "Next steps:"
echo "1. Update .env file with the DB_HOST"
echo "2. Run: ./database/init_databases.sh"
echo "========================================="
