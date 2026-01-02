#!/bin/bash

# Database Initialization Script
# Creates databases and schemas for Sales, Marketing, and Operations teams

set -e

echo "========================================="
echo "Database Initialization"
echo "========================================="

# Load environment variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo "Error: .env file not found"
    exit 1
fi

if [ -z "$DB_HOST" ]; then
    echo "Error: DB_HOST not set in .env file. Please run setup_aurora.sh first."
    exit 1
fi

echo "Connecting to: $DB_HOST"

# Create databases
echo "Creating databases..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d postgres -p $DB_PORT << EOF
CREATE DATABASE $SALES_DB_NAME;
CREATE DATABASE $MARKETING_DB_NAME;
CREATE DATABASE $OPERATIONS_DB_NAME;
EOF

echo "Databases created successfully!"

# Initialize Sales Database
echo "Initializing Sales database..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $SALES_DB_NAME -p $DB_PORT -f database/schemas/sales_schema.sql

# Initialize Marketing Database
echo "Initializing Marketing database..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $MARKETING_DB_NAME -p $DB_PORT -f database/schemas/marketing_schema.sql

# Initialize Operations Database
echo "Initializing Operations database..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $OPERATIONS_DB_NAME -p $DB_PORT -f database/schemas/operations_schema.sql

# Create team users and grant permissions
echo "Creating team users..."
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d postgres -p $DB_PORT << EOF
-- Sales Team User
CREATE USER $SALES_TEAM_USERNAME WITH PASSWORD '$SALES_TEAM_PASSWORD';
GRANT CONNECT ON DATABASE $SALES_DB_NAME TO $SALES_TEAM_USERNAME;

-- Marketing Team User
CREATE USER $MARKETING_TEAM_USERNAME WITH PASSWORD '$MARKETING_TEAM_PASSWORD';
GRANT CONNECT ON DATABASE $MARKETING_DB_NAME TO $MARKETING_TEAM_USERNAME;

-- Operations Team User
CREATE USER $OPERATIONS_TEAM_USERNAME WITH PASSWORD '$OPERATIONS_TEAM_PASSWORD';
GRANT CONNECT ON DATABASE $OPERATIONS_DB_NAME TO $OPERATIONS_TEAM_USERNAME;
EOF

# Grant schema permissions
echo "Granting permissions..."

# Sales permissions
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $SALES_DB_NAME -p $DB_PORT << EOF
GRANT USAGE ON SCHEMA public TO $SALES_TEAM_USERNAME;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $SALES_TEAM_USERNAME;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $SALES_TEAM_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $SALES_TEAM_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $SALES_TEAM_USERNAME;
EOF

# Marketing permissions
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $MARKETING_DB_NAME -p $DB_PORT << EOF
GRANT USAGE ON SCHEMA public TO $MARKETING_TEAM_USERNAME;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $MARKETING_TEAM_USERNAME;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $MARKETING_TEAM_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $MARKETING_TEAM_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $MARKETING_TEAM_USERNAME;
EOF

# Operations permissions
PGPASSWORD=$DB_MASTER_PASSWORD psql -h $DB_HOST -U $DB_MASTER_USERNAME -d $OPERATIONS_DB_NAME -p $DB_PORT << EOF
GRANT USAGE ON SCHEMA public TO $OPERATIONS_TEAM_USERNAME;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $OPERATIONS_TEAM_USERNAME;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $OPERATIONS_TEAM_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $OPERATIONS_TEAM_USERNAME;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO $OPERATIONS_TEAM_USERNAME;
EOF

echo ""
echo "========================================="
echo "Database Initialization Complete!"
echo "========================================="
echo "Databases created:"
echo "  - $SALES_DB_NAME (User: $SALES_TEAM_USERNAME)"
echo "  - $MARKETING_DB_NAME (User: $MARKETING_TEAM_USERNAME)"
echo "  - $OPERATIONS_DB_NAME (User: $OPERATIONS_TEAM_USERNAME)"
echo ""
echo "Next steps:"
echo "1. Test connection: psql -h $DB_HOST -U $SALES_TEAM_USERNAME -d $SALES_DB_NAME"
echo "2. Start building the FastAPI application"
echo "========================================="
