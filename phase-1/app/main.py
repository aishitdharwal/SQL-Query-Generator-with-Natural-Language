from fastapi import FastAPI, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel
from typing import Optional
import os

from app.auth import authenticate_user, verify_token
from app.database import db_manager
from app.sql_generator import sql_generator

# Initialize FastAPI app
app = FastAPI(title="SQL Query Generator", version="1.0.0")

# Setup templates
templates = Jinja2Templates(directory="templates")


# Pydantic models
class LoginRequest(BaseModel):
    username: str
    team: str
    password: str


class QueryRequest(BaseModel):
    natural_language_query: str
    token: str


class ExecuteQueryRequest(BaseModel):
    sql_query: str
    token: str


# Routes
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    """Serve the login page"""
    return templates.TemplateResponse("login.html", {"request": request})


@app.get("/dashboard", response_class=HTMLResponse)
async def dashboard(request: Request):
    """Serve the main dashboard"""
    return templates.TemplateResponse("dashboard.html", {"request": request})


@app.post("/api/login")
async def login(login_request: LoginRequest):
    """Authenticate user and return token"""
    result = authenticate_user(
        login_request.username,
        login_request.team,
        login_request.password
    )
    
    if not result["success"]:
        raise HTTPException(status_code=401, detail=result["message"])
    
    return result


@app.post("/api/verify-token")
async def verify_user_token(request: Request):
    """Verify if token is valid"""
    body = await request.json()
    token = body.get("token")
    
    if not token:
        raise HTTPException(status_code=401, detail="No token provided")
    
    result = verify_token(token)
    
    if not result["valid"]:
        raise HTTPException(status_code=401, detail=result["message"])
    
    return result


@app.post("/api/get-schema")
async def get_schema(request: Request):
    """Get database schema for authenticated user's team"""
    body = await request.json()
    token = body.get("token")
    
    if not token:
        raise HTTPException(status_code=401, detail="No token provided")
    
    # Verify token
    user_info = verify_token(token)
    if not user_info["valid"]:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    team = user_info["team"]
    
    try:
        schema_info = db_manager.get_table_schemas(team)
        return {
            "success": True,
            "team": team,
            "schema": schema_info
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/generate-query")
async def generate_query(query_request: QueryRequest):
    """Generate SQL query from natural language"""
    # Verify token
    user_info = verify_token(query_request.token)
    if not user_info["valid"]:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    team = user_info["team"]
    
    try:
        # Get schema for context
        schema_info = db_manager.get_table_schemas(team)
        
        # Generate SQL query
        result = sql_generator.generate_sql(
            query_request.natural_language_query,
            schema_info
        )
        
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["error"])
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/execute-query")
async def execute_query(execute_request: ExecuteQueryRequest):
    """Execute SQL query on the database"""
    # Verify token
    user_info = verify_token(execute_request.token)
    if not user_info["valid"]:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    team = user_info["team"]
    
    try:
        result = db_manager.execute_query(team, execute_request.sql_query)
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


# Cleanup on shutdown
@app.on_event("shutdown")
async def shutdown_event():
    """Close database connections on shutdown"""
    db_manager.close_all_pools()


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
