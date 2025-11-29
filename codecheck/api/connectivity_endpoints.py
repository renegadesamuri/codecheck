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


def get_connectivity_hub():
    """
    Get the connectivity hub instance.

    Must be called at runtime (not import time) to get the initialized hub.
    Uses sys.modules to get the actual running __main__ module.
    """
    import sys
    # When running as python main.py, the module is __main__ not main
    main_module = sys.modules.get('__main__')
    if main_module and hasattr(main_module, 'connectivity_hub'):
        return main_module.connectivity_hub
    # Fallback: try importing main module directly
    try:
        import main
        return main.connectivity_hub
    except ImportError:
        return None


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
    connectivity_hub = get_connectivity_hub()

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
    connectivity_hub = get_connectivity_hub()

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
    connectivity_hub = get_connectivity_hub()

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
    connectivity_hub = get_connectivity_hub()

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
    connectivity_hub = get_connectivity_hub()

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


@router.get("/scheduler/status")
async def get_scheduler_status(
    current_user: Optional[TokenData] = Depends(get_current_user_optional)
) -> Dict:
    """
    Get smart scheduler status and optimization metrics.

    Shows:
    - Current scheduling intervals for each agent
    - Adaptive adjustments made
    - Cache hit statistics
    - File change triggers
    - Compute savings metrics

    Returns scheduler optimization status.
    """
    connectivity_hub = get_connectivity_hub()

    if not connectivity_hub:
        raise HTTPException(
            status_code=503,
            detail="Connectivity monitoring not initialized"
        )

    try:
        return connectivity_hub.get_scheduler_status()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get scheduler status: {str(e)}"
        )


@router.get("/health")
async def connectivity_health_check() -> Dict:
    """
    Simple health check endpoint for connectivity monitoring.

    Returns basic status without detailed diagnostics.
    Useful for uptime monitoring and load balancers.

    Public endpoint (no authentication required).
    """
    connectivity_hub = get_connectivity_hub()

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


# ============================================================================
# Phase 7: Enhanced Diagnostics Dashboard
# ============================================================================

def get_diagnostic_service():
    """Get the diagnostic service instance"""
    from agents.mini_agents.diagnostic_service import diagnostic_service
    return diagnostic_service


@router.get("/dashboard")
async def get_diagnostic_dashboard(
    current_user: Optional[TokenData] = Depends(get_current_user_optional)
) -> Dict:
    """
    Get comprehensive diagnostic dashboard optimized for iOS display.

    Returns structured data including:
    - Overall system status with color-coded severity
    - Connection status with response times
    - Agent health and scheduling info
    - Performance metrics (cache hits, adaptive adjustments)
    - Quick stats summary
    - Recommended refresh interval

    Public endpoint (authentication optional).

    Perfect for SwiftUI rendering with sections and items.
    """
    connectivity_hub = get_connectivity_hub()

    if not connectivity_hub:
        return {
            "timestamp": datetime.now().isoformat(),
            "overall_status": "warning",
            "overall_message": "System initializing...",
            "quick_stats": {"healthy_count": 0, "total_count": 0, "health_percentage": 0},
            "sections": [],
            "refresh_interval_seconds": 5
        }

    try:
        diagnostic_service = get_diagnostic_service()
        dashboard = await diagnostic_service.get_dashboard(connectivity_hub)
        return dashboard

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get dashboard: {str(e)}"
        )


@router.get("/quick-status")
async def get_quick_status() -> Dict:
    """
    Get minimal status for quick polling.

    Optimized for low bandwidth - returns just essentials:
    - status: overall status string
    - healthy: count of healthy connections
    - total: total connection count
    - ok: boolean for quick checks

    Public endpoint (no authentication required).

    Use this for frequent polling to minimize bandwidth.
    """
    connectivity_hub = get_connectivity_hub()

    if not connectivity_hub:
        return {
            "status": "initializing",
            "healthy": 0,
            "total": 0,
            "ok": True,
            "timestamp": datetime.now().isoformat()
        }

    try:
        diagnostic_service = get_diagnostic_service()
        return await diagnostic_service.get_quick_status(connectivity_hub)

    except Exception as e:
        return {
            "status": "error",
            "error": str(e),
            "ok": False,
            "timestamp": datetime.now().isoformat()
        }


@router.get("/history")
async def get_diagnostic_history(
    minutes: int = 60,
    current_user: Optional[TokenData] = Depends(get_current_user_optional)
) -> Dict:
    """
    Get diagnostic history for trend analysis.

    Returns historical snapshots of system health for the specified time period.

    Args:
        minutes: Number of minutes of history to return (default: 60)

    Public endpoint (authentication optional).
    """
    try:
        diagnostic_service = get_diagnostic_service()
        history = diagnostic_service.get_history(minutes=minutes)

        return {
            "period_minutes": minutes,
            "snapshots": history,
            "count": len(history)
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to get history: {str(e)}"
        )
