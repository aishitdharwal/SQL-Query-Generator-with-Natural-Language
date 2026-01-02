"""
API Key Authorizer Lambda Function
Validates API keys and returns team context
"""
import json
import logging
import sys
import os

# Add parent directory to path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))

from shared.db_utils import get_team_by_api_key

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Lambda authorizer for API Gateway
    Validates API key and returns IAM policy with team context
    """
    try:
        # Extract API key from headers
        api_key = event.get('headers', {}).get('x-api-key') or event.get('headers', {}).get('X-Api-Key')
        
        if not api_key:
            logger.error("No API key provided")
            return generate_policy(None, 'Deny', event['methodArn'])
        
        # Validate API key and get team info
        team = get_team_by_api_key(api_key)
        
        if not team:
            logger.error(f"Invalid API key: {api_key[:8]}...")
            return generate_policy(None, 'Deny', event['methodArn'])
        
        if not team['is_active']:
            logger.error(f"Team is inactive: {team['team_id']}")
            return generate_policy(None, 'Deny', event['methodArn'])
        
        logger.info(f"Authorized team: {team['team_name']} ({team['team_id']})")
        
        # Return Allow policy with team context
        return generate_policy(
            team['team_id'],
            'Allow',
            event['methodArn'],
            context={
                'team_id': team['team_id'],
                'team_name': team['team_name'],
                'monthly_query_count': str(team['monthly_query_count']),
                'query_limit': str(team['query_limit'])
            }
        )
        
    except Exception as e:
        logger.error(f"Authorizer error: {str(e)}")
        return generate_policy(None, 'Deny', event['methodArn'])


def generate_policy(principal_id, effect, resource, context=None):
    """
    Generate IAM policy for API Gateway
    """
    policy = {
        'principalId': principal_id or 'unknown',
        'policyDocument': {
            'Version': '2012-10-17',
            'Statement': [
                {
                    'Action': 'execute-api:Invoke',
                    'Effect': effect,
                    'Resource': resource
                }
            ]
        }
    }
    
    if context:
        policy['context'] = context
    
    return policy
