"""
Connectivity Status API Endpoints

Provides API endpoints for monitoring system connectivity status,
viewing diagnostics, and triggering manual connection tests.
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, List, Optional
from datetime import datetime

from auth import get_current_admin_user, get_current_user_optional, TokenData

router = APIRouter(prefix="/api/connectivity", tags=["connectivity"])


@router.get("/status")
async def get_connectivity_status(
    current_user: Optional[TokenData] = Depends(get_current_user_optional)
) -> Dict:
    """
    Get current connectivity status for all components.

    Returns real-time status of all tested connections including
    database, API, Redis, and authentication flow.

    Public endpoint (authentication optional) - useful for health monitoring.
    """
    from main import connectivity_hub

    if not connectivity_hub:
        raise HTTPException(
            status_code=503,
            detail="Connectivity monitoring not initialized"
        )

    try:
        status = await connectivity_hub.get_current_status()
        return status
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get connectivity status: {str(e)}"
        )


@router.get("/test/{connection_name}")
async def test_specific_connection(
    connection_name: str,
    current_user: TokenData = Depends(get_current_admin_user)
) -> Dict:
    """
    Test a specific connection on-demand.

    Requires admin authentication.

    Args:
        connection_name: Name of connection to test (e.g., 'backend-database')
    """
    from main import connectivity_hub

    if not connectivity_hub:
        raise HTTPException(
            status_code=503,
            detail="Connectivity monitoring not initialized"
        )

    try:
        result = await connectivity_hub.test_connection(connection_name)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to test connection: {str(e)}"
        )


@router.post("/fix/{connection_name}")
async def attempt_auto_fix(
    connection_name: str,
    current_user: TokenData = Depends(get_current_admin_user)
) -> Dict:
    """
    Attempt to automatically fix a failed connection.

    Only fixes safe, non-destructive issues like:
    - Restarting connection pools
    - Updating CORS configuration
    - Clearing stale sessions

    Requires admin authentication.

    Args:
        connection_name: Name of connection to fix
    """
    from main import connectivity_hub

    if not connectivity_hub:
        raise HTTPException(
            status_code=503,
            detail="Connectivity monitoring not initialized"
        )

    try:
        result = await connectivity_hub.auto_fix_connection(connection_name)
        return result
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to auto-fix connection: {str(e)}"
        )


@router.get("/report")
async def get_detailed_report(
    format: str = "json",
    current_user: Optional[TokenData] = Depends(get_current_user_optional)
) -> Dict:
    """
    Get comprehensive connectivity report.

    Supports multiple formats:
    - json: Structured data (default)
    - markdown: Human-readable markdown
    - text: Plain text for terminal

    Public endpoint (authentication optional).

    Args:
        format: Report format ('json', 'markdown', 'text')
    """
    from main import connectivity_hub

    if not connectivity_hub:
        raise HTTPException(
            status_code=503,
            detail="Connectivity monitoring not initialized"
        )

    if format not in ['json', 'markdown', 'text']:
        raise HTTPException(
            status_code=400,
            detail="Invalid format. Must be 'json', 'markdown', or 'text'"
        )

    try:
        report = await connectivity_hub.generate_report(format=format)

        if format == 'json':
            return report
        else:
            # Return as plain text for markdown/text formats
            from fastapi.responses import PlainTextResponse
            return PlainTextResponse(content=report)

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate report: {str(e)}"
        )


@router.get("/config/validation")
async def validate_all_configs(
    current_user: TokenData = Depends(get_current_admin_user)
) -> Dict:
    """
    Validate consistency across all configuration files.

    Checks for mismatches between:
    - .env files
    - vite.config.ts
    - capacitor.config.ts
    - Port configurations
    - CORS settings

    Requires admin authentication.

    Returns validation results with actionable fixes for any issues found.
    """
    from main import connectivity_hub

    if not connectivity_hub:
        raise HTTPException(
            status_code=503,
            detail="Connectivity monitoring not initialized"
        )

    try:
        validation = await connectivity_hub.validate_all_configs()
        return validation
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to validate configs: {str(e)}"
        )


@router.get("/health")
async def connectivity_health_check() -> Dict:
    """
    Simple health check endpoint for connectivity monitoring.

    Returns basic status without detailed diagnostics.
    Useful for uptime monitoring and load balancers.

    Public endpoint (no authentication required).
    """
    from main import connectivity_hub

    if not connectivity_hub:
        return {
            "status": "degraded",
            "message": "Connectivity monitoring not initialized",
            "timestamp": datetime.now().isoformat()
        }

    try:
        status = await connectivity_hub.get_current_status()
        overall = status.get('overall_status', 'unknown')

        return {
            "status": overall,
            "timestamp": status.get('timestamp'),
            "connections_tested": len(status.get('connections', []))
        }

    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now().isoformat()
        }


@router.get("/network-info")
async def get_network_info() -> Dict:
    """
    Get network connection information for this API server.

    Returns the local network IP and API URLs that clients should use.
    Essential for iOS devices to connect to the backend on the local network.

    Public endpoint (no authentication required).

    Returns:
        Dictionary containing:
        - local_ip: Network IP address (e.g., '192.168.1.100')
        - api_base_url: Full API URL with protocol and port
        - localhost_url: Localhost URL (for browser testing)
        - port: API port number
        - environment: Current environment (development/production)
    """
    try:
        from network_utils import get_connection_info

        return get_connection_info()

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get network info: {str(e)}"
        )
