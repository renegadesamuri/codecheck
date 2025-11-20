# Database Migrations

This directory contains database migration scripts for the CodeCheck application.

## Migration Order

Migrations must be applied in order:

1. **001_add_users_and_security.sql** - Adds users, authentication, and security tables
2. **002_add_on_demand_loading.sql** - Adds on-demand code loading infrastructure

## Applying Migrations

### Using psql

```bash
# Connect to database
psql -h localhost -U postgres -d codecheck

# Apply a migration
\i /path/to/codecheck/database/migrations/002_add_on_demand_loading.sql

# Verify
\dt  # List tables
\df  # List functions
```

### Using Python

```python
import psycopg2

conn = psycopg2.connect(
    host='localhost',
    port='5432',
    user='postgres',
    password='your-password',
    database='codecheck'
)

with open('002_add_on_demand_loading.sql', 'r') as f:
    sql = f.read()

with conn.cursor() as cursor:
    cursor.execute(sql)
    conn.commit()
```

## Migration 002: On-Demand Loading

This migration adds the infrastructure for on-demand building code loading.

### Tables Added

#### `jurisdiction_data_status`
Tracks loading status and metadata for each jurisdiction.

**Columns:**
- `jurisdiction_id` (UUID, PK) - References jurisdiction(id)
- `status` (TEXT) - 'pending', 'loading', 'complete', 'failed'
- `rules_count` (INT) - Number of rules loaded
- `last_fetch_attempt` (TIMESTAMPTZ) - Last attempt timestamp
- `last_successful_fetch` (TIMESTAMPTZ) - Last success timestamp
- `error_message` (TEXT) - Error details if failed
- `created_at` (TIMESTAMPTZ) - Creation timestamp
- `updated_at` (TIMESTAMPTZ) - Last update timestamp

**Indexes:**
- `idx_jurisdiction_data_status_status` - Quick status lookups
- `idx_jurisdiction_data_status_updated` - Sort by update time

#### `agent_jobs`
Tracks background agent jobs for code loading.

**Columns:**
- `id` (UUID, PK) - Job identifier
- `jurisdiction_id` (UUID) - References jurisdiction(id)
- `job_type` (TEXT) - Type of job ('load_codes', etc.)
- `status` (TEXT) - 'pending', 'running', 'completed', 'failed'
- `progress_percentage` (INT) - Progress 0-100%
- `progress_message` (TEXT) - Current progress message
- `result` (JSONB) - Job result data
- `error_message` (TEXT) - Error details if failed
- `started_at` (TIMESTAMPTZ) - Job start time
- `completed_at` (TIMESTAMPTZ) - Job completion time
- `created_at` (TIMESTAMPTZ) - Creation timestamp
- `updated_at` (TIMESTAMPTZ) - Last update timestamp

**Indexes:**
- `idx_agent_jobs_jurisdiction` - Lookup by jurisdiction and status
- `idx_agent_jobs_status` - Filter by status
- `idx_agent_jobs_type` - Filter by job type

### Helper Functions Added

#### `jurisdiction_has_rules(jurisdiction_id)`
Returns `TRUE` if jurisdiction has any rules loaded.

```sql
SELECT jurisdiction_has_rules('550e8400-e29b-41d4-a716-446655440001');
```

#### `get_jurisdiction_status(jurisdiction_id)`
Returns comprehensive status information for a jurisdiction.

```sql
SELECT * FROM get_jurisdiction_status('550e8400-e29b-41d4-a716-446655440001');
```

**Returns:**
- `status` - Current status
- `rules_count` - Number of rules
- `is_loading` - Loading flag
- `has_active_job` - Active job flag
- `last_error` - Last error message
- `job_progress` - Current job progress %

#### `update_jurisdiction_status(jurisdiction_id, status, rules_count, error_message)`
Creates or updates jurisdiction loading status.

```sql
SELECT update_jurisdiction_status(
    '550e8400-e29b-41d4-a716-446655440001',
    'complete',
    15,
    NULL
);
```

#### `create_agent_job(jurisdiction_id, job_type)`
Creates a new agent job or returns existing pending/running job.

```sql
SELECT create_agent_job(
    '550e8400-e29b-41d4-a716-446655440001',
    'load_codes'
);
```

#### `update_agent_job_progress(job_id, status, progress, error_message, result)`
Updates agent job status, progress, and metadata.

```sql
SELECT update_agent_job_progress(
    'uuid-1234',
    'running',
    50,
    NULL,
    NULL
);
```

#### `cleanup_old_agent_jobs(days_to_keep)`
Deletes completed/failed jobs older than specified days (default 7).

```sql
SELECT cleanup_old_agent_jobs(7);
```

### Data Initialization

The migration automatically:
1. Initializes status for all existing jurisdictions
2. Sets status to 'complete' if rules exist, otherwise 'pending'
3. Updates rules_count for all jurisdictions

### Rollback

To rollback this migration:

```sql
-- Drop helper functions
DROP FUNCTION IF EXISTS cleanup_old_agent_jobs(INT);
DROP FUNCTION IF EXISTS update_agent_job_progress(UUID, TEXT, INT, TEXT, JSONB);
DROP FUNCTION IF EXISTS create_agent_job(UUID, TEXT);
DROP FUNCTION IF EXISTS update_jurisdiction_status(UUID, TEXT, INT, TEXT);
DROP FUNCTION IF EXISTS get_jurisdiction_status(UUID);
DROP FUNCTION IF EXISTS jurisdiction_has_rules(UUID);

-- Drop tables
DROP TABLE IF EXISTS agent_jobs CASCADE;
DROP TABLE IF EXISTS jurisdiction_data_status CASCADE;
```

## Testing After Migration

### Verify Tables

```sql
-- Check tables exist
\dt jurisdiction_data_status
\dt agent_jobs

-- Check data
SELECT * FROM jurisdiction_data_status;
SELECT * FROM agent_jobs;
```

### Verify Functions

```sql
-- List functions
\df jurisdiction_has_rules
\df get_jurisdiction_status
\df update_jurisdiction_status
\df create_agent_job
\df update_agent_job_progress
\df cleanup_old_agent_jobs

-- Test functions
SELECT jurisdiction_has_rules('550e8400-e29b-41d4-a716-446655440001');
SELECT * FROM get_jurisdiction_status('550e8400-e29b-41d4-a716-446655440001');
```

### Verify Triggers

```sql
-- Test updated_at trigger
UPDATE jurisdiction_data_status
SET status = 'loading'
WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001';

-- Check updated_at changed
SELECT jurisdiction_id, status, updated_at
FROM jurisdiction_data_status
WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001';
```

### Test Workflow

```sql
-- 1. Create a job
SELECT create_agent_job('550e8400-e29b-41d4-a716-446655440001', 'load_codes');
-- Returns: job_id

-- 2. Update status to loading
SELECT update_jurisdiction_status('550e8400-e29b-41d4-a716-446655440001', 'loading', NULL, NULL);

-- 3. Update job progress
SELECT update_agent_job_progress('your-job-id', 'running', 50, NULL, NULL);

-- 4. Complete job
SELECT update_agent_job_progress(
    'your-job-id',
    'completed',
    100,
    NULL,
    '{"rules_count": 15, "sources_found": 2}'::jsonb
);

-- 5. Update jurisdiction to complete
SELECT update_jurisdiction_status('550e8400-e29b-41d4-a716-446655440001', 'complete', 15, NULL);

-- 6. Verify status
SELECT * FROM get_jurisdiction_status('550e8400-e29b-41d4-a716-446655440001');
```

## Troubleshooting

### Issue: Migration fails with "table already exists"

**Solution**: The migration uses `IF NOT EXISTS` clauses, but if you're re-running:
```sql
-- Drop existing tables first
DROP TABLE IF EXISTS agent_jobs CASCADE;
DROP TABLE IF EXISTS jurisdiction_data_status CASCADE;
```

### Issue: Function creation fails

**Solution**: Drop existing functions first:
```sql
DROP FUNCTION IF EXISTS function_name(arg_types);
```

### Issue: Trigger not working

**Solution**: Verify the base trigger function exists:
```sql
SELECT * FROM pg_proc WHERE proname = 'update_updated_at_column';
```

If missing, it should be in the base schema.sql.

## Maintenance

### Regular Cleanup

Run cleanup periodically to prevent job table bloat:

```sql
-- Clean up jobs older than 7 days
SELECT cleanup_old_agent_jobs(7);
```

### Monitor Status

```sql
-- Check jurisdiction loading status
SELECT
    status,
    COUNT(*) as count,
    AVG(rules_count) as avg_rules
FROM jurisdiction_data_status
GROUP BY status;

-- Check job statistics
SELECT
    job_type,
    status,
    COUNT(*) as count,
    AVG(progress_percentage) as avg_progress
FROM agent_jobs
GROUP BY job_type, status;
```

### Performance Tuning

If queries are slow:

```sql
-- Analyze tables
ANALYZE jurisdiction_data_status;
ANALYZE agent_jobs;

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename IN ('jurisdiction_data_status', 'agent_jobs');
```

## Next Migration

When creating the next migration:

1. Name it `003_description.sql`
2. Include rollback instructions
3. Update this README with details
4. Test on a development database first

## Support

For migration issues:
- Check PostgreSQL logs
- Verify database user permissions
- Test queries manually before applying
- Keep backups before running migrations
