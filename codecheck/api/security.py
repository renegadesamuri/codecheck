"""
Security utilities and middleware for CodeCheck API
Includes rate limiting, request validation, and security headers
"""

import os
from typing import Callable
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
import psycopg2
from psycopg2.extras import RealDictCursor
import re
import json

# Rate limiter configuration
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["100/minute"],
    storage_uri=os.getenv("REDIS_URL", "memory://"),
    strategy="fixed-window"
)

# Security headers middleware
class SecurityHeadersMiddleware:
    """Add security headers to all responses"""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        async def send_with_headers(message):
            if message["type"] == "http.response.start":
                headers = dict(message.get("headers", []))

                # Security headers
                security_headers = {
                    b"x-content-type-options": b"nosniff",
                    b"x-frame-options": b"DENY",
                    b"x-xss-protection": b"1; mode=block",
                    b"strict-transport-security": b"max-age=31536000; includeSubDomains",
                    b"content-security-policy": b"default-src 'self'",
                    b"referrer-policy": b"strict-origin-when-cross-origin",
                    b"permissions-policy": b"geolocation=(self), microphone=(), camera=()"
                }

                for key, value in security_headers.items():
                    if key not in headers:
                        headers[key] = value

                message["headers"] = [(k, v) for k, v in headers.items()]

            await send(message)

        await self.app(scope, receive, send_with_headers)

# Input validation utilities
class InputValidator:
    """Validate and sanitize user inputs"""

    @staticmethod
    def validate_email(email: str) -> bool:
        """Validate email format"""
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return re.match(pattern, email) is not None

    @staticmethod
    def validate_uuid(uuid_string: str) -> bool:
        """Validate UUID format"""
        pattern = r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        return re.match(pattern, uuid_string.lower()) is not None

    @staticmethod
    def validate_coordinates(latitude: float, longitude: float) -> bool:
        """Validate coordinate ranges"""
        if not (-90 <= latitude <= 90):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Latitude must be between -90 and 90"
            )
        if not (-180 <= longitude <= 180):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Longitude must be between -180 and 180"
            )
        return True

    @staticmethod
    def sanitize_string(text: str, max_length: int = 1000) -> str:
        """Sanitize string input"""
        if not text:
            return ""

        # Remove potentially dangerous characters
        sanitized = text.strip()

        # Limit length
        if len(sanitized) > max_length:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Input too long. Maximum {max_length} characters"
            )

        return sanitized

    @staticmethod
    def validate_measurement_value(value: float) -> bool:
        """Validate measurement value"""
        if value < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Measurement value cannot be negative"
            )
        if value > 10000:  # Reasonable maximum in inches (833 feet)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Measurement value unreasonably large"
            )
        return True

# Audit logging
class AuditLogger:
    """Log security and user actions"""

    @staticmethod
    def log_event(
        conn,
        user_id: str = None,
        action: str = "",
        resource_type: str = None,
        resource_id: str = None,
        ip_address: str = None,
        user_agent: str = None,
        details: dict = None
    ):
        """Log a security event to the database"""
        try:
            with conn.cursor() as cursor:
                cursor.execute("""
                    INSERT INTO audit_log (user_id, action, resource_type, resource_id, ip_address, user_agent, details)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (user_id, action, resource_type, resource_id, ip_address, user_agent, json.dumps(details) if details else None))
                conn.commit()
        except Exception as e:
            # Don't fail the request if logging fails
            print(f"Audit logging error: {str(e)}")

    @staticmethod
    async def log_request(request: Request, user_id: str = None, action: str = ""):
        """Log an HTTP request"""
        ip_address = request.client.host if request.client else None
        user_agent = request.headers.get("user-agent")

        details = {
            "method": request.method,
            "path": str(request.url.path),
            "query_params": dict(request.query_params)
        }

        # Don't log request bodies for security
        return {
            "user_id": user_id,
            "action": action,
            "ip_address": ip_address,
            "user_agent": user_agent,
            "details": details
        }

# Database rate limiting
class DatabaseRateLimiter:
    """Rate limiting using database (fallback when Redis unavailable)"""

    @staticmethod
    def check_rate_limit(
        conn,
        identifier: str,
        endpoint: str,
        limit: int = 100,
        window_minutes: int = 1
    ) -> bool:
        """Check if request is within rate limit"""
        try:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT check_rate_limit(%s, %s, %s, %s)
                """, (identifier, endpoint, limit, window_minutes))

                result = cursor.fetchone()
                conn.commit()
                return result[0] if result else False

        except Exception as e:
            # If rate limiting fails, allow the request
            print(f"Rate limiting error: {str(e)}")
            return True

# IP-based rate limiting for unauthenticated requests
def get_rate_limit_identifier(request: Request, user_id: str = None) -> str:
    """Get identifier for rate limiting (user_id or IP)"""
    if user_id:
        return f"user:{user_id}"

    # Use IP address for unauthenticated requests
    ip = request.client.host if request.client else "unknown"
    return f"ip:{ip}"

# Request size limiter
class RequestSizeLimiter:
    """Limit request body size to prevent DoS attacks"""

    MAX_REQUEST_SIZE = 10 * 1024 * 1024  # 10 MB

    @staticmethod
    async def check_request_size(request: Request):
        """Check if request size is within limits"""
        content_length = request.headers.get("content-length")

        if content_length:
            content_length = int(content_length)
            if content_length > RequestSizeLimiter.MAX_REQUEST_SIZE:
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Request too large. Maximum {RequestSizeLimiter.MAX_REQUEST_SIZE / 1024 / 1024}MB"
                )

# Claude API rate limiting (to prevent bill explosions)
class ClaudeRateLimiter:
    """Rate limit Claude API calls per user"""

    # Limits: 20 requests per hour per user
    REQUESTS_PER_HOUR = 20

    @staticmethod
    def check_claude_rate_limit(conn, user_id: str) -> bool:
        """Check if user has exceeded Claude API rate limit"""
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cursor:
                cursor.execute("""
                    SELECT COUNT(*) as count
                    FROM audit_log
                    WHERE user_id = %s
                    AND action LIKE 'claude_api%'
                    AND created_at > NOW() - INTERVAL '1 hour'
                """, (user_id,))

                result = cursor.fetchone()
                count = result['count'] if result else 0

                return count < ClaudeRateLimiter.REQUESTS_PER_HOUR

        except Exception as e:
            print(f"Claude rate limit check error: {str(e)}")
            return True  # Allow on error

    @staticmethod
    def log_claude_request(conn, user_id: str):
        """Log a Claude API request"""
        AuditLogger.log_event(
            conn,
            user_id=user_id,
            action="claude_api_request",
            details={"timestamp": "now"}
        )

# CORS configuration helper
def get_cors_origins() -> list:
    """Get allowed CORS origins from environment"""
    allowed_origins = os.getenv('ALLOWED_ORIGINS', 'http://localhost:3000,http://localhost:8000')
    return allowed_origins.split(',')

# Environment validation
def validate_environment():
    """Validate required environment variables"""
    required_vars = ['JWT_SECRET_KEY', 'DB_PASSWORD']
    missing_vars = []

    for var in required_vars:
        if not os.getenv(var):
            missing_vars.append(var)

    if missing_vars:
        raise Exception(f"Missing required environment variables: {', '.join(missing_vars)}")

    # Warn about default JWT secret
    if os.getenv('JWT_SECRET_KEY') == 'CHANGE-THIS-IN-PRODUCTION-USE-LONG-RANDOM-STRING':
        print("WARNING: Using default JWT_SECRET_KEY. Change this in production!")
