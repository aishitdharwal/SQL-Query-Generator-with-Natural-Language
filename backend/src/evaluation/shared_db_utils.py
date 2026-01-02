"""
Shared database utilities for connecting to PostgreSQL databases
"""
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class DatabaseConnection:
    """Utility class for managing database connections"""
    
    @staticmethod
    def get_system_db_config():
        """Get system database configuration from environment variables"""
        return {
            'host': os.environ['SYSTEM_DB_HOST'],
            'database': os.environ['SYSTEM_DB_NAME'],
            'user': os.environ['SYSTEM_DB_USER'],
            'password': os.environ['SYSTEM_DB_PASSWORD'],
            'port': 5432
        }
    
    @staticmethod
    def parse_connection_string(connection_string):
        """
        Parse PostgreSQL connection string
        Format: postgresql://user:password@host:port/database
        """
        # Remove postgresql:// prefix
        conn_str = connection_string.replace('postgresql://', '')
        
        # Split into user:password and host:port/database
        auth, location = conn_str.split('@')
        user, password = auth.split(':')
        
        # Split location into host:port and database
        host_port, database = location.split('/')
        host, port = host_port.split(':') if ':' in host_port else (host_port, '5432')
        
        return {
            'host': host,
            'port': int(port),
            'database': database,
            'user': user,
            'password': password
        }
    
    @staticmethod
    @contextmanager
    def get_connection(db_config):
        """Context manager for database connections"""
        conn = None
        try:
            conn = psycopg2.connect(**db_config)
            yield conn
            conn.commit()
        except Exception as e:
            if conn:
                conn.rollback()
            logger.error(f"Database error: {str(e)}")
            raise
        finally:
            if conn:
                conn.close()
    
    @staticmethod
    def execute_query(db_config, query, params=None, fetch=True):
        """Execute a query and return results"""
        with DatabaseConnection.get_connection(db_config) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute(query, params)
                if fetch:
                    return cursor.fetchall()
                return cursor.rowcount
