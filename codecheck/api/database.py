"""
CodeCheck Database Connection Pool
Production-ready PostgreSQL connection pooling with comprehensive error handling,
monitoring, and security features.
"""

import os
import logging
import threading
from contextlib import contextmanager
from typing import Optional, Dict, Any, List, Tuple, Union
from urllib.parse import urlparse
from datetime import datetime

import psycopg2
from psycopg2 import pool, OperationalError, DatabaseError
from psycopg2.extras import RealDictCursor, DictCursor
from psycopg2.extensions import connection, cursor

# Configure logging
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Thread-local storage for connection pool
_local = threading.local()


class DatabaseConfig:
    """Database configuration from environment variables"""

    def __init__(self):
        # Try DATABASE_URL first (common in production/Heroku)
        database_url = os.getenv('DATABASE_URL')

        if database_url:
            self._parse_database_url(database_url)
        else:
            # Fall back to individual environment variables
            self.host = os.getenv('DB_HOST', 'localhost')
            self.port = int(os.getenv('DB_PORT', '5432'))
            self.user = os.getenv('DB_USER', 'postgres')
            self.password = os.getenv('DB_PASSWORD', '')
            self.database = os.getenv('DB_NAME', 'codecheck')
            self.sslmode = os.getenv('DB_SSLMODE', 'prefer')

        # Pool configuration
        self.min_connections = int(os.getenv('DB_POOL_MIN', '2'))
        self.max_connections = int(os.getenv('DB_POOL_MAX', '10'))
        self.connection_timeout = int(os.getenv('DB_TIMEOUT', '30'))
        self.statement_timeout = int(os.getenv('DB_STATEMENT_TIMEOUT', '30000'))  # milliseconds
        self.idle_in_transaction_timeout = int(os.getenv('DB_IDLE_TIMEOUT', '60000'))  # milliseconds

        # SSL configuration for production
        self.sslrootcert = os.getenv('DB_SSLROOTCERT')
        self.sslcert = os.getenv('DB_SSLCERT')
        self.sslkey = os.getenv('DB_SSLKEY')

    def _parse_database_url(self, url: str):
        """Parse DATABASE_URL into components"""
        try:
            parsed = urlparse(url)
            self.host = parsed.hostname or 'localhost'
            self.port = parsed.port or 5432
            self.user = parsed.username or 'postgres'
            self.password = parsed.password or ''
            self.database = parsed.path.lstrip('/') or 'codecheck'

            # Check for SSL requirement in query params
            if 'sslmode=' in url:
                self.sslmode = parsed.query.split('sslmode=')[1].split('&')[0]
            else:
                self.sslmode = 'require' if 'amazonaws.com' in url else 'prefer'

            logger.info(f"Parsed DATABASE_URL: {self.user}@{self.host}:{self.port}/{self.database}")
        except Exception as e:
            logger.error(f"Failed to parse DATABASE_URL: {e}")
            raise ValueError(f"Invalid DATABASE_URL format: {e}")

    def get_dsn(self) -> str:
        """Get connection DSN string"""
        dsn_parts = [
            f"host={self.host}",
            f"port={self.port}",
            f"user={self.user}",
            f"password={self.password}",
            f"dbname={self.database}",
            f"sslmode={self.sslmode}",
            f"connect_timeout={self.connection_timeout}",
        ]

        # Add SSL certificate paths if provided
        if self.sslrootcert:
            dsn_parts.append(f"sslrootcert={self.sslrootcert}")
        if self.sslcert:
            dsn_parts.append(f"sslcert={self.sslcert}")
        if self.sslkey:
            dsn_parts.append(f"sslkey={self.sslkey}")

        return " ".join(dsn_parts)

    def get_connection_kwargs(self) -> Dict[str, Any]:
        """Get connection parameters as kwargs"""
        kwargs = {
            'host': self.host,
            'port': self.port,
            'user': self.user,
            'password': self.password,
            'database': self.database,
            'connect_timeout': self.connection_timeout,
        }

        # SSL configuration
        sslmode_mapping = {
            'disable': False,
            'allow': False,
            'prefer': True,
            'require': True,
            'verify-ca': True,
            'verify-full': True
        }

        if self.sslmode in sslmode_mapping:
            kwargs['sslmode'] = self.sslmode

        if self.sslrootcert:
            kwargs['sslrootcert'] = self.sslrootcert
        if self.sslcert:
            kwargs['sslcert'] = self.sslcert
        if self.sslkey:
            kwargs['sslkey'] = self.sslkey

        return kwargs


class ConnectionPool:
    """Thread-safe PostgreSQL connection pool with monitoring and validation"""

    def __init__(self, config: Optional[DatabaseConfig] = None):
        self.config = config or DatabaseConfig()
        self._pool: Optional[pool.ThreadedConnectionPool] = None
        self._lock = threading.Lock()
        self._stats = {
            'total_connections': 0,
            'active_connections': 0,
            'errors': 0,
            'queries_executed': 0,
            'transactions_executed': 0,
            'pool_exhausted_count': 0,
            'last_error': None,
            'last_error_time': None
        }
        self._initialized = False

    def initialize(self):
        """Initialize the connection pool"""
        if self._initialized:
            logger.warning("Connection pool already initialized")
            return

        try:
            with self._lock:
                logger.info(f"Initializing connection pool (min={self.config.min_connections}, max={self.config.max_connections})")

                self._pool = pool.ThreadedConnectionPool(
                    minconn=self.config.min_connections,
                    maxconn=self.config.max_connections,
                    **self.config.get_connection_kwargs()
                )

                self._initialized = True
                logger.info("Connection pool initialized successfully")

                # Validate pool by getting and returning a connection
                self._validate_pool()

        except Exception as e:
            logger.error(f"Failed to initialize connection pool: {e}")
            self._record_error(e)
            raise DatabaseConnectionError(f"Failed to initialize connection pool: {e}")

    def _validate_pool(self):
        """Validate the connection pool by testing a connection"""
        try:
            conn = self._pool.getconn()
            if conn:
                # Test the connection
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
                self._pool.putconn(conn)
                logger.info("Connection pool validation successful")
        except Exception as e:
            logger.error(f"Connection pool validation failed: {e}")
            raise

    def get_connection(self, read_only: bool = False) -> connection:
        """
        Get a connection from the pool

        Args:
            read_only: If True, set connection to read-only mode

        Returns:
            psycopg2 connection object

        Raises:
            DatabaseConnectionError: If unable to get connection
        """
        if not self._initialized:
            self.initialize()

        try:
            conn = self._pool.getconn()

            if conn.closed:
                logger.warning("Got closed connection from pool, reconnecting")
                self._pool.putconn(conn, close=True)
                conn = self._pool.getconn()

            # Configure connection
            self._configure_connection(conn, read_only)

            # Validate connection before returning
            if not self._validate_connection(conn):
                logger.warning("Connection validation failed, getting new connection")
                self._pool.putconn(conn, close=True)
                conn = self._pool.getconn()
                self._configure_connection(conn, read_only)

            with self._lock:
                self._stats['total_connections'] += 1
                self._stats['active_connections'] += 1

            return conn

        except pool.PoolError as e:
            logger.error(f"Pool exhausted: {e}")
            with self._lock:
                self._stats['pool_exhausted_count'] += 1
            self._record_error(e)
            raise DatabaseConnectionError(f"Connection pool exhausted: {e}")
        except Exception as e:
            logger.error(f"Failed to get connection: {e}")
            self._record_error(e)
            raise DatabaseConnectionError(f"Failed to get connection: {e}")

    def _configure_connection(self, conn: connection, read_only: bool):
        """Configure connection with timeouts and settings"""
        try:
            with conn.cursor() as cur:
                # Set statement timeout
                cur.execute(f"SET statement_timeout = {self.config.statement_timeout}")

                # Set idle in transaction timeout
                cur.execute(f"SET idle_in_transaction_session_timeout = {self.config.idle_in_transaction_timeout}")

                # Set read-only mode if requested
                if read_only:
                    cur.execute("SET TRANSACTION READ ONLY")

                # Set application name for monitoring
                cur.execute("SET application_name = 'codecheck-api'")

            conn.commit()
        except Exception as e:
            logger.warning(f"Failed to configure connection: {e}")
            # Non-critical, continue anyway

    def _validate_connection(self, conn: connection) -> bool:
        """Validate that a connection is alive and working"""
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
                return True
        except Exception as e:
            logger.warning(f"Connection validation failed: {e}")
            return False

    def return_connection(self, conn: connection, close: bool = False):
        """
        Return a connection to the pool

        Args:
            conn: Connection to return
            close: If True, close the connection instead of returning to pool
        """
        if not conn:
            return

        try:
            # Rollback any uncommitted transactions
            if not conn.closed:
                conn.rollback()

            self._pool.putconn(conn, close=close)

            with self._lock:
                self._stats['active_connections'] = max(0, self._stats['active_connections'] - 1)

        except Exception as e:
            logger.error(f"Failed to return connection: {e}")
            # Try to close the connection directly
            try:
                conn.close()
            except:
                pass

    def _record_error(self, error: Exception):
        """Record error in statistics"""
        with self._lock:
            self._stats['errors'] += 1
            self._stats['last_error'] = str(error)
            self._stats['last_error_time'] = datetime.now()

    def get_stats(self) -> Dict[str, Any]:
        """Get connection pool statistics"""
        with self._lock:
            return {
                **self._stats,
                'pool_size': len(self._pool._used) + len(self._pool._pool) if self._pool else 0,
                'available_connections': len(self._pool._pool) if self._pool else 0,
                'used_connections': len(self._pool._used) if self._pool else 0,
                'min_connections': self.config.min_connections,
                'max_connections': self.config.max_connections,
            }

    def health_check(self) -> Dict[str, Any]:
        """Perform health check on the connection pool"""
        try:
            conn = self.get_connection()

            with conn.cursor() as cur:
                # Check database connection
                cur.execute("SELECT version()")
                db_version = cur.fetchone()[0]

                # Check database is accepting connections
                cur.execute("SELECT pg_is_in_recovery()")
                is_replica = cur.fetchone()[0]

                # Get current timestamp
                cur.execute("SELECT NOW()")
                db_time = cur.fetchone()[0]

            self.return_connection(conn)

            return {
                'status': 'healthy',
                'database_version': db_version,
                'is_replica': is_replica,
                'database_time': db_time.isoformat() if db_time else None,
                'pool_stats': self.get_stats()
            }

        except Exception as e:
            logger.error(f"Health check failed: {e}")
            return {
                'status': 'unhealthy',
                'error': str(e),
                'pool_stats': self.get_stats()
            }

    def close_all(self):
        """Close all connections and shutdown the pool"""
        if not self._initialized or not self._pool:
            return

        try:
            with self._lock:
                logger.info("Closing all database connections")
                self._pool.closeall()
                self._initialized = False
                self._stats['active_connections'] = 0
                logger.info("All database connections closed")
        except Exception as e:
            logger.error(f"Error closing connection pool: {e}")


# Global connection pool instance
_connection_pool: Optional[ConnectionPool] = None


def get_connection_pool() -> ConnectionPool:
    """Get or create the global connection pool"""
    global _connection_pool

    if _connection_pool is None:
        _connection_pool = ConnectionPool()
        _connection_pool.initialize()

    return _connection_pool


@contextmanager
def get_db(read_only: bool = False, cursor_factory=RealDictCursor):
    """
    Context manager to get a database connection and cursor

    Usage:
        with get_db() as cur:
            cur.execute("SELECT * FROM table")
            results = cur.fetchall()

    Args:
        read_only: If True, use read-only connection
        cursor_factory: Cursor factory class (default: RealDictCursor)

    Yields:
        Database cursor
    """
    pool = get_connection_pool()
    conn = None

    try:
        conn = pool.get_connection(read_only=read_only)
        cursor = conn.cursor(cursor_factory=cursor_factory)

        try:
            yield cursor
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Database operation failed: {e}")
            raise
        finally:
            cursor.close()

    finally:
        if conn:
            pool.return_connection(conn)


def execute_query(
    query: str,
    params: Optional[Union[Tuple, Dict]] = None,
    read_only: bool = True,
    cursor_factory=RealDictCursor
) -> List[Dict[str, Any]]:
    """
    Execute a SELECT query and return results

    Args:
        query: SQL query string
        params: Query parameters (tuple or dict)
        read_only: If True, use read-only connection
        cursor_factory: Cursor factory class

    Returns:
        List of result rows as dictionaries

    Raises:
        DatabaseQueryError: If query execution fails
    """
    pool = get_connection_pool()

    try:
        with get_db(read_only=read_only, cursor_factory=cursor_factory) as cur:
            cur.execute(query, params)
            results = cur.fetchall()

            with pool._lock:
                pool._stats['queries_executed'] += 1

            return results

    except Exception as e:
        logger.error(f"Query execution failed: {e}")
        logger.debug(f"Query: {query}, Params: {params}")
        raise DatabaseQueryError(f"Query execution failed: {e}")


def execute_transaction(
    operations: List[Tuple[str, Optional[Union[Tuple, Dict]]]],
    read_only: bool = False
) -> List[List[Dict[str, Any]]]:
    """
    Execute multiple queries in a single transaction

    Args:
        operations: List of (query, params) tuples
        read_only: If True, use read-only connection

    Returns:
        List of results for each query

    Raises:
        DatabaseTransactionError: If transaction fails
    """
    pool = get_connection_pool()
    conn = None
    results = []

    try:
        conn = pool.get_connection(read_only=read_only)
        cursor = conn.cursor(cursor_factory=RealDictCursor)

        try:
            for query, params in operations:
                cursor.execute(query, params)

                # Fetch results if it's a SELECT query
                if query.strip().upper().startswith('SELECT'):
                    results.append(cursor.fetchall())
                else:
                    results.append([])

            conn.commit()

            with pool._lock:
                pool._stats['transactions_executed'] += 1
                pool._stats['queries_executed'] += len(operations)

            return results

        except Exception as e:
            conn.rollback()
            logger.error(f"Transaction failed: {e}")
            raise DatabaseTransactionError(f"Transaction failed: {e}")
        finally:
            cursor.close()

    finally:
        if conn:
            pool.return_connection(conn)


def get_connection_pool_stats() -> Dict[str, Any]:
    """
    Get connection pool statistics

    Returns:
        Dictionary with pool statistics
    """
    try:
        pool = get_connection_pool()
        return pool.get_stats()
    except Exception as e:
        logger.error(f"Failed to get pool stats: {e}")
        return {'error': str(e)}


def database_health_check() -> Dict[str, Any]:
    """
    Perform comprehensive database health check

    Returns:
        Dictionary with health check results
    """
    try:
        pool = get_connection_pool()
        return pool.health_check()
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return {
            'status': 'unhealthy',
            'error': str(e)
        }


def shutdown_database():
    """Gracefully shutdown the database connection pool"""
    global _connection_pool

    if _connection_pool:
        logger.info("Shutting down database connection pool")
        _connection_pool.close_all()
        _connection_pool = None
        logger.info("Database connection pool shutdown complete")


# Custom exceptions
class DatabaseConnectionError(Exception):
    """Raised when database connection fails"""
    pass


class DatabaseQueryError(Exception):
    """Raised when query execution fails"""
    pass


class DatabaseTransactionError(Exception):
    """Raised when transaction fails"""
    pass


# Export public API
__all__ = [
    'get_db',
    'execute_query',
    'execute_transaction',
    'get_connection_pool_stats',
    'database_health_check',
    'shutdown_database',
    'DatabaseConnectionError',
    'DatabaseQueryError',
    'DatabaseTransactionError',
    'DatabaseConfig',
    'ConnectionPool',
]
