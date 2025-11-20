# Database Connection Pool Documentation

## Overview

The `database.py` module provides a production-ready PostgreSQL connection pooling system with comprehensive error handling, monitoring, and security features for the CodeCheck API.

## Features

### Core Features
- **Thread-safe connection pooling** using `psycopg2.pool.ThreadedConnectionPool`
- **Automatic connection recycling** and validation
- **Connection context managers** for safe resource handling
- **Read-only and read-write connection types**
- **SSL support** for secure production deployments
- **Comprehensive error handling** with custom exceptions
- **Connection pool monitoring** and statistics
- **Query timeout configuration** to prevent long-running queries
- **Graceful shutdown** handling

### Security Features
- SSL/TLS connection support with certificate validation
- Connection validation before use
- Statement timeout protection
- Idle transaction timeout protection
- Read-only connection mode for query separation

### Performance Features
- Connection reuse through pooling
- Automatic connection recycling
- Configurable pool size (min/max connections)
- Query execution statistics
- Pool exhaustion tracking

## Configuration

### Environment Variables

#### Individual Configuration
```bash
# Database Connection
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=codecheck
DB_SSLMODE=prefer

# Connection Pool Settings
DB_POOL_MIN=2              # Minimum connections in pool
DB_POOL_MAX=10             # Maximum connections in pool
DB_TIMEOUT=30              # Connection timeout (seconds)
DB_STATEMENT_TIMEOUT=30000 # Query timeout (milliseconds)
DB_IDLE_TIMEOUT=60000      # Idle transaction timeout (milliseconds)

# SSL Certificates (optional, for production)
DB_SSLROOTCERT=/path/to/root.crt
DB_SSLCERT=/path/to/client.crt
DB_SSLKEY=/path/to/client.key
```

#### Database URL Configuration
```bash
# Alternative: Single DATABASE_URL (Heroku, etc.)
DATABASE_URL=postgresql://user:password@host:port/database?sslmode=require
```

### SSL Modes

- `disable` - No SSL
- `allow` - Try SSL, fall back to non-SSL
- `prefer` - Try SSL first (default)
- `require` - Require SSL
- `verify-ca` - Require SSL + verify CA
- `verify-full` - Require SSL + verify CA + hostname

## Usage

### Basic Query Execution

#### Simple SELECT Query
```python
from database import execute_query

# Execute a read-only query
results = execute_query(
    "SELECT * FROM jurisdiction WHERE type = %s",
    params=('city',),
    read_only=True
)

for row in results:
    print(f"Jurisdiction: {row['name']}")
```

#### Using Context Manager
```python
from database import get_db

# More control with context manager
with get_db(read_only=True) as cur:
    cur.execute("SELECT * FROM jurisdiction WHERE id = %s", (jurisdiction_id,))
    jurisdiction = cur.fetchone()

    if jurisdiction:
        print(f"Found: {jurisdiction['name']}")
```

### Transaction Handling

#### Simple Transaction
```python
from database import execute_transaction

operations = [
    ("INSERT INTO audit_log (action, timestamp) VALUES (%s, %s)",
     ('user_login', datetime.now())),

    ("UPDATE stats SET login_count = login_count + 1 WHERE date = %s",
     (datetime.now().date(),)),

    ("SELECT * FROM user WHERE id = %s",
     (user_id,))
]

results = execute_transaction(operations, read_only=False)
print(f"Transaction completed: {len(results)} operations")
```

#### Complex Transaction with Context Manager
```python
from database import get_db

with get_db(read_only=False) as cur:
    # Insert jurisdiction
    cur.execute("""
        INSERT INTO jurisdiction (id, name, type)
        VALUES (%s, %s, %s)
        RETURNING id
    """, (jurisdiction_id, name, type))

    new_id = cur.fetchone()['id']

    # Insert related code adoptions
    cur.execute("""
        INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from)
        VALUES (%s, %s, %s, %s)
    """, (new_id, 'IBC', '2021', datetime.now().date()))

    # Transaction commits automatically on successful exit
    # Rolls back automatically on exception
```

### Read-Only vs Read-Write

```python
# Read-only query (can be routed to replicas)
results = execute_query(
    "SELECT COUNT(*) as total FROM rule",
    read_only=True
)

# Read-write query
with get_db(read_only=False) as cur:
    cur.execute(
        "INSERT INTO rule (id, code_family, section_ref) VALUES (%s, %s, %s)",
        (rule_id, 'IBC', 'Section 1012')
    )
```

### Monitoring and Health Checks

#### Connection Pool Statistics
```python
from database import get_connection_pool_stats

stats = get_connection_pool_stats()
print(f"Pool size: {stats['pool_size']}")
print(f"Active connections: {stats['active_connections']}")
print(f"Available connections: {stats['available_connections']}")
print(f"Total queries executed: {stats['queries_executed']}")
print(f"Total transactions: {stats['transactions_executed']}")
print(f"Errors: {stats['errors']}")
print(f"Pool exhausted count: {stats['pool_exhausted_count']}")
```

#### Database Health Check
```python
from database import database_health_check

health = database_health_check()
if health['status'] == 'healthy':
    print("Database is healthy")
    print(f"Version: {health['database_version']}")
    print(f"Database time: {health['database_time']}")
    print(f"Is replica: {health['is_replica']}")
else:
    print(f"Database unhealthy: {health['error']}")
```

### Graceful Shutdown

```python
from database import shutdown_database

# Call on application shutdown
shutdown_database()
```

## FastAPI Integration

### Complete Integration Example

```python
from fastapi import FastAPI
from database import (
    get_db,
    execute_query,
    database_health_check,
    shutdown_database,
    get_connection_pool_stats
)

app = FastAPI()

@app.on_event("startup")
async def startup_event():
    """Initialize on startup"""
    health = database_health_check()
    if health['status'] == 'healthy':
        print("✓ Database connection pool initialized")
    else:
        print(f"✗ Database health check failed: {health.get('error')}")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup on shutdown"""
    shutdown_database()

@app.get("/health")
async def health():
    """Health check endpoint"""
    health = database_health_check()
    stats = get_connection_pool_stats()
    return {
        "database": health['status'],
        "pool": {
            "size": stats['pool_size'],
            "active": stats['active_connections']
        }
    }

@app.get("/jurisdictions")
async def list_jurisdictions():
    """Example endpoint"""
    results = execute_query(
        "SELECT * FROM jurisdiction ORDER BY name",
        read_only=True
    )
    return {"jurisdictions": results}
```

## Error Handling

### Custom Exceptions

```python
from database import (
    DatabaseConnectionError,
    DatabaseQueryError,
    DatabaseTransactionError
)

try:
    results = execute_query("SELECT * FROM table")
except DatabaseConnectionError as e:
    # Connection pool or connection failure
    print(f"Connection error: {e}")
except DatabaseQueryError as e:
    # Query execution failure
    print(f"Query error: {e}")
except DatabaseTransactionError as e:
    # Transaction failure
    print(f"Transaction error: {e}")
```

### Error Recovery

The connection pool automatically handles:
- Closed connections (reconnects automatically)
- Failed connection validation (gets new connection)
- Transaction rollback on errors
- Connection return to pool on errors

## Performance Tuning

### Pool Size Configuration

```python
# For read-heavy workloads
DB_POOL_MIN=5
DB_POOL_MAX=20

# For write-heavy workloads (fewer connections)
DB_POOL_MIN=2
DB_POOL_MAX=10

# Calculate max connections per instance:
# max_connections = (database_max_connections - reserved) / num_instances
```

### Timeout Configuration

```python
# Short timeouts for API endpoints
DB_STATEMENT_TIMEOUT=5000   # 5 seconds
DB_IDLE_TIMEOUT=10000       # 10 seconds

# Longer timeouts for background jobs
DB_STATEMENT_TIMEOUT=300000  # 5 minutes
DB_IDLE_TIMEOUT=600000       # 10 minutes
```

### Monitoring Recommendations

Monitor these metrics:
- `pool_exhausted_count` - Should be low/zero
- `errors` - Should be low/zero
- `active_connections` - Should be < max_connections
- `queries_executed` - Track query volume
- `last_error` - Monitor recent errors

### Best Practices

1. **Use read-only connections** for SELECT queries
   - Enables replica routing
   - Reduces load on primary database

2. **Keep transactions short**
   - Use context managers
   - Commit or rollback quickly

3. **Use connection pooling**
   - Don't create new connections
   - Let the pool manage connections

4. **Handle errors gracefully**
   - Catch specific exceptions
   - Log errors appropriately

5. **Monitor pool statistics**
   - Track pool exhaustion
   - Monitor error rates
   - Check connection usage

6. **Configure timeouts appropriately**
   - Prevent long-running queries
   - Set statement timeouts
   - Configure idle timeouts

7. **Use SSL in production**
   - Set `DB_SSLMODE=require` or higher
   - Use certificate validation
   - Secure connection strings

## Testing

### Unit Tests

```bash
# Run unit tests
python -m pytest test_database.py -v

# Run specific test
python -m pytest test_database.py::TestDatabaseConfig -v
```

### Integration Tests

```bash
# Run integration tests (requires database)
python test_database.py

# Example output:
# Running unit tests...
# ✓ test_config_from_individual_vars
# ✓ test_config_from_database_url
# ✓ test_pool_initialization
#
# === Database Connection Pool Integration Test ===
# 1. Health Check: healthy
# 2. Simple Query: Total jurisdictions: 42
# 3. Connection Pool Statistics: Pool Size: 2, Active: 0
```

## Troubleshooting

### Connection Pool Exhausted

**Symptom:** `DatabaseConnectionError: Connection pool exhausted`

**Solutions:**
1. Increase `DB_POOL_MAX`
2. Check for connection leaks (always use context managers)
3. Reduce query execution time
4. Scale horizontally (more instances)

### High Error Rate

**Symptom:** High `errors` count in statistics

**Solutions:**
1. Check database connectivity
2. Verify credentials
3. Check SSL configuration
4. Review query syntax
5. Check database logs

### Slow Queries

**Symptom:** Queries timing out or slow responses

**Solutions:**
1. Add database indexes
2. Optimize query structure
3. Increase `DB_STATEMENT_TIMEOUT`
4. Use connection pooling
5. Check database performance

### Connection Refused

**Symptom:** `DatabaseConnectionError: Connection refused`

**Solutions:**
1. Verify database is running
2. Check `DB_HOST` and `DB_PORT`
3. Verify firewall rules
4. Check SSL requirements
5. Verify credentials

## Migration from Old Code

### Before (Direct Connection)
```python
def get_db_connection():
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST'),
        port=os.getenv('DB_PORT'),
        user=os.getenv('DB_USER'),
        password=os.getenv('DB_PASSWORD'),
        database=os.getenv('DB_NAME')
    )
    return conn

# Usage
conn = get_db_connection()
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM table")
        results = cursor.fetchall()
finally:
    conn.close()
```

### After (Connection Pool)
```python
from database import get_db

# Usage
with get_db() as cur:
    cur.execute("SELECT * FROM table")
    results = cur.fetchall()
    # Connection automatically returned to pool
```

## Security Considerations

1. **Never log passwords or sensitive data**
2. **Use SSL in production** (`DB_SSLMODE=require`)
3. **Rotate database credentials regularly**
4. **Use least-privilege database users**
5. **Set appropriate timeouts** to prevent DoS
6. **Monitor connection patterns** for anomalies
7. **Use read-only connections** when possible
8. **Validate SSL certificates** in production

## Production Deployment

### Heroku
```bash
# Heroku automatically provides DATABASE_URL
# No additional configuration needed

# Check connection
heroku pg:info

# Monitor connections
heroku pg:ps
```

### AWS RDS
```bash
# Set environment variables
DB_HOST=your-instance.rds.amazonaws.com
DB_PORT=5432
DB_SSLMODE=require
DB_SSLROOTCERT=/path/to/rds-ca-bundle.crt
```

### Docker
```dockerfile
ENV DB_HOST=db
ENV DB_PORT=5432
ENV DB_POOL_MIN=2
ENV DB_POOL_MAX=10
```

### Kubernetes
```yaml
env:
  - name: DATABASE_URL
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: url
  - name: DB_POOL_MAX
    value: "20"
```

## Support

For issues or questions:
1. Check logs for error messages
2. Review connection pool statistics
3. Run database health check
4. Verify environment variables
5. Test database connectivity directly

## License

Part of the CodeCheck API system.
