# SQL Query Generator with Natural Language

## Project Overview

A production-grade AI system that translates plain English questions into SQL queries by understanding database schemas, relationships, and business logic constraints. This project demonstrates building schema-aware AI systems, implementing robust query validation and security measures, and deploying scalable APIs.

## System Architecture

```
Frontend (React + S3/CloudFront)
    ↓
API Gateway (API Key Auth)
    ↓
Lambda Functions (VPC)
    ↓
┌─────────────────────┬──────────────────────┐
│   System RDS DB     │  Sample/User DB      │
│   (Metadata)        │  (Business Data)     │
└─────────────────────┴──────────────────────┘
    ↓
DynamoDB (Query Cache)
```

## Project Structure

```
SQL-Query-Generator-with-Natural-Language/
├── template.yaml                 # SAM CloudFormation template
├── README.md                      # This file
├── backend/
│   ├── src/
│   │   ├── shared/               # Shared utilities
│   │   │   ├── db_utils.py      # Database connection utilities
│   │   │   └── models.py        # Data models
│   │   ├── authorizer/           # API Key authorization
│   │   │   ├── app.py
│   │   │   └── requirements.txt
│   │   ├── query_generator/      # Main query generation
│   │   │   ├── app.py           # Lambda handler
│   │   │   ├── claude_client.py # Claude API integration
│   │   │   ├── cache_manager.py # DynamoDB caching
│   │   │   ├── query_validator.py # Security validation
│   │   │   ├── schema_manager.py # Schema retrieval
│   │   │   └── requirements.txt
│   │   ├── schema_uploader/      # Schema introspection
│   │   │   ├── app.py
│   │   │   └── requirements.txt
│   │   └── evaluation/           # Monitoring & evaluation
│   │       ├── aggregator.py    # Daily metrics aggregation
│   │       ├── model_tests.py   # Automated testing
│   │       ├── metrics.py       # Metrics API
│   │       └── requirements.txt
│   └── migrations/
│       ├── 01_system_db_schema.sql    # System database
│       └── 02_sample_ecommerce_schema.sql # Sample data
├── frontend/                     # React frontend (to be built)
│   └── src/
│       ├── components/
│       ├── services/
│       └── utils/
├── schemas/                      # Sample schemas for testing
├── tests/                        # Tests
│   ├── breaking_tests/          # Intentional failure tests
│   └── unit_tests/              # Unit tests
└── docs/                        # Documentation
```

## Key Features

### Phase 1: POC (Week 1-2)
- ✅ Basic query generation from natural language
- ✅ PostgreSQL schema understanding
- ✅ Query execution and result return
- ✅ Simple error handling

### Phase 2: Breaking Points (Week 2)
- SQL injection attempts
- Dangerous queries (DELETE/UPDATE without WHERE)
- Schema context window overflow
- Rate limiting failures
- Query timeout scenarios

### Phase 3: Production Features (Week 3-4)
- Query caching (80% cost reduction)
- Multi-team support with API keys
- User feedback and ratings
- Query refinement after errors
- Automated evaluation and testing
- Real-time metrics dashboard
- CloudWatch monitoring and alarms

## Database Schemas

### System Database (RDS PostgreSQL)
Stores application metadata:
- `teams` - Team information and API keys
- `database_schemas` - Schema metadata
- `tables_metadata` - Table DDL and descriptions
- `query_history` - All query executions with feedback
- `evaluation_metrics` - Daily aggregated metrics
- `model_evaluation_tests` - Automated test cases

### Sample E-commerce Database (RDS PostgreSQL)
Realistic business data for testing:
- Users, Products, Categories
- Orders, Order Items, Payments
- Reviews, Regions
- ~100 sample orders with realistic data
- Pre-built views for common queries

### Query Cache (DynamoDB)
- Partition Key: `cache_key` (hash of query + schema)
- TTL: 1 week (604,800 seconds)
- Global Secondary Index on `team_id`

## Deployment

### Prerequisites
1. AWS CLI configured
2. SAM CLI installed
3. Anthropic API key

### Deploy Backend

```bash
# Build the SAM application
sam build

# Deploy with guided setup
sam deploy --guided

# You'll be prompted for:
# - Stack name
# - AWS Region
# - System DB password
# - Sample DB password
# - Anthropic API key
```

### Initialize Databases

```bash
# Get RDS endpoints from CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name your-stack-name \
  --query 'Stacks[0].Outputs'

# Run system database migration
psql -h <system-db-endpoint> -U admin -d sql_query_generator \
  -f backend/migrations/01_system_db_schema.sql

# Run sample database migration
psql -h <sample-db-endpoint> -U admin -d ecommerce \
  -f backend/migrations/02_sample_ecommerce_schema.sql
```

### Test the API

```bash
# Get API endpoint
export API_ENDPOINT=$(aws cloudformation describe-stacks \
  --stack-name your-stack-name \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
  --output text)

# Generate a query
curl -X POST "$API_ENDPOINT/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me total revenue by region",
    "selected_tables": ["orders", "regions"]
  }'
```

## API Endpoints

### Query Generation
```
POST /query/generate
Headers: x-api-key
Body: {
  "natural_language_query": "string",
  "selected_tables": ["table1", "table2"]
}
```

### Query Refinement
```
POST /query/refine
Headers: x-api-key
Body: {
  "parent_query_id": "uuid",
  "user_refinement": "string"
}
```

### User Feedback
```
POST /query/feedback
Headers: x-api-key
Body: {
  "query_id": "uuid",
  "user_rating": 1-5,
  "user_feedback_type": "thumbs_up" | "thumbs_down",
  "user_feedback_text": "optional string"
}
```

### Evaluation Metrics
```
GET /evaluation/metrics?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD
Headers: x-api-key
```

### Run Model Tests
```
POST /evaluation/tests/run
Headers: x-api-key
```

## Evaluation & Monitoring

### Automated Metrics
- Success/failure rates
- Query execution times (avg, p95, p99)
- Cache hit rates
- Cost tracking (with/without cache)
- Error type breakdown

### User Feedback
- Star ratings (1-5)
- Thumbs up/down
- Optional text feedback
- Feedback rate tracking

### CloudWatch Alarms
- High error rate (>20%)
- Low success rate (<80%)
- Low user satisfaction (<3.5 rating)

### Daily Aggregation
- Lambda runs at midnight UTC
- Aggregates all metrics per team
- Publishes to CloudWatch
- Stores in `evaluation_metrics` table

## Cost Optimization

### Query Caching
- Cache key: hash(team_id + query + schema_hash)
- 1-week TTL
- Expected 80% cache hit rate
- Cost savings: ~$200/month per team

### Rate Limiting
- 10 requests/minute per team
- 1000 queries/month default limit
- Burst limit: 20 requests

### Resource Optimization
- Lambda: 512MB-1024MB memory
- RDS: db.t3.micro (free tier eligible)
- DynamoDB: Pay-per-request billing

## Security

### API Key Authentication
- Stored in system database
- Validated by Lambda authorizer
- Team context injected into requests

### Query Validation
- Syntax checking
- Dangerous operation detection
- SQL injection prevention
- Rate limiting per team

### VPC Configuration
- Lambdas in private subnets
- RDS in private subnets
- Security groups for access control

## Breaking Points Demonstrations

### 1. SQL Injection
```
Input: "Show users WHERE 1=1; DROP TABLE users;"
Expected: Blocked with security error
```

### 2. Dangerous DELETE
```
Input: "Delete all inactive users"
Generated: DELETE FROM users WHERE last_login < ...
Expected: Warning, require confirmation
```

### 3. Context Window Overflow
```
Input: Select 50 tables with complex schemas
Expected: Error, then implement smart filtering
```

### 4. Rate Limiting
```
Input: 100 concurrent requests
Expected: Throttling, then implement queue
```

### 5. Query Timeout
```
Input: "Analyze 10 years of data with complex joins"
Expected: Timeout, then implement 30s limit
```

## Future Enhancements

### Planned Features
- [ ] Support for MySQL and BigQuery dialects
- [ ] Natural language query suggestions
- [ ] Query optimization recommendations
- [ ] Visual query builder
- [ ] Slack integration for alerts
- [ ] Export results to CSV/Excel
- [ ] Scheduled/saved queries
- [ ] Team collaboration features

### Advanced Features
- [ ] Multi-database queries
- [ ] Query version history
- [ ] A/B testing different prompts
- [ ] Custom query templates
- [ ] Role-based access control

## Learning Objectives

### Students will learn:
1. Building production AI systems with Claude
2. Schema-aware prompt engineering
3. Query validation and security
4. Caching strategies for cost optimization
5. Error handling and user feedback loops
6. Evaluation and monitoring systems
7. CloudFormation/SAM deployment
8. VPC and security group configuration

## Course Context

This is **Project 2** in the Production AI Engineering cohort, following the Code Documentation Generator. It builds on concepts learned in Project 1 while introducing:
- More complex prompt engineering (schema context)
- Query validation and security
- User feedback loops
- Comprehensive evaluation systems
- Cost optimization through caching

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review RDS database for query history
3. Verify API key is valid
4. Ensure VPC and security groups are configured
5. Check DynamoDB for cache entries

## License

This project is for educational purposes as part of the Production AI Engineering cohort.
