"""
Claude API integration for natural language to SQL conversion
"""
import os
from anthropic import Anthropic
from typing import Dict, Any
from dotenv import load_dotenv

load_dotenv()


class SQLGenerator:
    """Generates SQL queries from natural language using Claude"""
    
    def __init__(self):
        self.client = Anthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
        self.model = os.getenv("CLAUDE_MODEL", "claude-sonnet-4-5-20250929")
    
    def generate_sql(
        self, 
        natural_query: str, 
        schema_info: Dict[str, Any],
        database_type: str = "postgresql"
    ) -> Dict[str, Any]:
        """
        Generate SQL query from natural language
        
        Args:
            natural_query: User's question in natural language
            schema_info: Database schema information
            database_type: Type of database (postgresql, mysql, etc.)
        
        Returns:
            Dictionary with generated SQL and explanation
        """
        
        # Format schema information for the prompt
        schema_text = self._format_schema(schema_info)
        
        # Create the prompt
        prompt = f"""You are a SQL query generator. Convert the following natural language question into a SQL query.

Database Type: {database_type}

Database Schema:
{schema_text}

User Question: {natural_query}

Instructions:
1. Generate a valid SQL query that answers the user's question
2. Use proper JOIN statements when querying multiple tables
3. Use appropriate WHERE clauses for filtering
4. Use aggregate functions (COUNT, SUM, AVG, etc.) when needed
5. Return ONLY the SQL query without any explanation or markdown formatting
6. Do not include semicolons at the end
7. Make sure the query is safe and doesn't modify data

Generate the SQL query:"""

        try:
            # Call Claude API
            message = self.client.messages.create(
                model=self.model,
                max_tokens=1000,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            
            # Extract the generated SQL
            sql_query = message.content[0].text.strip()
            
            # Remove markdown code blocks if present
            if sql_query.startswith("```"):
                lines = sql_query.split("\n")
                sql_query = "\n".join(lines[1:-1]) if len(lines) > 2 else sql_query
            
            # Remove semicolon if present
            sql_query = sql_query.rstrip(";")
            
            return {
                "success": True,
                "sql_query": sql_query,
                "model_used": self.model,
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": f"Failed to generate SQL: {str(e)}",
            }
    
    def _format_schema(self, schema_info: Dict[str, Any]) -> str:
        """Format schema information into a readable string"""
        formatted_lines = []
        
        for table_name, table_info in schema_info.items():
            formatted_lines.append(f"\nTable: {table_name}")
            formatted_lines.append("Columns:")
            
            for col in table_info["columns"]:
                pk_marker = " (PRIMARY KEY)" if col["column_name"] in table_info["primary_keys"] else ""
                nullable = "NULL" if col["is_nullable"] == "YES" else "NOT NULL"
                formatted_lines.append(
                    f"  - {col['column_name']}: {col['data_type']} {nullable}{pk_marker}"
                )
            
            if table_info["foreign_keys"]:
                formatted_lines.append("Foreign Keys:")
                for fk in table_info["foreign_keys"]:
                    formatted_lines.append(
                        f"  - {fk['column_name']} -> {fk['foreign_table_name']}.{fk['foreign_column_name']}"
                    )
        
        return "\n".join(formatted_lines)


# Singleton instance
sql_generator = SQLGenerator()
