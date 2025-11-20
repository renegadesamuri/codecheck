# Agent Coordinator System for On-Demand Code Loading

This directory contains the multi-agent system for on-demand building code loading and extraction.

## Overview

The agent coordinator system enables just-in-time (JIT) loading of building codes for jurisdictions, eliminating the need to pre-populate the database with all codes. When a user requests building code information for a jurisdiction that hasn't been loaded yet, the system automatically:

1. **Discovers** code sources for that jurisdiction
2. **Fetches** the building code documents
3. **Extracts** structured rules using AI (Claude)
4. **Persists** the rules to the database for future use

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         User Request                         │
│              "Check compliance for stair in Denver"          │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
                    ┌────────────────┐
                    │  Check Cache   │
                    │ (Database has  │
                    │  rules?)       │
                    └────┬───────┬───┘
                         │       │
                    YES  │       │  NO
                         │       │
                         ▼       ▼
            ┌────────────┐   ┌──────────────────┐
            │   Return   │   │  Trigger Agent   │
            │   Rules    │   │   Coordinator    │
            │ (instant)  │   │  (background)    │
            └────────────┘   └────────┬─────────┘
                                      │
                                      ▼
                        ┌──────────────────────────┐
                        │    Agent Coordinator     │
                        │  1. Source Discovery     │
                        │  2. Document Fetcher     │
                        │  3. Rule Extractor       │
                        │  4. Database Writer      │
                        └─────────┬────────────────┘
                                  │
                                  ▼
                        ┌──────────────────┐
                        │   Rules Cached   │
                        │   in Database    │
                        └──────────────────┘
```

## Components

### 1. Agent Coordinator (`coordinator.py`)

The main orchestrator that manages the workflow and coordinates between agents.

**Key Features:**
- Orchestrates the entire code loading workflow
- Progress tracking with callbacks (0-100%)
- Comprehensive error handling with fallbacks
- Database integration for rule persistence
- Automatic fallback to model codes (IRC 2021, IBC 2021)

**Usage:**
```python
from coordinator import create_agent_coordinator

coordinator = create_agent_coordinator(
    db_config={...},
    claude_api_key="your-api-key"
)

result = await coordinator.load_codes_for_jurisdiction(
    jurisdiction_id="uuid-1234",
    jurisdiction_name="Denver, CO",
    jurisdiction_type="city",
    state="CO",
    progress_callback=lambda progress, msg: print(f"[{progress}%] {msg}")
)
```

### 2. Source Discovery Agent (`source_discovery_agent.py`)

Discovers building code sources for a jurisdiction.

**MVP Implementation:**
- Returns hardcoded model codes (IRC 2021, IBC 2021) for all jurisdictions
- Provides foundation for future jurisdiction-specific discovery

**Future Enhancements:**
- Web scraping of state building department websites
- Integration with Municode/eCode360 for local ordinances
- ICC Digital Codes API integration
- Discovery of local amendments

**Usage:**
```python
from source_discovery_agent import create_source_discovery_agent

agent = create_source_discovery_agent()
sources = await agent.discover_sources(
    jurisdiction_name="Austin, TX",
    jurisdiction_type="city",
    state="TX"
)
```

### 3. Document Fetcher Agent (`document_fetcher_agent.py`)

Fetches building code documents from various sources.

**MVP Implementation:**
- Returns sample code text for IRC 2021 and IBC 2021
- Includes realistic building code sections (stairs, railings, doors, etc.)
- Simulates network delays for realistic testing

**Future Enhancements:**
- PDF download and text extraction (PyPDF2, pdfplumber)
- HTML scraping (BeautifulSoup, lxml)
- OCR for scanned documents (Tesseract)
- Caching layer for performance

**Usage:**
```python
from document_fetcher_agent import create_document_fetcher_agent

agent = create_document_fetcher_agent()
document = await agent.fetch_document(source)

if agent.validate_document(document):
    stats = agent.get_document_stats(document)
    print(f"Fetched {stats['character_count']} characters")
```

### 4. Enhanced Rule Extractor (`enhanced_rule_extractor.py`)

Extracts structured rules from building code text using Claude AI.

**Features:**
- Primary extraction using Claude 3.5 Sonnet
- Fallback to traditional regex-based extraction
- Rule validation and confidence scoring
- Unit normalization (inches, feet, mm, cm, m)

**Usage:**
```python
from enhanced_rule_extractor import create_enhanced_extractor

extractor = create_enhanced_extractor(claude_api_key="your-api-key")
rules = await extractor.extract_rules(
    section_text="...",
    section_ref="R311.7.3",
    code_family="IRC",
    edition="2021"
)
```

## Database Schema

### `jurisdiction_data_status`

Tracks the loading status for each jurisdiction.

```sql
CREATE TABLE jurisdiction_data_status (
    jurisdiction_id UUID PRIMARY KEY,
    status TEXT,  -- 'pending', 'loading', 'complete', 'failed'
    rules_count INT DEFAULT 0,
    last_fetch_attempt TIMESTAMPTZ,
    last_successful_fetch TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### `agent_jobs`

Tracks background agent jobs for code loading.

```sql
CREATE TABLE agent_jobs (
    id UUID PRIMARY KEY,
    jurisdiction_id UUID,
    job_type TEXT,  -- 'load_codes', 'source_discovery', etc.
    status TEXT,  -- 'pending', 'running', 'completed', 'failed'
    progress_percentage INT DEFAULT 0,
    progress_message TEXT,
    result JSONB,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## API Endpoints

### Check Jurisdiction Status

```http
GET /jurisdictions/{jurisdiction_id}/status
```

**Response:**
```json
{
  "status": "ready|loading|not_loaded|failed",
  "rule_count": 15,
  "progress": 100,
  "message": "Rules available",
  "job_id": "uuid-1234"
}
```

### Trigger Code Loading

```http
POST /jurisdictions/{jurisdiction_id}/load-codes
```

**Response:**
```json
{
  "status": "initiated|loading|already_loaded",
  "job_id": "uuid-1234",
  "message": "Code loading initiated. This may take 30-60 seconds."
}
```

### Get Job Progress

```http
GET /jobs/{job_id}
```

**Response:**
```json
{
  "id": "uuid-1234",
  "status": "running",
  "progress": 66,
  "result": null,
  "error": null,
  "started_at": "2025-01-19T10:30:00Z",
  "completed_at": null
}
```

## Progress Tracking

The system provides real-time progress updates during code loading:

- **0-5%**: Initializing
- **5-33%**: Discovering code sources
- **33-66%**: Fetching documents
- **66-95%**: Extracting rules with AI
- **95-100%**: Saving to database

Progress callbacks are invoked throughout the workflow to update the client.

## Error Handling

The system includes comprehensive error handling:

1. **Source Discovery Failure**: Falls back to model codes
2. **Document Fetch Failure**: Skips failed sources, continues with others
3. **Rule Extraction Failure**: Falls back to regex-based extraction
4. **Database Error**: Rollback transaction, mark job as failed
5. **Missing Claude API Key**: Graceful degradation with error message

## Configuration

### Environment Variables

```bash
# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your-password
DB_NAME=codecheck

# Claude API Configuration
CLAUDE_API_KEY=your-anthropic-api-key
```

### Claude Model Configuration

The system uses Claude 3.5 Sonnet by default. You can customize in `enhanced_rule_extractor.py`:

```python
config = ClaudeConfig(
    api_key=api_key,
    model="claude-3-5-sonnet-20241022",
    max_tokens=4000,
    temperature=0.1
)
```

## Testing

### Manual Testing

Each agent includes a `__main__` section for standalone testing:

```bash
# Test source discovery
cd /path/to/codecheck/agents
python source_discovery_agent.py

# Test document fetcher
python document_fetcher_agent.py

# Test coordinator
python coordinator.py
```

### Integration Testing

Test the full workflow through the API:

```bash
# Start the API server
cd /path/to/codecheck/api
uvicorn main:app --reload

# In another terminal, trigger code loading
curl -X POST http://localhost:8000/jurisdictions/{id}/load-codes \
  -H "Authorization: Bearer your-token"

# Monitor progress
curl http://localhost:8000/jobs/{job_id} \
  -H "Authorization: Bearer your-token"
```

## Performance

### MVP Performance

- **Source Discovery**: ~0.5s (hardcoded model codes)
- **Document Fetching**: ~1s per document (simulated delay)
- **Rule Extraction**: ~3-5s per section with Claude
- **Total Time**: 30-60 seconds for typical jurisdiction

### Production Optimizations

1. **Parallel Processing**: Fetch documents concurrently
2. **Caching**: Cache frequently accessed documents
3. **Batch Extraction**: Process multiple sections in one Claude call
4. **Pre-emptive Loading**: Load codes for nearby jurisdictions
5. **Background Refresh**: Update stale codes quarterly

## Monitoring & Logging

### Logging Levels

```python
import logging

# Set logging level
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
```

### Key Metrics to Monitor

- Jurisdictions requested (which cities are popular)
- Load time per jurisdiction (optimize bottlenecks)
- Cache hit rate (% of requests served instantly)
- Failed loads (which cities can't be loaded)
- User wait time tolerance (do they wait or leave?)

## Future Enhancements

### Phase 2 (Post-MVP)

1. **Celery/RQ Integration**: Robust distributed job queue
2. **WebSocket Updates**: Real-time progress streaming
3. **Pre-emptive Loading**: Load nearby jurisdictions in advance
4. **Background Refresh**: Update stale codes quarterly
5. **User Corrections**: Allow users to submit rule corrections

### Phase 3 (Scale)

1. **ML Predictions**: Predict which cities to pre-load
2. **Distributed Agents**: Multiple workers across regions
3. **CDN Caching**: Edge caching for jurisdiction data
4. **Regional Specificity**: Downtown vs suburbs variations
5. **Multi-language Support**: International building codes

## Troubleshooting

### Common Issues

**Problem**: Rules not being extracted
- **Solution**: Check Claude API key is set and valid
- **Check**: `echo $CLAUDE_API_KEY`

**Problem**: Database connection failures
- **Solution**: Verify database credentials and connectivity
- **Check**: Test connection with `psql -h localhost -U postgres -d codecheck`

**Problem**: Job stuck in "running" status
- **Solution**: Check logs for errors, restart API server
- **Recovery**: Update job status manually in database

**Problem**: No sources discovered
- **Solution**: System falls back to model codes automatically
- **Future**: Implement jurisdiction-specific discovery

## Contributing

When adding new features:

1. **Add Logging**: Use appropriate log levels (INFO, WARNING, ERROR)
2. **Error Handling**: Always include try/except with fallback behavior
3. **Progress Updates**: Update progress callback at key milestones
4. **Documentation**: Update this README with new functionality
5. **Testing**: Include test code in `__main__` section

## Support

For issues or questions:
- Check logs in `/var/log/codecheck/` or console output
- Review database records in `agent_jobs` table
- Contact development team with job_id and error details

## License

Copyright 2025 CodeCheck. All rights reserved.
