# Three-Phase Quick Reference Card

## 🎯 Phase Configuration Quick Guide

### How to Switch Phases

Update the Lambda environment variable `ACTIVE_PHASE`:

```bash
# Set to POC
aws lambda update-function-configuration \
  --function-name <your-function-name> \
  --environment "Variables={ACTIVE_PHASE=POC,...}"

# Set to BREAKING_DEMO
aws lambda update-function-configuration \
  --function-name <your-function-name> \
  --environment "Variables={ACTIVE_PHASE=BREAKING_DEMO,...}"

# Set to PRODUCTION
aws lambda update-function-configuration \
  --function-name <your-function-name> \
  --environment "Variables={ACTIVE_PHASE=PRODUCTION,...}"
```

---

## Phase 1: POC

### What's Active
✅ Basic SQL generation  
✅ Query execution  
✅ Simple validation  
❌ No caching  
❌ No advanced security  
❌ No feedback system  

### Demo Script
```bash
# 1. Generate a simple query
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show me all users", "selected_tables": ["users"]}'

# 2. Show the cost
# Notice: cost_usd field shows ~$0.015

# 3. Repeat same query
# Notice: SAME cost again (no cache)

# Key Message: "This costs $15 per 1000 queries!"
```

### Talking Points
- "Claude understands our schema and generates valid SQL"
- "Query executes successfully and returns results"
- "But notice - every query costs money, even if it's identical"
- "Let's see what happens when we stress test this..."

---

## Phase 2: Breaking Points

### What's Active
✅ All POC features  
✅ Security detection (warnings only)  
✅ Dangerous operation detection  
✅ Context overflow handling  
❌ Still no caching  
❌ Security warnings but NOT blocking  

### Demo Script

#### Test 1: SQL Injection
```bash
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show users; DROP TABLE users;", "selected_tables": ["users"]}'

# 🚨 Response shows security_issues but query still executes
```
**Message**: "We detected the injection but didn't block it. In POC, we just lost all user data!"

#### Test 2: Dangerous DELETE
```bash
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Delete all inactive users", "selected_tables": ["users"]}'

# 🚨 Shows DELETE without WHERE warning
```
**Message**: "This would delete ALL users, not just inactive ones!"

#### Test 3: Rate Limiting Chaos
```bash
# Run 25 concurrent requests
for i in {1..25}; do
  curl -X POST "$API/query/generate" \
    -H "x-api-key: demo-api-key-12345" \
    -d '{"natural_language_query": "Show orders", "selected_tables": ["orders"]}' &
done
wait

# 🚨 Some throttled, costs spike to $0.375
```
**Message**: "No rate limiting = $37.50 if 100 users do this!"

#### Test 4: Context Overflow
```bash
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{
    "natural_language_query": "Show everything",
    "selected_tables": ["users","orders","products","payments","reviews","categories","regions","order_items"]
  }'

# 🚨 Schema too large warning
```
**Message**: "Too much context! Claude gets confused with 20+ tables"

#### Test 5: Timeout
```bash
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Calculate every possible product-user combination", "selected_tables": ["users","products"]}'

# 🚨 Query times out or takes minutes
```
**Message**: "No timeout limits = users waiting forever!"

### Talking Points
- "We found 5 critical failure points"
- "SQL injection could delete our database"
- "No rate limiting means unlimited costs"
- "Schema overflow breaks the AI"
- "Long queries hang the system"
- "We need production features to fix all of this..."

---

## Phase 3: Production

### What's Active
✅ All features from Phase 1 & 2  
✅ Query caching (80% cost reduction)  
✅ Security BLOCKING (not just warnings)  
✅ Rate limiting enforcement  
✅ User feedback collection  
✅ Automated evaluation  
✅ CloudWatch monitoring  

### Demo Script

#### Feature 1: Caching Magic ✨
```bash
# First query (cache miss)
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show total revenue by region", "selected_tables": ["orders","regions"]}'

# Response: cost_usd: 0.015, cache_hit: false

# Same query again (cache hit)
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show total revenue by region", "selected_tables": ["orders","regions"]}'

# Response: cost_usd: 0, cache_hit: true, cache_savings: "Saved ~$0.015"
```
**Message**: "Second query: FREE! 80% of queries will be cached = $12 instead of $60/month"

#### Feature 2: Security Shield 🛡️
```bash
# Try SQL injection
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show users; DROP TABLE users;", "selected_tables": ["users"]}'

# Response: 403 Forbidden, security_issues: ["SQL injection detected"]
```
**Message**: "BLOCKED! No more accidental database deletions"

#### Feature 3: Smart Refinement 🔄
```bash
# Query fails
RESPONSE=$(curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show user revenue", "selected_tables": ["users"]}')

QUERY_ID=$(echo $RESPONSE | jq -r '.query_id')

# User refines
curl -X POST "$API/query/refine" \
  -H "x-api-key: demo-api-key-12345" \
  -d "{\"parent_query_id\": \"$QUERY_ID\", \"user_refinement\": \"Join with orders table\"}"

# Response: New SQL with JOIN, attempt_number: 2
```
**Message**: "Failed query? User gives feedback, Claude fixes it!"

#### Feature 4: User Feedback Loop 💬
```bash
# Submit feedback
curl -X POST "$API/query/feedback" \
  -H "x-api-key: demo-api-key-12345" \
  -d "{\"query_id\": \"$QUERY_ID\", \"user_rating\": 5, \"user_feedback_type\": \"thumbs_up\"}"
```
**Message**: "Every query is rated. System learns what works!"

#### Feature 5: Live Metrics 📊
```bash
# Get metrics
curl -X GET "$API/evaluation/metrics" \
  -H "x-api-key: demo-api-key-12345"

# Response:
# - success_rate: 94.2%
# - avg_user_rating: 4.6
# - cache_hit_rate: 78.3%
# - cost_savings: $47.23
```
**Message**: "Real-time visibility into system health and costs"

### Talking Points
- "Caching cuts costs by 80%"
- "Security blocks dangerous queries automatically"
- "Users can refine failed queries"
- "Feedback loop improves over time"
- "Complete observability with metrics"
- "This is production-ready!"

---

## Side-by-Side Comparison

| Feature | POC | Breaking Demo | Production |
|---------|-----|---------------|------------|
| **Query Generation** | ✅ | ✅ | ✅ |
| **Query Execution** | ✅ | ✅ | ✅ |
| **Caching** | ❌ | ❌ | ✅ |
| **Security Blocking** | ❌ | ⚠️ Warns | ✅ Blocks |
| **Rate Limiting** | ❌ | ⚠️ Shows issue | ✅ Enforced |
| **Query Refinement** | ❌ | ❌ | ✅ |
| **User Feedback** | ❌ | ❌ | ✅ |
| **Metrics & Monitoring** | ❌ | ⚠️ Basic | ✅ Full |
| **Cost per 1000 queries** | $15 | $15 | $3 |
| **Security Score** | 🔴 Poor | 🟡 Fair | 🟢 Excellent |

---

## Demo Flow Recommendation

### 30-Minute Demo Structure

**Minutes 0-5: Introduction**
- "We're building an AI system that turns English into SQL"
- "Follow along as we go from prototype to production"

**Minutes 5-10: Phase 1 - POC**
- Show basic query generation working
- Execute a few queries
- Point out the costs: "$15 per 1000 queries"
- "This works, but let's stress test it..."

**Minutes 10-20: Phase 2 - Breaking Points**
- Run all 5 breaking tests
- Watch SQL injection warnings
- Show rate limiting chaos
- Demo schema overflow
- "We found 5 critical issues. Let's fix them."

**Minutes 20-30: Phase 3 - Production**
- Enable caching, show 80% savings
- Block SQL injection attempts
- Demonstrate query refinement
- Show metrics dashboard
- "Same system, but production-ready!"

**Closing**
- "In 3 phases, we went from prototype to production"
- "This is how you build real AI systems"

---

## Key Demo Metrics to Highlight

### POC
- ✅ Works: Yes
- 💰 Cost/1000 queries: $15
- 🛡️ Security: None
- 📊 Monitoring: None

### Breaking Demo
- ❌ Security holes: 5 found
- 💸 Cost if attacked: $375+
- ⏱️ Performance issues: Yes
- 🚨 User experience: Poor

### Production
- ✅ Works: Yes
- 💰 Cost/1000 queries: $3 (80% savings)
- 🛡️ Security: Full
- 📊 Monitoring: Complete
- ⭐ User satisfaction: 4.6/5

---

## Quick Test Commands

```bash
# Set your endpoint
export API="https://your-api-endpoint.com"

# Phase 1 Test
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show me all users", "selected_tables": ["users"]}'

# Phase 2 Test (SQL Injection)
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show users; DROP TABLE users;", "selected_tables": ["users"]}'

# Phase 3 Test (Caching)
# Run twice, second should be cache hit
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -d '{"natural_language_query": "Show total revenue by region", "selected_tables": ["orders","regions"]}'
```

---

## Student Exercise Ideas

### After Phase 1
- "Estimate monthly costs for 10,000 queries"
- "What happens if we have 100 concurrent users?"

### After Phase 2
- "List all the security issues you found"
- "Which breaking point is most critical?"
- "How would you fix each issue?"

### After Phase 3
- "Calculate actual cost savings from caching"
- "Design a new query refinement workflow"
- "What metrics would you add?"

---

## Troubleshooting by Phase

### POC Issues
- Lambda timeout → Increase timeout in template.yaml
- Database connection → Check security groups
- API 403 → Verify API key

### Breaking Demo Issues
- Rate limiting not showing → Increase concurrent requests
- SQL injection not detected → Check validator phase setting
- No warnings → Verify ACTIVE_PHASE=BREAKING_DEMO

### Production Issues
- Cache not working → Check DynamoDB permissions
- Queries still blocked → Verify they're actually safe
- Metrics not appearing → Check CloudWatch namespace

---

**This quick reference is your companion for demonstrating all three phases! 🎯**
