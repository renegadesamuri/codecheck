-- ============================================================================
-- Migration 003: Add Agent Tracking and Connectivity Monitoring
-- ============================================================================
-- This migration adds tables for tracking mini-agent execution, connection
-- tests, and configuration state validation.
-- ============================================================================

-- Agent execution tracking
CREATE TABLE IF NOT EXISTS agent_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_name TEXT NOT NULL,
    run_type TEXT CHECK (run_type IN ('startup', 'scheduled', 'manual', 'event')),
    status TEXT CHECK (status IN ('running', 'completed', 'failed')),
    findings_count INT DEFAULT 0,
    remediations_count INT DEFAULT 0,
    execution_time_ms INT,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    findings JSONB,
    metrics JSONB
);

-- Connection test results
CREATE TABLE IF NOT EXISTS connection_tests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    run_id UUID REFERENCES agent_runs(id) ON DELETE CASCADE,
    connection_name TEXT NOT NULL,  -- 'frontend-backend', 'backend-database', 'backend-redis', etc.
    connection_type TEXT NOT NULL,  -- 'database', 'http', 'redis', 'auth'
    status TEXT CHECK (status IN ('healthy', 'degraded', 'failed')) NOT NULL,
    latency_ms INT,
    error_message TEXT,
    auto_fixed BOOLEAN DEFAULT FALSE,
    fix_action TEXT,
    metadata JSONB,
    tested_at TIMESTAMPTZ DEFAULT NOW()
);

-- Configuration state and validation
CREATE TABLE IF NOT EXISTS config_state (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    config_key TEXT NOT NULL,
    config_value TEXT,
    source TEXT NOT NULL,  -- 'master', '.env', 'vite.config.ts', 'capacitor.config.ts', etc.
    environment TEXT,  -- 'development', 'production', 'ios-simulator', 'ios-device'
    is_valid BOOLEAN DEFAULT TRUE,
    validation_error TEXT,
    last_validated_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(config_key, source, environment)
);

-- Agent configuration
CREATE TABLE IF NOT EXISTS agent_config (
    agent_name TEXT PRIMARY KEY,
    is_enabled BOOLEAN DEFAULT TRUE,
    schedule_interval_seconds INT DEFAULT 300,  -- Default: 5 minutes
    config JSONB,
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,
    consecutive_failures INT DEFAULT 0,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Agent resource usage tracking
CREATE TABLE IF NOT EXISTS agent_resource_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_name TEXT NOT NULL,
    execution_time_ms INT NOT NULL,
    cpu_percent NUMERIC(5,2),
    memory_mb NUMERIC(10,2),
    recorded_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_agent_runs_agent ON agent_runs(agent_name);
CREATE INDEX IF NOT EXISTS idx_agent_runs_started ON agent_runs(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_agent_runs_status ON agent_runs(status);

CREATE INDEX IF NOT EXISTS idx_connection_tests_run ON connection_tests(run_id);
CREATE INDEX IF NOT EXISTS idx_connection_tests_name ON connection_tests(connection_name);
CREATE INDEX IF NOT EXISTS idx_connection_tests_status ON connection_tests(status);
CREATE INDEX IF NOT EXISTS idx_connection_tests_tested ON connection_tests(tested_at DESC);

CREATE INDEX IF NOT EXISTS idx_config_state_key ON config_state(config_key);
CREATE INDEX IF NOT EXISTS idx_config_state_source ON config_state(source);
CREATE INDEX IF NOT EXISTS idx_config_state_valid ON config_state(is_valid);

CREATE INDEX IF NOT EXISTS idx_agent_resource_usage_agent ON agent_resource_usage(agent_name);
CREATE INDEX IF NOT EXISTS idx_agent_resource_usage_recorded ON agent_resource_usage(recorded_at DESC);

-- Update trigger for config_state updated_at
CREATE OR REPLACE FUNCTION update_config_state_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER config_state_updated_at
    BEFORE UPDATE ON config_state
    FOR EACH ROW
    EXECUTE FUNCTION update_config_state_updated_at();

-- Update trigger for agent_config updated_at
CREATE OR REPLACE FUNCTION update_agent_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER agent_config_updated_at
    BEFORE UPDATE ON agent_config
    FOR EACH ROW
    EXECUTE FUNCTION update_agent_config_updated_at();

-- Insert default agent configurations
INSERT INTO agent_config (agent_name, is_enabled, schedule_interval_seconds, config) VALUES
    ('connection_tester', TRUE, 60, '{"critical": true, "timeout_seconds": 5}'::JSONB),
    ('config_validator', TRUE, 300, '{"critical": false, "auto_fix": true}'::JSONB),
    ('auth_tester', TRUE, 3600, '{"critical": false, "cleanup_test_users": true}'::JSONB)
ON CONFLICT (agent_name) DO NOTHING;

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Function to get latest connection status
CREATE OR REPLACE FUNCTION get_latest_connection_status()
RETURNS TABLE (
    connection_name TEXT,
    status TEXT,
    latency_ms INT,
    error_message TEXT,
    tested_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT ON (ct.connection_name)
        ct.connection_name,
        ct.status,
        ct.latency_ms,
        ct.error_message,
        ct.tested_at
    FROM connection_tests ct
    ORDER BY ct.connection_name, ct.tested_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to get agent health summary
CREATE OR REPLACE FUNCTION get_agent_health_summary()
RETURNS TABLE (
    agent_name TEXT,
    is_enabled BOOLEAN,
    last_run_at TIMESTAMPTZ,
    last_status TEXT,
    consecutive_failures INT,
    avg_execution_time_ms NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ac.agent_name,
        ac.is_enabled,
        ac.last_run_at,
        (SELECT ar.status FROM agent_runs ar WHERE ar.agent_name = ac.agent_name ORDER BY ar.started_at DESC LIMIT 1) as last_status,
        ac.consecutive_failures,
        (SELECT AVG(ar2.execution_time_ms) FROM agent_runs ar2 WHERE ar2.agent_name = ac.agent_name AND ar2.status = 'completed') as avg_execution_time_ms
    FROM agent_config ac
    ORDER BY ac.agent_name;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup old agent runs (keep last 1000)
CREATE OR REPLACE FUNCTION cleanup_old_agent_runs()
RETURNS INT AS $$
DECLARE
    deleted_count INT;
BEGIN
    WITH runs_to_delete AS (
        SELECT id
        FROM agent_runs
        WHERE id NOT IN (
            SELECT id
            FROM agent_runs
            ORDER BY started_at DESC
            LIMIT 1000
        )
    )
    DELETE FROM agent_runs
    WHERE id IN (SELECT id FROM runs_to_delete);

    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE agent_runs IS 'Tracks execution history of all mini-agents';
COMMENT ON TABLE connection_tests IS 'Records results of connectivity tests performed by agents';
COMMENT ON TABLE config_state IS 'Stores current configuration state and validation results';
COMMENT ON TABLE agent_config IS 'Configuration settings for each agent';
COMMENT ON TABLE agent_resource_usage IS 'Tracks resource consumption of agents for optimization';
