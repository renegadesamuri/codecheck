# Database Connection Pool - Quick Start Guide

## Installation

No additional dependencies needed! Already included in `requirements.txt`:
- `psycopg2-binary==2.9.9`

## Setup

### 1. Configure Environment

Create or update `.env` file:
```bash
# Simple setup
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=codecheck

# Or use DATABASE_URL
DATABASE_URL=postgresql://user:pass@host:5432/database
```

### 2. Import the Module

```python
from database import get_db, execute_query, database_health_check, shutdown_database
```

### 3. Start Using!

```python
# Simple query
results = execute_query(
    "SELECT * FROM jurisdiction WHERE type = %s",
    params=('city',),
    read_only=True
)

# Context manager for more control
with get_db() as cur:
    cur.execute("SELECT * FROM table WHERE id = %s", (id,))
    result = cur.fetchone()
```

## Common Patterns

### Read a Single Record
```python
with get_db(read_only=True) as cur:
    cur.execute("SELECT * FROM jurisdiction WHERE id = %s", (jurisdiction_id,))
    jurisdiction = cur.fetchone()
    return jurisdiction
```

### Read Multiple Records
```python
results = execute_query(
    "SELECT * FROM rule WHERE code_family = %s",
    params=('IBC',),
    read_only=True
)
return results
```

### Insert Data
```python
with get_db(read_only=False) as cur:
    cur.execute(
        "INSERT INTO jurisdiction (id, name, type) VALUES (%s, %s, %s)",
        (id, name, type)
    )
    # Automatically committed
```

### Update Data
```python
with get_db(read_only=False) as cur:
    cur.execute(
        "UPDATE rule SET confidence = %s WHERE id = %s",
        (new_confidence, rule_id)
    )
```

### Transaction (Multiple Operations)
```python
with get_db(read_only=False) as cur:
    # All or nothing - automatic rollback on error
    cur.execute("INSERT INTO audit_log (...) VALUES (...)", (...))
    cur.execute("UPDATE stats SET count = count + 1 WHERE ...", (...))
    cur.execute("INSERT INTO notification (...) VALUES (...)", (...))
    # Automatically committed
```

### FastAPI Endpoint
```python
from fastapi import FastAPI, HTTPException
from database import execute_query, DatabaseQueryError

app = FastAPI()

@app.get("/jurisdictions")
async def list_jurisdictions():
    try:
        results = execute_query(
            "SELECT * FROM jurisdiction ORDER BY name",
            read_only=True
        )
        return {"jurisdictions": results}
    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=str(e))
```

### Health Check Endpoint
```python
@app.get("/health")
async def health():
    health = database_health_check()
    return {"status": health['status']}
```

### Application Lifecycle
```python
@app.on_event("startup")
async def startup():
    health = database_health_check()
    print(f"Database: {health['status']}")

@app.on_event("shutdown")
async def shutdown():
    shutdown_database()
```

## Key Features

### ✓ Automatic Connection Pooling
No need to manage connections manually - the pool handles everything.

### ✓ Transaction Safety
Automatic commit on success, rollback on error.

### ✓ Resource Cleanup
Context managers ensure connections are always returned to the pool.

### ✓ Error Handling
Clear exceptions for different failure types.

### ✓ Read-Only Connections
Optimize read queries and enable replica routing.

### ✓ Monitoring
Built-in statistics and health checks.

## Monitoring

### Check Pool Status
```python
from database import get_connection_pool_stats

stats = get_connection_pool_stats()
print(f"Active: {stats['active_connections']}/{stats['max_connections']}")
print(f"Queries: {stats['queries_executed']}")
print(f"Errors: {stats['errors']}")
```

### Health Check
```python
from database import database_health_check

health = database_health_check()
if health['status'] != 'healthy':
    print(f"Database issue: {health.get('error')}")
```

## Configuration Tips

### Development
```bash
DB_POOL_MIN=2
DB_POOL_MAX=5
DB_TIMEOUT=30
```

### Production
```bash
DB_POOL_MIN=5
DB_POOL_MAX=20
DB_TIMEOUT=10
DB_SSLMODE=require
```

### High Traffic
```bash
DB_POOL_MIN=10
DB_POOL_MAX=50
DB_STATEMENT_TIMEOUT=5000
```

## Common Issues

### "Connection pool exhausted"
**Solution:** Increase `DB_POOL_MAX` or check for connection leaks.

### "Connection refused"
**Solution:** Check `DB_HOST`, `DB_PORT`, and database is running.

### "SSL connection failed"
**Solution:** Set `DB_SSLMODE=prefer` or configure SSL certificates.

### Slow queries
**Solution:** Add indexes, optimize queries, or increase timeouts.

## Testing

### Quick Test
```python
from database import database_health_check

health = database_health_check()
print(health)
```

### Run Test Suite
```bash
python test_database.py
```

## Migration Checklist

- [ ] Replace `get_db_connection()` with `get_db()` context manager
- [ ] Replace `execute_query()` calls to use connection pool version
- [ ] Add `@app.on_event("startup")` for health check
- [ ] Add `@app.on_event("shutdown")` for cleanup
- [ ] Update environment variables
- [ ] Test connection pooling
- [ ] Monitor pool statistics
- [ ] Update error handling to use new exceptions

## Next Steps

1. **Read the full documentation**: `DATABASE_POOL_README.md`
2. **Review integration example**: `main_with_pool.py`
3. **Run tests**: `python test_database.py`
4. **Update your code**: Replace direct connections with pool
5. **Monitor in production**: Check pool statistics regularly

## Support

For detailed documentation, see `DATABASE_POOL_README.md`.
For usage examples, see `test_database.py` and `main_with_pool.py`.
