"""
Connection Tester Agent

Tests all critical connections in the CodeCheck application:
- Backend → Database (PostgreSQL + PostGIS)
- Backend API Health
- Frontend → Backend (if frontend is running)
- Redis connectivity (optional)

Provides clear diagnostic messages and auto-remediation where safe.
"""

import time
import socket
import requests
import psycopg2
from typing import List, Dict, Optional
import logging

from .base_agent import BaseAgent, AgentFinding, FindingSeverity

logger = logging.getLogger(__name__)


class ConnectionTesterAgent(BaseAgent):
    """
    Tests all critical system connections and provides clear diagnostics
    """

    def __init__(self):
        super().__init__(name="connection_tester", critical=True)
        self.timeout_seconds = 5

    async def run_checks(self) -> List[AgentFinding]:
        """Execute all connection tests"""
        findings = []

        # Test 1: Backend → Database
        findings.extend(await self.test_database_connection())

        # Test 2: Backend API Health
        findings.extend(await self.test_backend_health())

        # Test 3: Redis (optional - not critical)
        findings.extend(await self.test_redis_connection())

        # Store connection test results
        await self._store_connection_results(findings)

        return findings

    async def test_database_connection(self) -> List[AgentFinding]:
        """Test PostgreSQL database connection and PostGIS extension"""
        findings = []

        try:
            from api.database import get_db, get_connection_pool
            from psycopg2.extras import RealDictCursor

            start_time = time.time()

            # Test basic connection using context manager
            with get_db(read_only=True, cursor_factory=RealDictCursor) as cursor:
                # Test basic query
                cursor.execute("SELECT 1 AS test")
                result = cursor.fetchone()

                if result['test'] != 1:
                    raise Exception("Database query returned unexpected result")

                # Test PostGIS extension
                postgis_version = None
                try:
                    cursor.execute("SELECT PostGIS_Version() as version")
                    postgis_result = cursor.fetchone()
                    postgis_version = postgis_result['version']
                    self.logger.info(f"PostGIS version: {postgis_version}")
                except Exception as e:
                    findings.append(self.add_finding(
                        name="postgis_missing",
                        severity=FindingSeverity.CRITICAL,
                        category="database",
                        title="PostGIS Extension Not Available",
                        description=f"PostGIS extension is required but not available: {str(e)}",
                        auto_fixable=False,
                        fix_action="Run: CREATE EXTENSION IF NOT EXISTS postgis;",
                        metadata={"error": str(e)}
                    ))

            # Get connection pool stats
            pool_stats = None
            pool = get_connection_pool()
            if pool:
                pool_stats = {
                    'min_connections': pool._pool.minconn,
                    'max_connections': pool._pool.maxconn,
                    'available': len([c for c in pool._pool._pool if c.closed == 0])
                }
                self.logger.info(f"Connection pool stats: {pool_stats}")

                # Check for pool exhaustion
                if pool_stats['available'] == 0:
                    findings.append(self.add_finding(
                        name="connection_pool_exhausted",
                        severity=FindingSeverity.WARNING,
                        category="database",
                        title="Connection Pool Exhausted",
                        description="All database connections are in use. This may cause performance issues.",
                        auto_fixable=True,
                        fix_action="Close idle connections and reset pool",
                        metadata=pool_stats
                    ))

            latency_ms = int((time.time() - start_time) * 1000)

            # Record successful connection
            await self._record_connection_test(
                connection_name="backend-database",
                connection_type="database",
                status="healthy",
                latency_ms=latency_ms,
                metadata={
                    "postgis_version": postgis_version,
                    "pool_stats": pool_stats
                }
            )

            self.logger.info(f"✅ Database connection healthy ({latency_ms}ms)")

        except psycopg2.OperationalError as e:
            error_str = str(e).lower()

            if "connection refused" in error_str:
                fix = "PostgreSQL not running. Start it with: docker-compose up -d postgres"
            elif "authentication failed" in error_str or "password" in error_str:
                fix = "Check DB_PASSWORD in .env matches PostgreSQL password"
            elif "database" in error_str and "does not exist" in error_str:
                fix = "Create database: docker-compose exec postgres createdb codecheck"
            elif "could not connect to server" in error_str:
                fix = "Check DB_HOST and DB_PORT in .env (current values may be incorrect)"
            else:
                fix = "Check database configuration in .env file"

            findings.append(self.add_finding(
                name="database_connection_failed",
                severity=FindingSeverity.CRITICAL,
                category="database",
                title="Database Connection Failed",
                description=f"Could not connect to PostgreSQL: {str(e)}",
                auto_fixable=False,
                fix_action=fix,
                metadata={"error": str(e), "error_type": type(e).__name__}
            ))

            await self._record_connection_test(
                connection_name="backend-database",
                connection_type="database",
                status="failed",
                error_message=str(e),
                metadata={"error_type": type(e).__name__}
            )

        except Exception as e:
            findings.append(self.add_finding(
                name="database_unexpected_error",
                severity=FindingSeverity.CRITICAL,
                category="database",
                title="Unexpected Database Error",
                description=f"Unexpected error testing database: {str(e)}",
                auto_fixable=False,
                fix_action="Check database logs and configuration",
                metadata={"error": str(e), "error_type": type(e).__name__}
            ))

            await self._record_connection_test(
                connection_name="backend-database",
                connection_type="database",
                status="failed",
                error_message=str(e)
            )

        return findings

    async def test_backend_health(self) -> List[AgentFinding]:
        """Test if backend API is accessible"""
        findings = []

        try:
            import os

            api_host = os.getenv('API_HOST', '0.0.0.0')
            api_port = int(os.getenv('API_PORT', 8000))

            # Check if port is listening
            start_time = time.time()

            # Try to connect to the port
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(self.timeout_seconds)

            # Use localhost instead of 0.0.0.0 for testing
            test_host = 'localhost' if api_host == '0.0.0.0' else api_host

            result = sock.connect_ex((test_host, api_port))
            sock.close()

            latency_ms = int((time.time() - start_time) * 1000)

            if result == 0:
                # Port is open
                await self._record_connection_test(
                    connection_name="backend-api",
                    connection_type="http",
                    status="healthy",
                    latency_ms=latency_ms,
                    metadata={"host": test_host, "port": api_port}
                )

                self.logger.info(f"✅ Backend API reachable at {test_host}:{api_port} ({latency_ms}ms)")
            else:
                findings.append(self.add_finding(
                    name="backend_api_unreachable",
                    severity=FindingSeverity.CRITICAL,
                    category="connectivity",
                    title="Backend API Not Reachable",
                    description=f"Backend API port {api_port} is not accepting connections",
                    auto_fixable=False,
                    fix_action=f"Ensure backend is running on port {api_port}. Check API_PORT in .env",
                    metadata={"host": test_host, "port": api_port}
                ))

                await self._record_connection_test(
                    connection_name="backend-api",
                    connection_type="http",
                    status="failed",
                    error_message=f"Port {api_port} not accepting connections"
                )

        except Exception as e:
            findings.append(self.add_finding(
                name="backend_health_check_error",
                severity=FindingSeverity.WARNING,
                category="connectivity",
                title="Backend Health Check Error",
                description=f"Could not check backend health: {str(e)}",
                auto_fixable=False,
                fix_action="Check network configuration and firewall settings",
                metadata={"error": str(e)}
            ))

        return findings

    async def test_redis_connection(self) -> List[AgentFinding]:
        """Test Redis connection (optional - not critical)"""
        findings = []

        try:
            import os
            import redis

            redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379')

            if not redis_url or redis_url == 'memory://':
                # Redis not configured or using in-memory fallback
                self.logger.info("Redis not configured, skipping test")
                return findings

            start_time = time.time()

            # Parse Redis URL
            r = redis.from_url(redis_url, socket_timeout=self.timeout_seconds)

            # Test connection with ping
            r.ping()

            latency_ms = int((time.time() - start_time) * 1000)

            await self._record_connection_test(
                connection_name="backend-redis",
                connection_type="redis",
                status="healthy",
                latency_ms=latency_ms,
                metadata={"redis_url": redis_url}
            )

            self.logger.info(f"✅ Redis connection healthy ({latency_ms}ms)")

        except ImportError:
            # Redis library not installed - not critical
            self.logger.info("Redis library not installed, skipping test")
        except redis.ConnectionError as e:
            # Redis not available - not critical for basic functionality
            findings.append(self.add_finding(
                name="redis_unavailable",
                severity=FindingSeverity.INFO,
                category="connectivity",
                title="Redis Not Available",
                description=f"Redis is not available: {str(e)}. Rate limiting will use database fallback.",
                auto_fixable=False,
                fix_action="Start Redis with: docker-compose up -d redis",
                metadata={"error": str(e)}
            ))

            await self._record_connection_test(
                connection_name="backend-redis",
                connection_type="redis",
                status="degraded",
                error_message=str(e)
            )
        except Exception as e:
            self.logger.warning(f"Unexpected error testing Redis: {e}")

        return findings

    async def _record_connection_test(
        self,
        connection_name: str,
        connection_type: str,
        status: str,
        latency_ms: Optional[int] = None,
        error_message: Optional[str] = None,
        metadata: Optional[Dict] = None
    ):
        """Record connection test result in database"""
        try:
            from api.database import execute_transaction
            import json

            metadata_json = json.dumps(metadata) if metadata else None

            execute_transaction([
                ("""
                    INSERT INTO connection_tests
                    (run_id, connection_name, connection_type, status, latency_ms, error_message, metadata, tested_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s::jsonb, NOW())
                """, (
                    self.run_id,
                    connection_name,
                    connection_type,
                    status,
                    latency_ms,
                    error_message,
                    metadata_json
                ))
            ], read_only=False)
        except Exception as e:
            self.logger.warning(f"Failed to record connection test: {e}")

    async def _store_connection_results(self, findings: List[AgentFinding]):
        """Store all connection test results"""
        # Results are stored individually via _record_connection_test
        pass

    async def auto_fix(self, finding: AgentFinding) -> bool:
        """
        Attempt to auto-fix connection issues

        Currently supports:
        - Connection pool exhaustion (restart pool)
        """
        if finding.name == "connection_pool_exhausted":
            return await self._fix_connection_pool()

        return False

    async def _fix_connection_pool(self) -> bool:
        """Attempt to fix connection pool exhaustion"""
        try:
            from api.database import get_connection_pool

            pool = get_connection_pool()
            if pool:
                # Close all connections and restart pool
                pool.closeall()
                pool._initialize_pool()

                self.logger.info("Connection pool restarted successfully")
                return True
        except Exception as e:
            self.logger.error(f"Failed to restart connection pool: {e}")

        return False
