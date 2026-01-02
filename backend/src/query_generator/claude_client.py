"""
Claude API client for SQL generation
"""
import os
import logging
from anthropic import Anthropic

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Lazy initialization of Anthropic client
_client = None

def get_client():
    """Get or create Anthropic client"""
    global _client
    if _client is None:
        api_key = os.environ.get('ANTHROPIC_API_KEY')
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY environment variable not set")
        _client = Anthropic(api_key=api_key)
    return _client


def generate_sql_query(natural_language_query, schema_ddl, previous_attempt=None):
    """
    Generate SQL query using Claude API
    
    Args:
        natural_language_query: User's question in plain English
        schema_ddl: Database schema DDL statements
        previous_attempt: Optional dict with previous SQL and error for refinement
    
    Returns:
        dict with 'sql', 'explanation', 'input_tokens', 'output_tokens'
    """
    
    # Build the prompt
    if previous_attempt:
        prompt = build_refinement_prompt(
            natural_language_query,
            schema_ddl,
            previous_attempt['sql'],
            previous_attempt['error'],
            previous_attempt.get('refinement', '')
        )
    else:
        prompt = build_initial_prompt(natural_language_query, schema_ddl)
    
    try:
        # Get client
        client = get_client()
        
        # Call Claude API
        response = client.messages.create(
            model="claude-sonnet-4-20250514",
            max_tokens=2000,
            temperature=0,  # Deterministic for consistent SQL generation
            messages=[
                {
                    "role": "user",
                    "content": prompt
                }
            ]
        )
        
        # Extract response
        content = response.content[0].text
        
        # Parse SQL and explanation
        sql, explanation = parse_claude_response(content)
        
        logger.info(f"Generated SQL successfully. Tokens: {response.usage.input_tokens} in, {response.usage.output_tokens} out")
        
        return {
            'sql': sql,
            'explanation': explanation,
            'input_tokens': response.usage.input_tokens,
            'output_tokens': response.usage.output_tokens
        }
        
    except Exception as e:
        logger.error(f"Claude API error: {str(e)}")
        raise


def build_initial_prompt(natural_language_query, schema_ddl):
    """Build the initial prompt for SQL generation"""
    
    return f"""You are an expert PostgreSQL database assistant. Generate a SQL query based on the user's natural language question.

<database_schema>
{schema_ddl}
</database_schema>

<user_question>
{natural_language_query}
</user_question>

Instructions:
1. Generate a valid PostgreSQL query that answers the user's question
2. Use proper JOIN syntax when combining tables
3. Include appropriate WHERE clauses for filtering
4. Use meaningful column aliases when helpful
5. Optimize for readability and performance
6. Return reasonable result limits (use LIMIT when appropriate)

CRITICAL SAFETY RULES:
- NEVER generate DELETE, UPDATE, TRUNCATE, or DROP statements without explicit confirmation
- Always use WHERE clauses for UPDATE/DELETE operations
- Validate that the query is safe before returning it

Response format:
```sql
[Your SQL query here]
```

Explanation: [Brief explanation of what the query does and why you structured it this way]

Generate the SQL query now:"""


def build_refinement_prompt(natural_language_query, schema_ddl, previous_sql, error_message, user_refinement):
    """Build prompt for query refinement after an error"""
    
    return f"""You are an expert PostgreSQL database assistant. A previous SQL query failed and needs to be corrected.

<database_schema>
{schema_ddl}
</database_schema>

<original_question>
{natural_language_query}
</original_question>

<previous_sql>
{previous_sql}
</previous_sql>

<error_message>
{error_message}
</error_message>

{f'<user_refinement>{user_refinement}</user_refinement>' if user_refinement else ''}

Instructions:
1. Analyze the error message carefully
2. Correct the SQL query to fix the specific error
3. If user provided refinement, incorporate their feedback
4. Ensure the corrected query still answers the original question
5. Explain what was wrong and how you fixed it

Response format:
```sql
[Your corrected SQL query here]
```

Explanation: [Explain what was wrong with the previous query and how you fixed it]

Generate the corrected SQL query now:"""


def parse_claude_response(response_text):
    """
    Parse Claude's response to extract SQL and explanation
    
    Returns:
        tuple of (sql, explanation)
    """
    lines = response_text.strip().split('\n')
    
    sql_lines = []
    explanation_lines = []
    in_sql_block = False
    in_explanation = False
    
    for line in lines:
        # Detect SQL code block
        if line.strip().startswith('```sql'):
            in_sql_block = True
            continue
        elif line.strip() == '```' and in_sql_block:
            in_sql_block = False
            continue
        
        # Detect explanation section
        if line.strip().startswith('Explanation:'):
            in_explanation = True
            explanation_lines.append(line.replace('Explanation:', '').strip())
            continue
        
        # Collect SQL lines
        if in_sql_block:
            sql_lines.append(line)
        
        # Collect explanation lines
        elif in_explanation:
            explanation_lines.append(line)
    
    # Join lines
    sql = '\n'.join(sql_lines).strip()
    explanation = ' '.join(explanation_lines).strip()
    
    # If no explanation found, provide default
    if not explanation:
        explanation = "SQL query generated to answer your question."
    
    return sql, explanation


def estimate_cost(input_tokens, output_tokens):
    """
    Estimate cost of Claude API call
    Current pricing (as of early 2025):
    - Input: $3.00 per million tokens
    - Output: $15.00 per million tokens
    """
    input_cost = (input_tokens / 1_000_000) * 3.00
    output_cost = (output_tokens / 1_000_000) * 15.00
    return input_cost + output_cost
