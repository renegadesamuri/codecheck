"""
CodeCheck API
FastAPI backend for construction compliance system
"""

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from datetime import datetime, date
import uuid
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

# Database connection
def get_db_connection():
    """Get database connection"""
    try:
        conn = psycopg2.connect(
            host=os.getenv('DB_HOST', 'localhost'),
            port=os.getenv('DB_PORT', '5432'),
            user=os.getenv('DB_USER', 'postgres'),
            password=os.getenv('DB_PASSWORD', ''),
            database=os.getenv('DB_NAME', 'codecheck')
        )
        return conn
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Database connection failed: {str(e)}")

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
    metrics: Dict[str, float]  # e.g., {"stair_tread_in": 10.75, "riser_in": 7.5}

class ComplianceResult(BaseModel):
    is_compliant: bool
    violations: List[Dict[str, Any]]
    recommendations: List[str]
    confidence: float

# API Endpoints

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "CodeCheck API is running", "version": "1.0.0"}

@app.post("/resolve", response_model=ResolveResponse)
async def resolve_jurisdiction(request: ResolveRequest):
    """
    Resolve address/lat-lng to jurisdiction(s)
    Uses PostGIS spatial queries to find overlapping jurisdictions
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            # Use PostGIS to find jurisdictions containing the point
            cursor.execute("""
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
            """, (request.longitude, request.latitude))
            
            jurisdictions = []
            for row in cursor.fetchall():
                jurisdictions.append(JurisdictionResponse(**row))
            
            if not jurisdictions:
                raise HTTPException(
                    status_code=404, 
                    detail="No jurisdiction found for the provided coordinates"
                )
            
            return ResolveResponse(jurisdictions=jurisdictions)
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/codeset", response_model=CodeSetResponse)
async def get_code_set(request: CodeSetRequest):
    """
    Get adopted code families and editions for a jurisdiction
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            query_date = request.date or date.today()
            
            cursor.execute("""
                SELECT code_family, edition, effective_from, effective_to, adoption_doc_url
                FROM code_adoption
                WHERE jurisdiction_id = %s
                AND effective_from <= %s
                AND (effective_to IS NULL OR effective_to >= %s)
                ORDER BY code_family, effective_from DESC
            """, (request.jurisdiction_id, query_date, query_date))
            
            adoptions = []
            for row in cursor.fetchall():
                adoptions.append(CodeAdoption(**row))
            
            return CodeSetResponse(
                jurisdiction_id=request.jurisdiction_id,
                adoptions=adoptions
            )
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/rules/query", response_model=RuleQueryResponse)
async def query_rules(request: RuleQueryRequest):
    """
    Query rules by jurisdiction, category, and other filters
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
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
            
            # Only return validated or high-confidence rules
            query += " AND (validation_status = 'validated' OR confidence >= 0.8)"
            query += " ORDER BY confidence DESC, code_family, section_ref"
            
            cursor.execute(query, params)
            
            rules = []
            for row in cursor.fetchall():
                rules.append(Rule(**row))
            
            return RuleQueryResponse(
                jurisdiction_id=request.jurisdiction_id,
                rules=rules
            )
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/check", response_model=ComplianceResult)
async def check_compliance(request: ComplianceCheckRequest):
    """
    Check compliance against measured values
    """
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            violations = []
            recommendations = []
            is_compliant = True
            confidence_scores = []
            
            # Get relevant rules for the metrics provided
            for metric_name, measured_value in request.metrics.items():
                # Extract category from metric name (e.g., "stair_tread_in" -> "stairs.tread")
                category = metric_name.replace('_in', '').replace('_', '.')
                
                cursor.execute("""
                    SELECT id, section_ref, title, rule_json, confidence
                    FROM rule
                    WHERE jurisdiction_id = %s
                    AND rule_json->>'category' = %s
                    AND (validation_status = 'validated' OR confidence >= 0.8)
                    ORDER BY confidence DESC
                    LIMIT 1
                """, (request.jurisdiction_id, category))
                
                rule = cursor.fetchone()
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
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/explain")
async def explain_rule(rule_id: str, measurement_value: Optional[float] = None):
    """Generate plain-English explanation of a building code rule using Claude"""
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT id, section_ref, title, rule_json, confidence
                FROM rule
                WHERE id = %s
            """, (rule_id,))
            
            rule = cursor.fetchone()
            if not rule:
                raise HTTPException(status_code=404, detail="Rule not found")
            
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
            
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

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
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT id, name, type, fips_code, official_portal_url
                FROM jurisdiction
                ORDER BY type, name
            """)
            
            jurisdictions = []
            for row in cursor.fetchall():
                jurisdictions.append(JurisdictionResponse(**row))
            
            return {"jurisdictions": jurisdictions}
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)