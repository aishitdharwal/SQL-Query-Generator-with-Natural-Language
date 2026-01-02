# Backend API Documentation

## Part 2: FastAPI Backend

The backend provides a RESTful API for authentication, schema exploration, SQL generation, and query execution.

## Setup

### 1. Install Dependencies

```bash
cd backend
chmod +x setup.sh
./setup.sh
```

This will:
- Create a Python virtual environment
- Install all required packages
- Prepare the backend for running

### 2. Configure Environment

Ensure your `.env` file in the `phase-1/` directory has:
- `DB_HOST` - Aurora cluster endpoint
- `ANTHROPIC_API_KEY` - Your Claude API key
- Team credentials properly set

### 3. Run the Server

```bash
chmod +x run.sh
./run.sh
```

Or manually:
```bash
source venv/bin/activate
python main.py
```

The server will start on `http://localhost:8000`

## API Endpoints

### Health Check
- **GET** `/` - Root endpoint
- **GET** `/health` - Health check

### Authentication
- **POST** `/api/login` - Login with username and password
  ```json
  {
    "username": "sales_user",
    "password": "sales_secure_pass_123"
  }
  ```
  Returns session cookie

- **POST** `/api/logout` - Logout and clear session

- **GET** `/api/session` - Get current session info

### Schema Exploration
- **GET** `/api/schema` - Get full database schema for user's team
- **GET** `/api/tables` - Get list of tables
- **GET** `/api/table/{table_name}` - Get table details with sample data

### SQL Generation & Execution
- **POST** `/api/generate-sql` - Generate SQL from natural language
  ```json
  {
    "natural_query": "Show me all customers who made orders in December"
  }
  ```

- **POST** `/api/execute-query` - Execute a SQL query
  ```json
  {
    "sql_query": "SELECT * FROM customers LIMIT 10"
  }
  ```

- **POST** `/api/query` - Combined: Generate and execute in one call
  ```json
  {
    "natural_query": "What are the top 5 products by sales?"
  }
  ```

## Interactive API Documentation

Once the server is running, visit:
- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`

## Testing the API

### Using curl

```bash
# Login
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -d '{"username": "sales_user", "password": "sales_secure_pass_123"}' \
  -c cookies.txt

# Get schema
curl -X GET http://localhost:8000/api/schema \
  -b cookies.txt

# Generate SQL
curl -X POST http://localhost:8000/api/generate-sql \
  -H "Content-Type: application/json" \
  -d '{"natural_query": "Show me all customers"}' \
  -b cookies.txt

# Execute query
curl -X POST http://localhost:8000/api/query \
  -H "Content-Type: application/json" \
  -d '{"natural_query": "How many orders were placed in December 2024?"}' \
  -b cookies.txt
```

### Using Python

```python
import requests

# Login
session = requests.Session()
response = session.post(
    "http://localhost:8000/api/login",
    json={
        "username": "sales_user",
        "password": "sales_secure_pass_123"
    }
)
print(response.json())

# Get tables
response = session.get("http://localhost:8000/api/tables")
print(response.json())

# Generate and execute query
response = session.post(
    "http://localhost:8000/api/query",
    json={
        "natural_query": "Show me the top 5 customers by total order amount"
    }
)
print(response.json())
```

## Architecture

### Components

1. **main.py** - FastAPI application with all endpoints
2. **database.py** - Database connection and query execution
3. **sql_generator.py** - Claude API integration for SQL generation
4. **auth.py** - Authentication and session management

### Authentication Flow

1. User submits credentials via `/api/login`
2. Backend validates against team credentials
3. Session created and returned as HTTP-only cookie
4. Subsequent requests include session cookie
5. Backend validates session before processing requests

### SQL Generation Flow

1. User submits natural language query
2. Backend fetches database schema for user's team
3. Schema + query sent to Claude API
4. Claude generates SQL query
5. SQL returned to user or automatically executed

### Security Features

- Team-based access control
- Session-based authentication
- HTTP-only cookies
- Database user isolation (each team has separate DB user)
- Read-only by default (can be enhanced)

## Environment Variables Used

```
DB_HOST - Aurora cluster endpoint
DB_PORT - PostgreSQL port (5432)
SALES_TEAM_USERNAME - Sales team DB username
SALES_TEAM_PASSWORD - Sales team DB password
SALES_DB_NAME - Sales database name
MARKETING_TEAM_USERNAME - Marketing team DB username
MARKETING_TEAM_PASSWORD - Marketing team DB password
MARKETING_DB_NAME - Marketing database name
OPERATIONS_TEAM_USERNAME - Operations team DB username
OPERATIONS_TEAM_PASSWORD - Operations team DB password
OPERATIONS_DB_NAME - Operations database name
ANTHROPIC_API_KEY - Claude API key
CLAUDE_MODEL - Claude model to use (default: claude-sonnet-4-5-20250929)
```

## Next Steps

**Coming in Part 3:**
- HTML/CSS/JavaScript frontend
- User interface for login
- Schema browser
- Query input and results display
- Integration with backend API
