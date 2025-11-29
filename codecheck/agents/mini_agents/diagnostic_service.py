"""
Enhanced Diagnostic Service

Provides comprehensive diagnostics optimized for iOS display:
- Real-time system health dashboard
- Historical metrics tracking
- Actionable fix suggestions
- Visual status indicators

Phase 7 of the Connectivity-First Mini-Agent System.
"""

import logging
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from dataclasses import dataclass, field
from enum import Enum

logger = logging.getLogger(__name__)


class DiagnosticSeverity(Enum):
    """Severity levels for diagnostic messages"""
    SUCCESS = "success"      # Green - all good
    INFO = "info"           # Blue - informational
    WARNING = "warning"     # Yellow - needs attention
    ERROR = "error"         # Red - action required
    CRITICAL = "critical"   # Red pulsing - immediate action


@dataclass
class DiagnosticItem:
    """A single diagnostic item for display"""
    id: str
    title: str
    status: str
    severity: DiagnosticSeverity
    message: str
    details: Optional[str] = None
    fix_action: Optional[str] = None
    fix_command: Optional[str] = None
    last_checked: Optional[datetime] = None
    response_time_ms: Optional[int] = None

    def to_dict(self) -> Dict:
        return {
            'id': self.id,
            'title': self.title,
            'status': self.status,
            'severity': self.severity.value,
            'message': self.message,
            'details': self.details,
            'fix_action': self.fix_action,
            'fix_command': self.fix_command,
            'last_checked': self.last_checked.isoformat() if self.last_checked else None,
            'response_time_ms': self.response_time_ms
        }


@dataclass
class DiagnosticSection:
    """A section of diagnostics (e.g., Connections, Configuration)"""
    id: str
    title: str
    icon: str
    status: DiagnosticSeverity
    items: List[DiagnosticItem] = field(default_factory=list)

    def to_dict(self) -> Dict:
        return {
            'id': self.id,
            'title': self.title,
            'icon': self.icon,
            'status': self.status.value,
            'items': [item.to_dict() for item in self.items],
            'healthy_count': sum(1 for i in self.items if i.severity == DiagnosticSeverity.SUCCESS),
            'total_count': len(self.items)
        }


class DiagnosticService:
    """
    Enhanced diagnostic service for iOS-optimized status display.

    Provides:
    - Dashboard data formatted for iOS SwiftUI
    - Historical metrics for trend analysis
    - Actionable fix suggestions
    - Quick health summary
    """

    def __init__(self):
        self.history: List[Dict] = []  # Recent diagnostic history
        self.max_history = 100

    async def get_dashboard(self, connectivity_hub) -> Dict:
        """
        Get comprehensive dashboard data optimized for iOS display.

        Returns structured data for SwiftUI rendering.
        """
        now = datetime.now()

        # Get current status from hub
        try:
            current_status = await connectivity_hub.get_current_status()
        except Exception as e:
            logger.error(f"Failed to get status: {e}")
            current_status = {'connections': [], 'agents': [], 'overall_status': 'error'}

        # Build diagnostic sections
        sections = []

        # Section 1: Connection Status
        conn_section = await self._build_connection_section(current_status)
        sections.append(conn_section)

        # Section 2: Agent Health
        agent_section = await self._build_agent_section(current_status, connectivity_hub)
        sections.append(agent_section)

        # Section 3: System Performance
        perf_section = await self._build_performance_section(connectivity_hub)
        sections.append(perf_section)

        # Calculate overall health
        overall_severity = self._calculate_overall_severity(sections)

        # Build quick stats
        quick_stats = self._build_quick_stats(sections, current_status)

        dashboard = {
            'timestamp': now.isoformat(),
            'overall_status': overall_severity.value,
            'overall_message': self._get_overall_message(overall_severity),
            'quick_stats': quick_stats,
            'sections': [s.to_dict() for s in sections],
            'refresh_interval_seconds': self._get_recommended_refresh(overall_severity),
            'last_full_check': current_status.get('timestamp')
        }

        # Store in history
        self._add_to_history(dashboard)

        return dashboard

    async def _build_connection_section(self, status: Dict) -> DiagnosticSection:
        """Build connection status section"""
        items = []

        for conn in status.get('connections', []):
            severity = self._status_to_severity(conn.get('status', 'unknown'))

            # Build descriptive message
            if conn.get('status') == 'healthy':
                message = f"Connected ({conn.get('latency_ms', '?')}ms)"
            elif conn.get('status') == 'degraded':
                message = f"Slow response ({conn.get('latency_ms', '?')}ms)"
            else:
                message = conn.get('error') or "Connection failed"

            # Determine fix action
            fix_action = None
            fix_command = None
            if conn.get('status') != 'healthy':
                fix_action, fix_command = self._get_connection_fix(conn.get('name', ''))

            items.append(DiagnosticItem(
                id=f"conn_{conn.get('name', 'unknown')}",
                title=self._format_connection_name(conn.get('name', 'Unknown')),
                status=conn.get('status', 'unknown'),
                severity=severity,
                message=message,
                details=conn.get('error'),
                fix_action=fix_action,
                fix_command=fix_command,
                last_checked=datetime.fromisoformat(conn['last_tested']) if conn.get('last_tested') else None,
                response_time_ms=conn.get('latency_ms')
            ))

        # If no connections, add a warning
        if not items:
            items.append(DiagnosticItem(
                id="conn_none",
                title="No Connections",
                status="warning",
                severity=DiagnosticSeverity.WARNING,
                message="No connection data available",
                fix_action="Wait for initial connection tests to complete"
            ))

        section_status = self._calculate_section_severity(items)

        return DiagnosticSection(
            id="connections",
            title="Connections",
            icon="network",  # SF Symbol name
            status=section_status,
            items=items
        )

    async def _build_agent_section(self, status: Dict, connectivity_hub) -> DiagnosticSection:
        """Build agent health section"""
        items = []

        # Get scheduler status for more details
        try:
            scheduler_status = connectivity_hub.get_scheduler_status()
            schedules = scheduler_status.get('schedules', {})
        except:
            schedules = {}

        for agent in status.get('agents', []):
            name = agent.get('name', 'unknown')
            sched = schedules.get(name, {})

            # Determine severity
            if not agent.get('enabled'):
                severity = DiagnosticSeverity.INFO
                message = "Disabled"
            elif agent.get('failures', 0) > 0:
                severity = DiagnosticSeverity.ERROR
                message = f"{agent.get('failures')} consecutive failures"
            elif agent.get('last_status') == 'error':
                severity = DiagnosticSeverity.ERROR
                message = "Last run failed"
            else:
                severity = DiagnosticSeverity.SUCCESS
                interval = sched.get('current_interval', '?')
                message = f"Healthy (checking every {interval}s)"

            # Add scheduler info to details
            details = None
            if sched:
                details = f"Priority: {sched.get('priority', 'N/A')}, Cache: {'valid' if sched.get('cache_valid') else 'expired'}"

            items.append(DiagnosticItem(
                id=f"agent_{name}",
                title=self._format_agent_name(name),
                status='healthy' if severity == DiagnosticSeverity.SUCCESS else 'error',
                severity=severity,
                message=message,
                details=details,
                last_checked=datetime.fromisoformat(agent['last_run']) if agent.get('last_run') else None,
                response_time_ms=int(agent.get('avg_execution_ms')) if agent.get('avg_execution_ms') else None
            ))

        # If no agents, add info
        if not items:
            items.append(DiagnosticItem(
                id="agent_none",
                title="No Agents",
                status="info",
                severity=DiagnosticSeverity.INFO,
                message="No agent data available yet"
            ))

        section_status = self._calculate_section_severity(items)

        return DiagnosticSection(
            id="agents",
            title="Monitoring Agents",
            icon="cpu",
            status=section_status,
            items=items
        )

    async def _build_performance_section(self, connectivity_hub) -> DiagnosticSection:
        """Build system performance section"""
        items = []

        try:
            scheduler_status = connectivity_hub.get_scheduler_status()
            metrics = scheduler_status.get('metrics', {})

            # Total runs
            total_runs = metrics.get('total_runs', 0)
            items.append(DiagnosticItem(
                id="perf_runs",
                title="Total Checks",
                status="success",
                severity=DiagnosticSeverity.SUCCESS,
                message=f"{total_runs} checks completed"
            ))

            # Cache efficiency
            cached_hits = metrics.get('cached_hits', 0)
            skipped = metrics.get('skipped_runs', 0)
            efficiency = ((cached_hits + skipped) / max(total_runs + cached_hits + skipped, 1)) * 100

            if efficiency > 50:
                cache_severity = DiagnosticSeverity.SUCCESS
            elif efficiency > 20:
                cache_severity = DiagnosticSeverity.INFO
            else:
                cache_severity = DiagnosticSeverity.WARNING

            items.append(DiagnosticItem(
                id="perf_cache",
                title="Compute Savings",
                status="success" if efficiency > 30 else "info",
                severity=cache_severity,
                message=f"{efficiency:.0f}% checks optimized away",
                details=f"{cached_hits} cache hits, {skipped} skipped"
            ))

            # Average execution time
            avg_time = metrics.get('avg_execution_time_ms', 0)
            if avg_time < 100:
                time_severity = DiagnosticSeverity.SUCCESS
                time_msg = f"Fast ({avg_time}ms avg)"
            elif avg_time < 500:
                time_severity = DiagnosticSeverity.INFO
                time_msg = f"Normal ({avg_time}ms avg)"
            else:
                time_severity = DiagnosticSeverity.WARNING
                time_msg = f"Slow ({avg_time}ms avg)"

            items.append(DiagnosticItem(
                id="perf_time",
                title="Response Time",
                status="success" if avg_time < 500 else "warning",
                severity=time_severity,
                message=time_msg
            ))

            # Adaptive adjustments
            adjustments = metrics.get('adaptive_adjustments', 0)
            items.append(DiagnosticItem(
                id="perf_adaptive",
                title="Adaptive Tuning",
                status="success",
                severity=DiagnosticSeverity.SUCCESS,
                message=f"{adjustments} interval adjustments",
                details="System automatically optimizes check frequency"
            ))

        except Exception as e:
            logger.error(f"Failed to build performance section: {e}")
            items.append(DiagnosticItem(
                id="perf_error",
                title="Metrics Unavailable",
                status="warning",
                severity=DiagnosticSeverity.WARNING,
                message="Could not load performance metrics"
            ))

        section_status = self._calculate_section_severity(items)

        return DiagnosticSection(
            id="performance",
            title="Performance",
            icon="speedometer",
            status=section_status,
            items=items
        )

    def _format_connection_name(self, name: str) -> str:
        """Format connection name for display"""
        name_map = {
            'backend-database': 'Database',
            'backend-redis': 'Redis Cache',
            'backend-api': 'API Server',
            'frontend-backend': 'App to API',
            'ios-backend': 'iOS to API',
            'auth-flow': 'Authentication'
        }
        return name_map.get(name, name.replace('-', ' ').title())

    def _format_agent_name(self, name: str) -> str:
        """Format agent name for display"""
        name_map = {
            'connection_tester': 'Connection Monitor',
            'config_validator': 'Config Validator',
            'auth_flow_tester': 'Auth Tester'
        }
        return name_map.get(name, name.replace('_', ' ').title())

    def _status_to_severity(self, status: str) -> DiagnosticSeverity:
        """Convert status string to severity"""
        mapping = {
            'healthy': DiagnosticSeverity.SUCCESS,
            'degraded': DiagnosticSeverity.WARNING,
            'failed': DiagnosticSeverity.ERROR,
            'critical': DiagnosticSeverity.CRITICAL,
            'unknown': DiagnosticSeverity.INFO
        }
        return mapping.get(status, DiagnosticSeverity.INFO)

    def _calculate_section_severity(self, items: List[DiagnosticItem]) -> DiagnosticSeverity:
        """Calculate overall severity for a section"""
        if not items:
            return DiagnosticSeverity.INFO

        severities = [i.severity for i in items]

        if DiagnosticSeverity.CRITICAL in severities:
            return DiagnosticSeverity.CRITICAL
        if DiagnosticSeverity.ERROR in severities:
            return DiagnosticSeverity.ERROR
        if DiagnosticSeverity.WARNING in severities:
            return DiagnosticSeverity.WARNING
        if all(s == DiagnosticSeverity.SUCCESS for s in severities):
            return DiagnosticSeverity.SUCCESS
        return DiagnosticSeverity.INFO

    def _calculate_overall_severity(self, sections: List[DiagnosticSection]) -> DiagnosticSeverity:
        """Calculate overall system severity"""
        if not sections:
            return DiagnosticSeverity.INFO

        severities = [s.status for s in sections]

        if DiagnosticSeverity.CRITICAL in severities:
            return DiagnosticSeverity.CRITICAL
        if DiagnosticSeverity.ERROR in severities:
            return DiagnosticSeverity.ERROR
        if DiagnosticSeverity.WARNING in severities:
            return DiagnosticSeverity.WARNING
        if all(s == DiagnosticSeverity.SUCCESS for s in severities):
            return DiagnosticSeverity.SUCCESS
        return DiagnosticSeverity.INFO

    def _get_overall_message(self, severity: DiagnosticSeverity) -> str:
        """Get user-friendly message for overall status"""
        messages = {
            DiagnosticSeverity.SUCCESS: "All systems operational",
            DiagnosticSeverity.INFO: "System initializing...",
            DiagnosticSeverity.WARNING: "Some issues detected",
            DiagnosticSeverity.ERROR: "Action required",
            DiagnosticSeverity.CRITICAL: "Critical issues detected"
        }
        return messages.get(severity, "Status unknown")

    def _get_recommended_refresh(self, severity: DiagnosticSeverity) -> int:
        """Get recommended refresh interval based on severity"""
        intervals = {
            DiagnosticSeverity.SUCCESS: 30,
            DiagnosticSeverity.INFO: 10,
            DiagnosticSeverity.WARNING: 10,
            DiagnosticSeverity.ERROR: 5,
            DiagnosticSeverity.CRITICAL: 3
        }
        return intervals.get(severity, 15)

    def _build_quick_stats(self, sections: List[DiagnosticSection], status: Dict) -> Dict:
        """Build quick stats for dashboard header"""
        total_healthy = sum(s.to_dict()['healthy_count'] for s in sections)
        total_items = sum(s.to_dict()['total_count'] for s in sections)

        return {
            'healthy_count': total_healthy,
            'total_count': total_items,
            'health_percentage': int((total_healthy / max(total_items, 1)) * 100),
            'connections_up': len([c for c in status.get('connections', []) if c.get('status') == 'healthy']),
            'connections_total': len(status.get('connections', []))
        }

    def _get_connection_fix(self, connection_name: str) -> tuple[Optional[str], Optional[str]]:
        """Get fix suggestion for a failed connection"""
        fixes = {
            'backend-database': (
                "Check database is running and credentials are correct",
                "docker-compose up -d postgres"
            ),
            'backend-redis': (
                "Check Redis is running",
                "docker-compose up -d redis"
            ),
            'backend-api': (
                "Restart the API server",
                "python main.py"
            ),
            'frontend-backend': (
                "Check CORS settings and API URL in frontend config",
                None
            ),
            'ios-backend': (
                "Ensure iOS device and server are on same network. Check Info.plist allows local network",
                None
            ),
            'auth-flow': (
                "Verify JWT_SECRET_KEY is set and tokens are valid",
                None
            )
        }
        return fixes.get(connection_name, (None, None))

    def _add_to_history(self, dashboard: Dict):
        """Add dashboard snapshot to history"""
        self.history.append({
            'timestamp': dashboard['timestamp'],
            'overall_status': dashboard['overall_status'],
            'quick_stats': dashboard['quick_stats']
        })

        # Keep only recent history
        if len(self.history) > self.max_history:
            self.history = self.history[-self.max_history:]

    def get_history(self, minutes: int = 60) -> List[Dict]:
        """Get diagnostic history for the last N minutes"""
        cutoff = datetime.now() - timedelta(minutes=minutes)

        return [
            h for h in self.history
            if datetime.fromisoformat(h['timestamp']) > cutoff
        ]

    async def get_quick_status(self, connectivity_hub) -> Dict:
        """
        Get minimal status for quick polling.

        Optimized for low bandwidth - returns just essentials.
        """
        try:
            status = await connectivity_hub.get_current_status()

            connections = status.get('connections', [])
            healthy = len([c for c in connections if c.get('status') == 'healthy'])
            total = len(connections)

            overall = status.get('overall_status', 'unknown')

            return {
                'status': overall,
                'healthy': healthy,
                'total': total,
                'ok': overall in ('healthy', 'unknown'),
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            return {
                'status': 'error',
                'error': str(e),
                'ok': False,
                'timestamp': datetime.now().isoformat()
            }


# Singleton instance
diagnostic_service = DiagnosticService()
