import psycopg2
from psycopg2 import pool
from typing import List, Dict, Any
from app.config import DB_HOST, DB_PORT, DB_USER, DB_PASSWORD, TEAM_DATABASES


class DatabaseManager:
    """Manages database connections and queries for different teams"""
    
    def __init__(self):
        self.connection_pools = {}
        self._initialize_pools()
    
    def _initialize_pools(self):
        """Initialize connection pools for each team database"""
        for team, db_name in TEAM_DATABASES.items():
            try:
                self.connection_pools[team] = psycopg2.pool.SimpleConnectionPool(
                    1, 10,
                    host=DB_HOST,
                    port=DB_PORT,
                    database=db_name,
                    user=DB_USER,
                    password=DB_PASSWORD
                )
            except Exception as e:
                print(f"Error creating connection pool for {team}: {e}")
    
    def get_connection(self, team: str):
        """Get a connection from the pool for a specific team"""
        if team not in self.connection_pools:
            raise ValueError(f"Invalid team: {team}")
        return self.connection_pools[team].getconn()
    
    def release_connection(self, team: str, connection):
        """Release a connection back to the pool"""
        if team in self.connection_pools:
            self.connection_pools[team].putconn(connection)
    
    def get_table_schemas(self, team: str) -> Dict[str, List[Dict[str, Any]]]:
        """Get schema information for all tables in the team's database"""
        connection = None
        try:
            connection = self.get_connection(team)
            cursor = connection.cursor()
            
            # Get all tables
            cursor.execute("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'public' 
                AND table_type = 'BASE TABLE'
                ORDER BY table_name
            """)
            tables = [row[0] for row in cursor.fetchall()]
            
            schemas = {}
            for table in tables:
                # Get column information
                cursor.execute("""
                    SELECT 
                        column_name,
                        data_type,
                        is_nullable,
                        column_default
                    FROM information_schema.columns
                    WHERE table_name = %s
                    ORDER BY ordinal_position
                """, (table,))
                
                columns = []
                for row in cursor.fetchall():
                    columns.append({
                        "column_name": row[0],
                        "data_type": row[1],
                        "is_nullable": row[2],
                        "column_default": row[3]
                    })
                
                # Get primary key information
                cursor.execute("""
                    SELECT a.attname
                    FROM pg_index i
                    JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                    WHERE i.indrelid = %s::regclass AND i.indisprimary
                """, (table,))
                primary_keys = [row[0] for row in cursor.fetchall()]
                
                # Get foreign key information
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
                    AND tc.table_name = %s
                """, (table,))
                foreign_keys = [
                    {
                        "column": row[0],
                        "references_table": row[1],
                        "references_column": row[2]
                    }
                    for row in cursor.fetchall()
                ]
                
                schemas[table] = {
                    "columns": columns,
                    "primary_keys": primary_keys,
                    "foreign_keys": foreign_keys
                }
            
            cursor.close()
            return schemas
            
        except Exception as e:
            raise Exception(f"Error getting table schemas: {e}")
        finally:
            if connection:
                self.release_connection(team, connection)
    
    def execute_query(self, team: str, query: str) -> Dict[str, Any]:
        """Execute a SQL query and return results"""
        connection = None
        try:
            connection = self.get_connection(team)
            cursor = connection.cursor()
            
            cursor.execute(query)
            
            # Check if query returns results (SELECT query)
            if cursor.description:
                columns = [desc[0] for desc in cursor.description]
                rows = cursor.fetchall()
                results = [dict(zip(columns, row)) for row in rows]
                
                cursor.close()
                return {
                    "success": True,
                    "columns": columns,
                    "rows": results,
                    "row_count": len(results)
                }
            else:
                # For INSERT, UPDATE, DELETE queries
                connection.commit()
                cursor.close()
                return {
                    "success": True,
                    "message": "Query executed successfully",
                    "rows_affected": cursor.rowcount
                }
                
        except Exception as e:
            if connection:
                connection.rollback()
            return {
                "success": False,
                "error": str(e)
            }
        finally:
            if connection:
                self.release_connection(team, connection)
    
    def close_all_pools(self):
        """Close all connection pools"""
        for pool in self.connection_pools.values():
            pool.closeall()


# Global database manager instance
db_manager = DatabaseManager()
