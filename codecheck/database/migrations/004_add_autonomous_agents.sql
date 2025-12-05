-- Migration: Add Autonomous Research Agents Infrastructure
-- Purpose: Enable on-demand code discovery, scraping, and extraction
-- Date: 2025-12-05

-- ============================================================================
-- 1. CODE SOURCE REGISTRY
-- Purpose: Curated database of known building code sources (APIs, websites)
-- ============================================================================
CREATE TABLE IF NOT EXISTS code_source_registry (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_name TEXT NOT NULL UNIQUE,  -- 'ICC Digital Codes', 'Municode', etc.
    source_type TEXT NOT NULL CHECK (source_type IN ('api', 'web_portal', 'pdf_repository', 'html_scraper')),
    base_url TEXT NOT NULL,
    requires_auth BOOLEAN DEFAULT FALSE,
    auth_type TEXT CHECK (auth_type IN ('api_key', 'oauth', 'basic') OR auth_type IS NULL),
    reliability_score DECIMAL(3,2) DEFAULT 0.80 CHECK (reliability_score >= 0 AND reliability_score <= 1.00),
    avg_response_time_ms INT,
    supports_jurisdictions TEXT[],  -- Array of supported state codes ['CA', 'TX', 'ALL']
    last_successful_fetch TIMESTAMPTZ,
    last_failed_fetch TIMESTAMPTZ,
    total_successful_fetches INT DEFAULT 0,
    total_failed_fetches INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    rate_limit_per_hour INT,
    cost_per_request DECIMAL(10,4) DEFAULT 0.0000,  -- Track API costs
    metadata JSONB,  -- Flexible field for source-specific config
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_code_source_registry_type ON code_source_registry(source_type);
CREATE INDEX idx_code_source_registry_active ON code_source_registry(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_code_source_registry_reliability ON code_source_registry(reliability_score DESC);
CREATE INDEX idx_code_source_registry_supports ON code_source_registry USING GIN(supports_jurisdictions);

COMMENT ON TABLE code_source_registry IS 'Curated database of known building code sources';
COMMENT ON COLUMN code_source_registry.reliability_score IS 'Historical reliability (0.00-1.00)';
COMMENT ON COLUMN code_source_registry.metadata IS 'Source-specific config: search patterns, auth details, code families';

-- ============================================================================
-- 2. JURISDICTION SOURCE MAPPING
-- Purpose: Track which sources work for each jurisdiction (learned over time)
-- ============================================================================
CREATE TABLE IF NOT EXISTS jurisdiction_source_mapping (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID NOT NULL REFERENCES jurisdiction(id) ON DELETE CASCADE,
    source_id UUID NOT NULL REFERENCES code_source_registry(id) ON DELETE CASCADE,
    discovery_method TEXT CHECK (discovery_method IN ('manual', 'claude_research', 'pattern_match', 'user_submitted')),
    source_url TEXT,  -- Specific URL for this jurisdiction
    code_families_available TEXT[],  -- ['IRC', 'IBC', 'IFC', 'IECC', etc.]
    last_verified TIMESTAMPTZ,
    verification_status TEXT CHECK (verification_status IN ('verified', 'unverified', 'broken')),
    fetch_success_rate DECIMAL(3,2),  -- Track reliability per jurisdiction
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(jurisdiction_id, source_id)
);

CREATE INDEX idx_jurisdiction_source_jurisdiction ON jurisdiction_source_mapping(jurisdiction_id);
CREATE INDEX idx_jurisdiction_source_source ON jurisdiction_source_mapping(source_id);
CREATE INDEX idx_jurisdiction_source_status ON jurisdiction_source_mapping(verification_status);
CREATE INDEX idx_jurisdiction_source_verified ON jurisdiction_source_mapping(jurisdiction_id, verification_status)
    WHERE verification_status = 'verified';

COMMENT ON TABLE jurisdiction_source_mapping IS 'Learned mapping of which sources work for each jurisdiction';
COMMENT ON COLUMN jurisdiction_source_mapping.discovery_method IS 'How we found this source mapping';

-- ============================================================================
-- 3. EXTRACTION CACHE
-- Purpose: Deduplicate code extraction to save Claude API costs (KEY COST SAVER)
-- ============================================================================
CREATE TABLE IF NOT EXISTS extraction_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content_hash TEXT NOT NULL UNIQUE,  -- SHA-256 of normalized code text
    code_family TEXT NOT NULL,
    edition TEXT NOT NULL,
    section_ref TEXT,
    extracted_rules JSONB NOT NULL,  -- Cached extraction result
    extraction_method TEXT,  -- 'claude-3-5-sonnet', 'gpt-4', 'rule_extractor_v1'
    confidence_score DECIMAL(3,2),
    times_reused INT DEFAULT 0,
    cost_saved DECIMAL(10,2) DEFAULT 0.00,  -- Track savings from cache hits
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_used TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_extraction_cache_hash ON extraction_cache(content_hash);
CREATE INDEX idx_extraction_cache_family ON extraction_cache(code_family, edition);
CREATE INDEX idx_extraction_cache_reuse ON extraction_cache(times_reused DESC);
CREATE INDEX idx_extraction_cache_savings ON extraction_cache(cost_saved DESC);

COMMENT ON TABLE extraction_cache IS 'Deduplication cache for code extraction - saves 70%+ costs after month 3';
COMMENT ON COLUMN extraction_cache.content_hash IS 'SHA-256 of normalized code text for deduplication';
COMMENT ON COLUMN extraction_cache.cost_saved IS 'Total USD saved from cache hits (~$0.05 per reuse)';

-- ============================================================================
-- 4. JURISDICTION REQUEST TRACKING
-- Purpose: Track demand to prioritize which jurisdictions to load first
-- ============================================================================
CREATE TABLE IF NOT EXISTS jurisdiction_request_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID NOT NULL REFERENCES jurisdiction(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,  -- NULL for anonymous
    request_type TEXT,  -- 'compliance_check', 'load_codes', 'api_query', 'conversation'
    requested_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_jurisdiction_request_tracking_jurisdiction ON jurisdiction_request_tracking(jurisdiction_id, requested_at DESC);
CREATE INDEX idx_jurisdiction_request_tracking_user ON jurisdiction_request_tracking(user_id);
CREATE INDEX idx_jurisdiction_request_tracking_time ON jurisdiction_request_tracking(requested_at DESC);

COMMENT ON TABLE jurisdiction_request_tracking IS 'Track every user request to calculate demand-based priority';

-- Materialized view for fast demand analysis
CREATE MATERIALIZED VIEW IF NOT EXISTS jurisdiction_demand_summary AS
SELECT
    jurisdiction_id,
    COUNT(*) as total_requests,
    COUNT(*) FILTER (WHERE requested_at > NOW() - INTERVAL '7 days') as requests_last_7_days,
    COUNT(*) FILTER (WHERE requested_at > NOW() - INTERVAL '24 hours') as requests_last_24_hours,
    MAX(requested_at) as last_requested
FROM jurisdiction_request_tracking
GROUP BY jurisdiction_id;

CREATE UNIQUE INDEX idx_jurisdiction_demand_summary_jurisdiction ON jurisdiction_demand_summary(jurisdiction_id);
CREATE INDEX idx_jurisdiction_demand_summary_recent ON jurisdiction_demand_summary(requests_last_24_hours DESC);
CREATE INDEX idx_jurisdiction_demand_summary_weekly ON jurisdiction_demand_summary(requests_last_7_days DESC);

COMMENT ON MATERIALIZED VIEW jurisdiction_demand_summary IS 'Fast lookup for priority calculation - refresh periodically';

-- Function to refresh demand summary
CREATE OR REPLACE FUNCTION refresh_jurisdiction_demand_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY jurisdiction_demand_summary;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION refresh_jurisdiction_demand_summary() IS 'Refresh demand summary - run every 5 minutes via cron';

-- ============================================================================
-- 5. SCRAPING LOGS
-- Purpose: Monitor scraping success/failures for debugging and reliability
-- ============================================================================
CREATE TABLE IF NOT EXISTS scraping_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES agent_jobs(id) ON DELETE CASCADE,
    jurisdiction_id UUID REFERENCES jurisdiction(id) ON DELETE CASCADE,
    source_id UUID REFERENCES code_source_registry(id) ON DELETE SET NULL,
    scraping_method TEXT,  -- 'requests', 'selenium', 'playwright', 'api'
    status TEXT CHECK (status IN ('success', 'failed', 'partial', 'timeout', 'blocked')),
    http_status_code INT,
    response_time_ms INT,
    bytes_downloaded INT,
    documents_found INT,
    error_type TEXT,  -- 'timeout', 'blocked', '404', 'parse_error', 'rate_limit', etc.
    error_message TEXT,
    user_agent TEXT,
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_scraping_logs_job ON scraping_logs(job_id);
CREATE INDEX idx_scraping_logs_jurisdiction ON scraping_logs(jurisdiction_id);
CREATE INDEX idx_scraping_logs_source ON scraping_logs(source_id, status);
CREATE INDEX idx_scraping_logs_created ON scraping_logs(created_at DESC);
CREATE INDEX idx_scraping_logs_status ON scraping_logs(status) WHERE status IN ('failed', 'timeout', 'blocked');

COMMENT ON TABLE scraping_logs IS 'Detailed logging of every scraping attempt for debugging';
COMMENT ON COLUMN scraping_logs.error_type IS 'Categorized error for automated remediation';

-- ============================================================================
-- 6. API COST TRACKING
-- Purpose: Track Claude API usage and costs per jurisdiction
-- ============================================================================
CREATE TABLE IF NOT EXISTS api_cost_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES agent_jobs(id) ON DELETE CASCADE,
    api_provider TEXT NOT NULL,  -- 'anthropic', 'openai', etc.
    model TEXT NOT NULL,  -- 'claude-3-5-sonnet-20241022', 'gpt-4', etc.
    operation TEXT,  -- 'rule_extraction', 'source_research', 'validation'
    input_tokens INT NOT NULL,
    output_tokens INT NOT NULL,
    cost_usd DECIMAL(10,4) NOT NULL,
    jurisdiction_id UUID REFERENCES jurisdiction(id) ON DELETE CASCADE,
    cache_hit BOOLEAN DEFAULT FALSE,  -- Was extraction cached?
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_api_cost_tracking_job ON api_cost_tracking(job_id);
CREATE INDEX idx_api_cost_tracking_provider ON api_cost_tracking(api_provider, created_at DESC);
CREATE INDEX idx_api_cost_tracking_jurisdiction ON api_cost_tracking(jurisdiction_id);
CREATE INDEX idx_api_cost_tracking_created ON api_cost_tracking(created_at DESC);
CREATE INDEX idx_api_cost_tracking_cache ON api_cost_tracking(cache_hit) WHERE cache_hit = FALSE;

COMMENT ON TABLE api_cost_tracking IS 'Track all AI API usage and costs for budgeting';
COMMENT ON COLUMN api_cost_tracking.cache_hit IS 'TRUE if result was from extraction_cache (no API call)';

-- View for daily cost summary
CREATE OR REPLACE VIEW daily_api_costs AS
SELECT
    DATE(created_at) as date,
    api_provider,
    model,
    COUNT(*) as api_calls,
    SUM(input_tokens) as total_input_tokens,
    SUM(output_tokens) as total_output_tokens,
    SUM(cost_usd) as total_cost_usd,
    COUNT(*) FILTER (WHERE cache_hit = FALSE) as uncached_calls,
    COUNT(*) FILTER (WHERE cache_hit = TRUE) as cached_calls
FROM api_cost_tracking
GROUP BY DATE(created_at), api_provider, model
ORDER BY date DESC, total_cost_usd DESC;

COMMENT ON VIEW daily_api_costs IS 'Daily cost breakdown for budget tracking';

-- ============================================================================
-- 7. MODIFY EXISTING TABLES
-- Purpose: Add priority queue fields to agent_jobs
-- ============================================================================

-- Add priority queue columns to agent_jobs
ALTER TABLE agent_jobs
ADD COLUMN IF NOT EXISTS priority INT DEFAULT 5 CHECK (priority >= 1 AND priority <= 10),
ADD COLUMN IF NOT EXISTS job_category TEXT CHECK (job_category IN ('urgent', 'normal', 'background', 'batch')) DEFAULT 'normal',
ADD COLUMN IF NOT EXISTS estimated_cost_usd DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS actual_cost_usd DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS retry_count INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS max_retries INT DEFAULT 3,
ADD COLUMN IF NOT EXISTS scheduled_at TIMESTAMPTZ;

-- Index for priority queue sorting (highest priority, oldest first)
CREATE INDEX IF NOT EXISTS idx_agent_jobs_priority_queue
ON agent_jobs(priority DESC, created_at ASC)
WHERE status IN ('pending', 'running');

COMMENT ON COLUMN agent_jobs.priority IS 'Priority 1-10 (10=highest) for queue sorting';
COMMENT ON COLUMN agent_jobs.job_category IS 'urgent=user waiting, normal=standard, background=low priority, batch=overnight';

-- ============================================================================
-- 8. HELPER FUNCTIONS
-- Purpose: Utility functions for common operations
-- ============================================================================

-- Function to track jurisdiction request
CREATE OR REPLACE FUNCTION track_jurisdiction_request(
    p_jurisdiction_id UUID,
    p_user_id UUID DEFAULT NULL,
    p_request_type TEXT DEFAULT 'api_query'
)
RETURNS void AS $$
BEGIN
    INSERT INTO jurisdiction_request_tracking (jurisdiction_id, user_id, request_type)
    VALUES (p_jurisdiction_id, p_user_id, p_request_type);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION track_jurisdiction_request IS 'Log every jurisdiction request for demand tracking';

-- Function to get source reliability stats
CREATE OR REPLACE FUNCTION get_source_reliability(p_source_id UUID)
RETURNS TABLE (
    source_name TEXT,
    total_attempts INT,
    success_rate DECIMAL,
    avg_response_ms INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        csr.source_name,
        (csr.total_successful_fetches + csr.total_failed_fetches) as total_attempts,
        CASE
            WHEN (csr.total_successful_fetches + csr.total_failed_fetches) > 0
            THEN ROUND(csr.total_successful_fetches::decimal / (csr.total_successful_fetches + csr.total_failed_fetches), 2)
            ELSE 0
        END as success_rate,
        csr.avg_response_time_ms
    FROM code_source_registry csr
    WHERE csr.id = p_source_id;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate job priority
CREATE OR REPLACE FUNCTION calculate_job_priority(
    p_jurisdiction_id UUID,
    p_user_tier TEXT DEFAULT 'free',
    p_explicit_urgent BOOLEAN DEFAULT FALSE
)
RETURNS INT AS $$
DECLARE
    v_priority INT := 5;  -- Base priority
    v_demand RECORD;
BEGIN
    -- Explicit urgency (user waiting in app)
    IF p_explicit_urgent THEN
        v_priority := v_priority + 5;
    END IF;

    -- User tier bonus
    v_priority := v_priority + CASE
        WHEN LOWER(p_user_tier) = 'premium' THEN 3
        WHEN LOWER(p_user_tier) = 'pro' THEN 2
        ELSE 0
    END;

    -- Demand-based priority
    SELECT requests_last_24_hours, requests_last_7_days
    INTO v_demand
    FROM jurisdiction_demand_summary
    WHERE jurisdiction_id = p_jurisdiction_id;

    IF v_demand IS NOT NULL THEN
        -- High recent demand
        IF v_demand.requests_last_24_hours >= 10 THEN
            v_priority := v_priority + 2;
        ELSIF v_demand.requests_last_24_hours >= 3 THEN
            v_priority := v_priority + 1;
        END IF;

        -- Moderate weekly demand
        IF v_demand.requests_last_7_days >= 5 THEN
            v_priority := v_priority + 1;
        END IF;
    ELSE
        -- Never loaded before - first-time bonus
        v_priority := v_priority + 1;
    END IF;

    -- Cap at 10
    RETURN LEAST(v_priority, 10);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION calculate_job_priority IS 'Calculate priority (1-10) based on urgency, user tier, and demand';

-- Function to log scraping attempt
CREATE OR REPLACE FUNCTION log_scraping_attempt(
    p_job_id UUID,
    p_jurisdiction_id UUID,
    p_source_id UUID,
    p_method TEXT,
    p_status TEXT,
    p_http_status INT DEFAULT NULL,
    p_response_time_ms INT DEFAULT NULL,
    p_bytes_downloaded INT DEFAULT NULL,
    p_error_type TEXT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO scraping_logs (
        job_id, jurisdiction_id, source_id, scraping_method, status,
        http_status_code, response_time_ms, bytes_downloaded,
        error_type, error_message
    )
    VALUES (
        p_job_id, p_jurisdiction_id, p_source_id, p_method, p_status,
        p_http_status, p_response_time_ms, p_bytes_downloaded,
        p_error_type, p_error_message
    )
    RETURNING id INTO v_log_id;

    -- Update source registry stats
    IF p_status = 'success' THEN
        UPDATE code_source_registry
        SET total_successful_fetches = total_successful_fetches + 1,
            last_successful_fetch = NOW(),
            avg_response_time_ms = COALESCE(
                (avg_response_time_ms * total_successful_fetches + p_response_time_ms) / (total_successful_fetches + 1),
                p_response_time_ms
            )
        WHERE id = p_source_id;
    ELSE
        UPDATE code_source_registry
        SET total_failed_fetches = total_failed_fetches + 1,
            last_failed_fetch = NOW()
        WHERE id = p_source_id;
    END IF;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION log_scraping_attempt IS 'Log scraping attempt and update source reliability stats';

-- ============================================================================
-- 9. INITIAL DATA INTEGRITY
-- Purpose: Ensure referential integrity for existing data
-- ============================================================================

-- Set default priority for existing jobs
UPDATE agent_jobs SET priority = 5 WHERE priority IS NULL;
UPDATE agent_jobs SET job_category = 'normal' WHERE job_category IS NULL;

-- ============================================================================
-- MIGRATION COMPLETE
-- ============================================================================

-- Log migration completion
DO $$
BEGIN
    RAISE NOTICE 'Migration 004: Autonomous Research Agents infrastructure created successfully';
    RAISE NOTICE 'New tables: code_source_registry, jurisdiction_source_mapping, extraction_cache, jurisdiction_request_tracking, scraping_logs, api_cost_tracking';
    RAISE NOTICE 'Modified tables: agent_jobs (added priority queue fields)';
    RAISE NOTICE 'Next steps: Run seed_code_sources.sql to populate initial code sources';
END
$$;
