#!/bin/bash
# Security Management Script for SQL Query Generator
# Toggle between DEVELOPMENT (public) and PRODUCTION (private) security modes

set -e

STACK_NAME="sql-query-generator-poc"
MODE=$1

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [development|production|status]"
    echo ""
    echo "Modes:"
    echo "  development  - Open RDS to public access (0.0.0.0/0) for easy testing"
    echo "  production   - Lock down RDS to VPC-only access (secure)"
    echo "  status       - Show current security configuration"
    exit 1
}

if [ -z "$MODE" ]; then
    usage
fi

# Get VPC and security group IDs
echo "Getting security group information..."
VPC_ID=$(aws cloudformation describe-stack-resources \
  --stack-name $STACK_NAME \
  --query 'StackResources[?ResourceType==`AWS::EC2::VPC`].PhysicalResourceId' \
  --output text)

SYSTEM_DB_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*SystemDBSecurityGroup*" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

SAMPLE_DB_SG=$(aws ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=group-name,Values=*SampleDBSecurityGroup*" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

if [ "$MODE" == "status" ]; then
    echo -e "\n${YELLOW}=== Current Security Configuration ===${NC}\n"
    
    echo "System Database Security Group: $SYSTEM_DB_SG"
    aws ec2 describe-security-groups \
      --group-ids $SYSTEM_DB_SG \
      --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp,UserIdGroupPairs[0].GroupId]' \
      --output table
    
    echo ""
    echo "Sample Database Security Group: $SAMPLE_DB_SG"
    aws ec2 describe-security-groups \
      --group-ids $SAMPLE_DB_SG \
      --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp,UserIdGroupPairs[0].GroupId]' \
      --output table
    
    # Check if 0.0.0.0/0 exists
    PUBLIC_ACCESS=$(aws ec2 describe-security-groups \
      --group-ids $SYSTEM_DB_SG \
      --query 'SecurityGroups[0].IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`)]' \
      --output text)
    
    if [ -n "$PUBLIC_ACCESS" ]; then
        echo -e "\n${RED}⚠️  DEVELOPMENT MODE - Databases are publicly accessible!${NC}"
    else
        echo -e "\n${GREEN}✅ PRODUCTION MODE - Databases are VPC-only${NC}"
    fi
    
    exit 0
fi

if [ "$MODE" == "development" ]; then
    echo -e "${YELLOW}Switching to DEVELOPMENT mode...${NC}"
    echo "This will open RDS databases to public internet (0.0.0.0/0)"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
    
    echo "Adding public access rules..."
    
    # Check if rule already exists
    EXISTING=$(aws ec2 describe-security-groups \
      --group-ids $SYSTEM_DB_SG \
      --query 'SecurityGroups[0].IpPermissions[?contains(IpRanges[].CidrIp, `0.0.0.0/0`)]' \
      --output text)
    
    if [ -z "$EXISTING" ]; then
        # Add public access to System DB
        aws ec2 authorize-security-group-ingress \
          --group-id $SYSTEM_DB_SG \
          --protocol tcp \
          --port 5432 \
          --cidr 0.0.0.0/0 \
          --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Environment,Value=Development}]' \
          2>/dev/null || echo "Rule may already exist for System DB"
        
        # Add public access to Sample DB
        aws ec2 authorize-security-group-ingress \
          --group-id $SAMPLE_DB_SG \
          --protocol tcp \
          --port 5432 \
          --cidr 0.0.0.0/0 \
          --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Environment,Value=Development}]' \
          2>/dev/null || echo "Rule may already exist for Sample DB"
        
        echo -e "${GREEN}✅ DEVELOPMENT mode enabled${NC}"
        echo -e "${YELLOW}⚠️  Databases are now publicly accessible!${NC}"
        echo ""
        echo "You can now connect directly:"
        echo "  psql -h <db-endpoint> -U admin_user -d <database>"
    else
        echo -e "${YELLOW}Already in DEVELOPMENT mode${NC}"
    fi
    
elif [ "$MODE" == "production" ]; then
    echo -e "${YELLOW}Switching to PRODUCTION mode...${NC}"
    echo "This will remove public internet access from RDS databases"
    read -p "Are you sure? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 1
    fi
    
    echo "Removing public access rules..."
    
    # Remove public access from System DB
    aws ec2 revoke-security-group-ingress \
      --group-id $SYSTEM_DB_SG \
      --protocol tcp \
      --port 5432 \
      --cidr 0.0.0.0/0 \
      2>/dev/null || echo "Rule may not exist for System DB"
    
    # Remove public access from Sample DB
    aws ec2 revoke-security-group-ingress \
      --group-id $SAMPLE_DB_SG \
      --protocol tcp \
      --port 5432 \
      --cidr 0.0.0.0/0 \
      2>/dev/null || echo "Rule may not exist for Sample DB"
    
    echo -e "${GREEN}✅ PRODUCTION mode enabled${NC}"
    echo -e "${GREEN}Databases are now VPC-only (secure)${NC}"
    echo ""
    echo "Lambda functions can still access databases via VPC."
    echo "To access manually, you'll need a bastion host or VPN."
    
else
    usage
fi

echo ""
echo "Run '$0 status' to see current configuration"
