"""
Cache Manager - DynamoDB Query Caching
Manages query caching to reduce LLM costs by 80%
"""
import os
import json
import hashlib
import logging
import time
from typing import Optional, Dict, Any
import boto3
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('CACHE_TABLE_NAME')
cache_table = dynamodb.Table(table_name) if table_name else None

# PHASE 3: Cache TTL - 1 week
CACHE_TTL_SECONDS = 604800  # 7 days


class CacheManager:
    """Manages query caching in DynamoDB"""
    
    def __init__(self):
        """Initialize cache manager"""
        self.table = cache_table
        self.enabled = cache_table is not None
    
    # ===========================
    # PHASE 1: No Caching (POC)
    # ===========================
    # In POC phase, we intentionally skip caching to demonstrate cost without it
    
    @staticmethod
    def generate_cache_key(team_id: str, natural_language_query: str, schema_hash: str) -> str:
        """
        Generate unique cache key from query components
        
        Args:
            team_id: Team identifier
            natural_language_query: User's natural language question
            schema_hash: Hash of the database schema
        
        Returns:
            SHA-256 hash as cache key
        """
        # Normalize query (lowercase, strip whitespace)
        normalized_query = natural_language_query.lower().strip()
        
        # Create composite key
        composite = f"{team_id}:{normalized_query}:{schema_hash}"
        
        # Generate hash
        cache_key = hashlib.sha256(composite.encode()).hexdigest()
        
        return cache_key
    
    @staticmethod
    def generate_schema_hash(table_ddls: list) -> str:
        """
        Generate hash of database schema
        
        Args:
            table_ddls: List of table DDL strings
        
        Returns:
            MD5 hash of concatenated DDLs
        """
        # Sort DDLs for consistent hashing
        sorted_ddls = sorted(table_ddls)
        
        # Concatenate
        schema_text = '\n'.join(sorted_ddls)
        
        # Generate hash
        schema_hash = hashlib.md5(schema_text.encode()).hexdigest()
        
        return schema_hash
    
    # ===========================
    # PHASE 3: Cache Operations (Production)
    # ===========================
    
    def get_cached_query(
        self, 
        team_id: str, 
        natural_language_query: str, 
        schema_hash: str
    ) -> Optional[Dict[str, Any]]:
        """
        PHASE 3: Retrieve cached query result
        
        Returns:
            Cached query data or None if not found
        """
        if not self.enabled:
            logger.warning("Cache is not enabled (table not configured)")
            return None
        
        try:
            cache_key = self.generate_cache_key(team_id, natural_language_query, schema_hash)
            
            # Get item from DynamoDB
            response = self.table.get_item(Key={'cache_key': cache_key})
            
            if 'Item' not in response:
                logger.info(f"Cache miss for key: {cache_key[:16]}...")
                return None
            
            item = response['Item']
            
            # Check if TTL has expired (DynamoDB TTL is eventual, so we double-check)
            if 'ttl' in item:
                if item['ttl'] < int(time.time()):
                    logger.info(f"Cache entry expired for key: {cache_key[:16]}...")
                    return None
            
            # Increment hit count
            self._increment_hit_count(cache_key)
            
            logger.info(f"Cache hit for key: {cache_key[:16]}... (hits: {item.get('hit_count', 0) + 1})")
            
            return {
                'generated_sql': item['generated_sql'],
                'explanation': item['explanation'],
                'cache_key': cache_key,
                'hit_count': item.get('hit_count', 0) + 1,
                'created_at': item['created_at']
            }
            
        except ClientError as e:
            logger.error(f"DynamoDB error retrieving cache: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error retrieving cache: {str(e)}")
            return None
    
    def put_cached_query(
        self,
        team_id: str,
        natural_language_query: str,
        selected_tables: list,
        schema_hash: str,
        generated_sql: str,
        explanation: str
    ) -> bool:
        """
        PHASE 3: Store query result in cache
        
        Returns:
            True if successful, False otherwise
        """
        if not self.enabled:
            logger.warning("Cache is not enabled (table not configured)")
            return False
        
        try:
            cache_key = self.generate_cache_key(team_id, natural_language_query, schema_hash)
            
            # Calculate TTL
            ttl = int(time.time()) + CACHE_TTL_SECONDS
            
            # Create cache item
            item = {
                'cache_key': cache_key,
                'team_id': team_id,
                'natural_language_query': natural_language_query,
                'selected_tables': selected_tables,
                'generated_sql': generated_sql,
                'explanation': explanation,
                'schema_hash': schema_hash,
                'ttl': ttl,
                'created_at': int(time.time()),
                'hit_count': 0
            }
            
            # Put item in DynamoDB
            self.table.put_item(Item=item)
            
            logger.info(f"Cached query with key: {cache_key[:16]}... (TTL: {CACHE_TTL_SECONDS}s)")
            
            return True
            
        except ClientError as e:
            logger.error(f"DynamoDB error storing cache: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error storing cache: {str(e)}")
            return False
    
    def _increment_hit_count(self, cache_key: str) -> None:
        """
        Increment hit count for cache entry
        
        Args:
            cache_key: Cache key to update
        """
        try:
            self.table.update_item(
                Key={'cache_key': cache_key},
                UpdateExpression='SET hit_count = if_not_exists(hit_count, :zero) + :inc',
                ExpressionAttributeValues={
                    ':inc': 1,
                    ':zero': 0
                }
            )
        except Exception as e:
            logger.error(f"Error incrementing hit count: {str(e)}")
            # Non-critical error, don't raise
    
    def delete_cached_query(
        self,
        team_id: str,
        natural_language_query: str,
        schema_hash: str
    ) -> bool:
        """
        PHASE 3: Delete cached query (for cache invalidation)
        
        Returns:
            True if successful, False otherwise
        """
        if not self.enabled:
            return False
        
        try:
            cache_key = self.generate_cache_key(team_id, natural_language_query, schema_hash)
            
            self.table.delete_item(Key={'cache_key': cache_key})
            
            logger.info(f"Deleted cache entry: {cache_key[:16]}...")
            
            return True
            
        except ClientError as e:
            logger.error(f"DynamoDB error deleting cache: {str(e)}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error deleting cache: {str(e)}")
            return False
    
    def get_team_cache_stats(self, team_id: str, limit: int = 10) -> Dict[str, Any]:
        """
        PHASE 3: Get cache statistics for a team
        
        Returns:
            Dictionary with cache stats
        """
        if not self.enabled:
            return {'enabled': False}
        
        try:
            # Query by team_id using GSI
            response = self.table.query(
                IndexName='team-index',
                KeyConditionExpression='team_id = :team_id',
                ExpressionAttributeValues={':team_id': team_id},
                Limit=limit,
                ScanIndexForward=False  # Most recent first
            )
            
            items = response.get('Items', [])
            
            total_entries = len(items)
            total_hits = sum(item.get('hit_count', 0) for item in items)
            
            # Most popular queries
            popular_queries = sorted(
                items,
                key=lambda x: x.get('hit_count', 0),
                reverse=True
            )[:5]
            
            return {
                'enabled': True,
                'total_cached_queries': total_entries,
                'total_cache_hits': total_hits,
                'most_popular_queries': [
                    {
                        'query': q['natural_language_query'],
                        'hits': q.get('hit_count', 0),
                        'created_at': q['created_at']
                    }
                    for q in popular_queries
                ]
            }
            
        except Exception as e:
            logger.error(f"Error getting cache stats: {str(e)}")
            return {'enabled': True, 'error': str(e)}
    
    def clear_team_cache(self, team_id: str) -> int:
        """
        PHASE 3: Clear all cache entries for a team
        
        Returns:
            Number of entries deleted
        """
        if not self.enabled:
            return 0
        
        try:
            # Query all entries for team
            response = self.table.query(
                IndexName='team-index',
                KeyConditionExpression='team_id = :team_id',
                ExpressionAttributeValues={':team_id': team_id}
            )
            
            items = response.get('Items', [])
            deleted_count = 0
            
            # Delete each item
            for item in items:
                self.table.delete_item(Key={'cache_key': item['cache_key']})
                deleted_count += 1
            
            logger.info(f"Cleared {deleted_count} cache entries for team {team_id}")
            
            return deleted_count
            
        except Exception as e:
            logger.error(f"Error clearing team cache: {str(e)}")
            return 0


# Convenience functions

def get_cache_manager() -> CacheManager:
    """Get configured cache manager instance"""
    return CacheManager()


def calculate_cost_savings(
    total_queries: int,
    cache_hit_rate: float,
    avg_tokens_per_query: int = 1500
) -> Dict[str, float]:
    """
    PHASE 3: Calculate cost savings from caching
    
    Args:
        total_queries: Total number of queries
        cache_hit_rate: Percentage of cache hits (0.0 - 1.0)
        avg_tokens_per_query: Average tokens per query
    
    Returns:
        Dictionary with cost breakdown
    """
    # Pricing (as of early 2025)
    INPUT_COST_PER_TOKEN = 3.00 / 1_000_000
    OUTPUT_COST_PER_TOKEN = 15.00 / 1_000_000
    
    # Assume 60% input, 40% output
    input_tokens = avg_tokens_per_query * 0.6
    output_tokens = avg_tokens_per_query * 0.4
    
    cost_per_query = (input_tokens * INPUT_COST_PER_TOKEN) + (output_tokens * OUTPUT_COST_PER_TOKEN)
    
    # Without cache
    cost_without_cache = total_queries * cost_per_query
    
    # With cache (only pay for cache misses)
    cache_misses = total_queries * (1 - cache_hit_rate)
    cost_with_cache = cache_misses * cost_per_query
    
    # Savings
    savings = cost_without_cache - cost_with_cache
    savings_percentage = (savings / cost_without_cache) * 100 if cost_without_cache > 0 else 0
    
    return {
        'total_queries': total_queries,
        'cache_hit_rate': cache_hit_rate * 100,
        'cost_without_cache': round(cost_without_cache, 2),
        'cost_with_cache': round(cost_with_cache, 2),
        'savings': round(savings, 2),
        'savings_percentage': round(savings_percentage, 1)
    }
