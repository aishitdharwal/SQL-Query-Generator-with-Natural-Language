"""
Database connection and management utilities
"""
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Any, Optional
from dotenv import load_dotenv

load_dotenv()


class DatabaseManager:
    """Manages database connections and operations"""
    
    # Team configuration mapping
    TEAM_CONFIG = {
        "sales": {
            "username": os.getenv("SALES_TEAM_USERNAME"),
            "password": os.getenv("SALES_TEAM_PASSWORD"),
            "database": os.getenv("SALES_DB_NAME"),
        },
        "marketing": {
            "username": os.getenv("MARKETING_TEAM_USERNAME"),
            "password": os.getenv("MARKETING_TEAM_PASSWORD"),
            "database": os.getenv("MARKETING_DB_NAME"),
        },
        "operations": {
            "username": os.getenv("OPERATIONS_TEAM_USERNAME"),
            "password": os.getenv("OPERATIONS_TEAM_PASSWORD"),
            "database": os.getenv("OPERATIONS_DB_NAME"),
        },
    }
    
    def __init__(self):
        self.host = os.getenv("DB_HOST")
        self.port = int(os.getenv("DB_PORT", "5432"))
    
    def get_connection(self, team: str):
        """Get database connection for a specific team"""
        if team not in self.TEAM_CONFIG:
            raise ValueError(f"Invalid team: {team}")
        
        config = self.TEAM_CONFIG[team]
        
        try:
            conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                database=config["database"],
                user=config["username"],
                password=config["password"],
                cursor_factory=RealDictCursor,
            )
            return conn
        except Exception as e:
            raise Exception(f"Database connection failed: {str(e)}")
    
    def get_schema_info(self, team: str) -> Dict[str, Any]:
        """Get schema information for a team's database"""
        conn = self.get_connection(team)
        cursor = conn.cursor()
        
        try:
            # Get all tables in public schema
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_type = 'BASE TABLE'
                ORDER BY table_name;
            """)
            
            tables = [row['table_name'] for row in cursor.fetchall()]
            
            schema_info = {}
            
            for table in tables:
                # Get columns for each table
                cursor.execute("""
                    SELECT 
                        column_name,
                        data_type,
                        is_nullable,
                        column_default
                    FROM information_schema.columns
                    WHERE table_schema = 'public' 
                    AND table_name = %s
                    ORDER BY ordinal_position;
                """, (table,))
                
                columns = cursor.fetchall()
                
                # Get primary keys
                cursor.execute("""
                    SELECT a.attname
                    FROM pg_index i
                    JOIN pg_attribute a ON a.attrelid = i.indrelid
                        AND a.attnum = ANY(i.indkey)
                    WHERE i.indrelid = %s::regclass
                    AND i.indisprimary;
                """, (table,))
                
                primary_keys = [row['attname'] for row in cursor.fetchall()]
                
                # Get foreign keys
                cursor.execute("""
                    SELECT
                        kcu.column_name,
                        ccu.table_name AS foreign_table_name,
                        ccu.column_name AS foreign_column_name
                    FROM information_schema.table_constraints AS tc
                    JOIN information_schema.key_column_usage AS kcu
                        ON tc.constraint_name = kcu.constraint_name
                        AND tc.table_schema = kcu.table_schema
                    JOIN information_schema.constraint_column_usage AS ccu
                        ON ccu.constraint_name = tc.constraint_name
                        AND ccu.table_schema = tc.table_schema
                    WHERE tc.constraint_type = 'FOREIGN KEY'
                    AND tc.table_name = %s;
                """, (table,))
                
                foreign_keys = cursor.fetchall()
                
                schema_info[table] = {
                    "columns": [dict(col) for col in columns],
                    "primary_keys": primary_keys,
                    "foreign_keys": [dict(fk) for fk in foreign_keys],
                }
            
            return schema_info
            
        finally:
            cursor.close()
            conn.close()
    
    def execute_query(self, team: str, query: str) -> Dict[str, Any]:
        """Execute a SQL query and return results"""
        conn = self.get_connection(team)
        cursor = conn.cursor()
        
        try:
            cursor.execute(query)
            
            # Check if query returns data
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                rows = cursor.fetchall()
                
                return {
                    "success": True,
                    "columns": columns,
                    "rows": [dict(row) for row in rows],
                    "row_count": len(rows),
                }
            else:
                # Query doesn't return data (INSERT, UPDATE, DELETE, etc.)
                conn.commit()
                return {
                    "success": True,
                    "message": f"Query executed successfully. Rows affected: {cursor.rowcount}",
                    "row_count": cursor.rowcount,
                }
                
        except Exception as e:
            conn.rollback()
            return {
                "success": False,
                "error": str(e),
            }
        finally:
            cursor.close()
            conn.close()
    
    def get_sample_data(self, team: str, table: str, limit: int = 5) -> List[Dict]:
        """Get sample rows from a table"""
        conn = self.get_connection(team)
        cursor = conn.cursor()
        
        try:
            cursor.execute(f"SELECT * FROM {table} LIMIT %s;", (limit,))
            return [dict(row) for row in cursor.fetchall()]
        finally:
            cursor.close()
            conn.close()


# Singleton instance
db_manager = DatabaseManager()
