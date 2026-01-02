# SQL Query Generator - Deployment Guide

## Complete Deployment Instructions

This guide will walk you through deploying the complete SQL Query Generator system across all three phases.

---

## Prerequisites

1. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```

2. **AWS SAM CLI** installed
   ```bash
   brew install aws-sam-cli  # macOS
   # or
   pip install aws-sam-cli
   ```

3. **Python 3.11** installed

4. **PostgreSQL client** (psql) for database initialization
   ```bash
   brew install postgresql  # macOS
   ```

5. **Anthropic API Key**
   - Get from: https://console.anthropic.com/

---

## Phase-by-Phase Deployment

### PHASE 1: POC Deployment (Week 1)

**Goal**: Deploy basic system without caching or advanced features

#### Step 1: Build the SAM Application

```bash
# Navigate to project root
cd /path/to/SQL-Query-Generator-with-Natural-Language

# Build
sam build
```

#### Step 2: Deploy Infrastructure

```bash
sam deploy --guided

# Answer the prompts:
# Stack Name: sql-query-generator-poc
# AWS Region: us-east-1 (or your preferred region)
# Parameter Environment: dev
# Parameter SystemDBPassword: [create strong password]
# Parameter SampleDBPassword: [create strong password]
# Parameter AnthropicAPIKey: [your Anthropic API key]
# Confirm changes: y
# Allow SAM CLI IAM role creation: y
# Save arguments to configuration file: y
```

#### Step 3: Get Deployment Outputs

```bash
# Get outputs
aws cloudformation describe-stacks \
  --stack-name sql-query-generator-poc \
  --query 'Stacks[0].Outputs' \
  --output table

# Save these values:
# - ApiEndpoint
# - SystemDatabaseEndpoint
# - SampleDatabaseEndpoint
```

#### Step 4: Initialize System Database

```bash
# Connect and run migration
psql -h <SystemDatabaseEndpoint> \
     -U admin \
     -d sql_query_generator \
     -f backend/migrations/01_system_db_schema.sql

# When prompted, enter SystemDBPassword
```

#### Step 5: Initialize Sample Database

```bash
# Connect and run migration
psql -h <SampleDatabaseEndpoint> \
     -U admin \
     -d ecommerce \
     -f backend/migrations/02_sample_ecommerce_schema.sql

# When prompted, enter SampleDBPassword
```

#### Step 6: Update Team Connection String

```bash
# Update the demo team with correct sample DB endpoint
psql -h <SystemDatabaseEndpoint> \
     -U admin \
     -d sql_query_generator \
     -c "UPDATE teams SET db_connection_string = 'postgresql://admin:<SampleDBPassword>@<SampleDatabaseEndpoint>:5432/ecommerce' WHERE team_name = 'Demo Team';"
```

#### Step 7: Set Phase to POC

```bash
# Update Lambda environment variable
aws lambda update-function-configuration \
  --function-name sql-query-generator-poc-query-generator \
  --environment "Variables={ACTIVE_PHASE=POC,ENVIRONMENT=dev,...}"
```

#### Step 8: Test POC

```bash
# Set your API endpoint
export API_ENDPOINT="<your-api-endpoint>"

# Test query generation
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me all users",
    "selected_tables": ["users"]
  }'

# Should return SQL and results WITHOUT caching
```

**Phase 1 Complete! ✅**
- Basic query generation working
- No caching (observe costs)
- No advanced validation

---

### PHASE 2: Breaking Points Demo (Week 2)

**Goal**: Demonstrate security issues and system failures

#### Step 1: Update Phase Configuration

```bash
# Update to breaking demo mode
aws lambda update-function-configuration \
  --function-name sql-query-generator-poc-query-generator \
  --environment "Variables={ACTIVE_PHASE=BREAKING_DEMO,...}"
```

#### Step 2: Test Breaking Points

##### Test 1: SQL Injection

```bash
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show users WHERE 1=1; DROP TABLE users;",
    "selected_tables": ["users"]
  }'

# Expected: Security warning but query shown
```

##### Test 2: Dangerous DELETE

```bash
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Delete all inactive users",
    "selected_tables": ["users"]
  }'

# Expected: Warning about DELETE without WHERE
```

##### Test 3: Rate Limiting (use script)

```bash
# Create test script
cat > test_rate_limit.sh << 'EOF'
#!/bin/bash
for i in {1..25}; do
  echo "Request $i"
  curl -X POST "$API_ENDPOINT/query/generate" \
    -H "x-api-key: demo-api-key-12345" \
    -H "Content-Type: application/json" \
    -d '{"natural_language_query": "Show me orders", "selected_tables": ["orders"]}' &
done
wait
EOF

chmod +x test_rate_limit.sh
./test_rate_limit.sh

# Expected: Some requests throttled
```

##### Test 4: Context Overflow

```bash
# Try to query 20+ tables at once
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me everything",
    "selected_tables": ["users", "orders", "products", "payments", "reviews", "categories", "regions", "order_items"]
  }'

# Expected: Warning about too many tables
```

##### Test 5: Query Timeout

```bash
# Create intentionally slow query
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Calculate every possible combination of products and users",
    "selected_tables": ["users", "products"]
  }'

# Expected: May timeout or be very slow
```

**Phase 2 Complete! ✅**
- Demonstrated security vulnerabilities
- Showed performance issues
- Identified need for production features

---

### PHASE 3: Production Deployment (Week 3-4)

**Goal**: Deploy full production system with all features

#### Step 1: Update Phase Configuration

```bash
# Update to production mode
aws lambda update-function-configuration \
  --function-name sql-query-generator-poc-query-generator \
  --environment "Variables={ACTIVE_PHASE=PRODUCTION,...}"
```

#### Step 2: Test Production Features

##### Feature 1: Query Caching

```bash
# First query (cache miss)
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me total revenue by region",
    "selected_tables": ["orders", "regions"]
  }'
# Note the cost_usd in response

# Second identical query (cache hit)
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me total revenue by region",
    "selected_tables": ["orders", "regions"]
  }'
# Note cache_hit: true and cost_usd: 0
```

##### Feature 2: Security Blocking

```bash
# Try SQL injection (now blocked)
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show users; DROP TABLE users;",
    "selected_tables": ["users"]
  }'

# Expected: 403 Forbidden with security_issues
```

##### Feature 3: Query Refinement

```bash
# Get a query that fails
RESPONSE=$(curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me user revenue",
    "selected_tables": ["users"]
  }')

QUERY_ID=$(echo $RESPONSE | jq -r '.query_id')

# Refine with feedback
curl -X POST "$API_ENDPOINT/query/refine" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent_query_id\": \"$QUERY_ID\",
    \"user_refinement\": \"Join with orders table to calculate total revenue per user\"
  }"
```

##### Feature 4: User Feedback

```bash
# Submit feedback
curl -X POST "$API_ENDPOINT/query/feedback" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d "{
    \"query_id\": \"$QUERY_ID\",
    \"user_rating\": 5,
    \"user_feedback_type\": \"thumbs_up\",
    \"user_feedback_text\": \"Perfect query, worked great!\"
  }"
```

##### Feature 5: Evaluation Metrics

```bash
# Get metrics
curl -X GET "$API_ENDPOINT/evaluation/metrics?start_date=2025-01-01&end_date=2025-01-31" \
  -H "x-api-key: demo-api-key-12345"
```

#### Step 3: Trigger Manual Evaluation

```bash
# Run automated tests
curl -X POST "$API_ENDPOINT/evaluation/tests/run" \
  -H "x-api-key: demo-api-key-12345"
```

#### Step 4: Check CloudWatch Metrics

```bash
# View metrics in CloudWatch console
# Or use CLI:
aws cloudwatch get-metric-statistics \
  --namespace SQLQueryGenerator \
  --metric-name SuccessRate \
  --dimensions Name=TeamId,Value=<your-team-id> \
  --start-time 2025-01-01T00:00:00Z \
  --end-time 2025-01-31T23:59:59Z \
  --period 86400 \
  --statistics Average
```

**Phase 3 Complete! ✅**
- Caching reduces costs by 80%
- Security validation blocks dangerous queries
- User feedback loop implemented
- Comprehensive monitoring active

---

## Cost Analysis Demo

### Without Cache (Phase 1)
```bash
# Run 100 queries
for i in {1..100}; do
  curl -s -X POST "$API_ENDPOINT/query/generate" \
    -H "x-api-key: demo-api-key-12345" \
    -H "Content-Type: application/json" \
    -d '{"natural_language_query": "Show me orders", "selected_tables": ["orders"]}' \
    | jq -r '.cost_usd'
done | awk '{s+=$1} END {print "Total Cost: $"s}'

# Expected: ~$1.50-3.00 for 100 queries
```

### With Cache (Phase 3)
```bash
# Run same 100 queries
for i in {1..100}; do
  curl -s -X POST "$API_ENDPOINT/query/generate" \
    -H "x-api-key: demo-api-key-12345" \
    -H "Content-Type: application/json" \
    -d '{"natural_language_query": "Show me orders", "selected_tables": ["orders"]}' \
    | jq -r '.cost_usd'
done | awk '{s+=$1} END {print "Total Cost: $"s}'

# Expected: ~$0.015-0.30 (80-95% reduction)
```

---

## Monitoring Setup

### CloudWatch Dashboards

Create a dashboard to monitor key metrics:

```bash
# Create dashboard (use AWS Console or CLI)
aws cloudwatch put-dashboard \
  --dashboard-name SQLQueryGenerator \
  --dashboard-body file://dashboard.json
```

### SNS Alerts

Set up email notifications for alarms:

```bash
# Create SNS topic
aws sns create-topic --name sql-query-generator-alerts

# Subscribe email
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:sql-query-generator-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

---

## Troubleshooting

### Common Issues

**Issue**: Lambda can't connect to RDS
**Solution**: Check security group allows Lambda SG on port 5432

**Issue**: API returns 403 Unauthorized
**Solution**: Verify API key is correct: `demo-api-key-12345`

**Issue**: Queries timeout
**Solution**: Increase Lambda timeout in template.yaml

**Issue**: DynamoDB errors
**Solution**: Check IAM permissions for Lambda role

### Logs

```bash
# View Lambda logs
aws logs tail /aws/lambda/sql-query-generator-poc-query-generator --follow

# View aggregator logs
aws logs tail /aws/lambda/sql-query-generator-poc-evaluation-aggregator --follow
```

---

## Cleanup

To delete all resources:

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name sql-query-generator-poc

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name sql-query-generator-poc

# Verify deletion
aws cloudformation list-stacks --stack-status-filter DELETE_COMPLETE
```

---

## Production Checklist

Before going to production:

- [ ] Change default API key from `demo-api-key-12345`
- [ ] Enable VPC endpoints for DynamoDB (cost savings)
- [ ] Set up automated backups for RDS
- [ ] Configure CloudWatch alarms with SNS notifications
- [ ] Review and adjust rate limits per team
- [ ] Set up multi-team access
- [ ] Enable CloudTrail for audit logging
- [ ] Configure automated database backups
- [ ] Set up monitoring dashboard
- [ ] Document runbooks for common issues

---

## Next Steps

1. Build frontend application (React)
2. Create breaking tests suite
3. Add support for MySQL/BigQuery
4. Implement schema auto-introspection
5. Add query optimization suggestions
6. Build admin dashboard for team management

---

## Support

For issues during deployment:
1. Check CloudWatch logs
2. Verify environment variables are set
3. Ensure database migrations ran successfully
4. Confirm API Gateway is deployed correctly
5. Check security group rules

**Happy Deploying! 🚀**
