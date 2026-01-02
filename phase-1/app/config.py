import os
from dotenv import load_dotenv

load_dotenv()

# Database Configuration
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

# Team credentials
TEAM_PASSWORDS = {
    "sales": os.getenv("TEAM_SALES_PASSWORD"),
    "marketing": os.getenv("TEAM_MARKETING_PASSWORD"),
    "operations": os.getenv("TEAM_OPERATIONS_PASSWORD")
}

# Team to database mapping
TEAM_DATABASES = {
    "sales": "sales_db",
    "marketing": "marketing_db",
    "operations": "operations_db"
}

# Claude API
ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY")

# Application
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-change-this")
