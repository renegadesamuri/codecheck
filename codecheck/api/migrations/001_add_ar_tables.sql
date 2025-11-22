-- Migration: Add AR Measurement Tables

CREATE TABLE IF NOT EXISTS ar_sessions (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    jurisdiction_id UUID REFERENCES jurisdiction(id),
    project_id UUID,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ar_measurements (
    id UUID PRIMARY KEY,
    session_id UUID REFERENCES ar_sessions(id),
    type VARCHAR(50) NOT NULL,
    value FLOAT NOT NULL,
    unit VARCHAR(20) NOT NULL,
    start_point_x FLOAT,
    start_point_y FLOAT,
    start_point_z FLOAT,
    end_point_x FLOAT,
    end_point_y FLOAT,
    end_point_z FLOAT,
    confidence FLOAT,
    label VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_ar_sessions_user_id ON ar_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_ar_measurements_session_id ON ar_measurements(session_id);
