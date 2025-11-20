# Connection Pool Integration Checklist

## Pre-Integration

### Review Documentation
- [ ] Read `QUICK_START.md` for basic usage
- [ ] Review `DATABASE_POOL_README.md` for comprehensive guide
- [ ] Check `BEFORE_AFTER_COMPARISON.md` for examples
- [ ] Review `IMPLEMENTATION_SUMMARY.md` for overview

### Environment Setup
- [ ] Verify `.env` file exists
- [ ] Confirm database connection variables are set
  - [ ] `DB_HOST` or `DATABASE_URL`
  - [ ] `DB_PORT`
  - [ ] `DB_USER`
  - [ ] `DB_PASSWORD`
  - [ ] `DB_NAME`
- [ ] Configure pool settings (optional)
  - [ ] `DB_POOL_MIN` (default: 2)
  - [ ] `DB_POOL_MAX` (default: 10)
  - [ ] `DB_TIMEOUT` (default: 30)
- [ ] Configure SSL for production (if needed)
  - [ ] `DB_SSLMODE`
  - [ ] `DB_SSLROOTCERT` (if required)

### Testing Preparation
- [ ] Backup your current `main.py` file
  ```bash
  cp main.py main.py.backup
  ```
- [ ] Ensure database is running and accessible
- [ ] Have a test environment available

## Integration Steps

### 1. Test the New Module
```bash
# Test 1: Import the module
python3 -c "from database import get_db; print('✓ Import successful')"

# Test 2: Run health check (requires DB connection)
python3 -c "from database import database_health_check; print(database_health_check())"

# Test 3: Run unit tests
python3 -m pytest test_database.py -v

# Test 4: Run integration tests
python3 test_database.py
```

**Checklist:**
- [ ] Module imports without errors
- [ ] Health check returns 'healthy' status
- [ ] Unit tests pass
- [ ] Integration tests pass (if DB available)

### 2. Run Migration Helper
```bash
# Analyze current code
python3 migrate_to_pool.py main.py > migration_report.txt

# Review the report
cat migration_report.txt
```

**Checklist:**
- [ ] Review patterns found in your code
- [ ] Note number of places to update
- [ ] Save migration report for reference

### 3. Update Imports

Add to top of `main.py`:
```python
from database import (
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
```

**Checklist:**
- [ ] Added new imports
- [ ] Kept existing imports (for now)
- [ ] File still imports without errors

### 4. Add Lifecycle Handlers

Add startup and shutdown handlers:
```python
@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    try:
        health = database_health_check()
        if health['status'] == 'healthy':
            print("✓ Database connection pool initialized")
            print(f"  Version: {health.get('database_version', 'Unknown')}")
        else:
            print(f"✗ Database health check failed: {health.get('error')}")
    except Exception as e:
        print(f"✗ Failed to initialize database: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup resources on shutdown"""
    print("Shutting down database connection pool...")
    shutdown_database()
    print("✓ Shutdown complete")
```

**Checklist:**
- [ ] Added startup handler
- [ ] Added shutdown handler
- [ ] Test server starts without errors
- [ ] Test server shuts down gracefully

### 5. Update Endpoints One by One

For each endpoint, update the database code:

#### Simple Query Example
**Before:**
```python
conn = get_db_connection()
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM table")
        results = cursor.fetchall()
finally:
    conn.close()
```

**After:**
```python
results = execute_query("SELECT * FROM table", read_only=True)
```

#### Complex Query Example
**Before:**
```python
conn = get_db_connection()
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM table WHERE id = %s", (id,))
        result = cursor.fetchone()
finally:
    conn.close()
```

**After:**
```python
with get_db(read_only=True) as cur:
    cur.execute("SELECT * FROM table WHERE id = %s", (id,))
    result = cur.fetchone()
```

**Update Checklist (per endpoint):**
- [ ] `/` (root/health check)
- [ ] `/resolve`
- [ ] `/codeset`
- [ ] `/rules/query`
- [ ] `/check`
- [ ] `/explain`
- [ ] `/conversation`
- [ ] `/extract-rules`
- [ ] `/jurisdictions`
- [ ] Any custom endpoints

### 6. Update Error Handling

Replace generic exception handling:
```python
# Before
except Exception as e:
    raise HTTPException(status_code=500, detail=str(e))

# After
except DatabaseQueryError as e:
    raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
except DatabaseConnectionError as e:
    raise HTTPException(status_code=503, detail="Database unavailable")
```

**Checklist:**
- [ ] Updated all error handling
- [ ] Using specific exception types
- [ ] Appropriate HTTP status codes

### 7. Remove Old Connection Code

Once all endpoints are updated:
```python
# Remove or comment out the old function
# def get_db_connection():
#     ...
```

**Checklist:**
- [ ] Old `get_db_connection()` removed or commented
- [ ] No direct `psycopg2.connect()` calls remain
- [ ] All manual `conn.close()` calls removed
- [ ] All manual `conn.commit()` calls removed (except where intentional)
- [ ] All manual `conn.rollback()` calls removed (except where intentional)

### 8. Add Monitoring Endpoints

Add health and stats endpoints:
```python
@app.get("/health")
async def health_check():
    """Comprehensive health check"""
    health = database_health_check()
    stats = get_connection_pool_stats()
    return {
        "status": "healthy" if health['status'] == 'healthy' else "degraded",
        "timestamp": datetime.now().isoformat(),
        "database": health,
        "connection_pool": stats
    }

@app.get("/stats")
async def connection_stats():
    """Connection pool statistics"""
    return {
        "pool": get_connection_pool_stats(),
        "timestamp": datetime.now().isoformat()
    }
```

**Checklist:**
- [ ] Added `/health` endpoint
- [ ] Added `/stats` endpoint (optional, for admin)
- [ ] Endpoints return correct data

## Testing

### Local Testing

#### 1. Start the Server
```bash
cd /Users/raulherrera/autonomous-learning/codecheck/api
python3 main.py
```

**Checklist:**
- [ ] Server starts without errors
- [ ] Health check message appears on startup
- [ ] No connection errors in logs

#### 2. Test Health Endpoint
```bash
curl http://localhost:8000/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "database": {
    "status": "healthy",
    "database_version": "PostgreSQL ...",
    "is_replica": false
  },
  "connection_pool": {
    "pool_size": 2,
    "active_connections": 0,
    "available_connections": 2
  }
}
```

**Checklist:**
- [ ] `/health` returns 200 OK
- [ ] Database status is "healthy"
- [ ] Pool statistics are present

#### 3. Test Each Endpoint

Test each endpoint one by one:
```bash
# Test root
curl http://localhost:8000/

# Test jurisdictions
curl http://localhost:8000/jurisdictions

# Test resolve
curl -X POST http://localhost:8000/resolve \
  -H "Content-Type: application/json" \
  -d '{"latitude": 37.7749, "longitude": -122.4194}'

# Add tests for other endpoints...
```

**Checklist:**
- [ ] All endpoints respond correctly
- [ ] No 500 errors
- [ ] Response format unchanged
- [ ] Performance is good

#### 4. Monitor Pool Statistics

Watch pool statistics during testing:
```bash
# In another terminal
watch -n 2 'curl -s http://localhost:8000/stats | python3 -m json.tool'
```

**Observe:**
- [ ] Active connections increase during requests
- [ ] Connections return to pool after requests
- [ ] No connection leaks (active count returns to 0)
- [ ] Queries executed counter increases

#### 5. Load Testing (Optional)
```bash
# Simple load test
for i in {1..50}; do
  curl -s http://localhost:8000/jurisdictions > /dev/null &
done
wait

# Check stats after
curl http://localhost:8000/stats
```

**Checklist:**
- [ ] Server handles concurrent requests
- [ ] No pool exhaustion
- [ ] No errors under load
- [ ] Performance is good

#### 6. Error Handling Test

Test error scenarios:
```bash
# Test with invalid data
curl -X POST http://localhost:8000/resolve \
  -H "Content-Type: application/json" \
  -d '{"latitude": 999, "longitude": 999}'

# Test with missing parameters
curl -X POST http://localhost:8000/codeset \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Checklist:**
- [ ] Errors handled gracefully
- [ ] Appropriate error messages
- [ ] Connections still returned to pool
- [ ] No connection leaks after errors

### Graceful Shutdown Test
```bash
# Start server
python3 main.py &
PID=$!

# Wait a moment
sleep 2

# Shutdown gracefully
kill -TERM $PID

# Check logs for shutdown message
```

**Checklist:**
- [ ] Shutdown message appears
- [ ] All connections closed
- [ ] No errors during shutdown

## Production Readiness

### Configuration Review
- [ ] Review pool size for expected load
  - [ ] `DB_POOL_MIN` appropriate
  - [ ] `DB_POOL_MAX` appropriate
- [ ] SSL configuration in production
  - [ ] `DB_SSLMODE=require` or higher
  - [ ] SSL certificates configured
- [ ] Timeout configuration
  - [ ] `DB_STATEMENT_TIMEOUT` appropriate
  - [ ] `DB_IDLE_TIMEOUT` appropriate

### Security Review
- [ ] Database credentials secured
- [ ] SSL/TLS enabled in production
- [ ] Connection strings not logged
- [ ] Read-only connections used where appropriate
- [ ] Statement timeouts configured

### Monitoring Setup
- [ ] Health check endpoint accessible
- [ ] Stats endpoint accessible (if used)
- [ ] Logging configured
- [ ] Alerts set up for:
  - [ ] Pool exhaustion
  - [ ] High error rate
  - [ ] Database unavailability

### Documentation
- [ ] Update deployment documentation
- [ ] Document environment variables
- [ ] Document monitoring endpoints
- [ ] Update README if needed

## Deployment

### Deployment Checklist
- [ ] Backup database (if schema changes)
- [ ] Update environment variables
- [ ] Deploy new code
- [ ] Monitor startup logs
- [ ] Verify health check
- [ ] Test critical endpoints
- [ ] Monitor for errors
- [ ] Check pool statistics
- [ ] Verify performance metrics

### Rollback Plan
If issues occur:
1. [ ] Revert to backup code
   ```bash
   cp main.py.backup main.py
   ```
2. [ ] Restart service
3. [ ] Verify service is working
4. [ ] Investigate issues
5. [ ] Fix and redeploy

## Post-Deployment

### Monitoring (First 24 Hours)
- [ ] Watch error rates
- [ ] Monitor pool statistics
- [ ] Check response times
- [ ] Review database connections
- [ ] Check for memory leaks
- [ ] Verify graceful shutdowns

### Performance Tuning
- [ ] Review pool statistics
- [ ] Adjust pool size if needed
- [ ] Tune timeouts if needed
- [ ] Optimize slow queries
- [ ] Check connection usage patterns

### Documentation
- [ ] Document any configuration changes
- [ ] Note performance improvements
- [ ] Record any issues encountered
- [ ] Update runbooks if needed

## Troubleshooting

### Common Issues

#### "Connection pool exhausted"
- [ ] Check `DB_POOL_MAX` setting
- [ ] Review endpoint code for leaks
- [ ] Check for long-running queries
- [ ] Monitor concurrent request count

#### "Connection refused"
- [ ] Verify database is running
- [ ] Check `DB_HOST` and `DB_PORT`
- [ ] Verify firewall rules
- [ ] Check network connectivity

#### Slow performance
- [ ] Check pool statistics
- [ ] Review query execution times
- [ ] Check database indexes
- [ ] Monitor database performance

#### High error rate
- [ ] Review application logs
- [ ] Check database logs
- [ ] Verify credentials
- [ ] Check SSL configuration

## Success Criteria

### Functional
- ✅ All endpoints working correctly
- ✅ No increase in error rates
- ✅ Response times similar or better
- ✅ Health check passes

### Performance
- ✅ Reduced database connections
- ✅ Better resource utilization
- ✅ Handles concurrent requests well
- ✅ No connection leaks

### Monitoring
- ✅ Health check endpoint working
- ✅ Statistics tracking operational
- ✅ Error handling improved
- ✅ Logging appropriate

### Code Quality
- ✅ Code is cleaner and simpler
- ✅ Better error handling
- ✅ Good test coverage
- ✅ Well documented

## Completion

- [ ] All tests passing
- [ ] All endpoints updated
- [ ] Monitoring in place
- [ ] Documentation updated
- [ ] Team notified
- [ ] Deployment successful
- [ ] Post-deployment monitoring complete

**Date Completed:** _____________

**Deployed By:** _____________

**Notes:**
_____________________________________________
_____________________________________________
_____________________________________________

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review `DATABASE_POOL_README.md`
3. Check application logs
4. Review database logs
5. Contact support if needed

## Resources

- **Quick Start:** `QUICK_START.md`
- **Full Documentation:** `DATABASE_POOL_README.md`
- **Comparison:** `BEFORE_AFTER_COMPARISON.md`
- **Integration Example:** `main_with_pool.py`
- **Test Suite:** `test_database.py`
- **Migration Helper:** `migrate_to_pool.py`
