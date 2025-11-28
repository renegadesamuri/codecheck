"""
Auth Flow Testing Agent

Validates end-to-end authentication flows:
- Login/logout functionality
- Token validation and refresh
- Password requirements enforcement
- Security best practices
- Protected endpoint access

Detects auth issues and provides actionable fixes.
"""

import os
import re
import time
import asyncio
import logging
from pathlib import Path
from typing import List, Dict, Optional, Any
from datetime import datetime

import httpx

from .base_agent import BaseAgent, AgentFinding, FindingSeverity

logger = logging.getLogger(__name__)


class AuthFlowTesterAgent(BaseAgent):
    """
    Tests authentication flows and validates security practices
    """

    def __init__(self):
        super().__init__(name="auth_flow_tester", critical=False)

        # Get project root
        self.project_root = Path(__file__).parent.parent.parent

        # API configuration
        self.api_base_url = os.getenv('API_BASE_URL', 'http://localhost:8000')

        # Test credentials (for validation only, not real users)
        self.test_email = f"test_agent_{int(time.time())}@codecheck.local"
        self.test_password = "TestPass123!"

    async def run_checks(self) -> List[AgentFinding]:
        """Execute all authentication validation checks"""
        findings = []

        # Check 1: JWT Secret Security
        findings.extend(await self.check_jwt_secret_security())

        # Check 2: Password Policy
        findings.extend(await self.check_password_policy())

        # Check 3: API Endpoint Availability
        findings.extend(await self.check_auth_endpoints_available())

        # Check 4: Token Expiration Settings
        findings.extend(await self.check_token_expiration_settings())

        # Check 5: Login Flow (if API is running)
        findings.extend(await self.check_login_flow())

        # Check 6: Protected Endpoint Security
        findings.extend(await self.check_protected_endpoints())

        # Check 7: Audit Logging
        findings.extend(await self.check_audit_logging())

        return findings

    async def check_jwt_secret_security(self) -> List[AgentFinding]:
        """Check JWT secret is properly configured"""
        findings = []

        try:
            # Read auth.py to check JWT configuration
            auth_file = self.project_root / 'api' / 'auth.py'

            if not auth_file.exists():
                findings.append(self.add_finding(
                    name="auth_file_missing",
                    severity=FindingSeverity.CRITICAL,
                    category="security",
                    title="Authentication Module Missing",
                    description="auth.py file not found. Authentication system may not be configured.",
                    auto_fixable=False,
                    fix_action="Create api/auth.py with proper JWT configuration",
                    metadata={}
                ))
                return findings

            content = auth_file.read_text()

            # Check for default/weak secret
            default_secret_pattern = r"SECRET_KEY\s*=.*['\"]CHANGE-THIS|your-secret|changeme|secret123"
            if re.search(default_secret_pattern, content, re.IGNORECASE):
                findings.append(self.add_finding(
                    name="jwt_default_secret",
                    severity=FindingSeverity.CRITICAL,
                    category="security",
                    title="JWT Secret Using Default Value",
                    description="JWT_SECRET_KEY is using a default/weak value. This is a critical security vulnerability.",
                    auto_fixable=False,
                    fix_action="Set JWT_SECRET_KEY environment variable with a strong random secret (at least 32 characters)",
                    metadata={}
                ))

            # Check if secret is loaded from environment
            if "os.getenv('JWT_SECRET_KEY'" in content:
                # Good - using environment variable, now check if it's set
                env_file = self.project_root / 'api' / '.env'
                if env_file.exists():
                    env_content = env_file.read_text()
                    if 'JWT_SECRET_KEY=' in env_content:
                        # Extract the value
                        match = re.search(r'JWT_SECRET_KEY=(.+)', env_content)
                        if match:
                            secret_value = match.group(1).strip().strip('"').strip("'")
                            if len(secret_value) < 32:
                                findings.append(self.add_finding(
                                    name="jwt_secret_too_short",
                                    severity=FindingSeverity.WARNING,
                                    category="security",
                                    title="JWT Secret Too Short",
                                    description=f"JWT secret is only {len(secret_value)} characters. Recommended minimum is 32 characters.",
                                    auto_fixable=False,
                                    fix_action="Generate a longer JWT secret: python3 -c \"import secrets; print(secrets.token_urlsafe(64))\"",
                                    metadata={"current_length": len(secret_value)}
                                ))
                    else:
                        findings.append(self.add_finding(
                            name="jwt_secret_not_set",
                            severity=FindingSeverity.WARNING,
                            category="security",
                            title="JWT Secret Not Set in Environment",
                            description="JWT_SECRET_KEY not found in .env file. Using default fallback value.",
                            auto_fixable=False,
                            fix_action="Add JWT_SECRET_KEY to api/.env file with a strong random secret",
                            metadata={}
                        ))

            # Check algorithm security
            if 'ALGORITHM = "HS256"' in content:
                # HS256 is acceptable but RS256 is more secure for production
                self.logger.info("JWT using HS256 algorithm (acceptable for development)")

        except Exception as e:
            self.logger.error(f"Error checking JWT secret security: {e}")

        return findings

    async def check_password_policy(self) -> List[AgentFinding]:
        """Check password policy configuration"""
        findings = []

        try:
            auth_file = self.project_root / 'api' / 'auth.py'

            if not auth_file.exists():
                return findings

            content = auth_file.read_text()

            # Check for password validation
            if 'validate_password_strength' not in content:
                findings.append(self.add_finding(
                    name="no_password_validation",
                    severity=FindingSeverity.CRITICAL,
                    category="security",
                    title="No Password Strength Validation",
                    description="Password strength validation function not found. Users may set weak passwords.",
                    auto_fixable=False,
                    fix_action="Add validate_password_strength function with minimum requirements",
                    metadata={}
                ))
            else:
                # Check minimum password requirements
                if 'len(password) < 8' not in content and 'len(password) >= 8' not in content:
                    findings.append(self.add_finding(
                        name="weak_password_length",
                        severity=FindingSeverity.WARNING,
                        category="security",
                        title="Password Length Requirement Not Enforced",
                        description="Minimum password length of 8 characters not found in validation.",
                        auto_fixable=False,
                        fix_action="Ensure password validation requires at least 8 characters",
                        metadata={}
                    ))

            # Check for bcrypt usage
            if 'bcrypt' not in content:
                findings.append(self.add_finding(
                    name="weak_password_hashing",
                    severity=FindingSeverity.CRITICAL,
                    category="security",
                    title="Password Not Using bcrypt",
                    description="Passwords should be hashed with bcrypt. Other algorithms may be less secure.",
                    auto_fixable=False,
                    fix_action="Use passlib with bcrypt: CryptContext(schemes=['bcrypt'])",
                    metadata={}
                ))

        except Exception as e:
            self.logger.error(f"Error checking password policy: {e}")

        return findings

    async def check_auth_endpoints_available(self) -> List[AgentFinding]:
        """Check that auth endpoints are available"""
        findings = []

        required_endpoints = [
            ('POST', '/auth/register'),
            ('POST', '/auth/login'),
            ('POST', '/auth/refresh'),
        ]

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                for method, endpoint in required_endpoints:
                    try:
                        url = f"{self.api_base_url}{endpoint}"
                        # Use OPTIONS to check if endpoint exists without triggering auth
                        response = await client.options(url)

                        # Check if endpoint responds (even with 405 Method Not Allowed is OK)
                        if response.status_code >= 500:
                            findings.append(self.add_finding(
                                name=f"endpoint_error_{endpoint.replace('/', '_')}",
                                severity=FindingSeverity.CRITICAL,
                                category="authentication",
                                title=f"Auth Endpoint Error: {endpoint}",
                                description=f"{method} {endpoint} returned error: {response.status_code}",
                                auto_fixable=False,
                                fix_action="Check backend logs for errors on this endpoint",
                                metadata={"endpoint": endpoint, "status": response.status_code}
                            ))

                    except httpx.ConnectError:
                        findings.append(self.add_finding(
                            name="api_not_reachable",
                            severity=FindingSeverity.CRITICAL,
                            category="authentication",
                            title="API Not Reachable",
                            description=f"Cannot connect to API at {self.api_base_url}",
                            auto_fixable=False,
                            fix_action="Start the backend: cd api && python3 main.py",
                            metadata={"url": self.api_base_url}
                        ))
                        break  # Don't check other endpoints if API is down
                    except Exception as e:
                        self.logger.debug(f"Error checking endpoint {endpoint}: {e}")

        except Exception as e:
            self.logger.error(f"Error checking auth endpoints: {e}")

        return findings

    async def check_token_expiration_settings(self) -> List[AgentFinding]:
        """Check token expiration settings are appropriate"""
        findings = []

        try:
            auth_file = self.project_root / 'api' / 'auth.py'

            if not auth_file.exists():
                return findings

            content = auth_file.read_text()

            # Check access token expiration
            access_match = re.search(r'ACCESS_TOKEN_EXPIRE_MINUTES\s*=\s*(\d+)', content)
            if access_match:
                minutes = int(access_match.group(1))
                hours = minutes / 60

                if hours > 24:
                    findings.append(self.add_finding(
                        name="access_token_too_long",
                        severity=FindingSeverity.WARNING,
                        category="security",
                        title="Access Token Expiration Too Long",
                        description=f"Access tokens expire in {hours} hours. Recommended maximum is 24 hours.",
                        auto_fixable=False,
                        fix_action="Set ACCESS_TOKEN_EXPIRE_MINUTES to 1440 (24 hours) or less",
                        metadata={"current_hours": hours}
                    ))

            # Check refresh token expiration
            refresh_match = re.search(r'REFRESH_TOKEN_EXPIRE_DAYS\s*=\s*(\d+)', content)
            if refresh_match:
                days = int(refresh_match.group(1))

                if days > 90:
                    findings.append(self.add_finding(
                        name="refresh_token_too_long",
                        severity=FindingSeverity.WARNING,
                        category="security",
                        title="Refresh Token Expiration Too Long",
                        description=f"Refresh tokens expire in {days} days. Recommended maximum is 90 days.",
                        auto_fixable=False,
                        fix_action="Set REFRESH_TOKEN_EXPIRE_DAYS to 90 or less",
                        metadata={"current_days": days}
                    ))

        except Exception as e:
            self.logger.error(f"Error checking token expiration: {e}")

        return findings

    async def check_login_flow(self) -> List[AgentFinding]:
        """Test login flow with actual API calls"""
        findings = []

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                # Test 1: Login with invalid credentials (should fail gracefully)
                try:
                    response = await client.post(
                        f"{self.api_base_url}/auth/login",
                        json={
                            "email": "nonexistent@test.com",
                            "password": "wrongpassword123"
                        }
                    )

                    if response.status_code == 200:
                        findings.append(self.add_finding(
                            name="invalid_credentials_accepted",
                            severity=FindingSeverity.CRITICAL,
                            category="security",
                            title="Invalid Credentials Accepted",
                            description="Login succeeded with invalid credentials. This is a critical security issue.",
                            auto_fixable=False,
                            fix_action="Fix authentication logic to properly validate credentials",
                            metadata={}
                        ))
                    elif response.status_code == 401:
                        # Expected - this is correct behavior
                        self.logger.info("Login correctly rejects invalid credentials")
                    elif response.status_code >= 500:
                        findings.append(self.add_finding(
                            name="login_server_error",
                            severity=FindingSeverity.CRITICAL,
                            category="authentication",
                            title="Login Endpoint Server Error",
                            description=f"Login endpoint returned server error: {response.status_code}",
                            auto_fixable=False,
                            fix_action="Check backend logs for errors",
                            metadata={"status_code": response.status_code}
                        ))

                except httpx.ConnectError:
                    # API not running - already reported
                    pass
                except Exception as e:
                    self.logger.debug(f"Error testing login flow: {e}")

                # Test 2: Check error response doesn't leak information
                try:
                    response = await client.post(
                        f"{self.api_base_url}/auth/login",
                        json={
                            "email": "test@example.com",
                            "password": "wrongpassword"
                        }
                    )

                    if response.status_code == 401:
                        error_detail = response.json().get('detail', '')

                        # Check for information leakage
                        if 'user not found' in error_detail.lower():
                            findings.append(self.add_finding(
                                name="user_enumeration_vulnerability",
                                severity=FindingSeverity.WARNING,
                                category="security",
                                title="User Enumeration Vulnerability",
                                description="Login error message reveals whether user exists. Attackers can enumerate valid emails.",
                                auto_fixable=False,
                                fix_action="Use generic error message: 'Incorrect email or password'",
                                metadata={"error_message": error_detail}
                            ))

                except Exception:
                    pass

        except Exception as e:
            self.logger.error(f"Error checking login flow: {e}")

        return findings

    async def check_protected_endpoints(self) -> List[AgentFinding]:
        """Check that protected endpoints require authentication"""
        findings = []

        # Endpoints that should require authentication
        protected_endpoints = [
            '/api/connectivity/config/validation',
            '/api/analyze/image',
            '/auth/me',
        ]

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                for endpoint in protected_endpoints:
                    try:
                        url = f"{self.api_base_url}{endpoint}"
                        response = await client.get(url)

                        # Should return 401 or 403 without auth
                        if response.status_code == 200:
                            findings.append(self.add_finding(
                                name=f"unprotected_endpoint",
                                severity=FindingSeverity.CRITICAL,
                                category="security",
                                title=f"Endpoint Not Protected: {endpoint}",
                                description=f"{endpoint} should require authentication but returned 200 without token",
                                auto_fixable=False,
                                fix_action=f"Add authentication dependency to {endpoint}",
                                metadata={"endpoint": endpoint}
                            ))

                    except httpx.ConnectError:
                        break  # API not running
                    except Exception as e:
                        self.logger.debug(f"Error checking endpoint {endpoint}: {e}")

        except Exception as e:
            self.logger.error(f"Error checking protected endpoints: {e}")

        return findings

    async def check_audit_logging(self) -> List[AgentFinding]:
        """Check that authentication events are being logged"""
        findings = []

        try:
            # Check main.py for audit logging calls
            main_file = self.project_root / 'api' / 'main.py'

            if not main_file.exists():
                return findings

            content = main_file.read_text()

            # Check for audit logging on important events
            audit_events = [
                ('login_success', 'successful login'),
                ('login_failed', 'failed login'),
                ('user_registered', 'user registration'),
            ]

            missing_events = []
            for event_name, description in audit_events:
                if f'"{event_name}"' not in content and f"'{event_name}'" not in content:
                    missing_events.append(description)

            if missing_events:
                findings.append(self.add_finding(
                    name="missing_audit_logging",
                    severity=FindingSeverity.WARNING,
                    category="security",
                    title="Missing Audit Logging",
                    description=f"The following auth events may not be logged: {', '.join(missing_events)}",
                    auto_fixable=False,
                    fix_action="Add AuditLogger.log_event() calls for all authentication events",
                    metadata={"missing_events": missing_events}
                ))

            # Check if audit table exists in database
            try:
                from api.database import execute_query

                result = execute_query("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables
                        WHERE table_name = 'audit_log'
                    )
                """, read_only=True)

                if result and not result[0]['exists']:
                    findings.append(self.add_finding(
                        name="audit_table_missing",
                        severity=FindingSeverity.WARNING,
                        category="security",
                        title="Audit Log Table Missing",
                        description="audit_log table not found in database. Auth events may not be persisted.",
                        auto_fixable=False,
                        fix_action="Run database migrations to create audit_log table",
                        metadata={}
                    ))

            except Exception as e:
                self.logger.debug(f"Could not check audit table: {e}")

        except Exception as e:
            self.logger.error(f"Error checking audit logging: {e}")

        return findings

    async def auto_fix(self, finding: AgentFinding) -> bool:
        """
        Attempt to automatically fix authentication issues.
        Most auth issues require manual intervention for security reasons.
        """
        # Auth issues should not be auto-fixed for security reasons
        return False
