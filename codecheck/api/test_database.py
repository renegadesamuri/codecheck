"""
Test suite for database connection pool
Demonstrates usage patterns and validates functionality
"""

import unittest
import os
import time
from datetime import datetime
from unittest.mock import patch, MagicMock

from database import (
    DatabaseConfig,
    ConnectionPool,
    get_db,
    execute_query,
    execute_transaction,
    get_connection_pool_stats,
    database_health_check,
    shutdown_database,
    DatabaseConnectionError,
    DatabaseQueryError,
    DatabaseTransactionError
)


class TestDatabaseConfig(unittest.TestCase):
    """Test DatabaseConfig class"""

    def setUp(self):
        # Save original env vars
        self.original_env = os.environ.copy()

    def tearDown(self):
        # Restore original env vars
        os.environ.clear()
        os.environ.update(self.original_env)

    def test_config_from_individual_vars(self):
        """Test configuration from individual environment variables"""
        os.environ.update({
            'DB_HOST': 'testhost',
            'DB_PORT': '5433',
            'DB_USER': 'testuser',
            'DB_PASSWORD': 'testpass',
            'DB_NAME': 'testdb',
            'DB_SSLMODE': 'require'
        })

        config = DatabaseConfig()

        self.assertEqual(config.host, 'testhost')
        self.assertEqual(config.port, 5433)
        self.assertEqual(config.user, 'testuser')
        self.assertEqual(config.password, 'testpass')
        self.assertEqual(config.database, 'testdb')
        self.assertEqual(config.sslmode, 'require')

    def test_config_from_database_url(self):
        """Test configuration from DATABASE_URL"""
        os.environ['DATABASE_URL'] = 'postgresql://user:pass@host.com:5433/mydb?sslmode=require'

        config = DatabaseConfig()

        self.assertEqual(config.host, 'host.com')
        self.assertEqual(config.port, 5433)
        self.assertEqual(config.user, 'user')
        self.assertEqual(config.password, 'pass')
        self.assertEqual(config.database, 'mydb')
        self.assertEqual(config.sslmode, 'require')

    def test_config_pool_settings(self):
        """Test pool configuration settings"""
        os.environ.update({
            'DB_POOL_MIN': '5',
            'DB_POOL_MAX': '20',
            'DB_TIMEOUT': '60',
            'DB_STATEMENT_TIMEOUT': '45000'
        })

        config = DatabaseConfig()

        self.assertEqual(config.min_connections, 5)
        self.assertEqual(config.max_connections, 20)
        self.assertEqual(config.connection_timeout, 60)
        self.assertEqual(config.statement_timeout, 45000)

    def test_config_defaults(self):
        """Test default configuration values"""
        # Clear all DB-related env vars
        for key in list(os.environ.keys()):
            if key.startswith('DB_') or key == 'DATABASE_URL':
                del os.environ[key]

        config = DatabaseConfig()

        self.assertEqual(config.host, 'localhost')
        self.assertEqual(config.port, 5432)
        self.assertEqual(config.user, 'postgres')
        self.assertEqual(config.database, 'codecheck')
        self.assertEqual(config.min_connections, 2)
        self.assertEqual(config.max_connections, 10)


class TestConnectionPool(unittest.TestCase):
    """Test ConnectionPool class"""

    @patch('database.pool.ThreadedConnectionPool')
    def test_pool_initialization(self, mock_pool):
        """Test connection pool initialization"""
        config = DatabaseConfig()
        conn_pool = ConnectionPool(config)

        self.assertFalse(conn_pool._initialized)

        conn_pool.initialize()

        self.assertTrue(conn_pool._initialized)
        mock_pool.assert_called_once()

    def test_pool_stats_initialization(self):
        """Test pool statistics are initialized correctly"""
        config = DatabaseConfig()
        conn_pool = ConnectionPool(config)

        stats = conn_pool.get_stats()

        self.assertEqual(stats['total_connections'], 0)
        self.assertEqual(stats['active_connections'], 0)
        self.assertEqual(stats['errors'], 0)
        self.assertEqual(stats['queries_executed'], 0)
        self.assertEqual(stats['transactions_executed'], 0)


class TestDatabaseHelpers(unittest.TestCase):
    """Test database helper functions"""

    def test_get_connection_pool_stats(self):
        """Test getting connection pool statistics"""
        stats = get_connection_pool_stats()

        self.assertIsInstance(stats, dict)
        self.assertIn('total_connections', stats)
        self.assertIn('active_connections', stats)
        self.assertIn('queries_executed', stats)

    def test_database_health_check(self):
        """Test database health check"""
        health = database_health_check()

        self.assertIsInstance(health, dict)
        self.assertIn('status', health)


class TestUsageExamples(unittest.TestCase):
    """Example usage patterns for the database module"""

    def example_simple_query(self):
        """Example: Execute a simple SELECT query"""
        try:
            # Simple query with context manager
            with get_db() as cur:
                cur.execute("SELECT * FROM jurisdiction WHERE type = %s", ('city',))
                results = cur.fetchall()

                for row in results:
                    print(f"Jurisdiction: {row['name']}")

        except Exception as e:
            print(f"Query failed: {e}")

    def example_execute_query_helper(self):
        """Example: Use execute_query helper"""
        try:
            # Using the helper function
            results = execute_query(
                "SELECT * FROM jurisdiction WHERE type = %s",
                params=('city',),
                read_only=True
            )

            print(f"Found {len(results)} jurisdictions")

        except DatabaseQueryError as e:
            print(f"Query error: {e}")

    def example_transaction(self):
        """Example: Execute multiple queries in a transaction"""
        try:
            operations = [
                ("INSERT INTO audit_log (action, timestamp) VALUES (%s, %s)", ('query', datetime.now())),
                ("SELECT * FROM jurisdiction WHERE id = %s", ('test-id',)),
                ("UPDATE stats SET query_count = query_count + 1 WHERE date = %s", (datetime.now().date(),))
            ]

            results = execute_transaction(operations, read_only=False)

            print(f"Transaction completed: {len(results)} operations")

        except DatabaseTransactionError as e:
            print(f"Transaction failed: {e}")

    def example_read_only_query(self):
        """Example: Execute read-only query for replica"""
        try:
            # Read-only query that can be routed to replica
            results = execute_query(
                "SELECT COUNT(*) as total FROM rule WHERE validation_status = %s",
                params=('validated',),
                read_only=True
            )

            print(f"Total validated rules: {results[0]['total']}")

        except DatabaseQueryError as e:
            print(f"Read-only query failed: {e}")

    def example_monitoring(self):
        """Example: Monitor connection pool"""
        # Get pool statistics
        stats = get_connection_pool_stats()
        print(f"Active connections: {stats['active_connections']}/{stats['max_connections']}")
        print(f"Queries executed: {stats['queries_executed']}")
        print(f"Errors: {stats['errors']}")

        # Perform health check
        health = database_health_check()
        if health['status'] == 'healthy':
            print("Database is healthy")
            print(f"Database version: {health.get('database_version')}")
        else:
            print(f"Database unhealthy: {health.get('error')}")

    def example_complex_transaction(self):
        """Example: Complex transaction with multiple operations"""
        try:
            with get_db(read_only=False) as cur:
                # Start transaction (automatic with context manager)

                # Insert new jurisdiction
                cur.execute("""
                    INSERT INTO jurisdiction (id, name, type, fips_code)
                    VALUES (%s, %s, %s, %s)
                    RETURNING id
                """, ('test-id', 'Test City', 'city', '12345'))

                jurisdiction_id = cur.fetchone()['id']

                # Insert code adoptions for the jurisdiction
                cur.execute("""
                    INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from)
                    VALUES (%s, %s, %s, %s)
                """, (jurisdiction_id, 'IBC', '2021', datetime.now().date()))

                cur.execute("""
                    INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from)
                    VALUES (%s, %s, %s, %s)
                """, (jurisdiction_id, 'IRC', '2021', datetime.now().date()))

                # Log the action
                cur.execute("""
                    INSERT INTO audit_log (action, entity_type, entity_id, timestamp)
                    VALUES (%s, %s, %s, %s)
                """, ('create_jurisdiction', 'jurisdiction', jurisdiction_id, datetime.now()))

                print(f"Created jurisdiction: {jurisdiction_id}")

                # Transaction commits automatically on successful exit

        except Exception as e:
            # Transaction rolls back automatically on exception
            print(f"Transaction failed: {e}")

    def example_connection_cleanup(self):
        """Example: Proper cleanup and shutdown"""
        # Get some statistics before shutdown
        stats = get_connection_pool_stats()
        print(f"Connections before shutdown: {stats['pool_size']}")

        # Graceful shutdown
        shutdown_database()

        print("Database connection pool closed")


def integration_test_example():
    """Example: Integration test with real database"""

    print("=== Database Connection Pool Integration Test ===\n")

    # Test 1: Health Check
    print("1. Health Check:")
    health = database_health_check()
    print(f"   Status: {health['status']}")
    if health['status'] == 'healthy':
        print(f"   Database Time: {health['database_time']}")
        print(f"   Is Replica: {health['is_replica']}")

    # Test 2: Simple Query
    print("\n2. Simple Query:")
    try:
        results = execute_query(
            "SELECT COUNT(*) as count FROM jurisdiction",
            read_only=True
        )
        print(f"   Total jurisdictions: {results[0]['count']}")
    except Exception as e:
        print(f"   Error: {e}")

    # Test 3: Connection Pool Stats
    print("\n3. Connection Pool Statistics:")
    stats = get_connection_pool_stats()
    print(f"   Pool Size: {stats['pool_size']}")
    print(f"   Available: {stats['available_connections']}")
    print(f"   Active: {stats['active_connections']}")
    print(f"   Total Queries: {stats['queries_executed']}")
    print(f"   Total Errors: {stats['errors']}")

    # Test 4: Multiple Concurrent Queries
    print("\n4. Concurrent Query Test:")
    start_time = time.time()
    for i in range(10):
        try:
            execute_query("SELECT 1", read_only=True)
        except Exception as e:
            print(f"   Query {i} failed: {e}")
    elapsed = time.time() - start_time
    print(f"   Completed 10 queries in {elapsed:.3f}s")

    # Test 5: Transaction Test
    print("\n5. Transaction Test:")
    try:
        operations = [
            ("SELECT NOW()", None),
            ("SELECT version()", None),
        ]
        results = execute_transaction(operations, read_only=True)
        print(f"   Transaction completed: {len(results)} operations")
    except Exception as e:
        print(f"   Transaction failed: {e}")

    # Final Stats
    print("\n6. Final Statistics:")
    final_stats = get_connection_pool_stats()
    print(f"   Total Queries Executed: {final_stats['queries_executed']}")
    print(f"   Total Transactions: {final_stats['transactions_executed']}")
    print(f"   Pool Exhausted Count: {final_stats['pool_exhausted_count']}")
    print(f"   Total Errors: {final_stats['errors']}")

    # Cleanup
    print("\n7. Cleanup:")
    shutdown_database()
    print("   Database connection pool shutdown complete")


if __name__ == '__main__':
    # Run unit tests
    print("Running unit tests...\n")
    unittest.main(argv=[''], exit=False, verbosity=2)

    print("\n" + "="*60 + "\n")

    # Run integration test if database is available
    try:
        integration_test_example()
    except Exception as e:
        print(f"Integration test skipped (database not available): {e}")
