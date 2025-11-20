# On-Demand Code Loading Architecture
**Created**: 2025-01-19
**Status**: Recommended Approach for MVP

## Overview

Instead of pre-populating the database with all building codes, implement a **Just-In-Time (JIT) loading system** where codes are fetched and cached only when users request them.

---

## Why This Approach?

### MVP Benefits
- **Launch immediately** - No multi-day data population phase
- **Lower infrastructure costs** - Only store what's used
- **Organic growth** - Database grows with real usage
- **Faster iteration** - Focus on features, not data entry
- **Proves market fit** - Usage patterns reveal demand

### Investor Appeal
- **Smart resource allocation** - Don't waste money on unused data
- **Scalable architecture** - Handles 10 users or 10,000
- **Data-driven growth** - Show which jurisdictions are popular
- **Lower burn rate** - Reduces ongoing costs

### Technical Advantages
- **No data licensing issues** - Fetch on-demand from public sources
- **Always current** - Fetch latest codes when requested
- **Graceful degradation** - Fall back to model codes if unavailable
- **Natural caching** - Popular jurisdictions cached forever

---

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                         User Request                         │
│              "Check compliance for stair in Denver"          │
└────────────────────────────┬────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                    Jurisdiction Resolver                     │
│           GPS (39.7392, -104.9903) → Denver, CO             │
│                   jurisdiction_id: uuid-1234                 │
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
            │   Rules    │   │   Job System     │
            │ (instant)  │   │  (background)    │
            └────────────┘   └────────┬─────────┘
                                      │
                                      ▼
                        ┌──────────────────────────┐
                        │    Agent Orchestrator    │
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

### Database Schema Enhancement

```sql
-- Track jurisdiction data status
CREATE TABLE jurisdiction_data_status (
    jurisdiction_id UUID PRIMARY KEY REFERENCES jurisdiction(id),
    status TEXT CHECK (status IN ('pending', 'loading', 'complete', 'failed')),
    rules_count INT DEFAULT 0,
    last_fetch_attempt TIMESTAMPTZ,
    last_successful_fetch TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Track agent jobs
CREATE TABLE agent_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    jurisdiction_id UUID REFERENCES jurisdiction(id),
    job_type TEXT NOT NULL, -- 'source_discovery', 'document_fetch', 'rule_extraction'
    status TEXT CHECK (status IN ('pending', 'running', 'completed', 'failed')),
    progress_percentage INT DEFAULT 0,
    result JSONB,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick lookups
CREATE INDEX idx_jurisdiction_data_status ON jurisdiction_data_status(jurisdiction_id, status);
CREATE INDEX idx_agent_jobs_jurisdiction ON agent_jobs(jurisdiction_id, status);
```

---

## Implementation Plan

### Phase 1: Backend Job System (4-6 hours)

#### 1.1 Simple Job Queue (No Celery Yet)
**File**: `/codecheck/api/job_queue.py`

```python
"""
Simple in-memory job queue for MVP
Can be replaced with Celery/RQ later
"""
import asyncio
import uuid
from typing import Dict, List, Optional
from enum import Enum
from dataclasses import dataclass
from datetime import datetime

class JobStatus(Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"

@dataclass
class Job:
    id: str
    jurisdiction_id: str
    job_type: str
    status: JobStatus
    progress: int = 0
    result: Optional[Dict] = None
    error: Optional[str] = None
    created_at: datetime = datetime.now()
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

class JobQueue:
    """Simple in-memory job queue"""

    def __init__(self):
        self.jobs: Dict[str, Job] = {}
        self.queue: List[str] = []
        self.running = False

    def add_job(self, jurisdiction_id: str, job_type: str) -> str:
        """Add a job to the queue"""
        job_id = str(uuid.uuid4())
        job = Job(
            id=job_id,
            jurisdiction_id=jurisdiction_id,
            job_type=job_type,
            status=JobStatus.PENDING
        )
        self.jobs[job_id] = job
        self.queue.append(job_id)
        return job_id

    def get_job(self, job_id: str) -> Optional[Job]:
        """Get job by ID"""
        return self.jobs.get(job_id)

    async def process_queue(self):
        """Process jobs in background"""
        # Implementation will trigger agents
        pass

# Global instance
job_queue = JobQueue()
```

#### 1.2 Jurisdiction Status Checker
**Add to**: `/codecheck/api/main.py`

```python
@app.get("/jurisdictions/{jurisdiction_id}/status")
async def get_jurisdiction_status(
    jurisdiction_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """Check if jurisdiction has rules loaded"""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            # Check rule count
            cursor.execute("""
                SELECT COUNT(*) as rule_count
                FROM rule
                WHERE jurisdiction_id = %s
            """, (jurisdiction_id,))

            result = cursor.fetchone()
            rule_count = result['rule_count']

            # Check if job is running
            cursor.execute("""
                SELECT status, progress_percentage
                FROM agent_jobs
                WHERE jurisdiction_id = %s
                AND status IN ('pending', 'running')
                ORDER BY created_at DESC
                LIMIT 1
            """, (jurisdiction_id,))

            job = cursor.fetchone()

            if rule_count > 0:
                return {
                    "status": "ready",
                    "rule_count": rule_count,
                    "message": "Rules available"
                }
            elif job:
                return {
                    "status": "loading",
                    "progress": job['progress_percentage'],
                    "message": "Loading building codes..."
                }
            else:
                return {
                    "status": "not_loaded",
                    "rule_count": 0,
                    "message": "No rules available yet"
                }
    finally:
        conn.close()
```

#### 1.3 Trigger Code Loading
**Add to**: `/codecheck/api/main.py`

```python
@app.post("/jurisdictions/{jurisdiction_id}/load-codes")
async def trigger_code_loading(
    jurisdiction_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """Trigger on-demand code loading for jurisdiction"""
    conn = get_db_connection()
    try:
        # Check if already loaded or loading
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT COUNT(*) as count FROM rule
                WHERE jurisdiction_id = %s
            """, (jurisdiction_id,))

            if cursor.fetchone()['count'] > 0:
                return {
                    "status": "already_loaded",
                    "message": "Codes already available"
                }

            # Check if job already running
            cursor.execute("""
                SELECT id FROM agent_jobs
                WHERE jurisdiction_id = %s
                AND status IN ('pending', 'running')
            """, (jurisdiction_id,))

            existing_job = cursor.fetchone()
            if existing_job:
                return {
                    "status": "loading",
                    "job_id": existing_job['id'],
                    "message": "Loading already in progress"
                }

        # Create new job
        job_id = job_queue.add_job(jurisdiction_id, "load_codes")

        # Record in database
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO agent_jobs (id, jurisdiction_id, job_type, status)
                VALUES (%s, %s, 'load_codes', 'pending')
            """, (job_id, jurisdiction_id))
            conn.commit()

        # Trigger background processing
        asyncio.create_task(process_code_loading(job_id, jurisdiction_id))

        return {
            "status": "initiated",
            "job_id": job_id,
            "message": "Code loading initiated"
        }

    finally:
        conn.close()

async def process_code_loading(job_id: str, jurisdiction_id: str):
    """Background task to load codes"""
    # This will orchestrate the agent system
    # For MVP: Can start simple and enhance later
    pass
```

### Phase 2: iOS Integration (2-3 hours)

#### 2.1 Check Jurisdiction Status
**Update**: `/codecheck/ios-app/CodeCheck/Services/CodeLookupService.swift`

```swift
func checkJurisdictionStatus(jurisdictionId: String) async throws -> JurisdictionStatus {
    let url = baseURL.appendingPathComponent("jurisdictions/\(jurisdictionId)/status")

    let (data, _) = try await authenticatedRequest(url: url, method: "GET")
    let status = try JSONDecoder().decode(JurisdictionStatus.self, from: data)
    return status
}

struct JurisdictionStatus: Codable {
    let status: String  // "ready", "loading", "not_loaded"
    let ruleCount: Int?
    let progress: Int?
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case ruleCount = "rule_count"
        case progress
        case message
    }
}
```

#### 2.2 Trigger Code Loading
```swift
func triggerCodeLoading(jurisdictionId: String) async throws -> CodeLoadingResponse {
    let url = baseURL.appendingPathComponent("jurisdictions/\(jurisdictionId)/load-codes")

    let (data, _) = try await authenticatedRequest(url: url, method: "POST")
    let response = try JSONDecoder().decode(CodeLoadingResponse.self, from: data)
    return response
}

struct CodeLoadingResponse: Codable {
    let status: String
    let jobId: String?
    let message: String

    enum CodingKeys: String, CodingKey {
        case status
        case jobId = "job_id"
        case message
    }
}
```

#### 2.3 Update UI for Loading State
**Update**: `/codecheck/ios-app/CodeCheck/Views/MeasurementView.swift`

```swift
private func checkCompliance() async {
    isCheckingCompliance = true
    errorMessage = nil

    do {
        // ... existing code to get jurisdiction ...

        // NEW: Check if codes are loaded
        let status = try await codeLookup.checkJurisdictionStatus(
            jurisdictionId: jurisdiction.id
        )

        switch status.status {
        case "ready":
            // Codes available, proceed
            break

        case "loading":
            // Show loading progress
            showLoadingProgress = true
            loadingProgress = status.progress ?? 0
            errorMessage = "Loading building codes for \(jurisdiction.name)..."

            // Poll for completion
            try await pollForCompletion(jurisdictionId: jurisdiction.id)

        case "not_loaded":
            // Trigger loading
            let response = try await codeLookup.triggerCodeLoading(
                jurisdictionId: jurisdiction.id
            )

            showLoadingProgress = true
            errorMessage = "Loading building codes for the first time. This may take 30-60 seconds..."

            // Poll for completion
            try await pollForCompletion(jurisdictionId: jurisdiction.id)

        default:
            break
        }

        // ... continue with existing compliance check ...

    } catch {
        // ... error handling ...
    }

    isCheckingCompliance = false
}

private func pollForCompletion(jurisdictionId: String) async throws {
    var attempts = 0
    let maxAttempts = 60  // 60 seconds max

    while attempts < maxAttempts {
        try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        let status = try await codeLookup.checkJurisdictionStatus(
            jurisdictionId: jurisdictionId
        )

        if status.status == "ready" {
            return
        }

        if let progress = status.progress {
            loadingProgress = progress
        }

        attempts += 1
    }

    throw APIError.timeout
}
```

### Phase 3: Agent Orchestration (4-6 hours)

#### 3.1 Simple Agent Coordinator
**File**: `/codecheck/agents/coordinator.py`

```python
"""
Agent Coordinator for On-Demand Code Loading
Orchestrates the 3-agent system
"""
import asyncio
from typing import Dict, Optional
from source_discovery_agent import SourceDiscoveryAgent
from document_fetcher_agent import DocumentFetcherAgent
from enhanced_rule_extractor import RuleExtractor

class AgentCoordinator:
    """Coordinates agent workflow for jurisdiction code loading"""

    def __init__(self):
        self.source_agent = SourceDiscoveryAgent()
        self.fetcher_agent = DocumentFetcherAgent()
        self.extractor_agent = RuleExtractor()

    async def load_codes_for_jurisdiction(
        self,
        jurisdiction_id: str,
        jurisdiction_name: str,
        progress_callback=None
    ) -> Dict:
        """
        Full workflow to load codes for a jurisdiction

        Returns:
            {
                "success": bool,
                "rules_count": int,
                "sources_found": int,
                "error": str (optional)
            }
        """
        try:
            # Step 1: Discover sources (33% progress)
            if progress_callback:
                progress_callback(10, "Discovering code sources...")

            sources = await self.source_agent.discover_sources(
                jurisdiction_name=jurisdiction_name
            )

            if not sources:
                # Fall back to model codes (IRC, IBC)
                sources = self._get_model_code_sources()

            if progress_callback:
                progress_callback(33, f"Found {len(sources)} code sources")

            # Step 2: Fetch documents (66% progress)
            if progress_callback:
                progress_callback(40, "Downloading code documents...")

            documents = []
            for i, source in enumerate(sources):
                doc = await self.fetcher_agent.fetch_document(source)
                if doc:
                    documents.append(doc)

                progress = 40 + int((i / len(sources)) * 26)
                if progress_callback:
                    progress_callback(progress, f"Downloaded {i+1}/{len(sources)} documents")

            # Step 3: Extract rules (100% progress)
            if progress_callback:
                progress_callback(70, "Extracting rules with AI...")

            all_rules = []
            for i, doc in enumerate(documents):
                rules = await self.extractor_agent.extract_rules(
                    document=doc,
                    jurisdiction_id=jurisdiction_id
                )
                all_rules.extend(rules)

                progress = 70 + int((i / len(documents)) * 30)
                if progress_callback:
                    progress_callback(progress, f"Extracted rules from {i+1}/{len(documents)} documents")

            # Step 4: Save to database
            if progress_callback:
                progress_callback(95, "Saving rules to database...")

            saved_count = await self._save_rules(jurisdiction_id, all_rules)

            if progress_callback:
                progress_callback(100, "Complete!")

            return {
                "success": True,
                "rules_count": saved_count,
                "sources_found": len(sources)
            }

        except Exception as e:
            return {
                "success": False,
                "error": str(e)
            }

    def _get_model_code_sources(self) -> list:
        """Fall back to model codes if jurisdiction-specific not found"""
        return [
            {
                "name": "ICC IRC 2021",
                "url": "https://codes.iccsafe.org/content/IRC2021P1",
                "type": "model_code"
            },
            {
                "name": "ICC IBC 2021",
                "url": "https://codes.iccsafe.org/content/IBC2021P1",
                "type": "model_code"
            }
        ]

    async def _save_rules(self, jurisdiction_id: str, rules: list) -> int:
        """Save extracted rules to database"""
        # Implementation
        pass
```

### Phase 4: Seed Data (30 minutes)

**Pre-load just 3 jurisdictions for instant demo**:

```sql
-- Seed script
-- /codecheck/database/seed_demo_jurisdictions.sql

-- These 3 jurisdictions will be pre-loaded for demos
-- All others load on-demand

-- Pre-load Denver
INSERT INTO jurisdiction_data_status (jurisdiction_id, status, rules_count, last_successful_fetch)
SELECT id, 'complete', 15, NOW()
FROM jurisdiction WHERE name = 'Denver';

-- Pre-load Seattle
INSERT INTO jurisdiction_data_status (jurisdiction_id, status, rules_count, last_successful_fetch)
SELECT id, 'complete', 15, NOW()
FROM jurisdiction WHERE name = 'Seattle';

-- Pre-load Phoenix
INSERT INTO jurisdiction_data_status (jurisdiction_id, status, rules_count, last_successful_fetch)
SELECT id, 'complete', 15, NOW()
FROM jurisdiction WHERE name = 'Phoenix';

-- Insert sample rules for these 3 cities
-- (Use existing sample rules from schema.sql)
```

---

## Demo Flow

### Scenario 1: Pre-loaded City (Instant)
```
User measures in Denver
→ Backend: "Denver rules cached (15 rules)"
→ Response time: 50ms
→ Results displayed immediately ✅
```

### Scenario 2: New City (On-Demand)
```
User measures in Austin
→ Backend: "No rules for Austin yet"
→ UI shows: "Loading building codes for Austin, TX..."
→ Progress: "Discovering sources... 33%"
→ Progress: "Downloading documents... 66%"
→ Progress: "Extracting rules with AI... 95%"
→ Complete: "Found 12 rules for Austin!"
→ Results displayed ✅
→ Next Austin user: Instant (cached)
```

### Investor Pitch
"Our platform intelligently loads building codes on-demand. We start lean and grow organically with real usage. Currently supporting 3 cities, but can scale to 100+ as users expand to new markets. This keeps costs low while proving market demand."

---

## Cost Comparison

### Old Approach (Pre-populate)
- Days 2-3: Research and populate 20 cities
- Claude API: ~$50-100 to extract 1,000+ rules
- Storage: 100MB+ database immediately
- Risk: Might populate cities no one uses

### New Approach (On-Demand)
- Day 1: Pre-load 3 demo cities
- Claude API: ~$5-10 for 45 rules
- Storage: 5MB database initially
- Growth: Only pay for what's used
- Scaling: Costs grow with revenue

**Savings**: ~90% reduction in initial costs

---

## Monitoring & Analytics

Track these metrics:
- **Jurisdictions requested** (which cities are popular)
- **Load time per jurisdiction** (optimize bottlenecks)
- **Cache hit rate** (% of requests served instantly)
- **Failed loads** (which cities can't be loaded)
- **User wait time tolerance** (do they wait or leave?)

Dashboard shows:
```
📊 CodeCheck Growth
Cities Available: 3 → 8 → 25 → 50+
Total Rules: 45 → 120 → 485 → 1,250+
Cache Hit Rate: 100% → 89% → 95%
Avg Load Time: 45 seconds first request, <50ms cached
```

---

## Future Enhancements

### Phase 2 (Post-MVP)
1. **Celery/RQ integration** for robust job queue
2. **WebSocket updates** for real-time progress
3. **Pre-emptive loading** of nearby jurisdictions
4. **Background refresh** of stale codes (quarterly)
5. **User-submitted corrections** with validation

### Phase 3 (Scale)
1. **ML predictions** of which cities to pre-load
2. **Distributed agents** across multiple workers
3. **CDN caching** for jurisdiction data
4. **Regional specificity** (downtown vs suburbs)

---

## Implementation Checklist

### Backend (6-8 hours)
- [ ] Add `jurisdiction_data_status` table
- [ ] Add `agent_jobs` table
- [ ] Create simple JobQueue class
- [ ] Add GET `/jurisdictions/{id}/status` endpoint
- [ ] Add POST `/jurisdictions/{id}/load-codes` endpoint
- [ ] Implement agent coordinator
- [ ] Add progress tracking
- [ ] Test with 1-2 jurisdictions

### iOS (2-3 hours)
- [ ] Add `checkJurisdictionStatus()` to CodeLookupService
- [ ] Add `triggerCodeLoading()` to CodeLookupService
- [ ] Update MeasurementView with loading states
- [ ] Add progress bar UI
- [ ] Implement polling logic
- [ ] Add timeout handling
- [ ] Test on simulator

### Seed Data (30 minutes)
- [ ] Pre-load 3 demo jurisdictions (Denver, Seattle, Phoenix)
- [ ] Add 15 rules per demo city
- [ ] Test instant responses for demo cities

### Testing (2 hours)
- [ ] Test pre-loaded city (instant response)
- [ ] Test on-demand city (loading flow)
- [ ] Test concurrent requests (same city)
- [ ] Test agent failures (graceful degradation)
- [ ] Test timeout scenarios

---

## Launch Strategy

### Week 1: Soft Launch
- 3 pre-loaded cities for demos
- On-demand loading for others
- Monitor: Which cities get requested?

### Week 2-4: Optimize
- Pre-load top 5 most-requested cities
- Optimize slow-loading cities
- Add background refresh

### Month 2+: Scale
- Pre-load top 25 cities
- On-demand for long tail
- Background pre-fetch nearby cities

---

**Estimated Total Implementation Time**: 10-13 hours
**Launch Readiness**: Can launch with 3 pre-loaded cities TODAY

This approach gets you to market 3-4 days faster! 🚀
