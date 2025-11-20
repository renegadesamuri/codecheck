"""
CodeCheck API with Connection Pool Integration
Example of how to integrate the database connection pool into the existing API
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime, date
import uuid

# Import the new database module
from database import (
    get_db,
    execute_query,
    execute_transaction,
    get_connection_pool_stats,
    database_health_check,
    shutdown_database,
    DatabaseConnectionError,
    DatabaseQueryError,
    DatabaseTransactionError
)
from claude_service import get_claude_service

app = FastAPI(
    title="CodeCheck API",
    description="AI-Powered Construction Compliance Assistant API",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Startup event to initialize connection pool
@app.on_event("startup")
async def startup_event():
    """Initialize services on startup"""
    try:
        # Connection pool is automatically initialized on first use
        health = database_health_check()
        if health['status'] == 'healthy':
            print("✓ Database connection pool initialized successfully")
            print(f"  Database: {health.get('database_version', 'Unknown')}")
        else:
            print(f"✗ Database health check failed: {health.get('error')}")
    except Exception as e:
        print(f"✗ Failed to initialize database: {e}")

# Shutdown event to cleanup connections
@app.on_event("shutdown")
async def shutdown_event():
    """Cleanup resources on shutdown"""
    print("Shutting down database connection pool...")
    shutdown_database()
    print("✓ Shutdown complete")

# Pydantic models
class JurisdictionResponse(BaseModel):
    id: str
    name: str
    type: str
    fips_code: Optional[str] = None
    official_portal_url: Optional[str] = None

class ResolveRequest(BaseModel):
    latitude: float
    longitude: float
    address: Optional[str] = None

class ResolveResponse(BaseModel):
    jurisdictions: List[JurisdictionResponse]

class CodeSetRequest(BaseModel):
    jurisdiction_id: str
    date: Optional[date] = None

class CodeAdoption(BaseModel):
    code_family: str
    edition: str
    effective_from: date
    effective_to: Optional[date] = None
    adoption_doc_url: Optional[str] = None

class CodeSetResponse(BaseModel):
    jurisdiction_id: str
    adoptions: List[CodeAdoption]

class RuleQueryRequest(BaseModel):
    jurisdiction_id: str
    date: Optional[date] = None
    category: Optional[str] = None
    code_family: Optional[str] = None

class Rule(BaseModel):
    id: str
    code_family: str
    edition: str
    section_ref: str
    title: Optional[str] = None
    rule_json: Dict[str, Any]
    confidence: float
    validation_status: str
    source_doc_url: Optional[str] = None

class RuleQueryResponse(BaseModel):
    jurisdiction_id: str
    rules: List[Rule]

class ComplianceCheckRequest(BaseModel):
    jurisdiction_id: str
    date: Optional[date] = None
    metrics: Dict[str, float]

class ComplianceResult(BaseModel):
    is_compliant: bool
    violations: List[Dict[str, Any]]
    recommendations: List[str]
    confidence: float

# API Endpoints

@app.get("/")
async def root():
    """Health check endpoint with database status"""
    health = database_health_check()
    return {
        "message": "CodeCheck API is running",
        "version": "1.0.0",
        "database": health['status']
    }

@app.get("/health")
async def health_check():
    """Comprehensive health check endpoint"""
    health = database_health_check()
    stats = get_connection_pool_stats()

    return {
        "status": "healthy" if health['status'] == 'healthy' else "degraded",
        "timestamp": datetime.now().isoformat(),
        "database": health,
        "connection_pool": {
            "size": stats['pool_size'],
            "available": stats['available_connections'],
            "active": stats['active_connections'],
            "total_queries": stats['queries_executed'],
            "total_transactions": stats['transactions_executed'],
            "errors": stats['errors']
        }
    }

@app.post("/resolve", response_model=ResolveResponse)
async def resolve_jurisdiction(request: ResolveRequest):
    """
    Resolve address/lat-lng to jurisdiction(s)
    Uses PostGIS spatial queries - NOW WITH CONNECTION POOLING!
    """
    try:
        # Using the execute_query helper for read-only query
        results = execute_query(
            """
            SELECT id, name, type, fips_code, official_portal_url
            FROM jurisdiction
            WHERE ST_Contains(geo_boundary, ST_SetSRID(ST_MakePoint(%s, %s), 4326))
            ORDER BY
                CASE type
                    WHEN 'city' THEN 1
                    WHEN 'town' THEN 2
                    WHEN 'county' THEN 3
                    WHEN 'state' THEN 4
                    ELSE 5
                END
            """,
            params=(request.longitude, request.latitude),
            read_only=True
        )

        if not results:
            raise HTTPException(
                status_code=404,
                detail="No jurisdiction found for the provided coordinates"
            )

        jurisdictions = [JurisdictionResponse(**row) for row in results]
        return ResolveResponse(jurisdictions=jurisdictions)

    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/codeset", response_model=CodeSetResponse)
async def get_code_set(request: CodeSetRequest):
    """Get adopted code families and editions for a jurisdiction"""
    try:
        query_date = request.date or date.today()

        results = execute_query(
            """
            SELECT code_family, edition, effective_from, effective_to, adoption_doc_url
            FROM code_adoption
            WHERE jurisdiction_id = %s
            AND effective_from <= %s
            AND (effective_to IS NULL OR effective_to >= %s)
            ORDER BY code_family, effective_from DESC
            """,
            params=(request.jurisdiction_id, query_date, query_date),
            read_only=True
        )

        adoptions = [CodeAdoption(**row) for row in results]
        return CodeSetResponse(
            jurisdiction_id=request.jurisdiction_id,
            adoptions=adoptions
        )

    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/rules/query", response_model=RuleQueryResponse)
async def query_rules(request: RuleQueryRequest):
    """Query rules by jurisdiction, category, and other filters"""
    try:
        # Build dynamic query
        query = """
            SELECT id, code_family, edition, section_ref, title,
                   rule_json, confidence, validation_status, source_doc_url
            FROM rule
            WHERE jurisdiction_id = %s
        """
        params = [request.jurisdiction_id]

        if request.category:
            query += " AND rule_json->>'category' = %s"
            params.append(request.category)

        if request.code_family:
            query += " AND code_family = %s"
            params.append(request.code_family)

        query += " AND (validation_status = 'validated' OR confidence >= 0.8)"
        query += " ORDER BY confidence DESC, code_family, section_ref"

        results = execute_query(query, params=tuple(params), read_only=True)

        rules = [Rule(**row) for row in results]
        return RuleQueryResponse(
            jurisdiction_id=request.jurisdiction_id,
            rules=rules
        )

    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/check", response_model=ComplianceResult)
async def check_compliance(request: ComplianceCheckRequest):
    """Check compliance against measured values"""
    try:
        violations = []
        recommendations = []
        is_compliant = True
        confidence_scores = []

        # Use context manager for more complex queries
        with get_db(read_only=True) as cur:
            for metric_name, measured_value in request.metrics.items():
                category = metric_name.replace('_in', '').replace('_', '.')

                cur.execute("""
                    SELECT id, section_ref, title, rule_json, confidence
                    FROM rule
                    WHERE jurisdiction_id = %s
                    AND rule_json->>'category' = %s
                    AND (validation_status = 'validated' OR confidence >= 0.8)
                    ORDER BY confidence DESC
                    LIMIT 1
                """, (request.jurisdiction_id, category))

                rule = cur.fetchone()
                if not rule:
                    continue

                rule_data = rule['rule_json']
                requirement = rule_data.get('requirement')
                required_value = rule_data.get('value')
                unit = rule_data.get('unit', 'inch')

                confidence_scores.append(rule['confidence'])

                # Check compliance
                if requirement == 'min' and measured_value < required_value:
                    is_compliant = False
                    violations.append({
                        'rule_id': rule['id'],
                        'section_ref': rule['section_ref'],
                        'metric': metric_name,
                        'measured_value': measured_value,
                        'required_value': required_value,
                        'unit': unit,
                        'requirement_type': requirement,
                        'message': f"{metric_name} is {measured_value} {unit}, but minimum required is {required_value} {unit}"
                    })
                    recommendations.append(f"Increase {metric_name} to at least {required_value} {unit}")

                elif requirement == 'max' and measured_value > required_value:
                    is_compliant = False
                    violations.append({
                        'rule_id': rule['id'],
                        'section_ref': rule['section_ref'],
                        'metric': metric_name,
                        'measured_value': measured_value,
                        'required_value': required_value,
                        'unit': unit,
                        'requirement_type': requirement,
                        'message': f"{metric_name} is {measured_value} {unit}, but maximum allowed is {required_value} {unit}"
                    })
                    recommendations.append(f"Reduce {metric_name} to at most {required_value} {unit}")

        overall_confidence = sum(confidence_scores) / len(confidence_scores) if confidence_scores else 0.0

        return ComplianceResult(
            is_compliant=is_compliant,
            violations=violations,
            recommendations=recommendations,
            confidence=overall_confidence
        )

    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/explain")
async def explain_rule(rule_id: str, measurement_value: Optional[float] = None):
    """Generate plain-English explanation of a building code rule using Claude"""
    try:
        results = execute_query(
            """
            SELECT id, section_ref, title, rule_json, confidence
            FROM rule
            WHERE id = %s
            """,
            params=(rule_id,),
            read_only=True
        )

        if not results:
            raise HTTPException(status_code=404, detail="Rule not found")

        rule = results[0]

        # Generate explanation using Claude
        claude = get_claude_service()
        explanation = await claude.generate_explanation(
            dict(rule),
            measurement_value
        )

        return {
            "rule_id": rule_id,
            "explanation": explanation,
            "confidence": rule['confidence']
        }

    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/conversation")
async def conversational_ai(message: str, context: Optional[Dict[str, Any]] = None):
    """Generate conversational response using Claude AI"""
    try:
        claude = get_claude_service()
        response = await claude.generate_conversational_response(message, context)

        return {
            "message": message,
            "response": response,
            "timestamp": datetime.now().isoformat()
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/extract-rules")
async def extract_rules_from_text(section_text: str, section_ref: str,
                                code_family: str, edition: str):
    """Extract structured rules from building code text using Claude"""
    try:
        claude = get_claude_service()
        rules = await claude.extract_rules_from_text(
            section_text, section_ref, code_family, edition
        )

        return {
            "section_ref": section_ref,
            "extracted_rules": rules,
            "count": len(rules)
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/jurisdictions")
async def list_jurisdictions():
    """List all available jurisdictions"""
    try:
        results = execute_query(
            """
            SELECT id, name, type, fips_code, official_portal_url
            FROM jurisdiction
            ORDER BY type, name
            """,
            read_only=True
        )

        jurisdictions = [JurisdictionResponse(**row) for row in results]
        return {"jurisdictions": jurisdictions}

    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=f"Database query failed: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/stats")
async def connection_pool_stats():
    """Get connection pool statistics (admin endpoint)"""
    stats = get_connection_pool_stats()
    return {
        "pool": stats,
        "timestamp": datetime.now().isoformat()
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
