"""
Configuration Validator Agent

Validates configuration consistency across all configuration files:
- .env files (backend and frontend)
- vite.config.ts
- capacitor.config.ts
- Port configurations
- CORS settings
- Database URLs

Detects mismatches and provides actionable fixes.
"""

import os
import re
from pathlib import Path
from typing import List, Dict, Optional, Any
import logging

from .base_agent import BaseAgent, AgentFinding, FindingSeverity

logger = logging.getLogger(__name__)


class ConfigValidatorAgent(BaseAgent):
    """
    Validates configuration consistency across all config files
    """

    def __init__(self):
        super().__init__(name="config_validator", critical=False)

        # Get project root (codecheck directory)
        self.project_root = Path(__file__).parent.parent.parent

        # Config file paths
        self.config_files = {
            'backend_env': self.project_root / 'api' / '.env',
            'backend_env_example': self.project_root / 'api' / '.env.example',
            'root_env': self.project_root / '.env',
            'frontend_env': self.project_root.parent / 'photo-editor' / '.env',
            'vite_config': self.project_root.parent / 'photo-editor' / 'vite.config.ts',
            'capacitor_config': self.project_root.parent / 'photo-editor' / 'capacitor.config.ts',
        }

    async def run_checks(self) -> List[AgentFinding]:
        """Execute all configuration validation checks"""
        findings = []

        # Check 1: Port consistency
        findings.extend(await self.check_port_consistency())

        # Check 2: CORS configuration
        findings.extend(await self.check_cors_configuration())

        # Check 3: Database URL consistency
        findings.extend(await self.check_database_configuration())

        # Check 4: Exposed secrets
        findings.extend(await self.check_exposed_secrets())

        # Check 5: Capacitor configuration
        findings.extend(await self.check_capacitor_configuration())

        return findings

    async def check_port_consistency(self) -> List[AgentFinding]:
        """Check that ports are consistent across configurations"""
        findings = []

        try:
            # Get backend port from env
            backend_port = self._get_env_value(self.config_files['backend_env'], 'API_PORT', '8000')

            # Get Vite proxy target port
            vite_port = self._get_vite_proxy_port()

            if vite_port and backend_port != vite_port:
                findings.append(self.add_finding(
                    name="port_mismatch",
                    severity=FindingSeverity.CRITICAL,
                    category="configuration",
                    title="Port Mismatch Between Backend and Frontend",
                    description=f"Backend API_PORT is {backend_port} but Vite proxy targets port {vite_port}",
                    auto_fixable=False,
                    fix_action=f"Update vite.config.ts proxy target to 'http://localhost:{backend_port}'",
                    metadata={"backend_port": backend_port, "vite_port": vite_port}
                ))

            # Check if backend is actually running on the configured port
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(1)
            result = sock.connect_ex(('localhost', int(backend_port)))
            sock.close()

            if result != 0:
                findings.append(self.add_finding(
                    name="backend_not_running",
                    severity=FindingSeverity.WARNING,
                    category="configuration",
                    title="Backend Not Running on Configured Port",
                    description=f"Backend is configured for port {backend_port} but not accepting connections",
                    auto_fixable=False,
                    fix_action=f"Start backend: cd api && python3 main.py",
                    metadata={"port": backend_port}
                ))

        except Exception as e:
            logger.error(f"Error checking port consistency: {e}")

        return findings

    async def check_cors_configuration(self) -> List[AgentFinding]:
        """Check CORS configuration matches frontend URL"""
        findings = []

        try:
            # Get CORS origins from backend
            allowed_origins = self._get_env_value(
                self.config_files['backend_env'],
                'ALLOWED_ORIGINS',
                'http://localhost:3000'
            )

            # Get frontend port (default Vite port is 3000)
            frontend_port = self._get_env_value(
                self.config_files['frontend_env'],
                'VITE_PORT',
                '3000'
            )

            frontend_url = f'http://localhost:{frontend_port}'

            # Check if frontend URL is in CORS origins
            if frontend_url not in allowed_origins:
                findings.append(self.add_finding(
                    name="cors_misconfiguration",
                    severity=FindingSeverity.CRITICAL,
                    category="configuration",
                    title="Frontend URL Not in CORS Origins",
                    description=f"Frontend runs on {frontend_url} but this URL is not in ALLOWED_ORIGINS",
                    auto_fixable=True,
                    fix_action=f"Add '{frontend_url}' to ALLOWED_ORIGINS in api/.env",
                    metadata={
                        "frontend_url": frontend_url,
                        "current_origins": allowed_origins
                    }
                ))

            # Check for wildcard in production
            environment = self._get_env_value(self.config_files['backend_env'], 'ENVIRONMENT', 'development')
            if environment == 'production' and '*' in allowed_origins:
                findings.append(self.add_finding(
                    name="cors_wildcard_production",
                    severity=FindingSeverity.CRITICAL,
                    category="security",
                    title="CORS Wildcard in Production",
                    description="ALLOWED_ORIGINS contains '*' in production environment. This is a security risk.",
                    auto_fixable=False,
                    fix_action="Replace '*' with specific domain names in ALLOWED_ORIGINS",
                    metadata={"environment": environment}
                ))

        except Exception as e:
            logger.error(f"Error checking CORS configuration: {e}")

        return findings

    async def check_database_configuration(self) -> List[AgentFinding]:
        """Check database configuration consistency"""
        findings = []

        try:
            # Get DATABASE_URL if present
            database_url = self._get_env_value(self.config_files['backend_env'], 'DATABASE_URL')

            # Get individual DB params
            db_host = self._get_env_value(self.config_files['backend_env'], 'DB_HOST', 'localhost')
            db_port = self._get_env_value(self.config_files['backend_env'], 'DB_PORT', '5432')
            db_user = self._get_env_value(self.config_files['backend_env'], 'DB_USER', 'postgres')
            db_password = self._get_env_value(self.config_files['backend_env'], 'DB_PASSWORD', '')
            db_name = self._get_env_value(self.config_files['backend_env'], 'DB_NAME', 'codecheck')

            if database_url:
                # Parse DATABASE_URL and compare with individual params
                url_pattern = r'postgresql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)'
                match = re.match(url_pattern, database_url)

                if match:
                    url_user, url_pass, url_host, url_port, url_db = match.groups()

                    mismatches = []
                    if url_host != db_host:
                        mismatches.append(f"Host: DATABASE_URL={url_host}, DB_HOST={db_host}")
                    if url_port != db_port:
                        mismatches.append(f"Port: DATABASE_URL={url_port}, DB_PORT={db_port}")
                    if url_user != db_user:
                        mismatches.append(f"User: DATABASE_URL={url_user}, DB_USER={db_user}")
                    if url_db != db_name:
                        mismatches.append(f"Database: DATABASE_URL={url_db}, DB_NAME={db_name}")

                    if mismatches:
                        findings.append(self.add_finding(
                            name="database_config_mismatch",
                            severity=FindingSeverity.WARNING,
                            category="configuration",
                            title="DATABASE_URL and Individual DB Params Mismatch",
                            description="DATABASE_URL and DB_HOST/DB_PORT/etc have different values",
                            auto_fixable=False,
                            fix_action="Use either DATABASE_URL OR individual DB params, not both. Remove one set.",
                            metadata={"mismatches": mismatches}
                        ))

            # Check for default/weak passwords in production
            environment = self._get_env_value(self.config_files['backend_env'], 'ENVIRONMENT', 'development')
            if environment == 'production':
                weak_passwords = ['password', 'admin', '123456', 'postgres', '']
                if db_password.lower() in weak_passwords:
                    findings.append(self.add_finding(
                        name="weak_database_password",
                        severity=FindingSeverity.CRITICAL,
                        category="security",
                        title="Weak Database Password in Production",
                        description=f"Database password appears to be weak or default in production",
                        auto_fixable=False,
                        fix_action="Set a strong database password with at least 16 characters",
                        metadata={"environment": environment}
                    ))

        except Exception as e:
            logger.error(f"Error checking database configuration: {e}")

        return findings

    async def check_exposed_secrets(self) -> List[AgentFinding]:
        """Check for potentially exposed secrets"""
        findings = []

        # Files that should NEVER be committed
        sensitive_files = [
            self.config_files['backend_env'],
            self.config_files['root_env'],
            self.config_files['frontend_env'],
        ]

        for file_path in sensitive_files:
            if not file_path.exists():
                continue

            try:
                # Check if file is tracked by git
                import subprocess
                result = subprocess.run(
                    ['git', 'ls-files', '--error-unmatch', str(file_path)],
                    cwd=self.project_root,
                    capture_output=True,
                    text=True
                )

                if result.returncode == 0:
                    # File is tracked by git - this is bad!
                    findings.append(self.add_finding(
                        name="secrets_in_git",
                        severity=FindingSeverity.CRITICAL,
                        category="security",
                        title=f"Secrets File Tracked in Git",
                        description=f"{file_path.name} is tracked by git. This file contains secrets and should not be committed.",
                        auto_fixable=False,
                        fix_action=f"Run: git rm --cached {file_path.relative_to(self.project_root)} && echo '{file_path.name}' >> .gitignore",
                        metadata={"file": str(file_path)}
                    ))

                # Check for exposed API keys
                content = file_path.read_text()

                # Look for exposed Claude API keys
                if 'CLAUDE_API_KEY' in content:
                    api_key_match = re.search(r'CLAUDE_API_KEY=(.+)', content)
                    if api_key_match:
                        api_key = api_key_match.group(1).strip()
                        # Check if it looks like a real key (starts with expected pattern)
                        if api_key.startswith('sk-ant-') and len(api_key) > 20:
                            findings.append(self.add_finding(
                                name="exposed_api_key",
                                severity=FindingSeverity.CRITICAL,
                                category="security",
                                title="API Key Found in Config File",
                                description=f"Claude API key found in {file_path.name}. Ensure this file is in .gitignore.",
                                auto_fixable=False,
                                fix_action=f"Verify {file_path.name} is in .gitignore",
                                metadata={"file": str(file_path)}
                            ))

            except Exception as e:
                logger.debug(f"Error checking {file_path}: {e}")

        return findings

    async def check_capacitor_configuration(self) -> List[AgentFinding]:
        """Check Capacitor configuration for iOS/Android"""
        findings = []

        capacitor_config_path = self.config_files['capacitor_config']

        if not capacitor_config_path.exists():
            findings.append(self.add_finding(
                name="capacitor_config_missing",
                severity=FindingSeverity.WARNING,
                category="configuration",
                title="Capacitor Config Missing",
                description="capacitor.config.ts not found. Required for iOS/Android deployment.",
                auto_fixable=False,
                fix_action="Create capacitor.config.ts with proper server configuration",
                metadata={}
            ))
            return findings

        try:
            content = capacitor_config_path.read_text()

            # Check if server config exists for development
            if 'server:' not in content and 'server {' not in content:
                findings.append(self.add_finding(
                    name="capacitor_no_server_config",
                    severity=FindingSeverity.INFO,
                    category="configuration",
                    title="Capacitor Missing Server Configuration",
                    description="capacitor.config.ts doesn't have server configuration for development",
                    auto_fixable=False,
                    fix_action="Add server configuration to enable iOS development mode",
                    metadata={}
                ))

            # Check if cleartext is enabled for dev
            if 'cleartext' not in content:
                findings.append(self.add_finding(
                    name="capacitor_no_cleartext",
                    severity=FindingSeverity.INFO,
                    category="configuration",
                    title="Capacitor Cleartext Not Configured",
                    description="HTTP cleartext not enabled. May cause issues connecting to local backend.",
                    auto_fixable=False,
                    fix_action="Add 'cleartext: true' to server config in capacitor.config.ts",
                    metadata={}
                ))

        except Exception as e:
            logger.error(f"Error checking Capacitor configuration: {e}")

        return findings

    def _get_env_value(self, env_file: Path, key: str, default: str = '') -> str:
        """Get value from .env file"""
        if not env_file.exists():
            return default

        try:
            content = env_file.read_text()
            match = re.search(rf'^{key}=(.+)$', content, re.MULTILINE)
            if match:
                return match.group(1).strip().strip('"').strip("'")
        except Exception as e:
            logger.debug(f"Error reading {env_file}: {e}")

        return default

    def _get_vite_proxy_port(self) -> Optional[str]:
        """Extract proxy port from vite.config.ts"""
        vite_config = self.config_files['vite_config']

        if not vite_config.exists():
            return None

        try:
            content = vite_config.read_text()
            # Look for target: 'http://localhost:XXXX'
            match = re.search(r"target:\s*['\"]http://localhost:(\d+)['\"]", content)
            if match:
                return match.group(1)
        except Exception as e:
            logger.debug(f"Error reading vite.config.ts: {e}")

        return None

    async def auto_fix(self, finding: AgentFinding) -> bool:
        """
        Attempt to automatically fix configuration issues
        """
        if finding.name == "cors_misconfiguration":
            return await self._fix_cors_config(finding)

        return False

    async def _fix_cors_config(self, finding: AgentFinding) -> bool:
        """Fix CORS configuration by adding frontend URL"""
        try:
            frontend_url = finding.metadata.get('frontend_url')
            current_origins = finding.metadata.get('current_origins', '')

            if not frontend_url:
                return False

            backend_env = self.config_files['backend_env']

            if not backend_env.exists():
                return False

            # Read current content
            content = backend_env.read_text()

            # Add frontend URL to ALLOWED_ORIGINS
            if 'ALLOWED_ORIGINS=' in content:
                # Append to existing
                new_origins = f"{current_origins},{frontend_url}"
                content = re.sub(
                    r'ALLOWED_ORIGINS=.+',
                    f'ALLOWED_ORIGINS={new_origins}',
                    content
                )
            else:
                # Add new line
                content += f'\nALLOWED_ORIGINS={frontend_url}\n'

            # Write back
            backend_env.write_text(content)

            self.logger.info(f"Added {frontend_url} to ALLOWED_ORIGINS")
            return True

        except Exception as e:
            self.logger.error(f"Failed to fix CORS config: {e}")
            return False
