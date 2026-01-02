import anthropic
from app.config import ANTHROPIC_API_KEY
from typing import Dict, Any


class SQLGenerator:
    """Generates SQL queries from natural language using Claude API"""
    
    def __init__(self):
        self.client = anthropic.Anthropic(api_key=ANTHROPIC_API_KEY)
        self.model = "claude-sonnet-4-20250514"
    
    def generate_sql(self, natural_language_query: str, schema_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Generate SQL query from natural language using Claude API
        
        Args:
            natural_language_query: User's question in plain English
            schema_info: Database schema information
            
        Returns:
            Dictionary with generated SQL query and explanation
        """
        try:
            # Create schema description
            schema_description = self._format_schema(schema_info)
            
            # Create one-shot example based on the schema
            example = self._get_example_for_schema(schema_info)
            
            # Create prompt
            prompt = f"""You are a SQL query generator. Convert natural language questions into PostgreSQL queries.

Database Schema:
{schema_description}

Example:
{example}

Now, convert this question to SQL:
Question: {natural_language_query}

Provide the SQL query and a brief explanation of what it does.
Format your response as:
SQL: <your SQL query here>
Explanation: <brief explanation>

Important:
- Use PostgreSQL syntax
- Only use tables and columns that exist in the schema
- Ensure the query is safe and read-only when possible
- Use appropriate JOINs when querying multiple tables
- Use proper aggregation functions when needed"""

            message = self.client.messages.create(
                model=self.model,
                max_tokens=1024,
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            
            response_text = message.content[0].text
            
            # Parse response
            sql_query, explanation = self._parse_response(response_text)
            
            return {
                "success": True,
                "sql_query": sql_query,
                "explanation": explanation,
                "raw_response": response_text
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }
    
    def _format_schema(self, schema_info: Dict[str, Any]) -> str:
        """Format schema information into a readable string"""
        schema_lines = []
        
        for table_name, table_info in schema_info.items():
            schema_lines.append(f"\nTable: {table_name}")
            schema_lines.append("Columns:")
            
            for column in table_info["columns"]:
                nullable = "NULL" if column["is_nullable"] == "YES" else "NOT NULL"
                pk_marker = " (PRIMARY KEY)" if column["column_name"] in table_info["primary_keys"] else ""
                schema_lines.append(f"  - {column['column_name']}: {column['data_type']} {nullable}{pk_marker}")
            
            if table_info["foreign_keys"]:
                schema_lines.append("Foreign Keys:")
                for fk in table_info["foreign_keys"]:
                    schema_lines.append(f"  - {fk['column']} -> {fk['references_table']}.{fk['references_column']}")
        
        return "\n".join(schema_lines)
    
    def _get_example_for_schema(self, schema_info: Dict[str, Any]) -> str:
        """Generate a relevant example based on the schema"""
        tables = list(schema_info.keys())
        
        if not tables:
            return ""
        
        # Determine database type and provide appropriate example
        if "customers" in tables and "orders" in tables:
            # Sales database example
            return """Question: Show me all orders from customers in New York
SQL: SELECT o.order_id, o.order_date, o.total_amount, c.first_name, c.last_name 
FROM orders o 
JOIN customers c ON o.customer_id = c.customer_id 
WHERE c.city = 'New York';
Explanation: This query joins the orders and customers tables to find all orders placed by customers located in New York."""
        
        elif "campaigns" in tables and "email_campaigns" in tables:
            # Marketing database example
            return """Question: What is the average conversion rate for email campaigns?
SQL: SELECT AVG(conversion_rate) as avg_conversion_rate 
FROM email_campaigns;
Explanation: This query calculates the average conversion rate across all email campaigns."""
        
        elif "warehouses" in tables and "inventory" in tables:
            # Operations database example
            return """Question: Show me inventory levels below reorder level
SQL: SELECT i.product_name, i.quantity, i.reorder_level, w.warehouse_name 
FROM inventory i 
JOIN warehouses w ON i.warehouse_id = w.warehouse_id 
WHERE i.quantity < i.reorder_level;
Explanation: This query finds all products in inventory that have fallen below their reorder level, showing which warehouse they're in."""
        
        else:
            # Generic example
            first_table = tables[0]
            return f"""Question: Show me all records from {first_table}
SQL: SELECT * FROM {first_table} LIMIT 10;
Explanation: This query retrieves the first 10 records from the {first_table} table."""
    
    def _parse_response(self, response_text: str) -> tuple:
        """Parse the SQL query and explanation from Claude's response"""
        sql_query = ""
        explanation = ""
        
        lines = response_text.strip().split('\n')
        current_section = None
        
        for line in lines:
            line = line.strip()
            
            if line.startswith("SQL:"):
                current_section = "sql"
                sql_query = line.replace("SQL:", "").strip()
            elif line.startswith("Explanation:"):
                current_section = "explanation"
                explanation = line.replace("Explanation:", "").strip()
            elif current_section == "sql" and line:
                sql_query += " " + line
            elif current_section == "explanation" and line:
                explanation += " " + line
        
        # Clean up SQL query - remove markdown code blocks if present
        sql_query = sql_query.replace("```sql", "").replace("```", "").strip()
        
        return sql_query, explanation


# Global SQL generator instance
sql_generator = SQLGenerator()
