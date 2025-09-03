import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Config:
    """Configuration class for the Flask application"""
    
    # Supabase configuration
    SUPABASE_URL = os.getenv('SUPABASE_URL')
    SUPABASE_KEY = os.getenv('SUPABASE_KEY')
    
    # Flask configuration
    SECRET_KEY = os.getenv('FLASK_SECRET_KEY', 'your-secret-key-change-in-production')
    
    # Session configuration
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    PERMANENT_SESSION_LIFETIME = 86400  # 24 hours
    
    # Debug mode (should be False in production)
    DEBUG = os.getenv('FLASK_DEBUG', 'False').lower() == 'true'
    
    # Clear any proxy-related environment variables that might interfere with Supabase
    @staticmethod
    def clear_proxy_env():
        """Clear proxy environment variables that might cause issues with Supabase"""
        proxy_vars = ['HTTP_PROXY', 'HTTPS_PROXY', 'http_proxy', 'https_proxy', 'ALL_PROXY', 'all_proxy']
        for var in proxy_vars:
            if var in os.environ:
                del os.environ[var]
