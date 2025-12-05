-- Seed Data: Initial Code Source Registry
-- Purpose: Populate code_source_registry with 15 known building code sources
-- Date: 2025-12-05
-- Run after: 004_add_autonomous_agents.sql migration

-- ============================================================================
-- NATIONAL / MODEL CODE SOURCES
-- ============================================================================

-- 1. ICC Digital Codes Premium (Premier Source - Model Codes)
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    auth_type,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'ICC Digital Codes Premium',
    'web_portal',
    'https://codes.iccsafe.org',
    TRUE,
    'api_key',
    0.95,
    ARRAY['ALL'],  -- Supports all jurisdictions (model codes)
    NULL,  -- No known rate limit with subscription
    '{
        "requires_subscription": true,
        "code_families": ["IRC", "IBC", "IFC", "IECC", "IPC", "IMC", "IFGC", "IPMC", "IEBC"],
        "editions": ["2024", "2021", "2018", "2015", "2012"],
        "access_type": "html",
        "search_pattern": "https://codes.iccsafe.org/codes/{code_family}/{edition}",
        "features": ["full_text_search", "section_linking", "amendments"]
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 2. ICC Public Codes (Free Access)
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'ICC Public Codes',
    'web_portal',
    'https://codes.iccsafe.org/public',
    FALSE,
    0.90,
    ARRAY['ALL'],
    60,  -- Conservative rate limit for free tier
    '{
        "requires_subscription": false,
        "code_families": ["IRC", "IBC", "IFC"],
        "editions": ["2021", "2018"],
        "access_type": "html",
        "limitations": "Limited to recent editions only"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- ============================================================================
-- MUNICIPAL CODE PUBLISHERS (Multi-State Coverage)
-- ============================================================================

-- 3. Municode Library
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Municode Library',
    'web_portal',
    'https://library.municode.com',
    FALSE,
    0.88,
    ARRAY['AL','AZ','CA','CO','FL','GA','IL','NC','NV','TX','WA'],
    100,
    '{
        "search_pattern": "https://library.municode.com/{state_lower}/{city_slug}/codes/code_of_ordinances",
        "access_type": "html",
        "has_api": false,
        "robots_txt_compliant": true,
        "parsing_strategy": "beautifulsoup",
        "typical_structure": "div.MuniCodeContent",
        "major_cities": ["Atlanta", "Austin", "Charlotte", "Denver", "Las Vegas", "Phoenix", "San Francisco"]
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 4. eCode360 (General Code)
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'eCode360',
    'web_portal',
    'https://ecode360.com',
    FALSE,
    0.85,
    ARRAY['CA','CT','MA','MD','NJ','NY','PA','VA'],
    60,
    '{
        "search_pattern": "https://ecode360.com/{state_abbr}/{jurisdiction_name}",
        "access_type": "html",
        "has_search": true,
        "robots_txt_compliant": true,
        "parsing_strategy": "beautifulsoup",
        "typical_structure": "div.eCodeContent",
        "major_cities": ["New York City boroughs", "Philadelphia", "Boston suburbs", "Northern Virginia"]
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 5. American Legal Publishing
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'American Legal Publishing',
    'web_portal',
    'https://codelibrary.amlegal.com',
    FALSE,
    0.82,
    ARRAY['AZ','CA','CO','OR','TX','UT','WA'],
    80,
    '{
        "search_pattern": "https://codelibrary.amlegal.com/{jurisdiction_slug}",
        "access_type": "html",
        "has_pdf": true,
        "robots_txt_compliant": true,
        "parsing_strategy": "beautifulsoup",
        "typical_structure": "div.CodeContent",
        "major_cities": ["Seattle", "Portland", "Salt Lake City", "Tucson", "San Diego"]
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 6. Codified Ordinances (Code Publishing Co.)
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Code Publishing Co.',
    'web_portal',
    'https://www.codepublishing.com',
    FALSE,
    0.78,
    ARRAY['CA','OR','WA'],
    50,
    '{
        "search_pattern": "https://www.codepublishing.com/{state}/{city}",
        "access_type": "html",
        "has_pdf": true,
        "robots_txt_compliant": true,
        "parsing_strategy": "beautifulsoup",
        "coverage": "Primarily Pacific Northwest"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- ============================================================================
-- STATE-SPECIFIC BUILDING CODE SOURCES
-- ============================================================================

-- 7. California Building Standards Commission
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'California Building Standards Commission',
    'pdf_repository',
    'https://www.dgs.ca.gov/BSC',
    FALSE,
    0.90,
    ARRAY['CA'],
    50,
    '{
        "state_codes": true,
        "pdf_repository": true,
        "code_families": ["California Building Code", "California Residential Code", "California Fire Code"],
        "editions": ["2022", "2019", "2016"],
        "download_pattern": "https://www.dgs.ca.gov/BSC/Codes",
        "official": true,
        "parsing_strategy": "pdfplumber",
        "notes": "Triennial code adoption (every 3 years)"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 8. Texas Department of Licensing and Regulation
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Texas Department of Licensing and Regulation',
    'web_portal',
    'https://www.tdlr.texas.gov',
    FALSE,
    0.87,
    ARRAY['TX'],
    50,
    '{
        "state_codes": true,
        "code_families": ["IRC", "IBC", "IFC", "NEC"],
        "editions": ["2021", "2018"],
        "base_path": "/architecture-engineering-construction/building-codes",
        "official": true,
        "parsing_strategy": "html",
        "notes": "Adopts ICC codes with state amendments"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 9. Florida Building Commission
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Florida Building Commission',
    'web_portal',
    'https://floridabuilding.org',
    FALSE,
    0.89,
    ARRAY['FL'],
    50,
    '{
        "state_codes": true,
        "has_amendments": true,
        "code_families": ["Florida Building Code", "Florida Residential Code", "Florida Fire Prevention Code"],
        "editions": ["2023", "2020", "2017"],
        "official": true,
        "parsing_strategy": "html",
        "features": ["online_portal", "amendment_tracking"],
        "notes": "Extensive state amendments to ICC base codes"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 10. New York State Building Code
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'New York State Division of Building Standards',
    'pdf_repository',
    'https://dos.ny.gov/building-codes',
    FALSE,
    0.86,
    ARRAY['NY'],
    50,
    '{
        "state_codes": true,
        "pdf_based": true,
        "code_families": ["Uniform Code", "Residential Code", "Fire Code"],
        "editions": ["2020", "2017", "2015"],
        "official": true,
        "parsing_strategy": "PyPDF2",
        "download_pattern": "https://dos.ny.gov/system/files/documents/{year}/{code}.pdf",
        "notes": "Primarily PDF downloads, extensive local amendments in NYC"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 11. Illinois Capital Development Board
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Illinois Capital Development Board',
    'web_portal',
    'https://www2.illinois.gov/cdb',
    FALSE,
    0.83,
    ARRAY['IL'],
    50,
    '{
        "state_codes": true,
        "code_families": ["Illinois Building Code", "Illinois Plumbing Code"],
        "editions": ["2021", "2018"],
        "official": true,
        "base_path": "/building-codes",
        "parsing_strategy": "html",
        "notes": "Adopts IBC with state-specific amendments"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 12. Washington State Building Code Council
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Washington State Building Code Council',
    'web_portal',
    'https://sbcc.wa.gov',
    FALSE,
    0.88,
    ARRAY['WA'],
    50,
    '{
        "state_codes": true,
        "code_families": ["Washington State Building Code", "Washington State Residential Code"],
        "editions": ["2021", "2018", "2015"],
        "official": true,
        "features": ["online_viewer", "amendment_tracker"],
        "parsing_strategy": "html",
        "notes": "Well-structured online interface"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 13. Massachusetts State Building Code
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Massachusetts Board of Building Regulations',
    'pdf_repository',
    'https://www.mass.gov/building-code',
    FALSE,
    0.85,
    ARRAY['MA'],
    50,
    '{
        "state_codes": true,
        "pdf_based": true,
        "code_families": ["Base Building Code", "Residential Code", "Accessibility Code"],
        "editions": ["10th Edition", "9th Edition", "8th Edition"],
        "official": true,
        "parsing_strategy": "pdfplumber",
        "notes": "Uses unique edition numbering system"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 14. Colorado Division of Fire Prevention & Control
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Colorado Division of Fire Prevention',
    'web_portal',
    'https://dfpc.colorado.gov',
    FALSE,
    0.84,
    ARRAY['CO'],
    50,
    '{
        "state_codes": true,
        "code_families": ["IBC", "IRC", "IFC"],
        "editions": ["2021", "2018"],
        "official": true,
        "base_path": "/building-codes",
        "parsing_strategy": "html",
        "notes": "State adopts ICC codes with local jurisdiction amendments"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- 15. Georgia Department of Community Affairs
INSERT INTO code_source_registry (
    source_name,
    source_type,
    base_url,
    requires_auth,
    reliability_score,
    supports_jurisdictions,
    rate_limit_per_hour,
    metadata
) VALUES (
    'Georgia Department of Community Affairs',
    'web_portal',
    'https://www.dca.ga.gov',
    FALSE,
    0.86,
    ARRAY['GA'],
    50,
    '{
        "state_codes": true,
        "code_families": ["Georgia State Minimum Standard Codes"],
        "editions": ["2023", "2020", "2018"],
        "official": true,
        "base_path": "/safe-affordable-housing/codes-construction-standards",
        "parsing_strategy": "html",
        "features": ["amendment_register"],
        "notes": "Maintains comprehensive state amendment register"
    }'::JSONB
) ON CONFLICT (source_name) DO NOTHING;

-- ============================================================================
-- VERIFICATION & STATISTICS
-- ============================================================================

-- Display summary of seeded sources
DO $$
DECLARE
    v_count INT;
    v_states TEXT[];
BEGIN
    SELECT COUNT(*), array_agg(DISTINCT unnest(supports_jurisdictions))
    INTO v_count, v_states
    FROM code_source_registry;

    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Code Source Registry Seeded Successfully';
    RAISE NOTICE '======================================================================';
    RAISE NOTICE 'Total Sources: %', v_count;
    RAISE NOTICE 'States Covered: %', array_length(v_states, 1);
    RAISE NOTICE '';
    RAISE NOTICE 'Source Types:';

    FOR rec IN (
        SELECT source_type, COUNT(*) as count
        FROM code_source_registry
        GROUP BY source_type
        ORDER BY count DESC
    ) LOOP
        RAISE NOTICE '  - %: % sources', rec.source_type, rec.count;
    END LOOP;

    RAISE NOTICE '';
    RAISE NOTICE 'Coverage Analysis:';
    RAISE NOTICE '  - National/Model Codes: 2 sources';
    RAISE NOTICE '  - Multi-State Publishers: 4 sources';
    RAISE NOTICE '  - State-Specific: 9 sources';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '  1. Test source discovery with real jurisdictions';
    RAISE NOTICE '  2. Implement HTML/PDF scraping in document_fetcher_agent.py';
    RAISE NOTICE '  3. Build source verification workflow';
    RAISE NOTICE '======================================================================';
END
$$;

-- Create view for quick source lookup by state
CREATE OR REPLACE VIEW sources_by_state AS
SELECT
    unnest(supports_jurisdictions) as state_code,
    source_name,
    source_type,
    reliability_score,
    requires_auth,
    base_url
FROM code_source_registry
WHERE is_active = TRUE
ORDER BY state_code, reliability_score DESC;

COMMENT ON VIEW sources_by_state IS 'Quick lookup of available sources for each state';

-- Success message
SELECT 'Seed data loaded successfully! 15 code sources covering 15+ states.' as status;
