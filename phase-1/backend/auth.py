"""
Authentication and session management
"""
import os
from typing import Optional, Dict
from datetime import datetime, timedelta
from dotenv import load_dotenv

load_dotenv()


class AuthManager:
    """Manages user authentication and sessions"""
    
    # Team credentials
    TEAMS = {
        "sales": {
            "username": os.getenv("SALES_TEAM_USERNAME"),
            "password": os.getenv("SALES_TEAM_PASSWORD"),
        },
        "marketing": {
            "username": os.getenv("MARKETING_TEAM_USERNAME"),
            "password": os.getenv("MARKETING_TEAM_PASSWORD"),
        },
        "operations": {
            "username": os.getenv("OPERATIONS_TEAM_USERNAME"),
            "password": os.getenv("OPERATIONS_TEAM_PASSWORD"),
        },
    }
    
    def __init__(self):
        self.sessions = {}  # In-memory session storage (use Redis in production)
    
    def authenticate(self, username: str, password: str) -> Optional[str]:
        """
        Authenticate user and return team name if successful
        
        Args:
            username: User's username
            password: User's password
        
        Returns:
            Team name if authentication successful, None otherwise
        """
        for team_name, credentials in self.TEAMS.items():
            if (credentials["username"] == username and 
                credentials["password"] == password):
                return team_name
        
        return None
    
    def create_session(self, team: str, username: str) -> str:
        """Create a new session for authenticated user"""
        import secrets
        
        session_id = secrets.token_urlsafe(32)
        
        self.sessions[session_id] = {
            "team": team,
            "username": username,
            "created_at": datetime.now(),
            "last_accessed": datetime.now(),
        }
        
        return session_id
    
    def validate_session(self, session_id: str) -> Optional[Dict]:
        """Validate session and return session data if valid"""
        if session_id not in self.sessions:
            return None
        
        session = self.sessions[session_id]
        
        # Check if session is expired (24 hours)
        if datetime.now() - session["created_at"] > timedelta(hours=24):
            del self.sessions[session_id]
            return None
        
        # Update last accessed time
        session["last_accessed"] = datetime.now()
        
        return session
    
    def delete_session(self, session_id: str):
        """Delete a session (logout)"""
        if session_id in self.sessions:
            del self.sessions[session_id]


# Singleton instance
auth_manager = AuthManager()
