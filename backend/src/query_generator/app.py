"""
Main Query Generator Lambda Handler
Orchestrates the SQL query generation process across all phases
"""
import json
import logging
import os
import time
from typing import Dict, Any, Optional
import uuid

# Import local shared modules
from shared_db_utils import (
    DatabaseConnection,
    check_query_limit,
    increment_query_count,
    save_query_history,
    update_query_feedback,
    get_query_by_id
)
from shared_models import QueryResponse, FeedbackRequest
from claude_client import generate_sql_query, estimate_cost
from cache_manager import CacheManager
from query_validator import QueryValidator
from schema_manager import SchemaManager

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment configuration
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'dev')

# PHASE CONFIGURATION
# Set this to control which features are active
# 'POC' = Phase 1, 'BREAKING_DEMO' = Phase 2, 'PRODUCTION' = Phase 3
ACTIVE_PHASE = os.environ.get('ACTIVE_PHASE', 'PRODUCTION')

# Cache for demo team ID
_demo_team_id = None


def get_demo_team_id():
    """Get the demo team ID from database"""
    global _demo_team_id
    
    if _demo_team_id is not None:
        return _demo_team_id
    
    try:
        db_config = DatabaseConnection.get_system_db_config()
        query = "SELECT team_id FROM teams WHERE team_name = 'Demo Team' LIMIT 1"
        result = DatabaseConnection.execute_query(db_config, query)
        
        if result:
            _demo_team_id = str(result[0]['team_id'])
            return _demo_team_id
        else:
            logger.error("Demo team not found in database!")
            raise ValueError("Demo team not found")
    except Exception as e:
        logger.error(f"Error getting demo team: {str(e)}")
        raise


def lambda_handler(event, context):
    """
    Main Lambda handler for query generation
    Routes to appropriate handler based on path
    """
    try:
        # Parse request
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        
        logger.info(f"Request: {http_method} {path} [Phase: {ACTIVE_PHASE}]")
        
        # Route to appropriate handler
        if path.endswith('/query/generate'):
            return handle_generate_query(event, context)
        elif path.endswith('/query/refine'):
            return handle_refine_query(event, context)
        elif path.endswith('/query/feedback'):
            return handle_feedback(event, context)
        else:
            return response(404, {'error': 'Not found'})
            
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        return response(500, {'error': 'Internal server error'})


def handle_generate_query(event, context):
    """
    Handle query generation request
    
    PHASE 1 (POC): Basic generation without caching or advanced validation
    PHASE 2 (BREAKING_DEMO): Shows security issues and failures
    PHASE 3 (PRODUCTION): Full features with caching and validation
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Get team_id - if no authorizer (API key disabled), use demo team
        team_id = None
        if 'requestContext' in event and 'authorizer' in event['requestContext']:
            team_id = event['requestContext']['authorizer'].get('team_id')
        
        # If no team_id from authorizer, use demo team
        if not team_id:
            team_id = get_demo_team_id()
            logger.info(f"Using demo team: {team_id}")
        
        natural_language_query = body.get('natural_language_query')
        selected_tables = body.get('selected_tables', [])
        
        # Validation
        if not natural_language_query:
            return response(400, {'error': 'natural_language_query is required'})
        
        if not selected_tables:
            return response(400, {'error': 'selected_tables is required'})
        
        # PHASE 3: Check query limit
        if ACTIVE_PHASE == 'PRODUCTION':
            if not check_query_limit(team_id):
                return response(429, {
                    'error': 'Monthly query limit exceeded',
                    'message': 'Please contact support to increase your limit'
                })
        
        logger.info(f"Generating query for team {team_id}: '{natural_language_query}'")
        
        # Initialize components
        schema_manager = SchemaManager(team_id)
        cache_manager = CacheManager()
        validator = QueryValidator()
        
        start_time = time.time()
        
        # Step 1: Get schema
        tables = schema_manager.get_tables_ddl(selected_tables)
        
        if not tables:
            return response(404, {
                'error': 'No tables found',
                'message': f'Tables {selected_tables} not found in your schema'
            })
        
        schema_ddl = schema_manager.format_schema_for_claude(tables, phase=ACTIVE_PHASE)
        schema_hash = CacheManager.generate_schema_hash([t['table_ddl'] for t in tables])
        
        # Step 2: PHASE 3 ONLY - Check cache
        cached_result = None
        cache_hit = False
        
        if ACTIVE_PHASE == 'PRODUCTION':
            cached_result = cache_manager.get_cached_query(
                team_id,
                natural_language_query,
                schema_hash
            )
            
            if cached_result:
                cache_hit = True
                logger.info("🎯 Cache hit! Returning cached result")
                
                # Still validate cached SQL (security could have changed)
                validation = validator.validate(
                    cached_result['generated_sql'],
                    selected_tables,
                    phase=ACTIVE_PHASE
                )
                
                # Execute query
                execution_result = execute_query(
                    team_id,
                    cached_result['generated_sql']
                )
                
                execution_time = int((time.time() - start_time) * 1000)
                
                # Save to history
                query_data = {
                    'team_id': team_id,
                    'parent_query_id': None,
                    'attempt_number': 1,
                    'natural_language_query': natural_language_query,
                    'selected_tables': selected_tables,
                    'generated_sql': cached_result['generated_sql'],
                    'sql_explanation': cached_result['explanation'],
                    'execution_time_ms': execution_time,
                    'rows_returned': len(execution_result['rows']) if execution_result['success'] else None,
                    'cache_hit': True,
                    'success': execution_result['success'],
                    'error_message': execution_result.get('error'),
                    'error_type': execution_result.get('error_type'),
                    'sql_syntax_valid': validation['is_valid'],
                    'security_check_passed': validation['is_safe'],
                    'query_complexity_score': validation.get('complexity_score', 1),
                    'input_tokens': 0,  # No API call for cache hit
                    'output_tokens': 0,
                    'estimated_cost_usd': 0,
                    'user_refinement': None
                }
                
                query_id = save_query_history(query_data)
                
                return response(200, {
                    'query_id': query_id,
                    'generated_sql': cached_result['generated_sql'],
                    'explanation': cached_result['explanation'],
                    'results': execution_result['rows'] if execution_result['success'] else None,
                    'success': execution_result['success'],
                    'execution_time_ms': execution_time,
                    'cache_hit': True,
                    'cache_savings': 'Saved ~$0.015 by using cache',
                    'validation': validation
                })
        
        # Step 3: Generate SQL using Claude
        logger.info("💭 Generating new SQL query using Claude API")
        
        generation_result = generate_sql_query(
            natural_language_query,
            schema_ddl,
            previous_attempt=None
        )
        
        generated_sql = generation_result['sql']
        explanation = generation_result['explanation']
        input_tokens = generation_result['input_tokens']
        output_tokens = generation_result['output_tokens']
        cost = estimate_cost(input_tokens, output_tokens)
        
        # Step 4: Validate SQL
        validation = validator.validate(generated_sql, selected_tables, phase=ACTIVE_PHASE)
        
        # PHASE 2: Demonstrate security failures
        if ACTIVE_PHASE == 'BREAKING_DEMO' and not validation['is_safe']:
            logger.warning(f"⚠️ Security validation failed: {validation['security_issues']}")
            # In breaking demo, we still show the SQL but warn
        
        # PHASE 3: Block unsafe queries in production
        if ACTIVE_PHASE == 'PRODUCTION' and not validation['is_safe']:
            logger.error(f"🚫 Blocked unsafe query: {validation['security_issues']}")
            
            # Save to history as failed
            query_data = {
                'team_id': team_id,
                'parent_query_id': None,
                'attempt_number': 1,
                'natural_language_query': natural_language_query,
                'selected_tables': selected_tables,
                'generated_sql': generated_sql,
                'sql_explanation': explanation,
                'execution_time_ms': None,
                'rows_returned': None,
                'cache_hit': False,
                'success': False,
                'error_message': '; '.join(validation['security_issues']),
                'error_type': 'security',
                'sql_syntax_valid': validation['is_valid'],
                'security_check_passed': False,
                'query_complexity_score': validation.get('complexity_score', 1),
                'input_tokens': input_tokens,
                'output_tokens': output_tokens,
                'estimated_cost_usd': cost,
                'user_refinement': None
            }
            
            query_id = save_query_history(query_data)
            
            return response(403, {
                'query_id': query_id,
                'error': 'Query blocked for security reasons',
                'security_issues': validation['security_issues'],
                'generated_sql': generated_sql,
                'explanation': explanation,
                'validation': validation
            })
        
        # Step 5: Execute query
        execution_result = execute_query(team_id, generated_sql)
        
        execution_time = int((time.time() - start_time) * 1000)
        
        # Step 6: PHASE 3 ONLY - Cache successful queries
        if ACTIVE_PHASE == 'PRODUCTION' and execution_result['success']:
            cache_manager.put_cached_query(
                team_id,
                natural_language_query,
                selected_tables,
                schema_hash,
                generated_sql,
                explanation
            )
            logger.info("💾 Query cached for future use")
        
        # Step 7: Save to query history
        query_data = {
            'team_id': team_id,
            'parent_query_id': None,
            'attempt_number': 1,
            'natural_language_query': natural_language_query,
            'selected_tables': selected_tables,
            'generated_sql': generated_sql,
            'sql_explanation': explanation,
            'execution_time_ms': execution_time,
            'rows_returned': len(execution_result['rows']) if execution_result['success'] else None,
            'cache_hit': False,
            'success': execution_result['success'],
            'error_message': execution_result.get('error'),
            'error_type': execution_result.get('error_type'),
            'sql_syntax_valid': validation['is_valid'],
            'security_check_passed': validation['is_safe'],
            'query_complexity_score': validation.get('complexity_score', 1),
            'input_tokens': input_tokens,
            'output_tokens': output_tokens,
            'estimated_cost_usd': cost,
            'user_refinement': None
        }
        
        query_id = save_query_history(query_data)
        
        # Increment query count
        increment_query_count(team_id)
        
        # Step 8: Return response
        return response(200 if execution_result['success'] else 400, {
            'query_id': query_id,
            'generated_sql': generated_sql,
            'explanation': explanation,
            'results': execution_result['rows'] if execution_result['success'] else None,
            'success': execution_result['success'],
            'execution_time_ms': execution_time,
            'cache_hit': False,
            'cost_usd': round(cost, 6),
            'tokens': {
                'input': input_tokens,
                'output': output_tokens
            },
            'validation': validation,
            'error': execution_result.get('error'),
            'phase': ACTIVE_PHASE
        })
        
    except Exception as e:
        logger.error(f"Error generating query: {str(e)}", exc_info=True)
        return response(500, {'error': str(e)})


def handle_refine_query(event, context):
    """
    PHASE 2/3: Handle query refinement after errors
    
    This allows users to provide feedback and retry failed queries
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Get team_id - if no authorizer, use demo team
        team_id = None
        if 'requestContext' in event and 'authorizer' in event['requestContext']:
            team_id = event['requestContext']['authorizer'].get('team_id')
        if not team_id:
            team_id = get_demo_team_id()
        
        parent_query_id = body.get('parent_query_id')
        user_refinement = body.get('user_refinement', '')
        
        if not parent_query_id:
            return response(400, {'error': 'parent_query_id is required'})
        
        # Get previous query
        previous_query = get_query_by_id(parent_query_id)
        
        if not previous_query:
            return response(404, {'error': 'Previous query not found'})
        
        if previous_query['team_id'] != team_id:
            return response(403, {'error': 'Access denied'})
        
        logger.info(f"Refining query {parent_query_id} with: '{user_refinement}'")
        
        # Get schema
        schema_manager = SchemaManager(team_id)
        tables = schema_manager.get_tables_ddl(previous_query['selected_tables'])
        schema_ddl = schema_manager.format_schema_for_claude(tables, phase=ACTIVE_PHASE)
        
        start_time = time.time()
        
        # Generate refined SQL
        generation_result = generate_sql_query(
            previous_query['natural_language_query'],
            schema_ddl,
            previous_attempt={
                'sql': previous_query['generated_sql'],
                'error': previous_query['error_message'],
                'refinement': user_refinement
            }
        )
        
        generated_sql = generation_result['sql']
        explanation = generation_result['explanation']
        input_tokens = generation_result['input_tokens']
        output_tokens = generation_result['output_tokens']
        cost = estimate_cost(input_tokens, output_tokens)
        
        # Validate
        validator = QueryValidator()
        validation = validator.validate(generated_sql, previous_query['selected_tables'], phase=ACTIVE_PHASE)
        
        if ACTIVE_PHASE == 'PRODUCTION' and not validation['is_safe']:
            return response(403, {
                'error': 'Refined query still unsafe',
                'security_issues': validation['security_issues']
            })
        
        # Execute
        execution_result = execute_query(team_id, generated_sql)
        execution_time = int((time.time() - start_time) * 1000)
        
        # Save to history
        attempt_number = previous_query.get('attempt_number', 1) + 1
        
        query_data = {
            'team_id': team_id,
            'parent_query_id': parent_query_id,
            'attempt_number': attempt_number,
            'natural_language_query': previous_query['natural_language_query'],
            'selected_tables': previous_query['selected_tables'],
            'generated_sql': generated_sql,
            'sql_explanation': explanation,
            'execution_time_ms': execution_time,
            'rows_returned': len(execution_result['rows']) if execution_result['success'] else None,
            'cache_hit': False,
            'success': execution_result['success'],
            'error_message': execution_result.get('error'),
            'error_type': execution_result.get('error_type'),
            'sql_syntax_valid': validation['is_valid'],
            'security_check_passed': validation['is_safe'],
            'query_complexity_score': validation.get('complexity_score', 1),
            'input_tokens': input_tokens,
            'output_tokens': output_tokens,
            'estimated_cost_usd': cost,
            'user_refinement': user_refinement
        }
        
        query_id = save_query_history(query_data)
        
        return response(200 if execution_result['success'] else 400, {
            'query_id': query_id,
            'parent_query_id': parent_query_id,
            'attempt_number': attempt_number,
            'generated_sql': generated_sql,
            'explanation': explanation,
            'results': execution_result['rows'] if execution_result['success'] else None,
            'success': execution_result['success'],
            'execution_time_ms': execution_time,
            'cost_usd': round(cost, 6),
            'validation': validation,
            'error': execution_result.get('error')
        })
        
    except Exception as e:
        logger.error(f"Error refining query: {str(e)}", exc_info=True)
        return response(500, {'error': str(e)})


def handle_feedback(event, context):
    """
    PHASE 3: Handle user feedback on queries
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Get team_id - if no authorizer, use demo team
        team_id = None
        if 'requestContext' in event and 'authorizer' in event['requestContext']:
            team_id = event['requestContext']['authorizer'].get('team_id')
        if not team_id:
            team_id = get_demo_team_id()
        
        query_id = body.get('query_id')
        user_rating = body.get('user_rating')
        user_feedback_type = body.get('user_feedback_type')
        user_feedback_text = body.get('user_feedback_text')
        
        if not query_id:
            return response(400, {'error': 'query_id is required'})
        
        # Verify query belongs to team
        query = get_query_by_id(query_id)
        if not query or query['team_id'] != team_id:
            return response(403, {'error': 'Access denied'})
        
        # Validate feedback
        feedback_request = FeedbackRequest(
            query_id=query_id,
            user_rating=user_rating,
            user_feedback_type=user_feedback_type,
            user_feedback_text=user_feedback_text
        )
        
        feedback_request.validate()
        
        # Update feedback
        feedback_data = {
            'user_rating': user_rating,
            'user_feedback_type': user_feedback_type,
            'user_feedback_text': user_feedback_text
        }
        
        update_query_feedback(query_id, feedback_data)
        
        logger.info(f"Feedback saved for query {query_id}: rating={user_rating}, type={user_feedback_type}")
        
        return response(200, {
            'message': 'Feedback saved successfully',
            'query_id': query_id
        })
        
    except ValueError as e:
        return response(400, {'error': str(e)})
    except Exception as e:
        logger.error(f"Error saving feedback: {str(e)}", exc_info=True)
        return response(500, {'error': str(e)})


def execute_query(team_id: str, sql: str, timeout: int = 30) -> Dict[str, Any]:
    """
    Execute SQL query against team's database
    
    Args:
        team_id: Team identifier
        sql: SQL query to execute
        timeout: Query timeout in seconds (PHASE 3)
    
    Returns:
        Dict with success, rows, error
    """
    try:
        # Get team's database connection
        # For now, use sample database (PHASE 1)
        # In production, would use team's actual database connection
        db_config = {
            'host': os.environ.get('SAMPLE_DB_HOST'),
            'database': os.environ.get('SAMPLE_DB_NAME'),
            'user': os.environ.get('SAMPLE_DB_USER'),
            'password': os.environ.get('SAMPLE_DB_PASSWORD'),
            'port': 5432
        }
        
        # PHASE 3: Set statement timeout
        if ACTIVE_PHASE == 'PRODUCTION':
            timeout_sql = f"SET statement_timeout = {timeout * 1000};"  # milliseconds
            DatabaseConnection.execute_query(db_config, timeout_sql, fetch=False)
        
        # Execute query
        rows = DatabaseConnection.execute_query(db_config, sql)
        
        # Convert to list of dicts
        results = [dict(row) for row in rows]
        
        # PHASE 3: Limit results
        max_rows = 10000
        if ACTIVE_PHASE == 'PRODUCTION' and len(results) > max_rows:
            logger.warning(f"Query returned {len(results)} rows, truncating to {max_rows}")
            results = results[:max_rows]
        
        return {
            'success': True,
            'rows': results,
            'row_count': len(results)
        }
        
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Query execution error: {error_msg}")
        
        # Categorize error type
        error_type = 'execution'
        if 'syntax error' in error_msg.lower():
            error_type = 'syntax'
        elif 'timeout' in error_msg.lower() or 'canceling statement' in error_msg.lower():
            error_type = 'timeout'
        
        return {
            'success': False,
            'rows': [],
            'error': error_msg,
            'error_type': error_type
        }


def response(status_code: int, body: dict) -> dict:
    """Create Lambda response"""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,X-Api-Key',
            'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
        },
        'body': json.dumps(body, default=str)
    }


# For refine and feedback handlers
refinement_handler = handle_refine_query
feedback_handler = handle_feedback
