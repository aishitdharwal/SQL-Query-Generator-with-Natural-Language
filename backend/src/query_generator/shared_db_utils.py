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
    
    @staticmethod
    def execute_many(db_config, query, params_list):
        """Execute a query with multiple parameter sets"""
        with DatabaseConnection.get_connection(db_config) as conn:
            with conn.cursor() as cursor:
                cursor.executemany(query, params_list)
                return cursor.rowcount


def get_team_by_api_key(api_key):
    """Retrieve team information by API key"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        SELECT team_id, team_name, db_connection_string, 
               monthly_query_count, query_limit, is_active
        FROM teams
        WHERE api_key = %s AND is_active = TRUE
    """
    
    results = DatabaseConnection.execute_query(db_config, query, (api_key,))
    
    if not results:
        return None
    
    return dict(results[0])


def increment_query_count(team_id):
    """Increment the monthly query count for a team"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        UPDATE teams
        SET monthly_query_count = monthly_query_count + 1
        WHERE team_id = %s
        RETURNING monthly_query_count, query_limit
    """
    
    result = DatabaseConnection.execute_query(db_config, query, (team_id,))
    return dict(result[0]) if result else None


def check_query_limit(team_id):
    """Check if team has exceeded their query limit"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        SELECT monthly_query_count, query_limit
        FROM teams
        WHERE team_id = %s
    """
    
    result = DatabaseConnection.execute_query(db_config, query, (team_id,))
    
    if not result:
        return False
    
    team = dict(result[0])
    return team['monthly_query_count'] < team['query_limit']


def save_query_history(query_data):
    """Save query execution to history"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        INSERT INTO query_history (
            team_id, parent_query_id, attempt_number,
            natural_language_query, selected_tables, generated_sql, sql_explanation,
            execution_time_ms, rows_returned, cache_hit, success,
            error_message, error_type,
            sql_syntax_valid, security_check_passed, query_complexity_score,
            input_tokens, output_tokens, estimated_cost_usd,
            user_refinement
        ) VALUES (
            %(team_id)s, %(parent_query_id)s, %(attempt_number)s,
            %(natural_language_query)s, %(selected_tables)s, %(generated_sql)s, %(sql_explanation)s,
            %(execution_time_ms)s, %(rows_returned)s, %(cache_hit)s, %(success)s,
            %(error_message)s, %(error_type)s,
            %(sql_syntax_valid)s, %(security_check_passed)s, %(query_complexity_score)s,
            %(input_tokens)s, %(output_tokens)s, %(estimated_cost_usd)s,
            %(user_refinement)s
        )
        RETURNING query_id
    """
    
    result = DatabaseConnection.execute_query(db_config, query, query_data)
    return str(result[0]['query_id']) if result else None


def update_query_feedback(query_id, feedback_data):
    """Update user feedback for a query"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        UPDATE query_history
        SET user_rating = %(user_rating)s,
            user_feedback_type = %(user_feedback_type)s,
            user_feedback_text = %(user_feedback_text)s,
            feedback_timestamp = NOW()
        WHERE query_id = %(query_id)s
    """
    
    feedback_data['query_id'] = query_id
    DatabaseConnection.execute_query(db_config, query, feedback_data, fetch=False)


def get_query_by_id(query_id):
    """Retrieve query details by ID"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        SELECT *
        FROM query_history
        WHERE query_id = %s
    """
    
    result = DatabaseConnection.execute_query(db_config, query, (query_id,))
    return dict(result[0]) if result else None


def get_schema_for_tables(team_id, table_names):
    """Get DDL for specified tables"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        SELECT tm.table_name, tm.table_ddl, tm.description
        FROM tables_metadata tm
        JOIN database_schemas ds ON tm.schema_id = ds.schema_id
        WHERE ds.team_id = %s AND tm.table_name = ANY(%s)
        ORDER BY tm.table_name
    """
    
    results = DatabaseConnection.execute_query(db_config, query, (team_id, table_names))
    return [dict(row) for row in results]
