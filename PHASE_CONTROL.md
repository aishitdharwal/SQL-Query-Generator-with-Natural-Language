# Phase Control Guide - How Phase Separation Works

## 🎯 Overview

The SQL Query Generator system has **THREE DISTINCT PHASES** controlled by a single environment variable: `ACTIVE_PHASE`

- **POC** (Phase 1): Basic functionality
- **BREAKING_DEMO** (Phase 2): Shows security issues  
- **PRODUCTION** (Phase 3): Full features

## 🔧 How to Control Phases

### **Method 1: Set During Deployment (RECOMMENDED)**

When you run `sam deploy --guided`, you'll be prompted:

```
Parameter ActivePhase [POC]: 
```

**Enter one of:**
- `POC` - For Phase 1 demonstrations
- `BREAKING_DEMO` - For Phase 2 demonstrations  
- `PRODUCTION` - For Phase 3 demonstrations

The system will deploy with that phase active.

### **Method 2: Update After Deployment**

```bash
# Get your function name
aws lambda list-functions --query 'Functions[?contains(FunctionName, `query-generator`)].FunctionName'

# Update to POC
aws lambda update-function-configuration \
  --function-name <YOUR-FUNCTION-NAME> \
  --environment "Variables={ACTIVE_PHASE=POC}"

# Update to BREAKING_DEMO  
aws lambda update-function-configuration \
  --function-name <YOUR-FUNCTION-NAME> \
  --environment "Variables={ACTIVE_PHASE=BREAKING_DEMO}"

# Update to PRODUCTION
aws lambda update-function-configuration \
  --function-name <YOUR-FUNCTION-NAME> \
  --environment "Variables={ACTIVE_PHASE=PRODUCTION}"
```

**Note**: When updating environment variables via CLI, you must include ALL variables, not just ACTIVE_PHASE. Better to use Method 3.

### **Method 3: Use AWS Console (EASIEST)**

1. Go to AWS Lambda Console
2. Find your function: `<stack-name>-query-generator`
3. Click **Configuration** tab
4. Click **Environment variables**
5. Click **Edit**
6. Find `ACTIVE_PHASE` variable
7. Change value to: `POC`, `BREAKING_DEMO`, or `PRODUCTION`
8. Click **Save**

**Changes take effect immediately!**

---

## 📍 Where Phase Control Is Implemented

### **1. template.yaml (Lines 29-42)**

```yaml
ActivePhase:
  Type: String
  Default: POC
  AllowedValues:
    - POC
    - BREAKING_DEMO
    - PRODUCTION
  Description: |
    Active phase for the system:
    POC = Basic functionality, no caching, minimal validation
    BREAKING_DEMO = Shows security issues and failures (warnings only)
    PRODUCTION = Full features with caching, security blocking, monitoring
```

This creates a CloudFormation parameter that gets passed to all Lambda functions.

### **2. app.py (Main Handler) - Lines 24-26**

```python
# PHASE CONFIGURATION
ACTIVE_PHASE = os.environ.get('ACTIVE_PHASE', 'PRODUCTION')
```

Reads the environment variable.

### **3. app.py - Cache Check (Lines 89-96)**

```python
# Step 2: PHASE 3 ONLY - Check cache
cached_result = None
cache_hit = False

if ACTIVE_PHASE == 'PRODUCTION':
    cached_result = cache_manager.get_cached_query(
        team_id,
        natural_language_query,
        schema_hash
    )
```

**Phase Behavior:**
- **POC**: Skips cache completely (shows costs)
- **BREAKING_DEMO**: Skips cache (shows costs)
- **PRODUCTION**: Uses cache (saves 80%)

### **4. app.py - Security Handling (Lines 146-173)**

```python
# PHASE 2: Demonstrate security failures
if ACTIVE_PHASE == 'BREAKING_DEMO' and not validation['is_safe']:
    logger.warning(f"⚠️ Security validation failed: {validation['security_issues']}")
    # In breaking demo, we still show the SQL but warn

# PHASE 3: Block unsafe queries in production
if ACTIVE_PHASE == 'PRODUCTION' and not validation['is_safe']:
    logger.error(f"🚫 Blocked unsafe query: {validation['security_issues']}")
    return response(403, {...})
```

**Phase Behavior:**
- **POC**: Minimal validation, allows everything
- **BREAKING_DEMO**: Detects issues but allows execution (with warnings)
- **PRODUCTION**: Blocks dangerous queries (403 response)

### **5. query_validator.py - Validation Methods**

```python
def validate(self, sql: str, allowed_tables: List[str], phase: str = 'PRODUCTION') -> Dict:
    if phase == 'POC':
        return self.validate_for_poc(sql, allowed_tables)
    elif phase == 'BREAKING_DEMO':
        return self.validate_for_breaking_demo(sql, allowed_tables)
    else:
        return self.validate_for_production(sql, allowed_tables)
```

**Phase Behavior:**
- **POC**: Basic syntax validation only
- **BREAKING_DEMO**: Full security detection (but reports, doesn't block)
- **PRODUCTION**: Full validation with blocking

### **6. schema_manager.py - Schema Formatting**

```python
def format_schema_for_claude(self, tables: list, phase: str = 'POC') -> str:
    # PHASE 2: Check table count limits
    if phase == 'POC' and len(tables) > self.MAX_TABLES_POC:
        logger.warning(f"Too many tables for POC: {len(tables)} > {self.MAX_TABLES_POC}")
```

**Phase Behavior:**
- **POC**: Allows up to 5 tables
- **BREAKING_DEMO**: Shows warnings for context overflow
- **PRODUCTION**: Intelligently truncates large schemas

---

## 🎬 Phase-Specific Behaviors

### **PHASE 1: POC**

| Feature | Status | Behavior |
|---------|--------|----------|
| Query Generation | ✅ Active | Claude generates SQL |
| Query Execution | ✅ Active | Executes against database |
| Caching | ❌ Disabled | Every query calls Claude API |
| Security Validation | ⚠️ Minimal | Basic syntax only |
| Rate Limiting | ❌ Disabled | No limits |
| User Feedback | ❌ Disabled | Not collected |
| Metrics | ❌ Disabled | Basic logging only |

**Demo Focus**: Show it works, observe costs

### **PHASE 2: BREAKING_DEMO**

| Feature | Status | Behavior |
|---------|--------|----------|
| Query Generation | ✅ Active | Claude generates SQL |
| Query Execution | ✅ Active | Executes (even unsafe queries!) |
| Caching | ❌ Disabled | Shows costs |
| Security Validation | ⚠️ Detection Only | Warns but doesn't block |
| Rate Limiting | ⚠️ Shows Issue | Demonstrates throttling |
| Dangerous Queries | ⚠️ Allowed | DELETE/DROP execute with warning |
| SQL Injection | ⚠️ Detected | Pattern detected but allowed |

**Demo Focus**: Show 5 breaking points, build case for production features

### **PHASE 3: PRODUCTION**

| Feature | Status | Behavior |
|---------|--------|----------|
| Query Generation | ✅ Active | Claude generates SQL |
| Query Execution | ✅ Active | Only safe queries |
| Caching | ✅ Active | 80% cost reduction |
| Security Validation | ✅ Full | Blocks dangerous queries |
| Rate Limiting | ✅ Active | 10 req/min enforced |
| User Feedback | ✅ Active | Ratings collected |
| Metrics | ✅ Active | Full CloudWatch integration |
| Query Refinement | ✅ Active | Error recovery workflow |

**Demo Focus**: Show cost savings, security, monitoring

---

## 🧪 Testing Each Phase

### **Test POC Phase**

```bash
# Set phase
export ACTIVE_PHASE=POC

# Test basic query
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show me all users",
    "selected_tables": ["users"]
  }'

# Expected response:
# - success: true
# - generated_sql: "SELECT * FROM users LIMIT 100"
# - cache_hit: false
# - cost_usd: 0.015
# - phase: "POC"
```

### **Test BREAKING_DEMO Phase**

```bash
# Set phase
export ACTIVE_PHASE=BREAKING_DEMO

# Test SQL injection
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show users; DROP TABLE users;",
    "selected_tables": ["users"]
  }'

# Expected response:
# - success: true (still executes!)
# - security_issues: ["Detected injection pattern: ..."]
# - validation: { is_safe: false, warnings: [...] }
# - phase: "BREAKING_DEMO"
```

### **Test PRODUCTION Phase**

```bash
# Set phase
export ACTIVE_PHASE=PRODUCTION

# Test same SQL injection
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show users; DROP TABLE users;",
    "selected_tables": ["users"]
  }'

# Expected response:
# - statusCode: 403
# - error: "Query blocked for security reasons"
# - security_issues: ["SQL injection attempt detected"]
# - phase: "PRODUCTION"

# Test caching
curl -X POST "$API/query/generate" \
  -H "x-api-key: demo-api-key-12345" \
  -H "Content-Type: application/json" \
  -d '{
    "natural_language_query": "Show total revenue by region",
    "selected_tables": ["orders", "regions"]
  }'

# First time: cache_hit: false, cost_usd: 0.015
# Second time: cache_hit: true, cost_usd: 0
```

---

## 🔍 Verifying Active Phase

### **Check via Logs**

```bash
# View Lambda logs
aws logs tail /aws/lambda/<your-function-name> --follow

# Look for:
# "Request: POST /query/generate [Phase: POC]"
# "Request: POST /query/generate [Phase: BREAKING_DEMO]"  
# "Request: POST /query/generate [Phase: PRODUCTION]"
```

### **Check via API Response**

Every response includes the active phase:

```json
{
  "query_id": "...",
  "generated_sql": "...",
  "phase": "POC"  // ← Current phase
}
```

### **Check Environment Variable**

```bash
# Get current configuration
aws lambda get-function-configuration \
  --function-name <your-function-name> \
  --query 'Environment.Variables.ACTIVE_PHASE'

# Returns: "POC", "BREAKING_DEMO", or "PRODUCTION"
```

---

## 📊 Phase Comparison Table

| Feature | POC | BREAKING_DEMO | PRODUCTION |
|---------|-----|---------------|------------|
| **Query Generation** | ✅ | ✅ | ✅ |
| **Query Execution** | ✅ | ✅ | ✅ Safe Only |
| **Caching** | ❌ | ❌ | ✅ |
| **Security Detection** | ❌ | ✅ Warns | ✅ Blocks |
| **Rate Limiting** | ❌ | ❌ | ✅ |
| **Query Refinement** | ❌ | ❌ | ✅ |
| **User Feedback** | ❌ | ❌ | ✅ |
| **Metrics** | Basic | Basic | Full |
| **Cost/1000 queries** | $15 | $15 | $3 |
| **Security Score** | 🔴 | 🟡 | 🟢 |

---

## 🎓 Teaching Progression

### **Week 1: Deploy with POC**
```bash
sam deploy --guided
# When prompted: ActivePhase = POC
```

**Demonstrate:**
- Basic functionality works
- Every query costs money
- No security validation

### **Week 2: Switch to BREAKING_DEMO**
```bash
# Via Console or CLI
ACTIVE_PHASE=BREAKING_DEMO
```

**Demonstrate:**
- 5 breaking points
- Security vulnerabilities
- Cost problems
- Performance issues

### **Week 3: Switch to PRODUCTION**
```bash
# Via Console or CLI
ACTIVE_PHASE=PRODUCTION
```

**Demonstrate:**
- 80% cost savings from cache
- Security blocking works
- All production features active

---

## 🚨 Common Issues

### **Issue**: Phase not changing
**Solution**: Wait 30 seconds after updating environment variable for Lambda to pick up changes

### **Issue**: Still seeing old behavior
**Solution**: Check logs to confirm phase. Lambda may be using cached container.

### **Issue**: Can't find ACTIVE_PHASE variable
**Solution**: Redeploy stack with updated template.yaml that includes ActivePhase parameter

---

## ✅ Quick Commands

```bash
# Check current phase
aws lambda get-function-configuration \
  --function-name <name> \
  --query 'Environment.Variables.ACTIVE_PHASE'

# Switch to POC
aws lambda update-function-configuration \
  --function-name <name> \
  --environment "Variables={ACTIVE_PHASE=POC}"

# Switch to BREAKING_DEMO
aws lambda update-function-configuration \
  --function-name <name> \
  --environment "Variables={ACTIVE_PHASE=BREAKING_DEMO}"

# Switch to PRODUCTION
aws lambda update-function-configuration \
  --function-name <name> \
  --environment "Variables={ACTIVE_PHASE=PRODUCTION}"
```

---

**Phase control is now crystal clear! 🎯**
