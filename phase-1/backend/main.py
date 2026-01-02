"""
FastAPI application for SQL Query Generator
"""
from fastapi import FastAPI, HTTPException, Cookie, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, Dict, Any
import os
from dotenv import load_dotenv

from database import db_manager
from sql_generator import sql_generator
from auth import auth_manager

load_dotenv()

app = FastAPI(
    title="SQL Query Generator API",
    description="Natural language to SQL query converter with team-based access",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify exact origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic models
class LoginRequest(BaseModel):
    username: str
    password: str


class QueryRequest(BaseModel):
    natural_query: str


class ExecuteQueryRequest(BaseModel):
    sql_query: str


# Health check endpoint
@app.get("/")
async def root():
    return {
        "message": "SQL Query Generator API",
        "status": "running",
        "version": "1.0.0"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


# Authentication endpoints
@app.post("/api/login")
async def login(request: LoginRequest, response: Response):
    """Authenticate user and create session"""
    team = auth_manager.authenticate(request.username, request.password)
    
    if not team:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # Create session
    session_id = auth_manager.create_session(team, request.username)
    
    # Set session cookie
    response.set_cookie(
        key="session_id",
        value=session_id,
        httponly=True,
        max_age=86400,  # 24 hours
        samesite="lax"
    )
    
    return {
        "success": True,
        "team": team,
        "username": request.username,
    }


@app.post("/api/logout")
async def logout(response: Response, session_id: Optional[str] = Cookie(None)):
    """Logout user and delete session"""
    if session_id:
        auth_manager.delete_session(session_id)
    
    response.delete_cookie("session_id")
    
    return {"success": True, "message": "Logged out successfully"}


@app.get("/api/session")
async def get_session(session_id: Optional[str] = Cookie(None)):
    """Get current session information"""
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    return {
        "team": session["team"],
        "username": session["username"],
    }


# Database endpoints
@app.get("/api/schema")
async def get_schema(session_id: Optional[str] = Cookie(None)):
    """Get database schema for authenticated user's team"""
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    try:
        schema_info = db_manager.get_schema_info(session["team"])
        return {
            "success": True,
            "team": session["team"],
            "schema": schema_info,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/tables")
async def get_tables(session_id: Optional[str] = Cookie(None)):
    """Get list of tables for authenticated user's team"""
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    try:
        schema_info = db_manager.get_schema_info(session["team"])
        tables = list(schema_info.keys())
        
        return {
            "success": True,
            "team": session["team"],
            "tables": tables,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/table/{table_name}")
async def get_table_info(table_name: str, session_id: Optional[str] = Cookie(None)):
    """Get detailed information about a specific table"""
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    try:
        schema_info = db_manager.get_schema_info(session["team"])
        
        if table_name not in schema_info:
            raise HTTPException(status_code=404, detail=f"Table '{table_name}' not found")
        
        # Get sample data
        sample_data = db_manager.get_sample_data(session["team"], table_name, limit=5)
        
        return {
            "success": True,
            "table_name": table_name,
            "schema": schema_info[table_name],
            "sample_data": sample_data,
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# SQL generation and execution endpoints
@app.post("/api/generate-sql")
async def generate_sql(request: QueryRequest, session_id: Optional[str] = Cookie(None)):
    """Generate SQL query from natural language"""
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    try:
        # Get schema for the user's team
        schema_info = db_manager.get_schema_info(session["team"])
        
        # Generate SQL using Claude
        result = sql_generator.generate_sql(
            natural_query=request.natural_query,
            schema_info=schema_info,
            database_type="postgresql"
        )
        
        if not result["success"]:
            raise HTTPException(status_code=500, detail=result["error"])
        
        return {
            "success": True,
            "natural_query": request.natural_query,
            "sql_query": result["sql_query"],
            "model_used": result["model_used"],
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/execute-query")
async def execute_query(request: ExecuteQueryRequest, session_id: Optional[str] = Cookie(None)):
    """Execute a SQL query"""
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    try:
        result = db_manager.execute_query(session["team"], request.sql_query)
        
        return {
            **result,
            "sql_query": request.sql_query,
            "team": session["team"],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/api/query")
async def query_endpoint(request: QueryRequest, session_id: Optional[str] = Cookie(None)):
    """
    Combined endpoint: Generate SQL from natural language and execute it
    """
    if not session_id:
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    session = auth_manager.validate_session(session_id)
    
    if not session:
        raise HTTPException(status_code=401, detail="Invalid or expired session")
    
    try:
        # Get schema for the user's team
        schema_info = db_manager.get_schema_info(session["team"])
        
        # Generate SQL using Claude
        sql_result = sql_generator.generate_sql(
            natural_query=request.natural_query,
            schema_info=schema_info,
            database_type="postgresql"
        )
        
        if not sql_result["success"]:
            return {
                "success": False,
                "error": sql_result["error"],
                "stage": "sql_generation"
            }
        
        # Execute the generated SQL
        exec_result = db_manager.execute_query(session["team"], sql_result["sql_query"])
        
        return {
            "success": exec_result["success"],
            "natural_query": request.natural_query,
            "sql_query": sql_result["sql_query"],
            "model_used": sql_result["model_used"],
            **exec_result,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
