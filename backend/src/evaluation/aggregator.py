"""
Daily Evaluation Metrics Aggregator
PHASE 3: Runs daily to aggregate query metrics and publish to CloudWatch
"""
import json
import logging
import os
from datetime import datetime, timedelta
from typing import Dict, List
import boto3

from shared_db_utils import DatabaseConnection

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# CloudWatch client
cloudwatch = boto3.client('cloudwatch')


def lambda_handler(event, context):
    """
    PHASE 3: Daily aggregation of evaluation metrics
    Triggered by EventBridge at midnight UTC
    """
    try:
        logger.info("Starting daily evaluation aggregation")
        
        # Calculate date range (yesterday)
        yesterday = (datetime.now() - timedelta(days=1)).date()
        
        # Get all teams
        teams = get_all_teams()
        
        results = []
        
        for team in teams:
            logger.info(f"Processing team: {team['team_name']}")
            
            # Calculate metrics for team
            metrics = calculate_daily_metrics(team['team_id'], yesterday)
            
            # Store in database
            store_evaluation_metrics(team['team_id'], yesterday, metrics)
            
            # Publish to CloudWatch
            publish_cloudwatch_metrics(team['team_id'], metrics)
            
            results.append({
                'team_id': team['team_id'],
                'team_name': team['team_name'],
                'metrics': metrics
            })
        
        logger.info(f"Completed aggregation for {len(results)} teams")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'date': str(yesterday),
                'teams_processed': len(results),
                'results': results
            }, default=str)
        }
        
    except Exception as e:
        logger.error(f"Error in aggregation: {str(e)}", exc_info=True)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def get_all_teams() -> List[Dict]:
    """Get all active teams"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        SELECT team_id, team_name
        FROM teams
        WHERE is_active = TRUE
    """
    
    results = DatabaseConnection.execute_query(db_config, query)
    return [dict(row) for row in results]


def calculate_daily_metrics(team_id: str, date: datetime.date) -> Dict:
    """
    Calculate comprehensive metrics for a team for a specific day
    
    PHASE 3: Production metrics calculation
    """
    db_config = DatabaseConnection.get_system_db_config()
    
    # Date range
    start_time = datetime.combine(date, datetime.min.time())
    end_time = datetime.combine(date, datetime.max.time())
    
    # Get all queries for the day
    query = """
        SELECT *
        FROM query_history
        WHERE team_id = %s
        AND created_at >= %s
        AND created_at <= %s
    """
    
    queries = DatabaseConnection.execute_query(db_config, query, (team_id, start_time, end_time))
    queries = [dict(q) for q in queries]
    
    if not queries:
        return get_empty_metrics()
    
    # Calculate metrics
    total_queries = len(queries)
    successful_queries = sum(1 for q in queries if q['success'])
    failed_queries = sum(1 for q in queries if not q['success'])
    cached_queries = sum(1 for q in queries if q['cache_hit'])
    
    # Execution time metrics
    execution_times = [q['execution_time_ms'] for q in queries if q['execution_time_ms']]
    
    avg_execution_time = sum(execution_times) / len(execution_times) if execution_times else 0
    
    execution_times_sorted = sorted(execution_times) if execution_times else [0]
    p50_idx = int(len(execution_times_sorted) * 0.50)
    p95_idx = int(len(execution_times_sorted) * 0.95)
    p99_idx = int(len(execution_times_sorted) * 0.99)
    
    p50_execution_time = execution_times_sorted[p50_idx] if execution_times_sorted else 0
    p95_execution_time = execution_times_sorted[p95_idx] if execution_times_sorted else 0
    p99_execution_time = execution_times_sorted[p99_idx] if execution_times_sorted else 0
    max_execution_time = max(execution_times) if execution_times else 0
    
    # User feedback metrics
    ratings = [q['user_rating'] for q in queries if q['user_rating']]
    avg_user_rating = sum(ratings) / len(ratings) if ratings else None
    
    thumbs_up_count = sum(1 for q in queries if q['user_feedback_type'] == 'thumbs_up')
    thumbs_down_count = sum(1 for q in queries if q['user_feedback_type'] == 'thumbs_down')
    total_feedback_count = thumbs_up_count + thumbs_down_count
    feedback_rate = (total_feedback_count / total_queries * 100) if total_queries > 0 else 0
    
    # Error breakdown
    syntax_errors = sum(1 for q in queries if q['error_type'] == 'syntax')
    execution_errors = sum(1 for q in queries if q['error_type'] == 'execution')
    timeout_errors = sum(1 for q in queries if q['error_type'] == 'timeout')
    security_blocks = sum(1 for q in queries if q['error_type'] == 'security')
    validation_errors = sum(1 for q in queries if q['error_type'] == 'validation')
    
    # Cost metrics
    total_input_tokens = sum(q['input_tokens'] or 0 for q in queries)
    total_output_tokens = sum(q['output_tokens'] or 0 for q in queries)
    total_cost = sum(q['estimated_cost_usd'] or 0 for q in queries)
    
    # Cost savings from cache
    cache_hit_count = sum(1 for q in queries if q['cache_hit'])
    avg_cost_per_query = total_cost / (total_queries - cache_hit_count) if (total_queries - cache_hit_count) > 0 else 0
    cost_savings_from_cache = cache_hit_count * avg_cost_per_query
    
    # First attempt success rate
    first_attempts = [q for q in queries if q['attempt_number'] == 1]
    first_attempt_successes = sum(1 for q in first_attempts if q['success'])
    first_attempt_success_rate = (first_attempt_successes / len(first_attempts) * 100) if first_attempts else 0
    
    # Average retries per query
    query_chains = {}  # parent_query_id -> [queries]
    for q in queries:
        parent_id = q['parent_query_id'] or q['query_id']
        if parent_id not in query_chains:
            query_chains[parent_id] = []
        query_chains[parent_id].append(q)
    
    total_attempts = sum(len(chain) for chain in query_chains.values())
    avg_retries = (total_attempts / len(query_chains)) - 1 if query_chains else 0
    
    # Complexity metrics
    complexities = [q['query_complexity_score'] for q in queries if q['query_complexity_score']]
    avg_query_complexity = sum(complexities) / len(complexities) if complexities else 0
    
    return {
        'total_queries': total_queries,
        'successful_queries': successful_queries,
        'failed_queries': failed_queries,
        'cached_queries': cached_queries,
        'unique_users': 1,  # Simplified for POC
        
        'avg_execution_time_ms': round(avg_execution_time, 2),
        'p50_execution_time_ms': p50_execution_time,
        'p95_execution_time_ms': p95_execution_time,
        'p99_execution_time_ms': p99_execution_time,
        'max_execution_time_ms': max_execution_time,
        
        'avg_user_rating': round(avg_user_rating, 2) if avg_user_rating else None,
        'thumbs_up_count': thumbs_up_count,
        'thumbs_down_count': thumbs_down_count,
        'total_feedback_count': total_feedback_count,
        'feedback_rate': round(feedback_rate, 2),
        
        'syntax_errors': syntax_errors,
        'execution_errors': execution_errors,
        'timeout_errors': timeout_errors,
        'security_blocks': security_blocks,
        'validation_errors': validation_errors,
        
        'total_input_tokens': total_input_tokens,
        'total_output_tokens': total_output_tokens,
        'total_cost_usd': round(total_cost, 4),
        'cost_savings_from_cache_usd': round(cost_savings_from_cache, 4),
        
        'first_attempt_success_rate': round(first_attempt_success_rate, 2),
        'avg_retries_per_query': round(avg_retries, 2),
        
        'avg_query_complexity': round(avg_query_complexity, 2)
    }


def get_empty_metrics() -> Dict:
    """Return empty metrics when no queries found"""
    return {
        'total_queries': 0,
        'successful_queries': 0,
        'failed_queries': 0,
        'cached_queries': 0,
        'unique_users': 0,
        'avg_execution_time_ms': 0,
        'p50_execution_time_ms': 0,
        'p95_execution_time_ms': 0,
        'p99_execution_time_ms': 0,
        'max_execution_time_ms': 0,
        'avg_user_rating': None,
        'thumbs_up_count': 0,
        'thumbs_down_count': 0,
        'total_feedback_count': 0,
        'feedback_rate': 0,
        'syntax_errors': 0,
        'execution_errors': 0,
        'timeout_errors': 0,
        'security_blocks': 0,
        'validation_errors': 0,
        'total_input_tokens': 0,
        'total_output_tokens': 0,
        'total_cost_usd': 0,
        'cost_savings_from_cache_usd': 0,
        'first_attempt_success_rate': 0,
        'avg_retries_per_query': 0,
        'avg_query_complexity': 0
    }


def store_evaluation_metrics(team_id: str, date: datetime.date, metrics: Dict) -> None:
    """Store metrics in database"""
    db_config = DatabaseConnection.get_system_db_config()
    
    query = """
        INSERT INTO evaluation_metrics (
            team_id, date,
            total_queries, successful_queries, failed_queries, cached_queries, unique_users,
            avg_execution_time_ms, p50_execution_time_ms, p95_execution_time_ms, 
            p99_execution_time_ms, max_execution_time_ms,
            avg_user_rating, thumbs_up_count, thumbs_down_count, 
            total_feedback_count, feedback_rate,
            syntax_errors, execution_errors, timeout_errors, 
            security_blocks, validation_errors,
            total_input_tokens, total_output_tokens, total_cost_usd, 
            cost_savings_from_cache_usd,
            first_attempt_success_rate, avg_retries_per_query,
            avg_query_complexity
        ) VALUES (
            %(team_id)s, %(date)s,
            %(total_queries)s, %(successful_queries)s, %(failed_queries)s, %(cached_queries)s, %(unique_users)s,
            %(avg_execution_time_ms)s, %(p50_execution_time_ms)s, %(p95_execution_time_ms)s,
            %(p99_execution_time_ms)s, %(max_execution_time_ms)s,
            %(avg_user_rating)s, %(thumbs_up_count)s, %(thumbs_down_count)s,
            %(total_feedback_count)s, %(feedback_rate)s,
            %(syntax_errors)s, %(execution_errors)s, %(timeout_errors)s,
            %(security_blocks)s, %(validation_errors)s,
            %(total_input_tokens)s, %(total_output_tokens)s, %(total_cost_usd)s,
            %(cost_savings_from_cache_usd)s,
            %(first_attempt_success_rate)s, %(avg_retries_per_query)s,
            %(avg_query_complexity)s
        )
        ON CONFLICT (team_id, date) DO UPDATE SET
            total_queries = EXCLUDED.total_queries,
            successful_queries = EXCLUDED.successful_queries,
            failed_queries = EXCLUDED.failed_queries,
            cached_queries = EXCLUDED.cached_queries,
            unique_users = EXCLUDED.unique_users,
            avg_execution_time_ms = EXCLUDED.avg_execution_time_ms,
            p50_execution_time_ms = EXCLUDED.p50_execution_time_ms,
            p95_execution_time_ms = EXCLUDED.p95_execution_time_ms,
            p99_execution_time_ms = EXCLUDED.p99_execution_time_ms,
            max_execution_time_ms = EXCLUDED.max_execution_time_ms,
            avg_user_rating = EXCLUDED.avg_user_rating,
            thumbs_up_count = EXCLUDED.thumbs_up_count,
            thumbs_down_count = EXCLUDED.thumbs_down_count,
            total_feedback_count = EXCLUDED.total_feedback_count,
            feedback_rate = EXCLUDED.feedback_rate,
            syntax_errors = EXCLUDED.syntax_errors,
            execution_errors = EXCLUDED.execution_errors,
            timeout_errors = EXCLUDED.timeout_errors,
            security_blocks = EXCLUDED.security_blocks,
            validation_errors = EXCLUDED.validation_errors,
            total_input_tokens = EXCLUDED.total_input_tokens,
            total_output_tokens = EXCLUDED.total_output_tokens,
            total_cost_usd = EXCLUDED.total_cost_usd,
            cost_savings_from_cache_usd = EXCLUDED.cost_savings_from_cache_usd,
            first_attempt_success_rate = EXCLUDED.first_attempt_success_rate,
            avg_retries_per_query = EXCLUDED.avg_retries_per_query,
            avg_query_complexity = EXCLUDED.avg_query_complexity
    """
    
    params = {
        'team_id': team_id,
        'date': date,
        **metrics
    }
    
    DatabaseConnection.execute_query(db_config, query, params, fetch=False)
    logger.info(f"Stored metrics for team {team_id} on {date}")


def publish_cloudwatch_metrics(team_id: str, metrics: Dict) -> None:
    """
    PHASE 3: Publish metrics to CloudWatch
    """
    try:
        # Calculate success rate
        success_rate = 0
        if metrics['total_queries'] > 0:
            success_rate = (metrics['successful_queries'] / metrics['total_queries']) * 100
        
        # Calculate cache hit rate
        cache_hit_rate = 0
        if metrics['total_queries'] > 0:
            cache_hit_rate = (metrics['cached_queries'] / metrics['total_queries']) * 100
        
        metric_data = [
            {
                'MetricName': 'SuccessRate',
                'Value': success_rate,
                'Unit': 'Percent',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            },
            {
                'MetricName': 'ErrorRate',
                'Value': 100 - success_rate,
                'Unit': 'Percent',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            },
            {
                'MetricName': 'CacheHitRate',
                'Value': cache_hit_rate,
                'Unit': 'Percent',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            },
            {
                'MetricName': 'TotalQueries',
                'Value': metrics['total_queries'],
                'Unit': 'Count',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            },
            {
                'MetricName': 'AvgExecutionTime',
                'Value': metrics['avg_execution_time_ms'],
                'Unit': 'Milliseconds',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            }
        ]
        
        # Add user rating if available
        if metrics['avg_user_rating'] is not None:
            metric_data.append({
                'MetricName': 'AvgUserRating',
                'Value': metrics['avg_user_rating'],
                'Unit': 'None',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            })
        
        # Add cost metrics
        metric_data.extend([
            {
                'MetricName': 'DailyCost',
                'Value': metrics['total_cost_usd'],
                'Unit': 'None',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            },
            {
                'MetricName': 'CostSavings',
                'Value': metrics['cost_savings_from_cache_usd'],
                'Unit': 'None',
                'Dimensions': [{'Name': 'TeamId', 'Value': team_id}]
            }
        ])
        
        # Publish to CloudWatch
        cloudwatch.put_metric_data(
            Namespace='SQLQueryGenerator',
            MetricData=metric_data
        )
        
        logger.info(f"Published {len(metric_data)} metrics to CloudWatch for team {team_id}")
        
    except Exception as e:
        logger.error(f"Error publishing CloudWatch metrics: {str(e)}")
        # Don't fail the whole process if CloudWatch publish fails
