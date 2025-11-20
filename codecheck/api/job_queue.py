"""
Job Queue System for On-Demand Code Loading
Simple in-memory job queue for MVP - can be replaced with Celery/RQ later
"""

import asyncio
import uuid
import threading
from typing import Dict, List, Optional, Callable
from enum import Enum
from dataclasses import dataclass, field
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class JobStatus(Enum):
    """Job execution status"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class Job:
    """
    Job data structure

    Attributes:
        id: Unique job identifier
        jurisdiction_id: Target jurisdiction UUID
        job_type: Type of job (e.g., 'load_codes')
        status: Current job status
        progress: Progress percentage (0-100)
        result: Job result data (dict)
        error: Error message if failed
        created_at: Job creation timestamp
        started_at: Job start timestamp
        completed_at: Job completion timestamp
    """
    id: str
    jurisdiction_id: str
    job_type: str
    status: JobStatus = JobStatus.PENDING
    progress: int = 0
    result: Optional[Dict] = None
    error: Optional[str] = None
    created_at: datetime = field(default_factory=datetime.now)
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None

    def to_dict(self) -> Dict:
        """Convert job to dictionary for API responses"""
        return {
            "id": self.id,
            "jurisdiction_id": self.jurisdiction_id,
            "job_type": self.job_type,
            "status": self.status.value,
            "progress": self.progress,
            "result": self.result,
            "error": self.error,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "started_at": self.started_at.isoformat() if self.started_at else None,
            "completed_at": self.completed_at.isoformat() if self.completed_at else None
        }


class JobQueue:
    """
    Simple in-memory job queue with thread-safe operations

    Features:
    - Thread-safe job management
    - Progress tracking
    - Status queries
    - Job history retention

    Note: For production, consider replacing with Celery, RQ, or similar
    """

    def __init__(self, max_history: int = 1000):
        """
        Initialize job queue

        Args:
            max_history: Maximum number of completed jobs to keep in memory
        """
        self.jobs: Dict[str, Job] = {}
        self.queue: List[str] = []
        self.max_history = max_history
        self._lock = threading.Lock()
        self._running = False
        logger.info("JobQueue initialized")

    def add_job(self, jurisdiction_id: str, job_type: str) -> str:
        """
        Add a new job to the queue

        Args:
            jurisdiction_id: Target jurisdiction UUID
            job_type: Type of job to execute

        Returns:
            job_id: Unique identifier for the created job
        """
        job_id = str(uuid.uuid4())

        with self._lock:
            job = Job(
                id=job_id,
                jurisdiction_id=jurisdiction_id,
                job_type=job_type,
                status=JobStatus.PENDING
            )
            self.jobs[job_id] = job
            self.queue.append(job_id)

        logger.info(f"Job {job_id} added to queue for jurisdiction {jurisdiction_id}")
        return job_id

    def get_job(self, job_id: str) -> Optional[Job]:
        """
        Get job by ID

        Args:
            job_id: Job identifier

        Returns:
            Job object or None if not found
        """
        with self._lock:
            return self.jobs.get(job_id)

    def get_jobs_by_jurisdiction(self, jurisdiction_id: str) -> List[Job]:
        """
        Get all jobs for a specific jurisdiction

        Args:
            jurisdiction_id: Jurisdiction UUID

        Returns:
            List of Job objects
        """
        with self._lock:
            return [
                job for job in self.jobs.values()
                if job.jurisdiction_id == jurisdiction_id
            ]

    def get_active_jobs(self) -> List[Job]:
        """
        Get all pending or running jobs

        Returns:
            List of active Job objects
        """
        with self._lock:
            return [
                job for job in self.jobs.values()
                if job.status in (JobStatus.PENDING, JobStatus.RUNNING)
            ]

    def update_job_status(
        self,
        job_id: str,
        status: JobStatus,
        progress: Optional[int] = None,
        error: Optional[str] = None
    ) -> bool:
        """
        Update job status and metadata

        Args:
            job_id: Job identifier
            status: New status
            progress: Progress percentage (0-100)
            error: Error message if failed

        Returns:
            True if job was updated, False if job not found
        """
        with self._lock:
            job = self.jobs.get(job_id)
            if not job:
                return False

            job.status = status

            if progress is not None:
                job.progress = max(0, min(100, progress))

            if error:
                job.error = error

            if status == JobStatus.RUNNING and not job.started_at:
                job.started_at = datetime.now()

            if status in (JobStatus.COMPLETED, JobStatus.FAILED):
                job.completed_at = datetime.now()
                # Remove from queue
                if job_id in self.queue:
                    self.queue.remove(job_id)

            logger.info(f"Job {job_id} status updated to {status.value} (progress: {job.progress}%)")
            return True

    def update_job_result(self, job_id: str, result: Dict) -> bool:
        """
        Update job result data

        Args:
            job_id: Job identifier
            result: Result data dictionary

        Returns:
            True if job was updated, False if job not found
        """
        with self._lock:
            job = self.jobs.get(job_id)
            if not job:
                return False

            job.result = result
            return True

    def has_pending_job(self, jurisdiction_id: str) -> bool:
        """
        Check if there's already a pending/running job for a jurisdiction

        Args:
            jurisdiction_id: Jurisdiction UUID

        Returns:
            True if there's an active job, False otherwise
        """
        with self._lock:
            for job in self.jobs.values():
                if (job.jurisdiction_id == jurisdiction_id and
                    job.status in (JobStatus.PENDING, JobStatus.RUNNING)):
                    return True
            return False

    def get_queue_status(self) -> Dict:
        """
        Get overall queue status

        Returns:
            Dictionary with queue statistics
        """
        with self._lock:
            pending = sum(1 for j in self.jobs.values() if j.status == JobStatus.PENDING)
            running = sum(1 for j in self.jobs.values() if j.status == JobStatus.RUNNING)
            completed = sum(1 for j in self.jobs.values() if j.status == JobStatus.COMPLETED)
            failed = sum(1 for j in self.jobs.values() if j.status == JobStatus.FAILED)

            return {
                "total_jobs": len(self.jobs),
                "pending": pending,
                "running": running,
                "completed": completed,
                "failed": failed,
                "queue_length": len(self.queue)
            }

    def cleanup_old_jobs(self, keep_recent: int = 100):
        """
        Clean up old completed/failed jobs to prevent memory bloat

        Args:
            keep_recent: Number of recent completed jobs to keep
        """
        with self._lock:
            # Get completed and failed jobs sorted by completion time
            finished_jobs = [
                job for job in self.jobs.values()
                if job.status in (JobStatus.COMPLETED, JobStatus.FAILED) and job.completed_at
            ]

            if len(finished_jobs) <= keep_recent:
                return

            # Sort by completion time (oldest first)
            finished_jobs.sort(key=lambda j: j.completed_at)

            # Remove oldest jobs beyond the keep_recent limit
            jobs_to_remove = finished_jobs[:-keep_recent]
            for job in jobs_to_remove:
                del self.jobs[job.id]
                logger.debug(f"Cleaned up old job {job.id}")

            logger.info(f"Cleaned up {len(jobs_to_remove)} old jobs")


# Global job queue instance
# This is used throughout the application
job_queue = JobQueue()


# Helper functions for common operations

def create_code_loading_job(jurisdiction_id: str) -> str:
    """
    Create a new code loading job

    Args:
        jurisdiction_id: Target jurisdiction UUID

    Returns:
        job_id: Unique identifier for the created job
    """
    return job_queue.add_job(jurisdiction_id, "load_codes")


def get_job_status(job_id: str) -> Optional[Dict]:
    """
    Get job status as dictionary

    Args:
        job_id: Job identifier

    Returns:
        Dictionary with job data or None if not found
    """
    job = job_queue.get_job(job_id)
    return job.to_dict() if job else None


def update_job_progress(job_id: str, progress: int, status: Optional[JobStatus] = None):
    """
    Update job progress

    Args:
        job_id: Job identifier
        progress: Progress percentage (0-100)
        status: Optional status update
    """
    if status:
        job_queue.update_job_status(job_id, status, progress=progress)
    else:
        job = job_queue.get_job(job_id)
        if job:
            job_queue.update_job_status(job_id, job.status, progress=progress)


def mark_job_completed(job_id: str, result: Dict):
    """
    Mark job as completed with result

    Args:
        job_id: Job identifier
        result: Result data dictionary
    """
    job_queue.update_job_result(job_id, result)
    job_queue.update_job_status(job_id, JobStatus.COMPLETED, progress=100)


def mark_job_failed(job_id: str, error: str):
    """
    Mark job as failed with error message

    Args:
        job_id: Job identifier
        error: Error message
    """
    job_queue.update_job_status(job_id, JobStatus.FAILED, error=error)


def has_active_job_for_jurisdiction(jurisdiction_id: str) -> bool:
    """
    Check if jurisdiction has an active code loading job

    Args:
        jurisdiction_id: Jurisdiction UUID

    Returns:
        True if there's an active job, False otherwise
    """
    return job_queue.has_pending_job(jurisdiction_id)
