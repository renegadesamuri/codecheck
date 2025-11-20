-- Migration: Add on-demand code loading infrastructure
-- Created: 2025-01-19
-- Description: Add tables for tracking jurisdiction data status and agent jobs

-- Track jurisdiction data loading status
CREATE TABLE IF NOT EXISTS jurisdiction_data_status (
    jurisdiction_id UUID PRIMARY KEY REFERENCES jurisdiction(id) ON DELETE CASCADE,
    status TEXT CHECK (status IN ('pending', 'loading', 'complete', 'failed')) NOT NULL DEFAULT 'pending',
    rules_count INT DEFAULT 0,
    last_fetch_attempt TIMESTAMPTZ,
    last_successful_fetch TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Track agent jobs for code loading
CREATE TABLE IF NOT EXISTS agent_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID REFERENCES jurisdiction(id) ON DELETE CASCADE,
    job_type TEXT NOT NULL, -- 'load_codes', 'source_discovery', 'document_fetch', 'rule_extraction'
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')) NOT NULL DEFAULT 'pending',
    progress_percentage INT DEFAULT 0 CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
    progress_message TEXT,
    result JSONB,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for quick lookups
CREATE INDEX IF NOT EXISTS idx_jurisdiction_data_status_status ON jurisdiction_data_status(jurisdiction_id, status);
CREATE INDEX IF NOT EXISTS idx_jurisdiction_data_status_updated ON jurisdiction_data_status(updated_at);

CREATE INDEX IF NOT EXISTS idx_agent_jobs_jurisdiction ON agent_jobs(jurisdiction_id, status);
CREATE INDEX IF NOT EXISTS idx_agent_jobs_status ON agent_jobs(status, created_at);
CREATE INDEX IF NOT EXISTS idx_agent_jobs_type ON agent_jobs(job_type, status);

-- Trigger for updated_at on new tables
CREATE TRIGGER update_jurisdiction_data_status_updated_at
    BEFORE UPDATE ON jurisdiction_data_status
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_agent_jobs_updated_at
    BEFORE UPDATE ON agent_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Initialize jurisdiction_data_status for existing jurisdictions
INSERT INTO jurisdiction_data_status (jurisdiction_id, status, rules_count)
SELECT
    j.id,
    CASE
        WHEN COUNT(r.id) > 0 THEN 'complete'
        ELSE 'pending'
    END,
    COUNT(r.id)::INT
FROM jurisdiction j
LEFT JOIN rule r ON r.jurisdiction_id = j.id
WHERE NOT EXISTS (
    SELECT 1 FROM jurisdiction_data_status jds
    WHERE jds.jurisdiction_id = j.id
)
GROUP BY j.id
ON CONFLICT (jurisdiction_id) DO NOTHING;

-- Update rules_count for jurisdictions that already have status entries
UPDATE jurisdiction_data_status jds
SET
    rules_count = subq.count,
    status = CASE
        WHEN subq.count > 0 THEN 'complete'
        ELSE status
    END,
    updated_at = NOW()
FROM (
    SELECT jurisdiction_id, COUNT(*)::INT as count
    FROM rule
    GROUP BY jurisdiction_id
) subq
WHERE jds.jurisdiction_id = subq.jurisdiction_id;

-- Comments for documentation
COMMENT ON TABLE jurisdiction_data_status IS 'Tracks the loading status and metadata for building codes in each jurisdiction';
COMMENT ON TABLE agent_jobs IS 'Tracks background agent jobs for code loading and extraction';
COMMENT ON COLUMN agent_jobs.progress_percentage IS 'Progress from 0-100%, updated by agent coordinator';
COMMENT ON COLUMN agent_jobs.result IS 'JSON result of completed job, including rules_count, sources_found, etc.';

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to check if a jurisdiction has rules loaded
CREATE OR REPLACE FUNCTION jurisdiction_has_rules(p_jurisdiction_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM rule
    WHERE jurisdiction_id = p_jurisdiction_id;

    RETURN v_count > 0;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION jurisdiction_has_rules IS 'Returns true if jurisdiction has any rules loaded';

-- Function to get jurisdiction loading status
CREATE OR REPLACE FUNCTION get_jurisdiction_status(p_jurisdiction_id UUID)
RETURNS TABLE (
    status TEXT,
    rules_count INT,
    is_loading BOOLEAN,
    has_active_job BOOLEAN,
    last_error TEXT,
    job_progress INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COALESCE(jds.status, 'pending') as status,
        COALESCE(jds.rules_count, 0) as rules_count,
        COALESCE(jds.status IN ('pending', 'loading'), FALSE) as is_loading,
        EXISTS(
            SELECT 1 FROM agent_jobs aj
            WHERE aj.jurisdiction_id = p_jurisdiction_id
            AND aj.status IN ('pending', 'running')
        ) as has_active_job,
        jds.error_message as last_error,
        COALESCE((
            SELECT progress_percentage
            FROM agent_jobs aj
            WHERE aj.jurisdiction_id = p_jurisdiction_id
            AND aj.status = 'running'
            ORDER BY created_at DESC
            LIMIT 1
        ), 0) as job_progress
    FROM jurisdiction_data_status jds
    WHERE jds.jurisdiction_id = p_jurisdiction_id;

    -- If no status record exists, return defaults
    IF NOT FOUND THEN
        RETURN QUERY
        SELECT
            'pending'::TEXT,
            0::INT,
            FALSE::BOOLEAN,
            FALSE::BOOLEAN,
            NULL::TEXT,
            0::INT;
    END IF;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_jurisdiction_status IS 'Returns comprehensive status information for a jurisdiction';

-- Function to initialize or update jurisdiction status
CREATE OR REPLACE FUNCTION update_jurisdiction_status(
    p_jurisdiction_id UUID,
    p_status TEXT,
    p_rules_count INT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO jurisdiction_data_status (
        jurisdiction_id,
        status,
        rules_count,
        last_fetch_attempt,
        last_successful_fetch,
        error_message
    )
    VALUES (
        p_jurisdiction_id,
        p_status,
        COALESCE(p_rules_count, 0),
        CASE WHEN p_status IN ('loading', 'complete', 'failed') THEN NOW() ELSE NULL END,
        CASE WHEN p_status = 'complete' THEN NOW() ELSE NULL END,
        p_error_message
    )
    ON CONFLICT (jurisdiction_id)
    DO UPDATE SET
        status = EXCLUDED.status,
        rules_count = COALESCE(EXCLUDED.rules_count, jurisdiction_data_status.rules_count),
        last_fetch_attempt = CASE
            WHEN EXCLUDED.status IN ('loading', 'complete', 'failed') THEN NOW()
            ELSE jurisdiction_data_status.last_fetch_attempt
        END,
        last_successful_fetch = CASE
            WHEN EXCLUDED.status = 'complete' THEN NOW()
            ELSE jurisdiction_data_status.last_successful_fetch
        END,
        error_message = EXCLUDED.error_message,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_jurisdiction_status IS 'Creates or updates jurisdiction loading status with automatic timestamp management';

-- Function to get or create an agent job
CREATE OR REPLACE FUNCTION create_agent_job(
    p_jurisdiction_id UUID,
    p_job_type TEXT
) RETURNS UUID AS $$
DECLARE
    v_job_id UUID;
BEGIN
    -- Check if there's already a pending/running job of this type
    SELECT id INTO v_job_id
    FROM agent_jobs
    WHERE jurisdiction_id = p_jurisdiction_id
    AND job_type = p_job_type
    AND status IN ('pending', 'running')
    ORDER BY created_at DESC
    LIMIT 1;

    -- If found, return existing job
    IF v_job_id IS NOT NULL THEN
        RETURN v_job_id;
    END IF;

    -- Create new job
    INSERT INTO agent_jobs (jurisdiction_id, job_type, status, progress_percentage)
    VALUES (p_jurisdiction_id, p_job_type, 'pending', 0)
    RETURNING id INTO v_job_id;

    RETURN v_job_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION create_agent_job IS 'Creates a new agent job or returns existing pending/running job to prevent duplicates';

-- Function to update agent job progress
CREATE OR REPLACE FUNCTION update_agent_job_progress(
    p_job_id UUID,
    p_status TEXT,
    p_progress INT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL,
    p_result JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    UPDATE agent_jobs
    SET
        status = p_status,
        progress_percentage = COALESCE(p_progress, progress_percentage),
        error_message = p_error_message,
        result = COALESCE(p_result, result),
        started_at = CASE
            WHEN p_status = 'running' AND started_at IS NULL THEN NOW()
            ELSE started_at
        END,
        completed_at = CASE
            WHEN p_status IN ('completed', 'failed') THEN NOW()
            ELSE completed_at
        END,
        updated_at = NOW()
    WHERE id = p_job_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_agent_job_progress IS 'Updates agent job status, progress, and metadata';

-- Function to clean up old completed jobs
CREATE OR REPLACE FUNCTION cleanup_old_agent_jobs(p_days_to_keep INT DEFAULT 7)
RETURNS INT AS $$
DECLARE
    v_deleted_count INT;
BEGIN
    DELETE FROM agent_jobs
    WHERE status IN ('completed', 'failed')
    AND completed_at < NOW() - (p_days_to_keep || ' days')::INTERVAL;

    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION cleanup_old_agent_jobs IS 'Deletes completed/failed jobs older than specified days (default 7)';
