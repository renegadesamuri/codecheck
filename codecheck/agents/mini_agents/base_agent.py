"""
Base Agent Class

Provides common functionality for all mini-agents including execution tracking,
database integration, and result reporting.
"""

import time
import uuid
import logging
from abc import ABC, abstractmethod
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import Dict, List, Optional, Any
from enum import Enum

logger = logging.getLogger(__name__)


class AgentStatus(Enum):
    """Agent execution status"""
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


class ConnectionStatus(Enum):
    """Connection health status"""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    FAILED = "failed"


class FindingSeverity(Enum):
    """Severity level of findings"""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


@dataclass
class AgentFinding:
    """Represents an issue or observation found by an agent"""
    name: str
    severity: FindingSeverity
    category: str
    title: str
    description: str
    auto_fixable: bool = False
    auto_fixed: bool = False
    fix_action: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    detected_at: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'name': self.name,
            'severity': self.severity.value,
            'category': self.category,
            'title': self.title,
            'description': self.description,
            'auto_fixable': self.auto_fixable,
            'auto_fixed': self.auto_fixed,
            'fix_action': self.fix_action,
            'metadata': self.metadata,
            'detected_at': self.detected_at.isoformat()
        }


@dataclass
class AgentResult:
    """Results from agent execution"""
    agent_name: str
    status: AgentStatus
    findings: List[AgentFinding] = field(default_factory=list)
    remediations_count: int = 0
    execution_time_ms: int = 0
    error_message: Optional[str] = None
    metrics: Dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        return {
            'agent_name': self.agent_name,
            'status': self.status.value,
            'findings': [f.to_dict() for f in self.findings],
            'remediations_count': self.remediations_count,
            'execution_time_ms': self.execution_time_ms,
            'error_message': self.error_message,
            'metrics': self.metrics
        }


class BaseAgent(ABC):
    """
    Abstract base class for all mini-agents.

    Provides common functionality:
    - Execution tracking and timing
    - Database integration for storing results
    - Logging and error handling
    - Result reporting
    """

    def __init__(self, name: str, critical: bool = False):
        """
        Initialize agent

        Args:
            name: Agent name (e.g., 'connection_tester')
            critical: Whether this agent is critical for startup
        """
        self.name = name
        self.critical = critical
        self.run_id: Optional[str] = None
        self.findings: List[AgentFinding] = []
        self.remediations_count = 0
        self.logger = logging.getLogger(f"{__name__}.{name}")

    @abstractmethod
    async def run_checks(self) -> List[AgentFinding]:
        """
        Execute agent checks. Must be implemented by subclasses.

        Returns:
            List of findings discovered during checks
        """
        pass

    async def execute(self, run_type: str = 'manual') -> AgentResult:
        """
        Execute the agent and track results

        Args:
            run_type: Type of run ('startup', 'scheduled', 'manual', 'event')

        Returns:
            AgentResult containing execution results
        """
        start_time = time.time()
        self.run_id = str(uuid.uuid4())
        self.findings = []
        self.remediations_count = 0

        self.logger.info(f"Starting {self.name} agent (run_type={run_type})")

        try:
            # Create agent run record
            await self._create_run_record(run_type)

            # Execute checks
            self.findings = await self.run_checks()

            # Attempt auto-remediation for fixable findings
            if self.findings:
                await self._attempt_remediations()

            # Calculate execution time
            execution_time_ms = int((time.time() - start_time) * 1000)

            # Update run record with completion
            await self._complete_run_record(
                status=AgentStatus.COMPLETED,
                execution_time_ms=execution_time_ms
            )

            self.logger.info(
                f"Completed {self.name} agent: {len(self.findings)} findings, "
                f"{self.remediations_count} remediations in {execution_time_ms}ms"
            )

            return AgentResult(
                agent_name=self.name,
                status=AgentStatus.COMPLETED,
                findings=self.findings,
                remediations_count=self.remediations_count,
                execution_time_ms=execution_time_ms
            )

        except Exception as e:
            execution_time_ms = int((time.time() - start_time) * 1000)
            error_msg = str(e)

            self.logger.error(f"Failed {self.name} agent: {error_msg}", exc_info=True)

            # Update run record with failure
            await self._complete_run_record(
                status=AgentStatus.FAILED,
                execution_time_ms=execution_time_ms,
                error_message=error_msg
            )

            return AgentResult(
                agent_name=self.name,
                status=AgentStatus.FAILED,
                findings=self.findings,
                remediations_count=self.remediations_count,
                execution_time_ms=execution_time_ms,
                error_message=error_msg
            )

    async def _create_run_record(self, run_type: str):
        """Create initial agent run record in database"""
        try:
            from api.database import execute_transaction

            execute_transaction([
                ("""
                    INSERT INTO agent_runs
                    (id, agent_name, run_type, status, started_at)
                    VALUES (%s, %s, %s, %s, NOW())
                """, (self.run_id, self.name, run_type, AgentStatus.RUNNING.value))
            ], read_only=False)

        except Exception as e:
            self.logger.warning(f"Failed to create run record: {e}")

    async def _complete_run_record(
        self,
        status: AgentStatus,
        execution_time_ms: int,
        error_message: Optional[str] = None
    ):
        """Update agent run record with completion data"""
        try:
            from api.database import execute_transaction
            import json

            findings_json = json.dumps([f.to_dict() for f in self.findings])

            execute_transaction([
                ("""
                    UPDATE agent_runs
                    SET status = %s,
                        findings_count = %s,
                        remediations_count = %s,
                        execution_time_ms = %s,
                        error_message = %s,
                        findings = %s::jsonb,
                        completed_at = NOW()
                    WHERE id = %s
                """, (
                    status.value,
                    len(self.findings),
                    self.remediations_count,
                    execution_time_ms,
                    error_message,
                    findings_json,
                    self.run_id
                )),
                ("""
                    UPDATE agent_config
                    SET last_run_at = NOW(),
                        consecutive_failures = CASE
                            WHEN %s = 'failed' THEN consecutive_failures + 1
                            ELSE 0
                        END
                    WHERE agent_name = %s
                """, (status.value, self.name))
            ], read_only=False)

        except Exception as e:
            self.logger.warning(f"Failed to update run record: {e}")

    async def _attempt_remediations(self):
        """Attempt to auto-fix issues that are marked as fixable"""
        for finding in self.findings:
            if finding.auto_fixable and not finding.auto_fixed:
                try:
                    fixed = await self.auto_fix(finding)
                    if fixed:
                        finding.auto_fixed = True
                        self.remediations_count += 1
                        self.logger.info(
                            f"Auto-fixed: {finding.title} - {finding.fix_action}"
                        )
                except Exception as e:
                    self.logger.error(
                        f"Failed to auto-fix {finding.title}: {e}",
                        exc_info=True
                    )

    async def auto_fix(self, finding: AgentFinding) -> bool:
        """
        Attempt to automatically fix an issue. Can be overridden by subclasses.

        Args:
            finding: The finding to attempt to fix

        Returns:
            True if fix was successful, False otherwise
        """
        # Base implementation does nothing
        # Subclasses should override this method
        return False

    def add_finding(
        self,
        name: str,
        severity: FindingSeverity,
        category: str,
        title: str,
        description: str,
        auto_fixable: bool = False,
        fix_action: Optional[str] = None,
        metadata: Optional[Dict] = None
    ) -> AgentFinding:
        """
        Helper method to create and add a finding

        Args:
            name: Short identifier for the finding
            severity: Severity level
            category: Category (e.g., 'connectivity', 'configuration', 'security')
            title: Human-readable title
            description: Detailed description
            auto_fixable: Whether this can be automatically fixed
            fix_action: Description of fix action if auto_fixable
            metadata: Additional metadata

        Returns:
            The created AgentFinding
        """
        finding = AgentFinding(
            name=name,
            severity=severity,
            category=category,
            title=title,
            description=description,
            auto_fixable=auto_fixable,
            fix_action=fix_action,
            metadata=metadata or {}
        )
        self.findings.append(finding)
        return finding

    def get_critical_findings(self) -> List[AgentFinding]:
        """Get only critical severity findings"""
        return [f for f in self.findings if f.severity == FindingSeverity.CRITICAL]

    def has_critical_findings(self) -> bool:
        """Check if there are any critical findings"""
        return len(self.get_critical_findings()) > 0
