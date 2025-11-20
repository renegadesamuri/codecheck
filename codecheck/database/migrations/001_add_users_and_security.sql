-- Migration: Add users table and security features
-- Created: 2025-01-19
-- Description: Adds user authentication, audit logging, and security features

-- Users table for authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'inspector')),
    is_active BOOLEAN DEFAULT TRUE,
    email_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMPTZ,
    failed_login_attempts INT DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- API keys table for programmatic access
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash TEXT NOT NULL,
    name TEXT NOT NULL,
    last_used_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit log for security events
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action TEXT NOT NULL,
    resource_type TEXT,
    resource_id UUID,
    ip_address INET,
    user_agent TEXT,
    details JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rate limiting table
CREATE TABLE rate_limit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    identifier TEXT NOT NULL,  -- user_id, IP address, or API key
    endpoint TEXT NOT NULL,
    request_count INT DEFAULT 0,
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add user_id to existing project table
ALTER TABLE project ADD COLUMN user_id UUID REFERENCES users(id);

-- Add user_id index for performance
CREATE INDEX idx_project_user ON project(user_id);

-- Indexes for security and performance
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_api_keys_user ON api_keys(user_id);
CREATE INDEX idx_api_keys_active ON api_keys(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_audit_log_user ON audit_log(user_id);
CREATE INDEX idx_audit_log_action ON audit_log(action);
CREATE INDEX idx_audit_log_created ON audit_log(created_at);
CREATE INDEX idx_rate_limit_identifier ON rate_limit(identifier, endpoint);
CREATE INDEX idx_rate_limit_window ON rate_limit(window_end);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for users table
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Function to log security events
CREATE OR REPLACE FUNCTION log_security_event(
    p_user_id UUID,
    p_action TEXT,
    p_resource_type TEXT DEFAULT NULL,
    p_resource_id UUID DEFAULT NULL,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL,
    p_details JSONB DEFAULT NULL
) RETURNS VOID AS $$
BEGIN
    INSERT INTO audit_log (user_id, action, resource_type, resource_id, ip_address, user_agent, details)
    VALUES (p_user_id, p_action, p_resource_type, p_resource_id, p_ip_address, p_user_agent, p_details);
END;
$$ LANGUAGE plpgsql;

-- Function to check and update rate limit
CREATE OR REPLACE FUNCTION check_rate_limit(
    p_identifier TEXT,
    p_endpoint TEXT,
    p_limit INT,
    p_window_minutes INT
) RETURNS BOOLEAN AS $$
DECLARE
    v_count INT;
    v_window_start TIMESTAMPTZ;
    v_window_end TIMESTAMPTZ;
BEGIN
    v_window_end := NOW();
    v_window_start := NOW() - (p_window_minutes || ' minutes')::INTERVAL;

    -- Clean up old rate limit entries
    DELETE FROM rate_limit WHERE window_end < NOW() - INTERVAL '1 hour';

    -- Get current count
    SELECT request_count INTO v_count
    FROM rate_limit
    WHERE identifier = p_identifier
    AND endpoint = p_endpoint
    AND window_end > NOW();

    IF v_count IS NULL THEN
        -- First request in window
        INSERT INTO rate_limit (identifier, endpoint, request_count, window_start, window_end)
        VALUES (p_identifier, p_endpoint, 1, v_window_start, v_window_end + (p_window_minutes || ' minutes')::INTERVAL);
        RETURN TRUE;
    ELSIF v_count < p_limit THEN
        -- Within limit, increment
        UPDATE rate_limit
        SET request_count = request_count + 1
        WHERE identifier = p_identifier AND endpoint = p_endpoint AND window_end > NOW();
        RETURN TRUE;
    ELSE
        -- Rate limit exceeded
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Create default admin user (password: Admin123! - MUST CHANGE IN PRODUCTION)
-- Password hash for 'Admin123!' using bcrypt
INSERT INTO users (email, password_hash, full_name, role, is_active, email_verified)
VALUES (
    'admin@codecheck.local',
    '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5ND2TIWmW.g5i',
    'System Administrator',
    'admin',
    TRUE,
    TRUE
);

COMMENT ON TABLE users IS 'User accounts for authentication and authorization';
COMMENT ON TABLE api_keys IS 'API keys for programmatic access';
COMMENT ON TABLE audit_log IS 'Security and action audit trail';
COMMENT ON TABLE rate_limit IS 'Rate limiting tracking';
COMMENT ON COLUMN users.failed_login_attempts IS 'Number of consecutive failed login attempts';
COMMENT ON COLUMN users.locked_until IS 'Account locked until this timestamp (after too many failed attempts)';
