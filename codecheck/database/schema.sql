-- CodeCheck Database Schema
-- PostgreSQL + PostGIS for construction compliance system

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Core jurisdiction management
CREATE TABLE jurisdiction (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT CHECK (type IN ('state','county','city','town','state_agency')),
    parent_id UUID NULL REFERENCES jurisdiction(id),
    geo_boundary GEOMETRY(POLYGON, 4326),
    fips_code TEXT,
    municode_url TEXT,
    ecode360_url TEXT,
    official_portal_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Code adoption tracking
CREATE TABLE code_adoption (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID NOT NULL REFERENCES jurisdiction(id),
    code_family TEXT NOT NULL,        -- 'IBC','IRC','IECC','IFC','NEC','ADA','ASHRAE 90.1'
    edition TEXT NOT NULL,            -- '2018','2021','2024', or 'Local Ordinance YYYY'
    effective_from DATE NOT NULL,
    effective_to DATE NULL,           -- NULL = current
    adoption_doc_url TEXT,
    source_priority INT DEFAULT 1,    -- to arbitrate conflicting sources
    checksum TEXT,                    -- of the source content
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Local amendments
CREATE TABLE amendment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID NOT NULL REFERENCES jurisdiction(id),
    code_family TEXT NOT NULL,
    edition TEXT NOT NULL,
    section_ref TEXT NOT NULL,        -- e.g., 'IBC 1011.5.2'
    change_type TEXT CHECK (change_type IN ('add','replace','delete')),
    redline TEXT,                     -- HTML/Markdown redline or diff
    citation_url TEXT,
    page_anchor TEXT,                 -- anchor or page number in PDF
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Flexible rule engine
CREATE TABLE rule (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID NOT NULL REFERENCES jurisdiction(id),
    code_family TEXT NOT NULL,
    edition TEXT NOT NULL,
    section_ref TEXT NOT NULL,
    title TEXT,
    rule_json JSONB NOT NULL,         -- structured fields (see below)
    source_doc_url TEXT,
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    validation_status TEXT CHECK (validation_status IN ('auto','needs_review','validated')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects for organizing measurements
CREATE TABLE project (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT,
    jurisdiction_id UUID NOT NULL REFERENCES jurisdiction(id),
    project_type TEXT,                -- 'deck','stairs','electrical', etc.
    status TEXT CHECK (status IN ('planning','in_progress','completed','cancelled')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Measurement results
CREATE TABLE measurement (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID NOT NULL REFERENCES project(id),
    rule_id UUID NOT NULL REFERENCES rule(id),
    measured_value DECIMAL NOT NULL,
    unit TEXT NOT NULL,
    is_compliant BOOLEAN NOT NULL,
    confidence REAL CHECK (confidence >= 0 AND confidence <= 1),
    location GEOMETRY(POINT, 4326),
    photo_url TEXT,
    notes TEXT,
    measured_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_jurisdiction_geo ON jurisdiction USING GIST(geo_boundary);
CREATE INDEX idx_jurisdiction_type ON jurisdiction(type);
CREATE INDEX idx_jurisdiction_parent ON jurisdiction(parent_id);

CREATE INDEX idx_code_adoption_jurisdiction ON code_adoption(jurisdiction_id);
CREATE INDEX idx_code_adoption_family ON code_adoption(code_family);
CREATE INDEX idx_code_adoption_effective ON code_adoption(effective_from, effective_to);

CREATE INDEX idx_amendment_jurisdiction ON amendment(jurisdiction_id);
CREATE INDEX idx_amendment_section ON amendment(section_ref);

CREATE INDEX idx_rule_jurisdiction ON rule(jurisdiction_id);
CREATE INDEX idx_rule_family ON rule(code_family);
CREATE INDEX idx_rule_section ON rule(section_ref);
CREATE INDEX idx_rule_confidence ON rule(confidence);
CREATE INDEX idx_rule_validation ON rule(validation_status);
CREATE INDEX idx_rule_json ON rule USING GIN(rule_json);

CREATE INDEX idx_project_jurisdiction ON project(jurisdiction_id);
CREATE INDEX idx_project_type ON project(project_type);

CREATE INDEX idx_measurement_project ON measurement(project_id);
CREATE INDEX idx_measurement_rule ON measurement(rule_id);
CREATE INDEX idx_measurement_compliance ON measurement(is_compliant);
CREATE INDEX idx_measurement_date ON measurement(measured_at);

-- Triggers for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_jurisdiction_updated_at BEFORE UPDATE ON jurisdiction FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_code_adoption_updated_at BEFORE UPDATE ON code_adoption FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_amendment_updated_at BEFORE UPDATE ON amendment FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_rule_updated_at BEFORE UPDATE ON rule FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_project_updated_at BEFORE UPDATE ON project FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Sample data for MVP testing
INSERT INTO jurisdiction (id, name, type, geo_boundary) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'Denver', 'city', ST_GeomFromText('POLYGON((-105.109927 39.614431, -104.600298 39.614431, -104.600298 39.914231, -105.109927 39.914231, -105.109927 39.614431))', 4326)),
    ('550e8400-e29b-41d4-a716-446655440002', 'Austin', 'city', ST_GeomFromText('POLYGON((-97.938382 30.098659, -97.561501 30.098659, -97.561501 30.516863, -97.938382 30.516863, -97.938382 30.098659))', 4326)),
    ('550e8400-e29b-41d4-a716-446655440003', 'Portland', 'city', ST_GeomFromText('POLYGON((-122.837979 45.451746, -122.472029 45.451746, -122.472029 45.652632, -122.837979 45.652632, -122.837979 45.451746))', 4326)),
    ('550e8400-e29b-41d4-a716-446655440004', 'Seattle', 'city', ST_GeomFromText('POLYGON((-122.459696 47.481002, -122.224433 47.481002, -122.224433 47.734145, -122.459696 47.734145, -122.459696 47.481002))', 4326)),
    ('550e8400-e29b-41d4-a716-446655440005', 'Phoenix', 'city', ST_GeomFromText('POLYGON((-112.205078 33.206032, -111.908447 33.206032, -111.908447 33.631912, -112.205078 33.631912, -112.205078 33.206032))', 4326));

-- Sample code adoptions
INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from) VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', '2022-01-01'),
    ('550e8400-e29b-41d4-a716-446655440001', 'IBC', '2021', '2022-01-01'),
    ('550e8400-e29b-41d4-a716-446655440002', 'IRC', '2021', '2022-01-01'),
    ('550e8400-e29b-41d4-a716-446655440003', 'IRC', '2021', '2022-01-01'),
    ('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', '2022-01-01'),
    ('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', '2022-01-01');

-- Sample rules for MVP testing (deck railings, stairs, door clearances)
INSERT INTO rule (jurisdiction_id, code_family, edition, section_ref, title, rule_json, confidence, validation_status) VALUES
    -- Deck railing rules
    ('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R312.1', 'Deck Guard Height', '{"category":"railings.height","requirement":"min","unit":"inch","value":36.0,"conditions":[],"exceptions":[],"notes":"Minimum height for deck guardrails"}', 0.95, 'validated'),
    ('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R312.2', 'Deck Guard Spacing', '{"category":"railings.spacing","requirement":"max","unit":"inch","value":4.0,"conditions":[],"exceptions":[],"notes":"Maximum spacing between balusters"}', 0.95, 'validated'),
    
    -- Stair rules
    ('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.2', 'Stair Riser Height', '{"category":"stairs.riser","requirement":"max","unit":"inch","value":7.75,"conditions":[],"exceptions":[],"notes":"Maximum riser height for stairs"}', 0.95, 'validated'),
    ('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.3', 'Stair Tread Depth', '{"category":"stairs.tread","requirement":"min","unit":"inch","value":11.0,"conditions":[],"exceptions":[],"notes":"Minimum tread depth for stairs"}', 0.95, 'validated'),
    
    -- Door clearance rules
    ('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.3.1', 'Door Width', '{"category":"doors.width","requirement":"min","unit":"inch","value":32.0,"conditions":[],"exceptions":[],"notes":"Minimum door width for egress"}', 0.95, 'validated');

-- Copy rules for other jurisdictions (simplified for MVP)
INSERT INTO rule (jurisdiction_id, code_family, edition, section_ref, title, rule_json, confidence, validation_status)
SELECT 
    j.id,
    r.code_family,
    r.edition,
    r.section_ref,
    r.title,
    r.rule_json,
    r.confidence,
    r.validation_status
FROM rule r
CROSS JOIN jurisdiction j
WHERE r.jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001'
AND j.id != '550e8400-e29b-41d4-a716-446655440001';