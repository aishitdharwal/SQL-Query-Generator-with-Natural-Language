import jwt
from datetime import datetime, timedelta
from app.config import SECRET_KEY, TEAM_PASSWORDS


def authenticate_user(username: str, team: str, password: str) -> dict:
    """
    Authenticate user based on team password
    
    Args:
        username: User's username
        team: Team name (sales, marketing, operations)
        password: Team password
        
    Returns:
        Dictionary with authentication result and token if successful
    """
    if team not in TEAM_PASSWORDS:
        return {
            "success": False,
            "message": "Invalid team"
        }
    
    if TEAM_PASSWORDS[team] != password:
        return {
            "success": False,
            "message": "Invalid password"
        }
    
    # Generate JWT token
    token = generate_token(username, team)
    
    return {
        "success": True,
        "token": token,
        "username": username,
        "team": team
    }


def generate_token(username: str, team: str) -> str:
    """Generate JWT token for authenticated user"""
    payload = {
        "username": username,
        "team": team,
        "exp": datetime.utcnow() + timedelta(hours=8)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")


def verify_token(token: str) -> dict:
    """
    Verify JWT token and return user information
    
    Returns:
        Dictionary with verification result and user info if valid
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return {
            "valid": True,
            "username": payload["username"],
            "team": payload["team"]
        }
    except jwt.ExpiredSignatureError:
        return {
            "valid": False,
            "message": "Token has expired"
        }
    except jwt.InvalidTokenError:
        return {
            "valid": False,
            "message": "Invalid token"
        }
