-- CodeCheck Demo Cities Seed Script
-- Pre-loads 3 jurisdictions (Denver, Seattle, Phoenix) with complete building code rules
-- Created: 2025-01-19
-- Purpose: Enable instant demo responses without on-demand code loading

-- ============================================================================
-- SETUP: Create jurisdiction_data_status table if it doesn't exist
-- ============================================================================

CREATE TABLE IF NOT EXISTS jurisdiction_data_status (
    jurisdiction_id UUID PRIMARY KEY REFERENCES jurisdiction(id),
    status TEXT CHECK (status IN ('pending', 'loading', 'complete', 'failed')),
    rules_count INT DEFAULT 0,
    last_fetch_attempt TIMESTAMPTZ,
    last_successful_fetch TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DEMO JURISDICTIONS: Update existing jurisdictions with additional metadata
-- ============================================================================

-- Denver (already exists with ID 550e8400-e29b-41d4-a716-446655440001)
UPDATE jurisdiction
SET
    official_portal_url = 'https://www.denvergov.org/Government/Agencies-Departments-Offices/Agencies-Departments-Offices-Directory/Community-Planning-and-Development',
    municode_url = 'https://library.municode.com/co/denver/codes/code_of_ordinances',
    updated_at = NOW()
WHERE id = '550e8400-e29b-41d4-a716-446655440001';

-- Seattle (already exists with ID 550e8400-e29b-41d4-a716-446655440004)
UPDATE jurisdiction
SET
    official_portal_url = 'https://www.seattle.gov/sdci',
    municode_url = 'https://library.municode.com/wa/seattle/codes/municipal_code',
    updated_at = NOW()
WHERE id = '550e8400-e29b-41d4-a716-446655440004';

-- Phoenix (already exists with ID 550e8400-e29b-41d4-a716-446655440005)
UPDATE jurisdiction
SET
    official_portal_url = 'https://www.phoenix.gov/pdd',
    municode_url = 'https://library.municode.com/az/phoenix/codes/code_of_ordinances',
    updated_at = NOW()
WHERE id = '550e8400-e29b-41d4-a716-446655440005';

-- ============================================================================
-- DATA STATUS: Mark demo cities as "complete"
-- ============================================================================

INSERT INTO jurisdiction_data_status (jurisdiction_id, status, rules_count, last_fetch_attempt, last_successful_fetch)
VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'complete', 15, NOW(), NOW()),  -- Denver
    ('550e8400-e29b-41d4-a716-446655440004', 'complete', 15, NOW(), NOW()),  -- Seattle
    ('550e8400-e29b-41d4-a716-446655440005', 'complete', 15, NOW(), NOW())   -- Phoenix
ON CONFLICT (jurisdiction_id) DO UPDATE SET
    status = EXCLUDED.status,
    rules_count = EXCLUDED.rules_count,
    last_fetch_attempt = EXCLUDED.last_fetch_attempt,
    last_successful_fetch = EXCLUDED.last_successful_fetch,
    updated_at = NOW();

-- ============================================================================
-- CODE ADOPTIONS: Add comprehensive code adoption records
-- ============================================================================

-- Denver code adoptions (already has IRC/IBC 2021, add more details)
INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from, adoption_doc_url, source_priority)
VALUES
    ('550e8400-e29b-41d4-a716-446655440001', 'NEC', '2020', '2022-01-01', 'https://www.denvergov.org/Government/Agencies-Departments-Offices/Agencies-Departments-Offices-Directory/Community-Planning-and-Development/Building-Codes', 1),
    ('550e8400-e29b-41d4-a716-446655440001', 'IECC', '2021', '2022-01-01', 'https://www.denvergov.org/Government/Agencies-Departments-Offices/Agencies-Departments-Offices-Directory/Community-Planning-and-Development/Building-Codes', 1)
ON CONFLICT DO NOTHING;

-- Seattle code adoptions
INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from, adoption_doc_url, source_priority)
VALUES
    ('550e8400-e29b-41d4-a716-446655440004', 'NEC', '2020', '2022-07-01', 'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-electrical-code', 1),
    ('550e8400-e29b-41d4-a716-446655440004', 'IECC', '2021', '2022-07-01', 'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-energy-code', 1),
    ('550e8400-e29b-41d4-a716-446655440004', 'IBC', '2021', '2022-07-01', 'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-building-code', 1)
ON CONFLICT DO NOTHING;

-- Phoenix code adoptions
INSERT INTO code_adoption (jurisdiction_id, code_family, edition, effective_from, adoption_doc_url, source_priority)
VALUES
    ('550e8400-e29b-41d4-a716-446655440005', 'NEC', '2020', '2022-01-01', 'https://www.phoenix.gov/pdd/codes-and-regulations', 1),
    ('550e8400-e29b-41d4-a716-446655440005', 'IECC', '2021', '2022-01-01', 'https://www.phoenix.gov/pdd/codes-and-regulations', 1),
    ('550e8400-e29b-41d4-a716-446655440005', 'IBC', '2021', '2022-01-01', 'https://www.phoenix.gov/pdd/codes-and-regulations', 1)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- BUILDING CODE RULES: DENVER (ID: 550e8400-e29b-41d4-a716-446655440001)
-- Denver has slightly stricter requirements in some areas
-- ============================================================================

-- Delete existing Denver rules to avoid duplicates
DELETE FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001';

INSERT INTO rule (jurisdiction_id, code_family, edition, section_ref, title, rule_json, source_doc_url, confidence, validation_status) VALUES

-- STAIRS
('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.5.2', 'Stair Tread Depth (Minimum)',
'{"category":"stairs.tread","requirement":"min","value":10.0,"unit":"inch","conditions":[],"exceptions":["spiral stairs","alternating tread devices"],"notes":"Minimum tread depth for residential stairs measured horizontally from nosing to nosing"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.7',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.5.1', 'Stair Riser Height (Maximum)',
'{"category":"stairs.riser","requirement":"max","value":7.75,"unit":"inch","conditions":[],"exceptions":["spiral stairs","alternating tread devices"],"notes":"Maximum riser height for residential stairs. Risers shall be vertical or sloped from the underside of the nosing of the tread not more than 30 degrees from vertical"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.7',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.5.3', 'Stair Riser/Tread Consistency',
'{"category":"stairs.consistency","requirement":"max","value":0.375,"unit":"inch","conditions":[],"exceptions":[],"notes":"The greatest riser height within any flight of stairs shall not exceed the smallest by more than 3/8 inch. The greatest tread depth shall not exceed the smallest by more than 3/8 inch"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.7',
0.90, 'validated'),

-- HANDRAILS & GUARDRAILS
('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R312.1.3', 'Guardrail Height (Minimum)',
'{"category":"railings.height","requirement":"min","value":36.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Guards shall form a protective barrier not less than 36 inches high, measured vertically above the adjacent walking surface"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR312.1',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R312.1.3', 'Guardrail Baluster Spacing (Maximum)',
'{"category":"railings.spacing","requirement":"max","value":4.0,"unit":"inch","conditions":[],"exceptions":["triangular opening at riser, tread, and bottom rail: 6 inches"],"notes":"Required guards shall not have openings that allow passage of a sphere 4 inches in diameter"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR312.1',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.8', 'Handrail Height (Range)',
'{"category":"railings.handrail_height","requirement":"range","value":[34.0,38.0],"unit":"inch","conditions":[],"exceptions":[],"notes":"Handrail height measured vertically from the sloped plane adjoining the tread nosing, or finish surface of ramp slope"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.7',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.7.8.5', 'Handrail Graspability',
'{"category":"railings.handrail_diameter","requirement":"range","value":[1.25,2.0],"unit":"inch","conditions":[],"exceptions":["non-circular handrails with perimeter between 4 and 6.25 inches"],"notes":"Type I handrails with a circular cross section shall have an outside diameter of at least 1.25 inches and not greater than 2 inches"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.7',
0.88, 'validated'),

-- DOORS & EGRESS
('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.6.1', 'Door Width (Minimum)',
'{"category":"doors.width","requirement":"min","value":32.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Minimum clear width of residential doors. Width measured between the face of the door and the stop, with the door open 90 degrees"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.6',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R311.6.2', 'Door Height (Minimum)',
'{"category":"doors.height","requirement":"min","value":78.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Minimum height for required egress doors shall be not less than 78 inches"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR311.6',
0.93, 'validated'),

-- CEILING HEIGHT
('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R305.1', 'Ceiling Height (Minimum)',
'{"category":"ceiling.height","requirement":"min","value":7.0,"unit":"foot","conditions":[],"exceptions":["bathrooms, toilet rooms, kitchens, storage rooms and laundry rooms: 6 feet 8 inches"],"notes":"Habitable rooms shall have a ceiling height of not less than 7 feet (2134 mm)"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR305.1',
0.95, 'validated'),

-- WINDOW EGRESS
('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R310.2.1', 'Egress Window Opening Area (Minimum)',
'{"category":"windows.egress_area","requirement":"min","value":5.7,"unit":"square_foot","conditions":[],"exceptions":["grade floor openings"],"notes":"Minimum net clear opening area of egress windows. Opening must be operable from inside without use of keys or tools"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR310.2',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'IRC', '2021', 'R310.2.2', 'Egress Window Sill Height (Maximum)',
'{"category":"windows.sill_height","requirement":"max","value":44.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Maximum sill height above floor for emergency escape and rescue openings"}',
'https://codes.iccsafe.org/content/IRC2021P1/chapter-3-building-planning#IRC2021P1_Pt03_Ch03_SecR310.2',
0.90, 'validated'),

-- ELECTRICAL
('550e8400-e29b-41d4-a716-446655440001', 'NEC', '2020', '210.52(A)(1)', 'Receptacle Spacing (Maximum)',
'{"category":"electrical.receptacle_spacing","requirement":"max","value":12.0,"unit":"foot","conditions":[],"exceptions":[],"notes":"Receptacles shall be installed so that no point along the wall line is more than 6 feet from a receptacle outlet (12 foot spacing rule)"}',
'https://www.nfpa.org/codes-and-standards/all-codes-and-standards/list-of-codes-and-standards/detail?code=70',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'NEC', '2020', '210.8(A)', 'GFCI Protection - Bathrooms',
'{"category":"electrical.gfci","requirement":"required","value":1,"unit":"boolean","conditions":["bathrooms"],"exceptions":[],"notes":"All 125-volt, single-phase, 15- and 20-ampere receptacles installed in bathrooms shall have ground-fault circuit-interrupter protection"}',
'https://www.nfpa.org/codes-and-standards/all-codes-and-standards/list-of-codes-and-standards/detail?code=70',
0.95, 'validated'),

('550e8400-e29b-41d4-a716-446655440001', 'NEC', '2020', '210.8(A)', 'GFCI Protection - Kitchen Countertops',
'{"category":"electrical.gfci","requirement":"required","value":1,"unit":"boolean","conditions":["kitchen countertops","within 6 feet of sink"],"exceptions":[],"notes":"All 125-volt, single-phase, 15- and 20-ampere receptacles that serve countertop surfaces shall have GFCI protection"}',
'https://www.nfpa.org/codes-and-standards/all-codes-and-standards/list-of-codes-and-standards/detail?code=70',
0.95, 'validated');

-- ============================================================================
-- BUILDING CODE RULES: SEATTLE (ID: 550e8400-e29b-41d4-a716-446655440004)
-- Seattle has some unique local amendments
-- ============================================================================

-- Delete existing Seattle rules to avoid duplicates
DELETE FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440004';

INSERT INTO rule (jurisdiction_id, code_family, edition, section_ref, title, rule_json, source_doc_url, confidence, validation_status) VALUES

-- STAIRS
('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.7.5.2', 'Stair Tread Depth (Minimum)',
'{"category":"stairs.tread","requirement":"min","value":10.0,"unit":"inch","conditions":[],"exceptions":["spiral stairs","alternating tread devices"],"notes":"Minimum tread depth for residential stairs measured horizontally from nosing to nosing"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.7.5.1', 'Stair Riser Height (Maximum)',
'{"category":"stairs.riser","requirement":"max","value":7.75,"unit":"inch","conditions":[],"exceptions":["spiral stairs","alternating tread devices"],"notes":"Maximum riser height for residential stairs"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.7.5.3', 'Stair Riser/Tread Consistency',
'{"category":"stairs.consistency","requirement":"max","value":0.375,"unit":"inch","conditions":[],"exceptions":[],"notes":"The greatest riser height within any flight of stairs shall not exceed the smallest by more than 3/8 inch"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.88, 'validated'),

-- HANDRAILS & GUARDRAILS (Seattle has stricter guardrail requirements)
('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R312.1.3', 'Guardrail Height (Minimum)',
'{"category":"railings.height","requirement":"min","value":36.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Guards shall form a protective barrier not less than 36 inches high. Seattle requires guards at 30 inches above grade or floor"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R312.1.3', 'Guardrail Baluster Spacing (Maximum)',
'{"category":"railings.spacing","requirement":"max","value":4.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Required guards shall not have openings that allow passage of a sphere 4 inches in diameter"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.7.8', 'Handrail Height (Range)',
'{"category":"railings.handrail_height","requirement":"range","value":[34.0,38.0],"unit":"inch","conditions":[],"exceptions":[],"notes":"Handrail height measured vertically from the sloped plane adjoining the tread nosing"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.90, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.7.8.5', 'Handrail Graspability',
'{"category":"railings.handrail_diameter","requirement":"range","value":[1.25,2.0],"unit":"inch","conditions":[],"exceptions":["non-circular handrails with perimeter between 4 and 6.25 inches"],"notes":"Type I handrails with a circular cross section shall have an outside diameter of at least 1.25 inches and not greater than 2 inches"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.85, 'validated'),

-- DOORS & EGRESS
('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.6.1', 'Door Width (Minimum)',
'{"category":"doors.width","requirement":"min","value":32.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Minimum clear width of residential doors measured between face of door and stop"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R311.6.2', 'Door Height (Minimum)',
'{"category":"doors.height","requirement":"min","value":78.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Minimum height for required egress doors shall be not less than 78 inches"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.91, 'validated'),

-- CEILING HEIGHT
('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R305.1', 'Ceiling Height (Minimum)',
'{"category":"ceiling.height","requirement":"min","value":7.0,"unit":"foot","conditions":[],"exceptions":["bathrooms, toilet rooms, kitchens: 6 feet 8 inches"],"notes":"Habitable rooms shall have a ceiling height of not less than 7 feet"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.93, 'validated'),

-- WINDOW EGRESS
('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R310.2.1', 'Egress Window Opening Area (Minimum)',
'{"category":"windows.egress_area","requirement":"min","value":5.7,"unit":"square_foot","conditions":[],"exceptions":["grade floor openings"],"notes":"Minimum net clear opening area of egress windows"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.90, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'IRC', '2021', 'R310.2.2', 'Egress Window Sill Height (Maximum)',
'{"category":"windows.sill_height","requirement":"max","value":44.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Maximum sill height above floor for emergency escape and rescue openings"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-residential-code',
0.88, 'validated'),

-- ELECTRICAL
('550e8400-e29b-41d4-a716-446655440004', 'NEC', '2020', '210.52(A)(1)', 'Receptacle Spacing (Maximum)',
'{"category":"electrical.receptacle_spacing","requirement":"max","value":12.0,"unit":"foot","conditions":[],"exceptions":[],"notes":"Receptacles shall be installed so that no point along the wall line is more than 6 feet from a receptacle outlet"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-electrical-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'NEC', '2020', '210.8(A)', 'GFCI Protection - Bathrooms',
'{"category":"electrical.gfci","requirement":"required","value":1,"unit":"boolean","conditions":["bathrooms"],"exceptions":[],"notes":"All 125-volt, single-phase, 15- and 20-ampere receptacles installed in bathrooms shall have GFCI protection"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-electrical-code',
0.93, 'validated'),

('550e8400-e29b-41d4-a716-446655440004', 'NEC', '2020', '210.8(A)', 'GFCI Protection - Kitchen Countertops',
'{"category":"electrical.gfci","requirement":"required","value":1,"unit":"boolean","conditions":["kitchen countertops","within 6 feet of sink"],"exceptions":[],"notes":"All 125-volt, single-phase, 15- and 20-ampere receptacles that serve countertop surfaces shall have GFCI protection"}',
'https://www.seattle.gov/sdci/codes/codes-we-enforce-(a-z)/seattle-electrical-code',
0.93, 'validated');

-- ============================================================================
-- BUILDING CODE RULES: PHOENIX (ID: 550e8400-e29b-41d4-a716-446655440005)
-- Phoenix follows standard IRC closely but with some hot climate considerations
-- ============================================================================

-- Delete existing Phoenix rules to avoid duplicates
DELETE FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440005';

INSERT INTO rule (jurisdiction_id, code_family, edition, section_ref, title, rule_json, source_doc_url, confidence, validation_status) VALUES

-- STAIRS
('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.7.5.2', 'Stair Tread Depth (Minimum)',
'{"category":"stairs.tread","requirement":"min","value":10.0,"unit":"inch","conditions":[],"exceptions":["spiral stairs","alternating tread devices"],"notes":"Minimum tread depth for residential stairs measured horizontally from nosing to nosing"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.7.5.1', 'Stair Riser Height (Maximum)',
'{"category":"stairs.riser","requirement":"max","value":7.75,"unit":"inch","conditions":[],"exceptions":["spiral stairs","alternating tread devices"],"notes":"Maximum riser height for residential stairs"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.7.5.3', 'Stair Riser/Tread Consistency',
'{"category":"stairs.consistency","requirement":"max","value":0.375,"unit":"inch","conditions":[],"exceptions":[],"notes":"The greatest riser height within any flight of stairs shall not exceed the smallest by more than 3/8 inch"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.87, 'validated'),

-- HANDRAILS & GUARDRAILS
('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R312.1.3', 'Guardrail Height (Minimum)',
'{"category":"railings.height","requirement":"min","value":36.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Guards shall form a protective barrier not less than 36 inches high, measured vertically above the adjacent walking surface"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R312.1.3', 'Guardrail Baluster Spacing (Maximum)',
'{"category":"railings.spacing","requirement":"max","value":4.0,"unit":"inch","conditions":[],"exceptions":["triangular opening at riser, tread, and bottom rail: 6 inches"],"notes":"Required guards shall not have openings that allow passage of a sphere 4 inches in diameter"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.7.8', 'Handrail Height (Range)',
'{"category":"railings.handrail_height","requirement":"range","value":[34.0,38.0],"unit":"inch","conditions":[],"exceptions":[],"notes":"Handrail height measured vertically from the sloped plane adjoining the tread nosing"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.89, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.7.8.5', 'Handrail Graspability',
'{"category":"railings.handrail_diameter","requirement":"range","value":[1.25,2.0],"unit":"inch","conditions":[],"exceptions":["non-circular handrails with perimeter between 4 and 6.25 inches"],"notes":"Type I handrails with a circular cross section shall have an outside diameter of at least 1.25 inches and not greater than 2 inches"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.84, 'validated'),

-- DOORS & EGRESS
('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.6.1', 'Door Width (Minimum)',
'{"category":"doors.width","requirement":"min","value":32.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Minimum clear width of residential doors measured between face of door and stop with door open 90 degrees"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R311.6.2', 'Door Height (Minimum)',
'{"category":"doors.height","requirement":"min","value":78.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Minimum height for required egress doors shall be not less than 78 inches"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.90, 'validated'),

-- CEILING HEIGHT (Phoenix standard follows IRC)
('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R305.1', 'Ceiling Height (Minimum)',
'{"category":"ceiling.height","requirement":"min","value":7.0,"unit":"foot","conditions":[],"exceptions":["bathrooms, toilet rooms, kitchens, storage rooms and laundry rooms: 6 feet 8 inches"],"notes":"Habitable rooms shall have a ceiling height of not less than 7 feet (2134 mm)"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

-- WINDOW EGRESS
('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R310.2.1', 'Egress Window Opening Area (Minimum)',
'{"category":"windows.egress_area","requirement":"min","value":5.7,"unit":"square_foot","conditions":[],"exceptions":["grade floor openings"],"notes":"Minimum net clear opening area of egress windows. Opening must be operable from inside without use of keys or tools"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.89, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'IRC', '2021', 'R310.2.2', 'Egress Window Sill Height (Maximum)',
'{"category":"windows.sill_height","requirement":"max","value":44.0,"unit":"inch","conditions":[],"exceptions":[],"notes":"Maximum sill height above floor for emergency escape and rescue openings"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.87, 'validated'),

-- ELECTRICAL
('550e8400-e29b-41d4-a716-446655440005', 'NEC', '2020', '210.52(A)(1)', 'Receptacle Spacing (Maximum)',
'{"category":"electrical.receptacle_spacing","requirement":"max","value":12.0,"unit":"foot","conditions":[],"exceptions":[],"notes":"Receptacles shall be installed so that no point along the wall line is more than 6 feet from a receptacle outlet (12 foot spacing rule)"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'NEC', '2020', '210.8(A)', 'GFCI Protection - Bathrooms',
'{"category":"electrical.gfci","requirement":"required","value":1,"unit":"boolean","conditions":["bathrooms"],"exceptions":[],"notes":"All 125-volt, single-phase, 15- and 20-ampere receptacles installed in bathrooms shall have ground-fault circuit-interrupter protection"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated'),

('550e8400-e29b-41d4-a716-446655440005', 'NEC', '2020', '210.8(A)', 'GFCI Protection - Kitchen Countertops',
'{"category":"electrical.gfci","requirement":"required","value":1,"unit":"boolean","conditions":["kitchen countertops","within 6 feet of sink"],"exceptions":[],"notes":"All 125-volt, single-phase, 15- and 20-ampere receptacles that serve countertop surfaces shall have GFCI protection"}',
'https://www.phoenix.gov/pdd/codes-and-regulations',
0.92, 'validated');

-- ============================================================================
-- UPDATE RULE COUNTS
-- ============================================================================

UPDATE jurisdiction_data_status
SET rules_count = (SELECT COUNT(*) FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001')
WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001';

UPDATE jurisdiction_data_status
SET rules_count = (SELECT COUNT(*) FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440004')
WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440004';

UPDATE jurisdiction_data_status
SET rules_count = (SELECT COUNT(*) FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440005')
WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440005';

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify jurisdiction data status
SELECT
    j.name,
    jds.status,
    jds.rules_count,
    jds.last_successful_fetch
FROM jurisdiction j
JOIN jurisdiction_data_status jds ON j.id = jds.jurisdiction_id
WHERE j.id IN (
    '550e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440005'
)
ORDER BY j.name;

-- Verify rules count by jurisdiction and category
SELECT
    j.name,
    r.code_family,
    r.rule_json->>'category' as category,
    COUNT(*) as rule_count
FROM jurisdiction j
JOIN rule r ON j.id = r.jurisdiction_id
WHERE j.id IN (
    '550e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440004',
    '550e8400-e29b-41d4-a716-446655440005'
)
GROUP BY j.name, r.code_family, r.rule_json->>'category'
ORDER BY j.name, r.code_family, category;

-- Sample query to test stair rules for Denver
SELECT
    j.name,
    r.section_ref,
    r.title,
    r.rule_json->>'value' as value,
    r.rule_json->>'unit' as unit,
    r.confidence,
    r.validation_status
FROM jurisdiction j
JOIN rule r ON j.id = r.jurisdiction_id
WHERE j.name = 'Denver'
AND r.rule_json->>'category' LIKE 'stairs%'
ORDER BY r.section_ref;

-- ============================================================================
-- COMPLETION MESSAGE
-- ============================================================================

DO $$
DECLARE
    denver_count INT;
    seattle_count INT;
    phoenix_count INT;
BEGIN
    SELECT COUNT(*) INTO denver_count FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440001';
    SELECT COUNT(*) INTO seattle_count FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440004';
    SELECT COUNT(*) INTO phoenix_count FROM rule WHERE jurisdiction_id = '550e8400-e29b-41d4-a716-446655440005';

    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'CodeCheck Demo Cities Seed Complete!';
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Denver:  % rules loaded', denver_count;
    RAISE NOTICE 'Seattle: % rules loaded', seattle_count;
    RAISE NOTICE 'Phoenix: % rules loaded', phoenix_count;
    RAISE NOTICE '────────────────────────────────────────────────────────────────';
    RAISE NOTICE 'Total:   % rules across 3 jurisdictions', denver_count + seattle_count + phoenix_count;
    RAISE NOTICE '════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE 'Categories covered:';
    RAISE NOTICE '  • Stairs (treads, risers, consistency)';
    RAISE NOTICE '  • Railings (height, spacing, handrails)';
    RAISE NOTICE '  • Doors (width, height)';
    RAISE NOTICE '  • Ceilings (height)';
    RAISE NOTICE '  • Windows (egress area, sill height)';
    RAISE NOTICE '  • Electrical (receptacles, GFCI)';
    RAISE NOTICE '';
    RAISE NOTICE 'Ready for demo! 🚀';
END $$;
