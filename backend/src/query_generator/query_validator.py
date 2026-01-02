"""
Query Validator - Security and Validation
Validates SQL queries for safety and correctness
"""
import re
import logging
from typing import Dict, List, Optional, Tuple

logger = logging.getLogger()
logger.setLevel(logging.INFO)


class QueryValidator:
    """Validates SQL queries for security and correctness"""
    
    # PHASE 1: Basic validation patterns
    BASIC_SQL_KEYWORDS = ['SELECT', 'FROM', 'WHERE', 'JOIN', 'GROUP BY', 'ORDER BY', 'LIMIT']
    
    # PHASE 2: Dangerous operations (for breaking points demo)
    DANGEROUS_KEYWORDS = ['DELETE', 'DROP', 'TRUNCATE', 'ALTER', 'CREATE', 'INSERT', 'UPDATE']
    
    # PHASE 2: SQL injection patterns
    INJECTION_PATTERNS = [
        r';\s*DROP',
        r';\s*DELETE',
        r';\s*UPDATE',
        r';\s*INSERT',
        r'UNION\s+SELECT',
        r'--',  # SQL comments
        r'/\*',  # Multi-line comments
        r"'\s*OR\s+'1'\s*=\s*'1",
        r"'\s*OR\s+1\s*=\s*1",
    ]
    
    def __init__(self):
        """Initialize validator"""
        self.validation_errors = []
        self.validation_warnings = []
    
    # ===========================
    # PHASE 1: Basic Validation (POC)
    # ===========================
    
    def validate_basic_syntax(self, sql: str) -> Tuple[bool, Optional[str]]:
        """
        PHASE 1: Basic syntax validation
        
        Returns:
            (is_valid, error_message)
        """
        if not sql or not sql.strip():
            return False, "Empty SQL query"
        
        sql_upper = sql.upper()
        
        # Must contain SELECT
        if 'SELECT' not in sql_upper:
            return False, "Query must contain SELECT statement"
        
        # Must contain FROM
        if 'FROM' not in sql_upper:
            return False, "Query must contain FROM clause"
        
        # Basic parentheses matching
        if sql.count('(') != sql.count(')'):
            return False, "Unmatched parentheses in query"
        
        return True, None
    
    # ===========================
    # PHASE 2: Security Validation (Breaking Points)
    # ===========================
    
    def check_sql_injection(self, sql: str) -> Tuple[bool, List[str]]:
        """
        PHASE 2: Check for SQL injection patterns
        
        Returns:
            (is_safe, detected_patterns)
        """
        detected = []
        sql_upper = sql.upper()
        
        for pattern in self.INJECTION_PATTERNS:
            if re.search(pattern, sql_upper, re.IGNORECASE):
                detected.append(f"Detected injection pattern: {pattern}")
                logger.warning(f"SQL injection attempt detected: {pattern}")
        
        return len(detected) == 0, detected
    
    def check_dangerous_operations(self, sql: str) -> Tuple[bool, List[str], List[str]]:
        """
        PHASE 2: Check for dangerous SQL operations
        
        Returns:
            (is_safe, dangerous_ops, warnings)
        """
        dangerous = []
        warnings = []
        sql_upper = sql.upper()
        
        for keyword in self.DANGEROUS_KEYWORDS:
            if keyword in sql_upper:
                dangerous.append(keyword)
                
                # Check if it's a DELETE/UPDATE without WHERE
                if keyword in ['DELETE', 'UPDATE']:
                    if 'WHERE' not in sql_upper:
                        warnings.append(f"{keyword} operation without WHERE clause - affects all rows!")
                    else:
                        warnings.append(f"{keyword} operation detected - requires confirmation")
                
                elif keyword in ['DROP', 'TRUNCATE', 'ALTER']:
                    warnings.append(f"{keyword} operation detected - extremely dangerous!")
        
        return len(dangerous) == 0, dangerous, warnings
    
    def validate_table_references(self, sql: str, allowed_tables: List[str]) -> Tuple[bool, Optional[str]]:
        """
        PHASE 2: Validate that query only references allowed tables
        
        Returns:
            (is_valid, error_message)
        """
        sql_upper = sql.upper()
        allowed_upper = [t.upper() for t in allowed_tables]
        
        # Extract table names from FROM and JOIN clauses
        # This is a simplified check - regex pattern for table names
        from_pattern = r'FROM\s+(\w+)'
        join_pattern = r'JOIN\s+(\w+)'
        
        referenced_tables = set()
        
        for match in re.finditer(from_pattern, sql_upper):
            referenced_tables.add(match.group(1))
        
        for match in re.finditer(join_pattern, sql_upper):
            referenced_tables.add(match.group(1))
        
        # Check if all referenced tables are allowed
        unauthorized = referenced_tables - set(allowed_upper)
        
        if unauthorized:
            return False, f"Unauthorized table reference(s): {', '.join(unauthorized)}"
        
        return True, None
    
    # ===========================
    # PHASE 3: Advanced Validation (Production)
    # ===========================
    
    def estimate_query_complexity(self, sql: str) -> int:
        """
        PHASE 3: Estimate query complexity score (1-10)
        
        Factors:
        - Number of JOINs
        - Subqueries
        - Aggregations
        - Window functions
        """
        score = 1
        sql_upper = sql.upper()
        
        # Count JOINs (each adds 1 point)
        join_count = sql_upper.count('JOIN')
        score += min(join_count, 3)
        
        # Subqueries (each adds 2 points)
        subquery_count = sql_upper.count('SELECT') - 1  # Main SELECT doesn't count
        score += min(subquery_count * 2, 4)
        
        # Aggregations
        agg_functions = ['SUM', 'COUNT', 'AVG', 'MAX', 'MIN']
        has_aggregation = any(func in sql_upper for func in agg_functions)
        if has_aggregation:
            score += 1
        
        # GROUP BY
        if 'GROUP BY' in sql_upper:
            score += 1
        
        # Window functions
        if 'OVER' in sql_upper:
            score += 2
        
        return min(score, 10)
    
    def validate_result_limit(self, sql: str, max_rows: int = 10000) -> Tuple[bool, Optional[str]]:
        """
        PHASE 3: Ensure query has reasonable LIMIT
        
        Returns:
            (is_valid, warning_message)
        """
        sql_upper = sql.upper()
        
        # Check if LIMIT exists
        if 'LIMIT' not in sql_upper:
            return False, f"Query should include LIMIT clause (max {max_rows} rows)"
        
        # Extract LIMIT value
        limit_match = re.search(r'LIMIT\s+(\d+)', sql_upper)
        if limit_match:
            limit_value = int(limit_match.group(1))
            if limit_value > max_rows:
                return False, f"LIMIT {limit_value} exceeds maximum of {max_rows} rows"
        
        return True, None
    
    # ===========================
    # Main Validation Methods
    # ===========================
    
    def validate_for_poc(self, sql: str, allowed_tables: List[str]) -> Dict:
        """
        PHASE 1: POC validation - basic syntax only
        
        Returns validation result dict
        """
        result = {
            'is_valid': True,
            'is_safe': True,
            'errors': [],
            'warnings': [],
            'complexity_score': 1,
            'phase': 'POC'
        }
        
        # Basic syntax validation
        is_valid, error = self.validate_basic_syntax(sql)
        if not is_valid:
            result['is_valid'] = False
            result['errors'].append(error)
        
        return result
    
    def validate_for_breaking_demo(self, sql: str, allowed_tables: List[str]) -> Dict:
        """
        PHASE 2: Breaking points validation - shows security issues
        
        Returns validation result dict with detailed security analysis
        """
        result = {
            'is_valid': True,
            'is_safe': True,
            'errors': [],
            'warnings': [],
            'security_issues': [],
            'complexity_score': 1,
            'phase': 'BREAKING_DEMO'
        }
        
        # Basic syntax
        is_valid, error = self.validate_basic_syntax(sql)
        if not is_valid:
            result['is_valid'] = False
            result['errors'].append(error)
            return result
        
        # SQL injection check
        is_safe_injection, injection_patterns = self.check_sql_injection(sql)
        if not is_safe_injection:
            result['is_safe'] = False
            result['security_issues'].extend(injection_patterns)
            result['errors'].append("SQL injection attempt detected")
        
        # Dangerous operations
        is_safe_ops, dangerous_ops, op_warnings = self.check_dangerous_operations(sql)
        if not is_safe_ops:
            result['is_safe'] = False
            result['security_issues'].append(f"Dangerous operations: {', '.join(dangerous_ops)}")
            result['warnings'].extend(op_warnings)
        
        # Table references
        is_valid_tables, table_error = self.validate_table_references(sql, allowed_tables)
        if not is_valid_tables:
            result['is_valid'] = False
            result['errors'].append(table_error)
        
        return result
    
    def validate_for_production(self, sql: str, allowed_tables: List[str]) -> Dict:
        """
        PHASE 3: Production validation - comprehensive checks
        
        Returns complete validation result dict
        """
        result = {
            'is_valid': True,
            'is_safe': True,
            'errors': [],
            'warnings': [],
            'security_issues': [],
            'complexity_score': 1,
            'phase': 'PRODUCTION'
        }
        
        # All Phase 2 checks
        phase2_result = self.validate_for_breaking_demo(sql, allowed_tables)
        result.update(phase2_result)
        
        if not result['is_valid'] or not result['is_safe']:
            return result
        
        # Phase 3: Additional production checks
        
        # Complexity estimation
        result['complexity_score'] = self.estimate_query_complexity(sql)
        
        # Result limit validation
        has_limit, limit_warning = self.validate_result_limit(sql)
        if not has_limit:
            result['warnings'].append(limit_warning)
        
        return result
    
    def validate(self, sql: str, allowed_tables: List[str], phase: str = 'PRODUCTION') -> Dict:
        """
        Main validation entry point
        
        Args:
            sql: SQL query to validate
            allowed_tables: List of tables user is allowed to query
            phase: 'POC', 'BREAKING_DEMO', or 'PRODUCTION'
        
        Returns:
            Validation result dictionary
        """
        if phase == 'POC':
            return self.validate_for_poc(sql, allowed_tables)
        elif phase == 'BREAKING_DEMO':
            return self.validate_for_breaking_demo(sql, allowed_tables)
        else:
            return self.validate_for_production(sql, allowed_tables)


# Convenience functions for different phases

def validate_query_poc(sql: str, allowed_tables: List[str]) -> Dict:
    """PHASE 1: Simple validation for POC"""
    validator = QueryValidator()
    return validator.validate_for_poc(sql, allowed_tables)


def validate_query_breaking(sql: str, allowed_tables: List[str]) -> Dict:
    """PHASE 2: Security validation for breaking points demo"""
    validator = QueryValidator()
    return validator.validate_for_breaking_demo(sql, allowed_tables)


def validate_query_production(sql: str, allowed_tables: List[str]) -> Dict:
    """PHASE 3: Full production validation"""
    validator = QueryValidator()
    return validator.validate_for_production(sql, allowed_tables)
