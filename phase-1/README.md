# SQL Query Generator - Phase 1 POC

Natural language to SQL query generator for e-commerce databases with team-based access control.

## Project Structure

```
phase-1/
├── infrastructure/          # AWS setup scripts
│   └── setup_aurora.sh     # Aurora PostgreSQL creation script
├── database/               # Database initialization
│   ├── init_databases.sh   # Database and user creation script
│   └── schemas/            # SQL schema files
│       ├── sales_schema.sql
│       ├── marketing_schema.sql
│       └── operations_schema.sql
├── .env.example            # Environment variables template
└── README.md              # This file
```

## Part 1: Infrastructure & Database Setup

### Prerequisites

- AWS CLI configured with appropriate credentials
- PostgreSQL client (`psql`) installed
- Bash shell

### Setup Instructions

#### Step 1: Configure Environment Variables

```bash
# Copy the example env file
cp .env.example .env

# Edit .env and fill in:
# - AWS_REGION (default: us-east-1)
# - AWS_PROFILE (default: default)
# - DB_MASTER_PASSWORD (strong password)
# - Team passwords (change from defaults)
# - ANTHROPIC_API_KEY (your Claude API key)
# - APP_SECRET_KEY (generate a random secret)
```

#### Step 2: Create Aurora PostgreSQL Cluster

```bash
# Make script executable
chmod +x infrastructure/setup_aurora.sh

# Run the setup script
./infrastructure/setup_aurora.sh
```

This script will:
- Create a security group allowing PostgreSQL access (port 5432)
- Create a DB subnet group using default VPC
- Create Aurora PostgreSQL Serverless v2 cluster (v15.5)
- Create a Serverless v2 instance with 0.5-1.0 ACU scaling
- Output the cluster endpoint

**Important:** After the script completes, update your `.env` file with:
- `SECURITY_GROUP_ID` - from script output
- `DB_HOST` - cluster endpoint from script output

#### Step 3: Initialize Databases

```bash
# Make script executable
chmod +x database/init_databases.sh

# Run the initialization script
./database/init_databases.sh
```

This script will:
- Create three databases: `sales_db`, `marketing_db`, `operations_db`
- Create tables and insert sample data for each database
- Create team-specific database users
- Grant appropriate permissions to each team

### Database Schema Overview

#### Sales Database (`sales_db`)
Access: Sales Team
- `customers` - Customer information
- `products` - Product catalog
- `orders` - Order transactions
- `order_items` - Line items for orders
- `sales_representatives` - Sales team members
- `sales_assignments` - Customer-rep assignments

#### Marketing Database (`marketing_db`)
Access: Marketing Team
- `campaigns` - Marketing campaigns
- `leads` - Lead information
- `email_campaigns` - Email campaign metrics
- `customer_segments` - Customer segmentation
- `marketing_events` - Events and webinars
- `social_media_posts` - Social media performance
- `content_performance` - Content analytics

#### Operations Database (`operations_db`)
Access: Operations Team
- `warehouses` - Warehouse locations
- `suppliers` - Supplier information
- `inventory` - Current inventory levels
- `purchase_orders` - Purchase order management
- `po_items` - Purchase order line items
- `shipments` - Shipment tracking
- `shipment_items` - Shipment contents
- `inventory_movements` - Inventory transaction log

### Team Access

Each team has its own credentials defined in `.env`:

```
Sales Team:
  Username: sales_user
  Password: sales_secure_pass_123
  Database: sales_db

Marketing Team:
  Username: marketing_user
  Password: marketing_secure_pass_123
  Database: marketing_db

Operations Team:
  Username: operations_user
  Password: operations_secure_pass_123
  Database: operations_db
```

### Testing Database Access

Test connection to each database:

```bash
# Sales
PGPASSWORD=sales_secure_pass_123 psql -h <DB_HOST> -U sales_user -d sales_db

# Marketing
PGPASSWORD=marketing_secure_pass_123 psql -h <DB_HOST> -U marketing_user -d marketing_db

# Operations
PGPASSWORD=operations_secure_pass_123 psql -h <DB_HOST> -U operations_user -d operations_db
```

### Cost Considerations

**Aurora Serverless v2:**
- Minimum: 0.5 ACU (~$0.06/hour when active)
- Maximum: 1.0 ACU (~$0.12/hour at peak)
- Estimated cost: $40-90/month depending on usage
- Automatically scales down when idle

**To minimize costs:**
- Delete the cluster when not in use
- Monitor via AWS Console > RDS > your cluster

**To delete resources:**
```bash
# Delete DB instance
aws rds delete-db-instance \
  --db-instance-identifier sql-generator-aurora-instance \
  --skip-final-snapshot

# Delete DB cluster
aws rds delete-db-cluster \
  --db-cluster-identifier sql-generator-aurora-cluster \
  --skip-final-snapshot

# Delete subnet group and security group via AWS Console
```

## Next Steps

Part 1 is complete! The infrastructure and databases are ready.

**Coming in Part 2:**
- FastAPI backend with authentication
- Claude API integration for SQL generation
- Schema introspection utilities
- Query execution engine

**Coming in Part 3:**
- HTML frontend
- Session management
- Result display
- Local testing instructions

**Coming in Part 4:**
- EC2 deployment guide
- Production considerations
- Monitoring and logging
