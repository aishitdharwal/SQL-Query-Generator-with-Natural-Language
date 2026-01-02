"""
Data models and schemas
"""
from dataclasses import dataclass, field, asdict
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum


class ErrorType(Enum):
    """Query error types"""
    SYNTAX = "syntax"
    EXECUTION = "execution"
    TIMEOUT = "timeout"
    SECURITY = "security"
    VALIDATION = "validation"


class QueryStatus(Enum):
    """Query execution status"""
    PENDING = "pending"
    PROCESSING = "processing"
    SUCCESS = "success"
    FAILED = "failed"


@dataclass
class QueryRequest:
    """Query generation request"""
    natural_language_query: str
    selected_tables: List[str]
    team_id: str
    api_key: str
    parent_query_id: Optional[str] = None
    user_refinement: Optional[str] = None


@dataclass
class QueryResponse:
    """Query generation response"""
    query_id: str
    generated_sql: str
    explanation: str
    success: bool
    execution_time_ms: int
    rows_returned: Optional[int] = None
    cache_hit: bool = False
    results: Optional[List[Dict[str, Any]]] = None
    error_message: Optional[str] = None
    error_type: Optional[str] = None
    
    def to_dict(self):
        return asdict(self)


@dataclass
class FeedbackRequest:
    """User feedback request"""
    query_id: str
    user_rating: Optional[int] = None  # 1-5
    user_feedback_type: Optional[str] = None  # thumbs_up, thumbs_down
    user_feedback_text: Optional[str] = None
    
    def validate(self):
        """Validate feedback data"""
        if self.user_rating is not None:
            if not (1 <= self.user_rating <= 5):
                raise ValueError("Rating must be between 1 and 5")
        
        if self.user_feedback_type is not None:
            if self.user_feedback_type not in ['thumbs_up', 'thumbs_down']:
                raise ValueError("Feedback type must be thumbs_up or thumbs_down")


@dataclass
class QueryHistoryEntry:
    """Query history entry"""
    query_id: str
    team_id: str
    natural_language_query: str
    selected_tables: List[str]
    generated_sql: Optional[str]
    sql_explanation: Optional[str]
    execution_time_ms: Optional[int]
    rows_returned: Optional[int]
    cache_hit: bool
    success: bool
    error_message: Optional[str]
    error_type: Optional[str]
    created_at: datetime
    parent_query_id: Optional[str] = None
    attempt_number: int = 1
    user_rating: Optional[int] = None
    user_feedback_type: Optional[str] = None
    user_feedback_text: Optional[str] = None
    
    def to_dict(self):
        data = asdict(self)
        data['created_at'] = self.created_at.isoformat()
        return data


@dataclass
class TeamInfo:
    """Team information"""
    team_id: str
    team_name: str
    db_connection_string: str
    monthly_query_count: int
    query_limit: int
    is_active: bool


@dataclass
class SchemaTable:
    """Database table schema"""
    table_name: str
    table_ddl: str
    description: Optional[str] = None


@dataclass
class CacheEntry:
    """Query cache entry"""
    cache_key: str
    team_id: str
    natural_language_query: str
    selected_tables: List[str]
    generated_sql: str
    explanation: str
    schema_hash: str
    ttl: int
    created_at: int
    hit_count: int = 0
    
    def to_dynamodb_item(self):
        """Convert to DynamoDB item format"""
        return {
            'cache_key': self.cache_key,
            'team_id': self.team_id,
            'natural_language_query': self.natural_language_query,
            'selected_tables': self.selected_tables,
            'generated_sql': self.generated_sql,
            'explanation': self.explanation,
            'schema_hash': self.schema_hash,
            'ttl': self.ttl,
            'created_at': self.created_at,
            'hit_count': self.hit_count
        }
