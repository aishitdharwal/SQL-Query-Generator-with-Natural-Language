"""
Schema Manager - Database Schema Retrieval and Formatting
Manages schema context for Claude API
"""
import logging

from shared_db_utils import DatabaseConnection, get_schema_for_tables

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class SchemaManager:
    """Manages database schema retrieval and formatting for Claude"""
    
    # PHASE 2: Context window limits (for breaking point demo)
    MAX_TABLES_POC = 5
    MAX_TABLES_PRODUCTION = 50
    MAX_SCHEMA_CHARS = 50000  # Approximate token limit
    
    def __init__(self, team_id: str):
        """
        Initialize schema manager
        
        Args:
            team_id: Team identifier
        """
        self.team_id = team_id
    
    # ===========================
    # PHASE 1: Basic Schema Retrieval (POC)
    # ===========================
    
    def get_tables_ddl(self, table_names: list) -> list:
        """
        PHASE 1: Get DDL for specified tables
        
        Args:
            table_names: List of table names to retrieve
        
        Returns:
            List of dicts with table_name, table_ddl, description
        """
        try:
            tables = get_schema_for_tables(self.team_id, table_names)
            
            if not tables:
                logger.warning(f"No tables found for team {self.team_id}")
            
            return tables
            
        except Exception as e:
            logger.error(f"Error retrieving table DDLs: {str(e)}")
            return []
    
    def format_schema_for_claude(self, tables: list, phase: str = 'POC') -> str:
        """
        PHASE 1: Format schema DDL for Claude API prompt
        
        Args:
            tables: List of table metadata dicts
            phase: 'POC', 'BREAKING_DEMO', or 'PRODUCTION'
        
        Returns:
            Formatted schema string
        """
        if not tables:
            return "-- No schema information available"
        
        # PHASE 2: Check table count limits
        if phase == 'POC' and len(tables) > self.MAX_TABLES_POC:
            logger.warning(f"Too many tables for POC: {len(tables)} > {self.MAX_TABLES_POC}")
        
        schema_parts = []
        
        # Header
        schema_parts.append("-- Database Schema")
        schema_parts.append(f"-- Tables: {', '.join(t['table_name'] for t in tables)}")
        schema_parts.append("")
        
        # Add each table DDL
        for table in tables:
            schema_parts.append(f"-- Table: {table['table_name']}")
            
            if table.get('description'):
                schema_parts.append(f"-- Description: {table['description']}")
            
            schema_parts.append(table['table_ddl'])
            schema_parts.append("")
        
        schema_text = '\n'.join(schema_parts)
        
        # PHASE 2: Check size limits (for context window overflow demo)
        if len(schema_text) > self.MAX_SCHEMA_CHARS:
            logger.warning(f"Schema exceeds size limit: {len(schema_text)} > {self.MAX_SCHEMA_CHARS}")
            if phase == 'BREAKING_DEMO':
                # In breaking demo, we let it fail
                pass
            elif phase == 'PRODUCTION':
                # In production, we truncate with warning
                schema_text = self._truncate_schema(schema_text)
        
        return schema_text
    
    # ===========================
    # PHASE 3: Advanced Schema Features (Production)
    # ===========================
    
    def _truncate_schema(self, schema_text: str) -> str:
        """
        PHASE 3: Intelligently truncate schema to fit context window
        
        Args:
            schema_text: Full schema text
        
        Returns:
            Truncated schema with warning
        """
        # Keep first 80% of allowed size
        max_size = int(self.MAX_SCHEMA_CHARS * 0.8)
        
        if len(schema_text) <= max_size:
            return schema_text
        
        truncated = schema_text[:max_size]
        
        # Try to truncate at a clean line break
        last_newline = truncated.rfind('\n')
        if last_newline > max_size * 0.9:
            truncated = truncated[:last_newline]
        
        # Add warning
        warning = "\n\n-- WARNING: Schema truncated due to size limits"
        warning += "\n-- Some table definitions may be incomplete"
        
        return truncated + warning
    
    def get_schema_with_relationships(self, table_names: list) -> str:
        """
        PHASE 3: Get schema with foreign key relationships highlighted
        
        This helps Claude understand table relationships better
        
        Args:
            table_names: List of table names
        
        Returns:
            Enhanced schema with relationship information
        """
        tables = self.get_tables_ddl(table_names)
        
        if not tables:
            return "-- No schema information available"
        
        schema_parts = []
        
        # Header with relationship summary
        schema_parts.append("-- Database Schema with Relationships")
        schema_parts.append(f"-- Tables: {', '.join(t['table_name'] for t in tables)}")
        schema_parts.append("")
        
        # Extract and summarize relationships
        relationships = self._extract_relationships(tables)
        
        if relationships:
            schema_parts.append("-- Relationships:")
            for rel in relationships:
                schema_parts.append(f"-- {rel}")
            schema_parts.append("")
        
        # Add table DDLs
        for table in tables:
            schema_parts.append(f"-- Table: {table['table_name']}")
            
            if table.get('description'):
                schema_parts.append(f"-- Description: {table['description']}")
            
            schema_parts.append(table['table_ddl'])
            schema_parts.append("")
        
        return '\n'.join(schema_parts)
    
    def _extract_relationships(self, tables: list) -> list:
        """
        Extract foreign key relationships from DDL
        
        Returns:
            List of relationship descriptions
        """
        import re
        
        relationships = []
        
        for table in tables:
            ddl = table['table_ddl']
            table_name = table['table_name']
            
            # Find REFERENCES clauses
            # Pattern: REFERENCES other_table(column)
            pattern = r'REFERENCES\s+(\w+)\s*\((\w+)\)'
            
            matches = re.findall(pattern, ddl, re.IGNORECASE)
            
            for ref_table, ref_column in matches:
                relationships.append(
                    f"{table_name} -> {ref_table}.{ref_column}"
                )
        
        return relationships
    
    def get_sample_queries_for_tables(self, table_names: list) -> list:
        """
        PHASE 3: Get sample queries for reference
        
        Helps Claude understand common query patterns
        
        Args:
            table_names: List of table names
        
        Returns:
            List of sample query strings
        """
        db_config = DatabaseConnection.get_system_db_config()
        
        query = """
            SELECT tm.table_name, tm.sample_queries
            FROM tables_metadata tm
            JOIN database_schemas ds ON tm.schema_id = ds.schema_id
            WHERE ds.team_id = %s AND tm.table_name = ANY(%s)
            AND tm.sample_queries IS NOT NULL
        """
        
        try:
            results = DatabaseConnection.execute_query(
                db_config,
                query,
                (self.team_id, table_names)
            )
            
            samples = []
            for row in results:
                if row['sample_queries']:
                    for sample in row['sample_queries']:
                        samples.append(f"-- Example for {row['table_name']}: {sample}")
            
            return samples
            
        except Exception as e:
            logger.error(f"Error retrieving sample queries: {str(e)}")
            return []
    
    # ===========================
    # PHASE 2: Schema Introspection (Breaking Demo)
    # ===========================
    
    def introspect_database_schema(self, db_config: dict) -> list:
        """
        PHASE 2: Introspect a PostgreSQL database to extract schema
        
        This is used when users upload their own database connection string
        
        Args:
            db_config: Database configuration dict
        
        Returns:
            List of table metadata dicts
        """
        introspect_query = """
            SELECT 
                t.table_name,
                obj_description((t.table_schema || '.' || t.table_name)::regclass) as table_description
            FROM information_schema.tables t
            WHERE t.table_schema = 'public'
            AND t.table_type = 'BASE TABLE'
            ORDER BY t.table_name
        """
        
        try:
            tables_list = DatabaseConnection.execute_query(db_config, introspect_query)
            
            table_metadata = []
            
            for table_info in tables_list:
                table_name = table_info['table_name']
                
                # Get DDL using pg_dump-like query
                ddl = self._generate_table_ddl(db_config, table_name)
                
                table_metadata.append({
                    'table_name': table_name,
                    'table_ddl': ddl,
                    'description': table_info.get('table_description')
                })
            
            logger.info(f"Introspected {len(table_metadata)} tables from database")
            
            return table_metadata
            
        except Exception as e:
            logger.error(f"Error introspecting database: {str(e)}")
            return []
    
    def _generate_table_ddl(self, db_config: dict, table_name: str) -> str:
        """
        Generate CREATE TABLE DDL for a specific table
        
        Args:
            db_config: Database configuration
            table_name: Name of table
        
        Returns:
            DDL string
        """
        # Get column information
        column_query = """
            SELECT 
                column_name,
                data_type,
                character_maximum_length,
                is_nullable,
                column_default
            FROM information_schema.columns
            WHERE table_name = %s
            AND table_schema = 'public'
            ORDER BY ordinal_position
        """
        
        columns = DatabaseConnection.execute_query(db_config, column_query, (table_name,))
        
        if not columns:
            return f"-- Unable to retrieve DDL for {table_name}"
        
        # Build CREATE TABLE statement
        ddl_parts = [f"CREATE TABLE {table_name} ("]
        
        column_defs = []
        for col in columns:
            col_def = f"    {col['column_name']} {col['data_type']}"
            
            if col['character_maximum_length']:
                col_def += f"({col['character_maximum_length']})"
            
            if col['is_nullable'] == 'NO':
                col_def += " NOT NULL"
            
            if col['column_default']:
                col_def += f" DEFAULT {col['column_default']}"
            
            column_defs.append(col_def)
        
        ddl_parts.append(',\n'.join(column_defs))
        ddl_parts.append(");")
        
        return '\n'.join(ddl_parts)


# Convenience functions

def get_schema_manager(team_id: str) -> SchemaManager:
    """Get schema manager instance for team"""
    return SchemaManager(team_id)


def format_schema_simple(table_names: list, team_id: str) -> str:
    """
    PHASE 1: Simple schema formatting for POC
    
    Args:
        table_names: List of table names
        team_id: Team identifier
    
    Returns:
        Formatted schema string
    """
    manager = SchemaManager(team_id)
    tables = manager.get_tables_ddl(table_names)
    return manager.format_schema_for_claude(tables, phase='POC')
