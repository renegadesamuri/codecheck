"""
Agent Hub (Connectivity Hub)

Central coordinator for all mini-agents. Manages:
- Agent initialization and execution
- Startup validation (blocking)
- Background monitoring (non-blocking)
- Result aggregation and reporting
"""

import asyncio
import logging
from typing import List, Dict, Optional, Any
from datetime import datetime

from .base_agent import BaseAgent, AgentResult, FindingSeverity
from .connection_tester import ConnectionTesterAgent
from .config_validator import ConfigValidatorAgent

logger = logging.getLogger(__name__)


class ConnectivityHub:
    """
    Central hub for managing connectivity and configuration agents
    """

    def __init__(self):
        """Initialize the connectivity hub and register agents"""
        self.agents: Dict[str, BaseAgent] = {}
        self.startup_complete = False
        self.monitoring_task: Optional[asyncio.Task] = None

        # Register agents
        self._register_agents()

    def _register_agents(self):
        """Register all available agents"""
        # Connection Tester (critical)
        self.agents['connection_tester'] = ConnectionTesterAgent()

        # Config Validator (non-critical, but important)
        self.agents['config_validator'] = ConfigValidatorAgent()

        logger.info(f"Registered {len(self.agents)} agents")

    async def run_startup_tests(self) -> List[Dict]:
        """
        Run critical startup tests (BLOCKING).

        This should be called during application startup and will test all
        critical connections before the application is marked as ready.

        Returns:
            List of connection test results with 'critical' flag
        """
        logger.info("🔍 Running startup connectivity tests...")

        results = []

        # Run connection tester (critical)
        try:
            conn_result = await self.agents['connection_tester'].execute(run_type='startup')

            # Check for critical failures
            critical_findings = conn_result.get_critical_findings() if hasattr(conn_result, 'get_critical_findings') else []

            result_dict = {
                'agent': 'connection_tester',
                'critical': True,
                'status': 'failed' if critical_findings else 'healthy',
                'findings': len(conn_result.findings),
                'critical_findings': len(critical_findings),
                'execution_time_ms': conn_result.execution_time_ms
            }

            # Add error details for critical findings
            if critical_findings:
                result_dict['errors'] = [{
                    'name': f.name,
                    'title': f.title,
                    'description': f.description,
                    'fix': f.fix_action
                } for f in critical_findings]

            results.append(result_dict)

        except Exception as e:
            logger.error(f"Critical startup test failed: {e}", exc_info=True)
            results.append({
                'agent': 'connection_tester',
                'critical': True,
                'status': 'failed',
                'error': str(e),
                'fix': 'Check logs for details'
            })

        self.startup_complete = True
        return results

    async def start_monitoring(self):
        """
        Start background monitoring of connections and configuration.

        This is non-blocking and runs periodically to monitor system health.
        """
        logger.info("🔄 Starting background connectivity monitoring...")

        while True:
            try:
                # Wait for configured interval (default: 1 minute for connection tests)
                await asyncio.sleep(60)

                # Run connection tester
                result = await self.agents['connection_tester'].execute(run_type='scheduled')

                # Log any new issues
                if result.findings:
                    critical = [f for f in result.findings if f.severity == FindingSeverity.CRITICAL]
                    warnings = [f for f in result.findings if f.severity == FindingSeverity.WARNING]

                    if critical:
                        logger.error(f"❌ Found {len(critical)} critical connectivity issues")
                    if warnings:
                        logger.warning(f"⚠️  Found {len(warnings)} connectivity warnings")

            except asyncio.CancelledError:
                logger.info("Background monitoring cancelled")
                break
            except Exception as e:
                logger.error(f"Error in background monitoring: {e}", exc_info=True)
                await asyncio.sleep(60)  # Wait before retrying

    async def get_current_status(self) -> Dict:
        """
        Get current connectivity status for all components.

        Returns:
            Dictionary with current status of all connections
        """
        try:
            from api.database import execute_query

            # Get latest connection test results
            connection_status = execute_query("""
                SELECT * FROM get_latest_connection_status()
            """, read_only=True)

            # Get agent health summary
            agent_health = execute_query("""
                SELECT * FROM get_agent_health_summary()
            """, read_only=True)

            # Format response
            return {
                'timestamp': datetime.now().isoformat(),
                'overall_status': self._calculate_overall_status(connection_status),
                'connections': [{
                    'name': conn['connection_name'],
                    'status': conn['status'],
                    'latency_ms': conn['latency_ms'],
                    'error': conn['error_message'],
                    'last_tested': conn['tested_at'].isoformat() if conn['tested_at'] else None
                } for conn in connection_status],
                'agents': [{
                    'name': agent['agent_name'],
                    'enabled': agent['is_enabled'],
                    'last_run': agent['last_run_at'].isoformat() if agent['last_run_at'] else None,
                    'last_status': agent['last_status'],
                    'failures': agent['consecutive_failures'],
                    'avg_execution_ms': float(agent['avg_execution_time_ms']) if agent['avg_execution_time_ms'] else None
                } for agent in agent_health]
            }

        except Exception as e:
            logger.error(f"Failed to get current status: {e}", exc_info=True)
            return {
                'timestamp': datetime.now().isoformat(),
                'overall_status': 'unknown',
                'error': str(e),
                'connections': [],
                'agents': []
            }

    async def test_connection(self, connection_name: str) -> Dict:
        """
        Test a specific connection on-demand.

        Args:
            connection_name: Name of connection to test

        Returns:
            Test result dictionary
        """
        logger.info(f"Testing connection: {connection_name}")

        # For now, just run the full connection tester
        # In the future, could be more granular
        result = await self.agents['connection_tester'].execute(run_type='manual')

        return {
            'connection_name': connection_name,
            'timestamp': datetime.now().isoformat(),
            'status': 'completed' if result.status.value == 'completed' else 'failed',
            'findings': [f.to_dict() for f in result.findings]
        }

    async def auto_fix_connection(self, connection_name: str) -> Dict:
        """
        Attempt to auto-fix a failed connection.

        Args:
            connection_name: Name of connection to fix

        Returns:
            Fix result dictionary
        """
        logger.info(f"Attempting to auto-fix connection: {connection_name}")

        try:
            # Run connection tester to get current findings
            result = await self.agents['connection_tester'].execute(run_type='manual')

            # Find relevant findings for this connection
            relevant_findings = [
                f for f in result.findings
                if connection_name in f.metadata.get('connection_name', '')
                or connection_name in f.name
            ]

            if not relevant_findings:
                return {
                    'connection_name': connection_name,
                    'status': 'no_issues_found',
                    'message': 'No issues found for this connection'
                }

            # Check if any findings are auto-fixable
            fixable = [f for f in relevant_findings if f.auto_fixable and not f.auto_fixed]

            if not fixable:
                return {
                    'connection_name': connection_name,
                    'status': 'not_fixable',
                    'message': 'Issues found but cannot be automatically fixed',
                    'findings': [f.to_dict() for f in relevant_findings]
                }

            # Attempt fixes
            fixed_count = sum(1 for f in fixable if f.auto_fixed)

            return {
                'connection_name': connection_name,
                'status': 'fixed' if fixed_count > 0 else 'fix_failed',
                'fixed_count': fixed_count,
                'findings': [f.to_dict() for f in relevant_findings]
            }

        except Exception as e:
            logger.error(f"Failed to auto-fix connection {connection_name}: {e}", exc_info=True)
            return {
                'connection_name': connection_name,
                'status': 'error',
                'error': str(e)
            }

    async def generate_report(self, format: str = 'json') -> Any:
        """
        Generate a comprehensive connectivity report.

        Args:
            format: Report format ('json', 'markdown', 'text')

        Returns:
            Formatted report
        """
        status = await self.get_current_status()

        if format == 'markdown':
            return self._generate_markdown_report(status)
        elif format == 'text':
            return self._generate_text_report(status)
        else:
            return status  # JSON format

    def _generate_markdown_report(self, status: Dict) -> str:
        """Generate Markdown formatted report"""
        report = "# CodeCheck Connectivity Report\n\n"
        report += f"**Generated:** {status['timestamp']}\n\n"
        report += f"**Overall Status:** {status['overall_status'].upper()}\n\n"

        # Connections
        report += "## Connection Status\n\n"
        report += "| Connection | Status | Latency | Last Tested |\n"
        report += "|------------|--------|---------|-------------|\n"

        for conn in status.get('connections', []):
            status_emoji = {
                'healthy': '✅',
                'degraded': '⚠️',
                'failed': '❌'
            }.get(conn['status'], '❓')

            latency = f"{conn['latency_ms']}ms" if conn['latency_ms'] else 'N/A'
            last_tested = conn['last_tested'][:19] if conn['last_tested'] else 'Never'

            report += f"| {conn['name']} | {status_emoji} {conn['status']} | {latency} | {last_tested} |\n"

        # Issues
        failed = [c for c in status.get('connections', []) if c['status'] == 'failed']
        if failed:
            report += "\n## Issues Detected\n\n"
            for conn in failed:
                report += f"### {conn['name']}\n\n"
                report += f"**Error:** {conn['error']}\n\n"

        # Agents
        report += "\n## Agent Status\n\n"
        for agent in status.get('agents', []):
            enabled = "✓" if agent['enabled'] else "✗"
            report += f"- **{agent['name']}** [{enabled}]: "
            report += f"Last run {agent['last_run'] or 'Never'}, "
            report += f"Status: {agent['last_status'] or 'N/A'}\n"

        return report

    def _generate_text_report(self, status: Dict) -> str:
        """Generate plain text report"""
        report = "\n" + "=" * 60 + "\n"
        report += "  CODECHECK CONNECTIVITY STATUS\n"
        report += "=" * 60 + "\n\n"

        for conn in status.get('connections', []):
            status_symbol = {
                'healthy': '✓',
                'degraded': '⚠',
                'failed': '✗'
            }.get(conn['status'], '?')

            report += f"[{status_symbol}] {conn['name']:<30}"

            if conn['status'] == 'healthy':
                latency = f" ({conn['latency_ms']}ms)" if conn['latency_ms'] else ""
                report += f"OK{latency}\n"
            else:
                report += f"FAILED\n"
                if conn['error']:
                    report += f"    Error: {conn['error']}\n"

        report += "\n" + "=" * 60 + "\n"
        return report

    def _calculate_overall_status(self, connections: List[Dict]) -> str:
        """Calculate overall system status from connection results"""
        if not connections:
            return 'unknown'

        statuses = [c.get('status') for c in connections]

        if 'failed' in statuses:
            return 'critical'
        elif 'degraded' in statuses:
            return 'warning'
        elif all(s == 'healthy' for s in statuses):
            return 'healthy'
        else:
            return 'unknown'

    async def validate_all_configs(self) -> Dict:
        """
        Validate consistency across all configuration files.

        Returns:
            Dictionary with validation results
        """
        logger.info("Running configuration validation...")

        try:
            result = await self.agents['config_validator'].execute(run_type='manual')

            # Categorize findings by severity
            critical = [f for f in result.findings if f.severity == FindingSeverity.CRITICAL]
            warnings = [f for f in result.findings if f.severity == FindingSeverity.WARNING]
            info = [f for f in result.findings if f.severity == FindingSeverity.INFO]

            return {
                'timestamp': datetime.now().isoformat(),
                'status': 'critical' if critical else ('warning' if warnings else 'healthy'),
                'total_findings': len(result.findings),
                'critical': len(critical),
                'warnings': len(warnings),
                'info': len(info),
                'execution_time_ms': result.execution_time_ms,
                'findings': [f.to_dict() for f in result.findings]
            }

        except Exception as e:
            logger.error(f"Failed to validate configs: {e}", exc_info=True)
            return {
                'timestamp': datetime.now().isoformat(),
                'status': 'error',
                'error': str(e)
            }

    async def shutdown(self):
        """Cleanup and shutdown monitoring"""
        logger.info("Shutting down connectivity hub...")

        if self.monitoring_task and not self.monitoring_task.done():
            self.monitoring_task.cancel()
            try:
                await self.monitoring_task
            except asyncio.CancelledError:
                pass

        logger.info("Connectivity hub shut down")
