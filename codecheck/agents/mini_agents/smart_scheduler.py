"""
Smart Scheduler for Mini-Agents

Implements intelligent, low-compute scheduling strategies:
- Adaptive intervals based on system health
- File change detection to avoid redundant checks
- Resource-aware execution
- Result caching with smart invalidation
- Priority-based execution queue

Optimizes compute usage while maintaining system reliability.
"""

import os
import asyncio
import hashlib
import logging
import time
from pathlib import Path
from typing import Dict, List, Optional, Any, Callable
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from enum import Enum
import json

logger = logging.getLogger(__name__)


class SchedulePriority(Enum):
    """Priority levels for agent execution"""
    CRITICAL = 1    # Must run immediately (connection failures)
    HIGH = 2        # Should run soon (security checks)
    NORMAL = 3      # Regular scheduled checks
    LOW = 4         # Can be deferred (non-critical config)
    IDLE = 5        # Only run when system is idle


class HealthStatus(Enum):
    """System health status affecting scheduling"""
    HEALTHY = "healthy"         # All systems normal
    DEGRADED = "degraded"       # Some issues detected
    CRITICAL = "critical"       # Critical failures
    UNKNOWN = "unknown"         # Not yet determined


@dataclass
class AgentSchedule:
    """Schedule configuration for an agent"""
    agent_name: str
    priority: SchedulePriority = SchedulePriority.NORMAL

    # Interval settings (in seconds)
    base_interval: int = 60                 # Default check interval
    healthy_interval: int = 300             # Interval when healthy (5 min)
    degraded_interval: int = 30             # Interval when degraded
    critical_interval: int = 10             # Interval when critical

    # Current state
    current_interval: int = 60
    last_run: Optional[datetime] = None
    last_status: HealthStatus = HealthStatus.UNKNOWN
    consecutive_failures: int = 0
    consecutive_successes: int = 0

    # File watching (for config-based agents)
    watch_files: List[str] = field(default_factory=list)
    file_hashes: Dict[str, str] = field(default_factory=dict)

    # Caching
    cache_ttl: int = 300                    # Cache results for 5 min
    cached_result: Optional[Any] = None
    cache_time: Optional[datetime] = None

    # Resource limits
    max_execution_time_ms: int = 30000      # 30 second timeout
    skip_if_load_above: float = 0.8         # Skip if CPU > 80%


@dataclass
class SchedulerMetrics:
    """Metrics for scheduler performance"""
    total_runs: int = 0
    skipped_runs: int = 0
    cached_hits: int = 0
    file_change_triggers: int = 0
    adaptive_adjustments: int = 0
    total_execution_time_ms: int = 0

    def to_dict(self) -> Dict:
        return {
            'total_runs': self.total_runs,
            'skipped_runs': self.skipped_runs,
            'cached_hits': self.cached_hits,
            'file_change_triggers': self.file_change_triggers,
            'adaptive_adjustments': self.adaptive_adjustments,
            'total_execution_time_ms': self.total_execution_time_ms,
            'avg_execution_time_ms': (
                self.total_execution_time_ms // self.total_runs
                if self.total_runs > 0 else 0
            )
        }


class SmartScheduler:
    """
    Intelligent scheduler that minimizes compute while maintaining reliability.

    Key optimizations:
    1. Adaptive intervals - check more when unhealthy, less when healthy
    2. File watching - only check config when files change
    3. Result caching - avoid redundant expensive checks
    4. Load awareness - defer non-critical checks during high load
    5. Priority queue - ensure critical checks run first
    """

    def __init__(self, project_root: Optional[Path] = None):
        self.project_root = project_root or Path(__file__).parent.parent.parent
        self.schedules: Dict[str, AgentSchedule] = {}
        self.metrics = SchedulerMetrics()
        self.global_health = HealthStatus.UNKNOWN
        self._running = False
        self._task: Optional[asyncio.Task] = None

        # Initialize default schedules
        self._init_default_schedules()

    def _init_default_schedules(self):
        """Initialize default schedules for known agents"""

        # Connection tester - lightweight, run frequently
        self.schedules['connection_tester'] = AgentSchedule(
            agent_name='connection_tester',
            priority=SchedulePriority.CRITICAL,
            base_interval=60,
            healthy_interval=120,       # 2 min when healthy
            degraded_interval=30,       # 30 sec when degraded
            critical_interval=10,       # 10 sec when critical
            cache_ttl=30,               # Cache for 30 sec
            max_execution_time_ms=5000  # 5 sec timeout
        )

        # Config validator - heavier, run less often
        self.schedules['config_validator'] = AgentSchedule(
            agent_name='config_validator',
            priority=SchedulePriority.NORMAL,
            base_interval=300,          # 5 min default
            healthy_interval=600,       # 10 min when healthy
            degraded_interval=120,      # 2 min when degraded
            critical_interval=60,       # 1 min when critical
            cache_ttl=300,              # Cache for 5 min
            watch_files=[
                'api/.env',
                'api/.env.example',
                '../photo-editor/.env',
                '../photo-editor/vite.config.ts',
                '../photo-editor/capacitor.config.ts',
            ],
            max_execution_time_ms=10000  # 10 sec timeout
        )

        # Auth flow tester - security focused
        self.schedules['auth_flow_tester'] = AgentSchedule(
            agent_name='auth_flow_tester',
            priority=SchedulePriority.HIGH,
            base_interval=600,          # 10 min default
            healthy_interval=1800,      # 30 min when healthy
            degraded_interval=300,      # 5 min when degraded
            critical_interval=60,       # 1 min when critical
            cache_ttl=600,              # Cache for 10 min
            watch_files=[
                'api/auth.py',
                'api/.env',
            ],
            max_execution_time_ms=15000  # 15 sec timeout
        )

    def register_agent(self, agent_name: str, schedule: AgentSchedule):
        """Register a custom schedule for an agent"""
        self.schedules[agent_name] = schedule
        logger.info(f"Registered schedule for {agent_name}: interval={schedule.base_interval}s")

    def should_run(self, agent_name: str) -> tuple[bool, str]:
        """
        Determine if an agent should run now.

        Returns:
            (should_run, reason) tuple
        """
        if agent_name not in self.schedules:
            return True, "no_schedule"

        schedule = self.schedules[agent_name]
        now = datetime.now()

        # Check 1: Has enough time passed?
        if schedule.last_run:
            elapsed = (now - schedule.last_run).total_seconds()
            if elapsed < schedule.current_interval:
                return False, f"interval_not_reached ({elapsed:.0f}s < {schedule.current_interval}s)"

        # Check 2: File changes (for file-watching agents)
        if schedule.watch_files:
            files_changed = self._check_file_changes(schedule)
            if files_changed:
                self.metrics.file_change_triggers += 1
                return True, "file_changed"
            elif schedule.last_run:
                # If files haven't changed and we ran before, can use longer interval
                if elapsed < schedule.healthy_interval:
                    return False, "files_unchanged"

        # Check 3: System load (skip non-critical if load is high)
        if schedule.priority.value > SchedulePriority.HIGH.value:
            load = self._get_system_load()
            if load > schedule.skip_if_load_above:
                self.metrics.skipped_runs += 1
                return False, f"high_load ({load:.1%})"

        # Check 4: Can use cached result?
        if schedule.cached_result and schedule.cache_time:
            cache_age = (now - schedule.cache_time).total_seconds()
            if cache_age < schedule.cache_ttl:
                self.metrics.cached_hits += 1
                return False, f"cache_valid ({cache_age:.0f}s old)"

        return True, "scheduled"

    def _check_file_changes(self, schedule: AgentSchedule) -> bool:
        """Check if any watched files have changed"""
        changed = False

        for rel_path in schedule.watch_files:
            file_path = self.project_root / rel_path

            if not file_path.exists():
                continue

            try:
                # Calculate hash of file content
                content = file_path.read_bytes()
                current_hash = hashlib.md5(content).hexdigest()

                # Compare with stored hash
                stored_hash = schedule.file_hashes.get(rel_path)
                if stored_hash != current_hash:
                    schedule.file_hashes[rel_path] = current_hash
                    if stored_hash is not None:  # Don't count initial hash
                        changed = True
                        logger.debug(f"File changed: {rel_path}")

            except Exception as e:
                logger.debug(f"Error checking file {rel_path}: {e}")

        return changed

    def _get_system_load(self) -> float:
        """Get current system CPU load (0.0 - 1.0)"""
        try:
            # Use os.getloadavg() on Unix systems
            load_1min, _, _ = os.getloadavg()
            cpu_count = os.cpu_count() or 1
            return min(load_1min / cpu_count, 1.0)
        except (OSError, AttributeError):
            # Fallback for systems without getloadavg
            return 0.5

    def update_health(self, agent_name: str, status: HealthStatus, findings_count: int = 0):
        """
        Update health status and adjust intervals accordingly.

        Adaptive behavior:
        - Healthy with 0 findings: extend interval
        - Degraded: shorten interval
        - Critical: use minimum interval
        """
        if agent_name not in self.schedules:
            return

        schedule = self.schedules[agent_name]
        old_interval = schedule.current_interval
        old_status = schedule.last_status

        schedule.last_status = status
        schedule.last_run = datetime.now()

        # Update consecutive counters
        if status == HealthStatus.HEALTHY and findings_count == 0:
            schedule.consecutive_successes += 1
            schedule.consecutive_failures = 0
        elif status in (HealthStatus.DEGRADED, HealthStatus.CRITICAL):
            schedule.consecutive_failures += 1
            schedule.consecutive_successes = 0

        # Adapt interval based on status
        if status == HealthStatus.HEALTHY and findings_count == 0:
            # Gradually extend interval when healthy
            if schedule.consecutive_successes >= 3:
                schedule.current_interval = schedule.healthy_interval
            elif schedule.consecutive_successes >= 1:
                schedule.current_interval = min(
                    schedule.current_interval + 30,
                    schedule.healthy_interval
                )
        elif status == HealthStatus.DEGRADED:
            schedule.current_interval = schedule.degraded_interval
        elif status == HealthStatus.CRITICAL:
            schedule.current_interval = schedule.critical_interval
        else:
            schedule.current_interval = schedule.base_interval

        # Log if interval changed
        if old_interval != schedule.current_interval:
            self.metrics.adaptive_adjustments += 1
            logger.info(
                f"Adaptive interval for {agent_name}: "
                f"{old_interval}s -> {schedule.current_interval}s "
                f"(status: {old_status.value} -> {status.value})"
            )

    def cache_result(self, agent_name: str, result: Any):
        """Cache an agent's result"""
        if agent_name in self.schedules:
            self.schedules[agent_name].cached_result = result
            self.schedules[agent_name].cache_time = datetime.now()

    def get_cached_result(self, agent_name: str) -> Optional[Any]:
        """Get cached result if still valid"""
        if agent_name not in self.schedules:
            return None

        schedule = self.schedules[agent_name]
        if not schedule.cached_result or not schedule.cache_time:
            return None

        cache_age = (datetime.now() - schedule.cache_time).total_seconds()
        if cache_age < schedule.cache_ttl:
            return schedule.cached_result

        return None

    def invalidate_cache(self, agent_name: str):
        """Invalidate cached result for an agent"""
        if agent_name in self.schedules:
            self.schedules[agent_name].cached_result = None
            self.schedules[agent_name].cache_time = None

    def get_next_scheduled(self) -> List[tuple[str, int]]:
        """
        Get list of agents sorted by when they should run next.

        Returns:
            List of (agent_name, seconds_until_run) tuples
        """
        now = datetime.now()
        schedule_list = []

        for name, schedule in self.schedules.items():
            if schedule.last_run:
                elapsed = (now - schedule.last_run).total_seconds()
                remaining = max(0, schedule.current_interval - elapsed)
            else:
                remaining = 0  # Never run, should run now

            schedule_list.append((name, int(remaining), schedule.priority.value))

        # Sort by priority first, then by remaining time
        schedule_list.sort(key=lambda x: (x[2], x[1]))

        return [(name, remaining) for name, remaining, _ in schedule_list]

    def get_status(self) -> Dict:
        """Get current scheduler status"""
        return {
            'global_health': self.global_health.value,
            'metrics': self.metrics.to_dict(),
            'schedules': {
                name: {
                    'priority': sched.priority.name,
                    'current_interval': sched.current_interval,
                    'base_interval': sched.base_interval,
                    'last_run': sched.last_run.isoformat() if sched.last_run else None,
                    'last_status': sched.last_status.value,
                    'consecutive_successes': sched.consecutive_successes,
                    'consecutive_failures': sched.consecutive_failures,
                    'cache_valid': (
                        sched.cached_result is not None and
                        sched.cache_time is not None and
                        (datetime.now() - sched.cache_time).total_seconds() < sched.cache_ttl
                    ),
                    'watched_files': len(sched.watch_files),
                }
                for name, sched in self.schedules.items()
            },
            'next_runs': self.get_next_scheduled()
        }

    def record_execution(self, agent_name: str, execution_time_ms: int):
        """Record execution metrics"""
        self.metrics.total_runs += 1
        self.metrics.total_execution_time_ms += execution_time_ms

        if agent_name in self.schedules:
            self.schedules[agent_name].last_run = datetime.now()


class OptimizedAgentRunner:
    """
    Runs agents with smart scheduling optimizations.

    Wraps the scheduler with actual agent execution.
    """

    def __init__(self, hub, scheduler: Optional[SmartScheduler] = None):
        self.hub = hub
        self.scheduler = scheduler or SmartScheduler()
        self._running = False

    async def run_agent_if_needed(self, agent_name: str, force: bool = False) -> Optional[Any]:
        """
        Run an agent only if the scheduler says it should run.

        Args:
            agent_name: Name of agent to potentially run
            force: Force run regardless of schedule

        Returns:
            Agent result or cached result, None if skipped
        """
        # Check if we should run
        if not force:
            should_run, reason = self.scheduler.should_run(agent_name)

            if not should_run:
                logger.debug(f"Skipping {agent_name}: {reason}")

                # Return cached result if available
                cached = self.scheduler.get_cached_result(agent_name)
                if cached:
                    return cached
                return None

        # Run the agent
        if agent_name not in self.hub.agents:
            logger.warning(f"Agent {agent_name} not found in hub")
            return None

        try:
            start_time = time.time()
            result = await self.hub.agents[agent_name].execute(run_type='scheduled')
            execution_time_ms = int((time.time() - start_time) * 1000)

            # Record metrics
            self.scheduler.record_execution(agent_name, execution_time_ms)

            # Determine health status from result
            critical_findings = [
                f for f in result.findings
                if f.severity.value == 'critical'
            ]

            if critical_findings:
                status = HealthStatus.CRITICAL
            elif result.findings:
                status = HealthStatus.DEGRADED
            else:
                status = HealthStatus.HEALTHY

            # Update scheduler
            self.scheduler.update_health(agent_name, status, len(result.findings))
            self.scheduler.cache_result(agent_name, result)

            return result

        except Exception as e:
            logger.error(f"Error running {agent_name}: {e}")
            self.scheduler.update_health(agent_name, HealthStatus.CRITICAL)
            return None

    async def run_optimized_monitoring(self):
        """
        Run optimized background monitoring loop.

        Instead of running all agents on a fixed interval,
        this runs each agent based on its own adaptive schedule.
        """
        self._running = True
        logger.info("Starting optimized monitoring loop...")

        while self._running:
            try:
                # Get next scheduled agents
                next_runs = self.scheduler.get_next_scheduled()

                # Run any agents that are due
                for agent_name, seconds_remaining in next_runs:
                    if seconds_remaining <= 0:
                        await self.run_agent_if_needed(agent_name)

                # Sleep for a short interval before checking again
                await asyncio.sleep(5)

            except asyncio.CancelledError:
                logger.info("Optimized monitoring cancelled")
                break
            except Exception as e:
                logger.error(f"Error in optimized monitoring: {e}")
                await asyncio.sleep(10)

        self._running = False

    def stop(self):
        """Stop the monitoring loop"""
        self._running = False

    def get_status(self) -> Dict:
        """Get scheduler status"""
        return self.scheduler.get_status()
