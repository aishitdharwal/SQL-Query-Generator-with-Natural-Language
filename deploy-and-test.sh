#!/bin/bash
# Complete Deployment and Testing Script
# This script handles the entire deployment and initialization process

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STACK_NAME="sql-query-generator-poc"

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║   SQL Query Generator - Complete Deployment Script       ║
║   Production AI Engineering Course                       ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

command -v aws >/dev/null 2>&1 || { echo -e "${RED}AWS CLI not found. Please install it.${NC}"; exit 1; }
command -v sam >/dev/null 2>&1 || { echo -e "${RED}SAM CLI not found. Please install it.${NC}"; exit 1; }
command -v psql >/dev/null 2>&1 || { echo -e "${RED}PostgreSQL client not found. Please install it.${NC}"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo -e "${RED}jq not found. Please install it.${NC}"; exit 1; }

echo -e "${GREEN}✓ All prerequisites installed${NC}\n"

# Function to get stack outputs
get_outputs() {
    aws cloudformation describe-stacks \
      --stack-name $STACK_NAME \
      --query 'Stacks[0].Outputs' \
      --output json
}

# Function to save deployment info
save_deployment_info() {
    OUTPUTS=$(get_outputs)
    
    API_ENDPOINT=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="ApiEndpoint") | .OutputValue')
    SYSTEM_DB=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="SystemDatabaseEndpoint") | .OutputValue')
    SAMPLE_DB=$(echo $OUTPUTS | jq -r '.[] | select(.OutputKey=="SampleDatabaseEndpoint") | .OutputValue')
    
    cat > deployment-info.sh << EOF
#!/bin/bash
# Auto-generated deployment information
# Source this file: source deployment-info.sh

export API_ENDPOINT="$API_ENDPOINT"
export SYSTEM_DB_ENDPOINT="$SYSTEM_DB"
export SAMPLE_DB_ENDPOINT="$SAMPLE_DB"
export SYSTEM_DB_PASSWORD="$SYSTEM_DB_PASSWORD"
export SAMPLE_DB_PASSWORD="$SAMPLE_DB_PASSWORD"
export STACK_NAME="$STACK_NAME"

echo "Deployment info loaded:"
echo "  API Endpoint: \$API_ENDPOINT"
echo "  System DB: \$SYSTEM_DB_ENDPOINT"
echo "  Sample DB: \$SAMPLE_DB_ENDPOINT"
EOF
    
    chmod +x deployment-info.sh
    
    echo -e "${GREEN}✓ Deployment info saved to deployment-info.sh${NC}"
    echo -e "  Run: ${YELLOW}source deployment-info.sh${NC} to load variables\n"
}

# Main deployment flow
echo -e "${BLUE}=== STEP 1: Deployment Configuration ===${NC}\n"

# Check if already deployed
EXISTING_STACK=$(aws cloudformation describe-stacks --stack-name $STACK_NAME 2>/dev/null || echo "")

if [ -n "$EXISTING_STACK" ]; then
    echo -e "${YELLOW}Stack already exists!${NC}"
    echo "Options:"
    echo "  1) Update existing stack"
    echo "  2) Delete and redeploy"
    echo "  3) Skip deployment"
    read -p "Choose (1-3): " deploy_choice
    
    if [ "$deploy_choice" == "2" ]; then
        echo "Deleting stack..."
        aws cloudformation delete-stack --stack-name $STACK_NAME
        aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME
        echo -e "${GREEN}✓ Stack deleted${NC}"
        DEPLOY_MODE="create"
    elif [ "$deploy_choice" == "3" ]; then
        DEPLOY_MODE="skip"
    else
        DEPLOY_MODE="update"
    fi
else
    DEPLOY_MODE="create"
fi

if [ "$DEPLOY_MODE" != "skip" ]; then
    # Get passwords if creating new
    if [ "$DEPLOY_MODE" == "create" ]; then
        echo -e "\n${YELLOW}Enter database passwords (or press Enter for defaults):${NC}"
        read -sp "System DB Password [default: TestPassword123!]: " SYSTEM_DB_PASSWORD
        echo
        SYSTEM_DB_PASSWORD=${SYSTEM_DB_PASSWORD:-TestPassword123!}
        
        read -sp "Sample DB Password [default: TestPassword456!]: " SAMPLE_DB_PASSWORD
        echo
        SAMPLE_DB_PASSWORD=${SAMPLE_DB_PASSWORD:-TestPassword456!}
        
        read -p "Anthropic API Key: " ANTHROPIC_API_KEY
        
        if [ -z "$ANTHROPIC_API_KEY" ]; then
            echo -e "${RED}Anthropic API key is required!${NC}"
            exit 1
        fi
    else
        # For updates, load existing info
        if [ -f "deployment-info.sh" ]; then
            source deployment-info.sh
        else
            echo -e "${RED}deployment-info.sh not found. Cannot update.${NC}"
            exit 1
        fi
    fi
    
    echo -e "\n${BLUE}=== STEP 2: Building Application ===${NC}\n"
    sam build
    echo -e "${GREEN}✓ Build complete${NC}\n"
    
    echo -e "${BLUE}=== STEP 3: Deploying to AWS ===${NC}\n"
    
    if [ "$DEPLOY_MODE" == "create" ]; then
        sam deploy \
          --stack-name $STACK_NAME \
          --parameter-overrides \
            SystemDBPassword=$SYSTEM_DB_PASSWORD \
            SampleDBPassword=$SAMPLE_DB_PASSWORD \
            AnthropicAPIKey=$ANTHROPIC_API_KEY \
            ActivePhase=POC \
          --capabilities CAPABILITY_IAM \
          --resolve-s3 \
          --no-confirm-changeset
    else
        sam deploy \
          --stack-name $STACK_NAME \
          --capabilities CAPABILITY_IAM \
          --no-confirm-changeset
    fi
    
    echo -e "${GREEN}✓ Deployment complete${NC}\n"
    
    # Wait for databases to be available
    echo -e "${YELLOW}Waiting for databases to be ready (this takes 5-10 minutes)...${NC}"
    sleep 60
    
    save_deployment_info
    source deployment-info.sh
fi

# Database initialization
echo -e "${BLUE}=== STEP 4: Database Initialization ===${NC}\n"

if [ -f "deployment-info.sh" ]; then
    source deployment-info.sh
else
    echo -e "${RED}deployment-info.sh not found!${NC}"
    exit 1
fi

echo "Initializing System Database..."
PGPASSWORD=$SYSTEM_DB_PASSWORD psql \
  -h $SYSTEM_DB_ENDPOINT \
  -U admin_user \
  -d sql_query_generator \
  -f backend/migrations/01_system_db_schema.sql \
  -q

echo -e "${GREEN}✓ System database initialized${NC}\n"

echo "Initializing Sample E-commerce Database..."
PGPASSWORD=$SAMPLE_DB_PASSWORD psql \
  -h $SAMPLE_DB_ENDPOINT \
  -U admin_user \
  -d ecommerce \
  -f backend/migrations/02_sample_ecommerce_schema.sql \
  -q

echo -e "${GREEN}✓ Sample database initialized${NC}\n"

echo "Updating team connection string..."
PGPASSWORD=$SYSTEM_DB_PASSWORD psql \
  -h $SYSTEM_DB_ENDPOINT \
  -U admin_user \
  -d sql_query_generator \
  -c "UPDATE teams SET db_connection_string = 'postgresql://admin_user:$SAMPLE_DB_PASSWORD@$SAMPLE_DB_ENDPOINT:5432/ecommerce' WHERE team_name = 'Demo Team';" \
  -q

echo -e "${GREEN}✓ Connection string updated${NC}\n"

# Testing
echo -e "${BLUE}=== STEP 5: Running Tests ===${NC}\n"

echo "Test 1: Basic query generation..."
RESPONSE=$(curl -s -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me all users",
    "selected_tables": ["users"]
  }')

SUCCESS=$(echo $RESPONSE | jq -r '.success // false')

if [ "$SUCCESS" == "true" ]; then
    echo -e "${GREEN}✓ Basic query test PASSED${NC}"
    echo "  Generated SQL: $(echo $RESPONSE | jq -r '.generated_sql')"
    echo "  Cost: \$$(echo $RESPONSE | jq -r '.cost_usd')"
    echo "  Phase: $(echo $RESPONSE | jq -r '.phase')"
else
    echo -e "${RED}✗ Basic query test FAILED${NC}"
    echo "  Error: $(echo $RESPONSE | jq -r '.error // "Unknown error"')"
fi

echo ""
echo "Test 2: JOIN query..."
RESPONSE=$(curl -s -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show total revenue by region",
    "selected_tables": ["orders", "regions"]
  }')

SUCCESS=$(echo $RESPONSE | jq -r '.success // false')

if [ "$SUCCESS" == "true" ]; then
    echo -e "${GREEN}✓ JOIN query test PASSED${NC}"
    RESULTS=$(echo $RESPONSE | jq -r '.results | length')
    echo "  Results returned: $RESULTS rows"
else
    echo -e "${RED}✗ JOIN query test FAILED${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 DEPLOYMENT COMPLETE! 🎉                   ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo ""
echo "1. Load deployment info:"
echo -e "   ${YELLOW}source deployment-info.sh${NC}"
echo ""
echo "2. Test the API:"
echo -e "   ${YELLOW}curl -X POST \"\$API_ENDPOINT/query/generate\" \\${NC}"
echo -e "   ${YELLOW}  -H \"x-api-key: demo-api-key-12345\" \\${NC}"
echo -e "   ${YELLOW}  -d '{\"natural_language_query\":\"Show me all users\",\"selected_tables\":[\"users\"]}'${NC}"
echo ""
echo "3. Switch phases:"
echo -e "   ${YELLOW}./manage-security.sh status${NC}      # Check current security"
echo -e "   ${YELLOW}# Update ACTIVE_PHASE in Lambda console${NC}"
echo ""
echo "4. Lock down for production:"
echo -e "   ${YELLOW}./manage-security.sh production${NC}"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  - Full guide: DEPLOYMENT_GUIDE.md"
echo "  - Phase reference: PHASE_REFERENCE.md"
echo "  - Security management: ./manage-security.sh --help"
echo ""
