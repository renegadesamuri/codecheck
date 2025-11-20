"""
CodeCheck API
FastAPI backend for construction compliance system with authentication and security
"""

from fastapi import FastAPI, HTTPException, Depends, Request, status
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from datetime import datetime, date
import uuid
from claude_service import get_claude_service

# Import authentication and security modules
from auth import (
    UserCreate, UserLogin, Token, User, TokenData,
    get_current_user, get_current_admin_user, get_current_user_optional,
    get_password_hash, verify_password, validate_password_strength,
    create_access_token, create_refresh_token, decode_token
)
from security import (
    SecurityHeadersMiddleware, InputValidator, AuditLogger,
    limiter, get_cors_origins, ClaudeRateLimiter
)

# Import job queue for on-demand code loading
from job_queue import (
    job_queue, JobStatus,
    create_code_loading_job, get_job_status,
    update_job_progress, mark_job_completed, mark_job_failed,
    has_active_job_for_jurisdiction
)

app = FastAPI(
    title="CodeCheck API",
    description="AI-Powered Construction Compliance Assistant API",
    version="1.0.0"
)

# Add security headers middleware
app.add_middleware(SecurityHeadersMiddleware)

# CORS middleware with environment-based configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Add rate limiter
app.state.limiter = limiter

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

class RefreshTokenRequest(BaseModel):
    refresh_token: str

# Helper function to get user from database
def get_user_from_db(conn, email: str) -> Optional[Dict]:
    """Get user from database by email"""
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT id, email, password_hash, full_name, role, is_active, created_at
                FROM users
                WHERE email = %s
            """, (email,))
            return cursor.fetchone()
    except Exception:
        return None

def get_user_by_id(conn, user_id: str) -> Optional[Dict]:
    """Get user from database by ID"""
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT id, email, password_hash, full_name, role, is_active, created_at
                FROM users
                WHERE id = %s
            """, (user_id,))
            return cursor.fetchone()
    except Exception:
        return None

# API Endpoints

@app.get("/")
async def root():
    """Health check endpoint"""
    return {"message": "CodeCheck API is running", "version": "1.0.0"}

# ========== Authentication Endpoints ==========

@app.post("/auth/register", response_model=Token, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/hour")
async def register(request: Request, user_data: UserCreate):
    """
    Register a new user
    Rate limited to 5 registrations per hour per IP
    """
    conn = get_db_connection()
    try:
        # Validate email format
        if not InputValidator.validate_email(user_data.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid email format"
            )

        # Validate password strength
        validate_password_strength(user_data.password)

        # Sanitize full name
        full_name = InputValidator.sanitize_string(user_data.full_name or "", 100)

        # Check if user already exists
        existing_user = get_user_from_db(conn, user_data.email)
        if existing_user:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )

        # Hash password
        password_hash = get_password_hash(user_data.password)

        # Create user
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            user_id = str(uuid.uuid4())
            cursor.execute("""
                INSERT INTO users (id, email, password_hash, full_name, role, is_active, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                RETURNING id, email, full_name, role, created_at
            """, (user_id, user_data.email, password_hash, full_name, "user", True, datetime.utcnow()))

            new_user = cursor.fetchone()
            conn.commit()

        # Log registration
        AuditLogger.log_event(
            conn,
            user_id=new_user['id'],
            action="user_registered",
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
            details={"email": user_data.email}
        )

        # Create tokens
        token_data = {
            "sub": new_user['id'],
            "email": new_user['email'],
            "role": new_user['role']
        }
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer"
        )

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/auth/login", response_model=Token)
@limiter.limit("10/minute")
async def login(request: Request, credentials: UserLogin):
    """
    Authenticate user and return JWT tokens
    Rate limited to 10 attempts per minute per IP
    """
    conn = get_db_connection()
    try:
        # Validate email format
        if not InputValidator.validate_email(credentials.email):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid email format"
            )

        # Get user from database
        user = get_user_from_db(conn, credentials.email)

        if not user or not verify_password(credentials.password, user['password_hash']):
            # Log failed attempt
            AuditLogger.log_event(
                conn,
                action="login_failed",
                ip_address=request.client.host if request.client else None,
                user_agent=request.headers.get("user-agent"),
                details={"email": credentials.email}
            )
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Incorrect email or password"
            )

        if not user['is_active']:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is disabled"
            )

        # Log successful login
        AuditLogger.log_event(
            conn,
            user_id=user['id'],
            action="login_success",
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent"),
            details={"email": credentials.email}
        )

        # Create tokens
        token_data = {
            "sub": user['id'],
            "email": user['email'],
            "role": user['role']
        }
        access_token = create_access_token(token_data)
        refresh_token = create_refresh_token(token_data)

        return Token(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer"
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/auth/refresh", response_model=Token)
@limiter.limit("20/hour")
async def refresh_token(request: Request, refresh_request: RefreshTokenRequest):
    """
    Refresh access token using refresh token
    Rate limited to 20 refreshes per hour per IP
    """
    conn = get_db_connection()
    try:
        # Decode refresh token
        token_data = decode_token(refresh_request.refresh_token)

        # Verify user still exists and is active
        user = get_user_by_id(conn, token_data.user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )

        if not user['is_active']:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is disabled"
            )

        # Log token refresh
        AuditLogger.log_event(
            conn,
            user_id=user['id'],
            action="token_refreshed",
            ip_address=request.client.host if request.client else None,
            user_agent=request.headers.get("user-agent")
        )

        # Create new tokens
        new_token_data = {
            "sub": user['id'],
            "email": user['email'],
            "role": user['role']
        }
        access_token = create_access_token(new_token_data)
        new_refresh_token = create_refresh_token(new_token_data)

        return Token(
            access_token=access_token,
            refresh_token=new_refresh_token,
            token_type="bearer"
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.get("/auth/me", response_model=User)
async def get_current_user_info(
    current_user: TokenData = Depends(get_current_user)
):
    """
    Get current authenticated user information
    Requires valid JWT token
    """
    conn = get_db_connection()
    try:
        user = get_user_by_id(conn, current_user.user_id)
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )

        return User(
            id=user['id'],
            email=user['email'],
            full_name=user['full_name'],
            role=user['role'],
            is_active=user['is_active'],
            created_at=user['created_at']
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# ========== Protected Endpoints (Require Authentication) ==========

@app.post("/resolve", response_model=ResolveResponse)
@limiter.limit("30/minute")
async def resolve_jurisdiction(
    request: Request,
    resolve_request: ResolveRequest,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Resolve address/lat-lng to jurisdiction(s)
    Uses PostGIS spatial queries to find overlapping jurisdictions
    Requires authentication
    """
    # Validate coordinates
    InputValidator.validate_coordinates(resolve_request.latitude, resolve_request.longitude)

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
            """, (resolve_request.longitude, resolve_request.latitude))

            jurisdictions = []
            for row in cursor.fetchall():
                jurisdictions.append(JurisdictionResponse(**row))

            if not jurisdictions:
                raise HTTPException(
                    status_code=404,
                    detail="No jurisdiction found for the provided coordinates"
                )

            # Log the query
            AuditLogger.log_event(
                conn,
                user_id=current_user.user_id,
                action="resolve_jurisdiction",
                resource_type="jurisdiction",
                ip_address=request.client.host if request.client else None
            )

            return ResolveResponse(jurisdictions=jurisdictions)

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/codeset", response_model=CodeSetResponse)
async def get_code_set(
    request: CodeSetRequest,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Get adopted code families and editions for a jurisdiction
    Requires authentication
    """
    # Validate jurisdiction_id format
    if not InputValidator.validate_uuid(request.jurisdiction_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid jurisdiction ID format"
        )

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
async def query_rules(
    request: RuleQueryRequest,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Query rules by jurisdiction, category, and other filters
    Requires authentication
    """
    # Validate jurisdiction_id format
    if not InputValidator.validate_uuid(request.jurisdiction_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid jurisdiction ID format"
        )

    # Sanitize category and code_family if provided
    if request.category:
        request.category = InputValidator.sanitize_string(request.category, 100)
    if request.code_family:
        request.code_family = InputValidator.sanitize_string(request.code_family, 50)

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
@limiter.limit("20/minute")
async def check_compliance(
    request_obj: Request,
    check_request: ComplianceCheckRequest,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Check compliance against measured values
    Requires authentication
    Rate limited to 20 checks per minute
    """
    # Validate jurisdiction_id format
    if not InputValidator.validate_uuid(check_request.jurisdiction_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid jurisdiction ID format"
        )

    # Validate measurement values
    for metric_name, value in check_request.metrics.items():
        InputValidator.validate_measurement_value(value)

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            violations = []
            recommendations = []
            is_compliant = True
            confidence_scores = []

            # Get relevant rules for the metrics provided
            for metric_name, measured_value in check_request.metrics.items():
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
                """, (check_request.jurisdiction_id, category))

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

            # Log compliance check
            AuditLogger.log_event(
                conn,
                user_id=current_user.user_id,
                action="compliance_check",
                resource_type="jurisdiction",
                resource_id=check_request.jurisdiction_id,
                ip_address=request_obj.client.host if request_obj.client else None,
                details={
                    "is_compliant": is_compliant,
                    "violations_count": len(violations)
                }
            )

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
@limiter.limit("10/minute")
async def explain_rule(
    request: Request,
    rule_id: str,
    measurement_value: Optional[float] = None,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Generate plain-English explanation of a building code rule using Claude
    Requires authentication
    Rate limited to 10 requests per minute
    """
    # Validate rule_id format
    if not InputValidator.validate_uuid(rule_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid rule ID format"
        )

    # Validate measurement value if provided
    if measurement_value is not None:
        InputValidator.validate_measurement_value(measurement_value)

    conn = get_db_connection()
    try:
        # Check Claude API rate limit
        if not ClaudeRateLimiter.check_claude_rate_limit(conn, current_user.user_id):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Claude API rate limit exceeded. Please try again later."
            )

        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT id, section_ref, title, rule_json, confidence
                FROM rule
                WHERE id = %s
            """, (rule_id,))

            rule = cursor.fetchone()
            if not rule:
                raise HTTPException(status_code=404, detail="Rule not found")

            # Log Claude API request
            ClaudeRateLimiter.log_claude_request(conn, current_user.user_id)

            # Generate explanation using Claude
            claude = get_claude_service()
            explanation = await claude.generate_explanation(
                dict(rule),
                measurement_value
            )

            # Log the query
            AuditLogger.log_event(
                conn,
                user_id=current_user.user_id,
                action="claude_api_explain",
                resource_type="rule",
                resource_id=rule_id,
                ip_address=request.client.host if request.client else None
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
@limiter.limit("10/minute")
async def conversational_ai(
    request: Request,
    message: str,
    context: Optional[Dict[str, Any]] = None,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Generate conversational response using Claude AI
    Requires authentication
    Rate limited to 10 requests per minute
    """
    # Sanitize message
    message = InputValidator.sanitize_string(message, 2000)

    conn = get_db_connection()
    try:
        # Check Claude API rate limit
        if not ClaudeRateLimiter.check_claude_rate_limit(conn, current_user.user_id):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Claude API rate limit exceeded. Please try again later."
            )

        # Log Claude API request
        ClaudeRateLimiter.log_claude_request(conn, current_user.user_id)

        claude = get_claude_service()
        response = await claude.generate_conversational_response(message, context)

        # Log the conversation
        AuditLogger.log_event(
            conn,
            user_id=current_user.user_id,
            action="claude_api_conversation",
            ip_address=request.client.host if request.client else None,
            details={"message_length": len(message)}
        )

        return {
            "message": message,
            "response": response,
            "timestamp": datetime.now().isoformat()
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.post("/extract-rules")
@limiter.limit("5/minute")
async def extract_rules_from_text(
    request: Request,
    section_text: str,
    section_ref: str,
    code_family: str,
    edition: str,
    current_user: TokenData = Depends(get_current_admin_user)  # Admin only
):
    """
    Extract structured rules from building code text using Claude
    Requires admin authentication
    Rate limited to 5 requests per minute
    """
    # Sanitize inputs
    section_text = InputValidator.sanitize_string(section_text, 10000)
    section_ref = InputValidator.sanitize_string(section_ref, 100)
    code_family = InputValidator.sanitize_string(code_family, 50)
    edition = InputValidator.sanitize_string(edition, 50)

    conn = get_db_connection()
    try:
        # Check Claude API rate limit
        if not ClaudeRateLimiter.check_claude_rate_limit(conn, current_user.user_id):
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Claude API rate limit exceeded. Please try again later."
            )

        # Log Claude API request
        ClaudeRateLimiter.log_claude_request(conn, current_user.user_id)

        claude = get_claude_service()
        rules = await claude.extract_rules_from_text(
            section_text, section_ref, code_family, edition
        )

        # Log the extraction
        AuditLogger.log_event(
            conn,
            user_id=current_user.user_id,
            action="claude_api_extract_rules",
            ip_address=request.client.host if request.client else None,
            details={
                "section_ref": section_ref,
                "rules_count": len(rules)
            }
        )

        return {
            "section_ref": section_ref,
            "extracted_rules": rules,
            "count": len(rules)
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

@app.get("/jurisdictions/{jurisdiction_id}/status")
async def get_jurisdiction_status(
    jurisdiction_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Check if jurisdiction has rules loaded and get loading status
    Requires authentication

    Returns:
        - status: 'ready', 'loading', 'not_loaded', or 'failed'
        - rule_count: Number of rules available
        - progress: Loading progress (0-100) if loading
        - message: Status message
        - job_id: Active job ID if loading
    """
    # Validate jurisdiction_id format
    if not InputValidator.validate_uuid(jurisdiction_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid jurisdiction ID format"
        )

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
                SELECT id, status, progress_percentage, error_message
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
                    "progress": 100,
                    "message": "Rules available",
                    "job_id": None
                }
            elif job:
                job_status_map = {
                    'pending': 'loading',
                    'running': 'loading'
                }
                return {
                    "status": job_status_map.get(job['status'], 'loading'),
                    "rule_count": 0,
                    "progress": job['progress_percentage'],
                    "message": f"Loading building codes... ({job['progress_percentage']}%)",
                    "job_id": job['id']
                }
            else:
                # Check if there was a previous failed attempt
                cursor.execute("""
                    SELECT error_message
                    FROM agent_jobs
                    WHERE jurisdiction_id = %s
                    AND status = 'failed'
                    ORDER BY created_at DESC
                    LIMIT 1
                """, (jurisdiction_id,))

                failed_job = cursor.fetchone()
                if failed_job:
                    return {
                        "status": "failed",
                        "rule_count": 0,
                        "progress": 0,
                        "message": f"Loading failed: {failed_job['error_message']}",
                        "job_id": None
                    }

                return {
                    "status": "not_loaded",
                    "rule_count": 0,
                    "progress": 0,
                    "message": "No rules available yet",
                    "job_id": None
                }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.post("/jurisdictions/{jurisdiction_id}/load-codes")
@limiter.limit("5/minute")
async def trigger_code_loading(
    request: Request,
    jurisdiction_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Trigger on-demand code loading for a jurisdiction
    Requires authentication
    Rate limited to 5 requests per minute

    Returns:
        - status: 'already_loaded', 'loading', or 'initiated'
        - job_id: Job identifier for tracking progress
        - message: Status message
    """
    # Validate jurisdiction_id format
    if not InputValidator.validate_uuid(jurisdiction_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid jurisdiction ID format"
        )

    conn = get_db_connection()
    try:
        # Check if jurisdiction exists
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT id, name FROM jurisdiction WHERE id = %s
            """, (jurisdiction_id,))

            jurisdiction = cursor.fetchone()
            if not jurisdiction:
                raise HTTPException(
                    status_code=404,
                    detail="Jurisdiction not found"
                )

            # Check if already loaded
            cursor.execute("""
                SELECT COUNT(*) as count FROM rule
                WHERE jurisdiction_id = %s
            """, (jurisdiction_id,))

            if cursor.fetchone()['count'] > 0:
                return {
                    "status": "already_loaded",
                    "job_id": None,
                    "message": f"Codes already available for {jurisdiction['name']}"
                }

            # Check if job already running
            cursor.execute("""
                SELECT id, status, progress_percentage FROM agent_jobs
                WHERE jurisdiction_id = %s
                AND status IN ('pending', 'running')
                ORDER BY created_at DESC
                LIMIT 1
            """, (jurisdiction_id,))

            existing_job = cursor.fetchone()
            if existing_job:
                return {
                    "status": "loading",
                    "job_id": existing_job['id'],
                    "progress": existing_job['progress_percentage'],
                    "message": f"Loading already in progress for {jurisdiction['name']}"
                }

        # Create new job
        job_id = create_code_loading_job(jurisdiction_id)

        # Record in database
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO agent_jobs (id, jurisdiction_id, job_type, status, progress_percentage)
                VALUES (%s, %s, 'load_codes', 'pending', 0)
            """, (job_id, jurisdiction_id))

            # Update jurisdiction status
            cursor.execute("""
                INSERT INTO jurisdiction_data_status (jurisdiction_id, status)
                VALUES (%s, 'pending')
                ON CONFLICT (jurisdiction_id)
                DO UPDATE SET status = 'pending', updated_at = NOW()
            """, (jurisdiction_id,))

            conn.commit()

        # Log the action
        AuditLogger.log_event(
            conn,
            user_id=current_user.user_id,
            action="trigger_code_loading",
            resource_type="jurisdiction",
            resource_id=jurisdiction_id,
            ip_address=request.client.host if request.client else None,
            details={"job_id": job_id}
        )

        # Trigger background processing
        asyncio.create_task(process_code_loading(job_id, jurisdiction_id, jurisdiction['name']))

        return {
            "status": "initiated",
            "job_id": job_id,
            "message": f"Code loading initiated for {jurisdiction['name']}. This may take 30-60 seconds."
        }

    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


@app.get("/jobs/{job_id}")
async def get_job_progress(
    job_id: str,
    current_user: TokenData = Depends(get_current_user)
):
    """
    Get the status and progress of a background job
    Requires authentication

    Returns:
        - id: Job identifier
        - status: 'pending', 'running', 'completed', or 'failed'
        - progress: Progress percentage (0-100)
        - result: Job result (if completed)
        - error: Error message (if failed)
    """
    # Validate job_id format
    if not InputValidator.validate_uuid(job_id):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid job ID format"
        )

    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT
                    id,
                    jurisdiction_id,
                    job_type,
                    status,
                    progress_percentage,
                    result,
                    error_message,
                    started_at,
                    completed_at,
                    created_at
                FROM agent_jobs
                WHERE id = %s
            """, (job_id,))

            job = cursor.fetchone()
            if not job:
                raise HTTPException(status_code=404, detail="Job not found")

            return {
                "id": job['id'],
                "jurisdiction_id": job['jurisdiction_id'],
                "job_type": job['job_type'],
                "status": job['status'],
                "progress": job['progress_percentage'],
                "result": job['result'],
                "error": job['error_message'],
                "started_at": job['started_at'].isoformat() if job['started_at'] else None,
                "completed_at": job['completed_at'].isoformat() if job['completed_at'] else None,
                "created_at": job['created_at'].isoformat() if job['created_at'] else None
            }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


async def process_code_loading(job_id: str, jurisdiction_id: str, jurisdiction_name: str):
    """
    Background task to load codes for a jurisdiction using AgentCoordinator

    Orchestrates the multi-agent workflow:
    1. Source Discovery Agent - Find code sources
    2. Document Fetcher Agent - Download documents
    3. Rule Extractor Agent - Extract structured rules
    4. Database Persistence - Save rules to database

    Args:
        job_id: Job identifier for progress tracking
        jurisdiction_id: Target jurisdiction UUID
        jurisdiction_name: Jurisdiction name for logging
    """
    import logging
    import sys
    import os

    # Add agents directory to path for imports
    agents_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'agents')
    if agents_path not in sys.path:
        sys.path.insert(0, agents_path)

    from coordinator import create_agent_coordinator

    logger = logging.getLogger(__name__)

    conn = None
    try:
        logger.info(f"Starting code loading job {job_id} for {jurisdiction_name}")

        # Update job status to running
        update_job_progress(job_id, 5, JobStatus.RUNNING)

        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE agent_jobs
                SET status = 'running', progress_percentage = 5, started_at = NOW()
                WHERE id = %s
            """, (job_id,))

            cursor.execute("""
                UPDATE jurisdiction_data_status
                SET status = 'loading', last_fetch_attempt = NOW(), updated_at = NOW()
                WHERE jurisdiction_id = %s
            """, (jurisdiction_id,))

            conn.commit()

        # Progress callback to update job status in database
        def progress_callback(progress: int, message: str):
            """Update job progress in database and job queue"""
            try:
                # Update in-memory job queue
                update_job_progress(job_id, progress)

                # Update database
                with conn.cursor() as cursor:
                    cursor.execute("""
                        UPDATE agent_jobs
                        SET progress_percentage = %s, progress_message = %s, updated_at = NOW()
                        WHERE id = %s
                    """, (progress, message, job_id))
                    conn.commit()

                logger.info(f"Job {job_id}: [{progress}%] {message}")
            except Exception as e:
                logger.error(f"Failed to update progress for job {job_id}: {e}")

        # Get database configuration
        db_config = {
            'host': os.getenv('DB_HOST', 'localhost'),
            'port': os.getenv('DB_PORT', '5432'),
            'user': os.getenv('DB_USER', 'postgres'),
            'password': os.getenv('DB_PASSWORD', ''),
            'database': os.getenv('DB_NAME', 'codecheck')
        }

        # Create agent coordinator
        coordinator = create_agent_coordinator(
            db_config=db_config,
            claude_api_key=os.getenv('CLAUDE_API_KEY')
        )

        # Get jurisdiction details
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("""
                SELECT name, type FROM jurisdiction WHERE id = %s
            """, (jurisdiction_id,))
            jurisdiction = cursor.fetchone()

            if not jurisdiction:
                raise Exception(f"Jurisdiction {jurisdiction_id} not found")

            jurisdiction_type = jurisdiction.get('type')

            # Extract state from name if available (e.g., "Denver, CO" -> "CO")
            state = None
            if ',' in jurisdiction_name:
                parts = jurisdiction_name.split(',')
                if len(parts) >= 2:
                    state = parts[-1].strip()

        # Execute agent workflow
        logger.info(f"Starting agent workflow for {jurisdiction_name}")
        result = await coordinator.load_codes_for_jurisdiction(
            jurisdiction_id=jurisdiction_id,
            jurisdiction_name=jurisdiction_name,
            jurisdiction_type=jurisdiction_type,
            state=state,
            progress_callback=progress_callback
        )

        if result.get('success'):
            # Successfully loaded codes
            rules_count = result.get('rules_count', 0)
            sources_found = result.get('sources_found', 0)
            sources_used = result.get('sources_used', 0)

            with conn.cursor() as cursor:
                # Update job as completed
                cursor.execute("""
                    UPDATE agent_jobs
                    SET
                        status = 'completed',
                        progress_percentage = 100,
                        result = %s,
                        completed_at = NOW()
                    WHERE id = %s
                """, (
                    psycopg2.extras.Json({
                        "rules_count": rules_count,
                        "sources_found": sources_found,
                        "sources_used": sources_used
                    }),
                    job_id
                ))

                # Update jurisdiction status (coordinator should have done this, but double-check)
                cursor.execute("""
                    SELECT update_jurisdiction_status(%s, %s, %s, %s)
                """, (jurisdiction_id, 'complete', rules_count, None))

                conn.commit()

            mark_job_completed(job_id, {
                "rules_count": rules_count,
                "sources_found": sources_found,
                "sources_used": sources_used
            })

            logger.info(f"Job {job_id} completed successfully. Loaded {rules_count} rules for {jurisdiction_name}")

        else:
            # Workflow failed
            error_message = result.get('error', 'Unknown error during code loading')
            raise Exception(error_message)

    except Exception as e:
        logger.error(f"Job {job_id} failed: {str(e)}", exc_info=True)

        # Mark job as failed
        mark_job_failed(job_id, str(e))

        if conn:
            try:
                with conn.cursor() as cursor:
                    cursor.execute("""
                        UPDATE agent_jobs
                        SET status = 'failed', error_message = %s, completed_at = NOW()
                        WHERE id = %s
                    """, (str(e), job_id))

                    cursor.execute("""
                        SELECT update_jurisdiction_status(%s, %s, %s, %s)
                    """, (jurisdiction_id, 'failed', None, str(e)))

                    conn.commit()
            except Exception as db_error:
                logger.error(f"Failed to update job status in database: {str(db_error)}")

    finally:
        if conn:
            conn.close()


@app.get("/jurisdictions")
async def list_jurisdictions(
    current_user: TokenData = Depends(get_current_user)
):
    """
    List all available jurisdictions
    Requires authentication
    """
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
