#!/usr/bin/env python3
"""
Autonomous Coding AI Framework
This system enables the AI to learn coding patterns autonomously through:
1. Knowledge gap identification
2. Autonomous research via MCP servers  
3. Experimentation and testing
4. Pattern storage and retrieval
5. Continuous learning loop
"""

import json
import os
import subprocess
import time
from datetime import datetime
from typing import Dict, List, Any, Optional
from pathlib import Path
import hashlib


class AutonomousCoder:
    def __init__(self, workspace_path: str = "."):
        self.workspace = Path(workspace_path)
        self.knowledge_base = self.workspace / "autonomous-learning" / "knowledge-base"
        self.experiments = self.workspace / "autonomous-learning" / "experiments"
        self.patterns = self.workspace / "autonomous-learning" / "learned-patterns"
        self.research_logs = self.workspace / "autonomous-learning" / "research-logs"
        self.training_data = self.workspace / "autonomous-learning" / "training-data"
        
        # Ensure directories exist
        for path in [self.knowledge_base, self.experiments, self.patterns, self.research_logs, self.training_data]:
            path.mkdir(parents=True, exist_ok=True)
    
    def identify_knowledge_gap(self, task: str, error_context: str = None) -> Dict[str, Any]:
        """
        Identify what the AI doesn't know to complete a coding task
        """
        gap_id = hashlib.md5(f"{task}{error_context}".encode()).hexdigest()[:8]
        
        knowledge_gap = {
            "id": gap_id,
            "timestamp": datetime.now().isoformat(),
            "task": task,
            "error_context": error_context,
            "gap_type": self._classify_gap_type(task, error_context),
            "research_priority": self._assess_priority(task),
            "status": "identified"
        }
        
        # Save gap for tracking
        gap_file = self.research_logs / f"gap_{gap_id}.json"
        with open(gap_file, 'w') as f:
            json.dump(knowledge_gap, f, indent=2)
        
        return knowledge_gap
    
    def research_solution(self, knowledge_gap: Dict[str, Any]) -> Dict[str, Any]:
        """
        Autonomously research solutions using available MCP servers
        """
        research_plan = {
            "gap_id": knowledge_gap["id"],
            "research_steps": [],
            "findings": [],
            "code_examples": [],
            "best_practices": [],
            "references": []
        }
        
        # Step 1: Query Context7 for up-to-date documentation
        context7_query = f"How to implement {knowledge_gap['task']} in modern programming"
        research_plan["research_steps"].append({
            "step": "context7_research",
            "query": context7_query,
            "timestamp": datetime.now().isoformat()
        })
        
        # Step 2: Search for real-world examples
        if knowledge_gap.get("gap_type") == "implementation":
            search_query = f"{knowledge_gap['task']} code examples best practices"
            research_plan["research_steps"].append({
                "step": "web_search",
                "query": search_query,
                "timestamp": datetime.now().isoformat()
            })
        
        # Step 3: Look for similar patterns in existing codebase
        similar_patterns = self._find_similar_patterns(knowledge_gap["task"])
        research_plan["similar_patterns"] = similar_patterns
        
        # Save research plan
        research_file = self.research_logs / f"research_{knowledge_gap['id']}.json"
        with open(research_file, 'w') as f:
            json.dump(research_plan, f, indent=2)
        
        return research_plan
    
    def create_experiment(self, research_plan: Dict[str, Any]) -> str:
        """
        Create experimental code to test learned concepts
        """
        experiment_id = f"exp_{research_plan['gap_id']}_{int(time.time())}"
        experiment_dir = self.experiments / experiment_id
        experiment_dir.mkdir(exist_ok=True)
        
        # Create experiment manifest
        experiment_manifest = {
            "id": experiment_id,
            "gap_id": research_plan["gap_id"],
            "created": datetime.now().isoformat(),
            "hypothesis": f"Testing implementation approach for: {research_plan.get('task', 'unknown')}",
            "status": "created",
            "test_files": [],
            "results": None
        }
        
        # Create basic test structure
        test_file = experiment_dir / "test_implementation.py"
        with open(test_file, 'w') as f:
            f.write(f"""
# Autonomous Learning Experiment: {experiment_id}
# Testing: {research_plan.get('task', 'unknown')}
# Created: {datetime.now().isoformat()}

import sys
import traceback
from typing import Any, Dict, List

def test_implementation():
    \"\"\"
    Experimental implementation based on research findings
    \"\"\"
    try:
        # TODO: Implement based on research findings
        # This will be filled by the AI based on research_plan
        pass
        
    except Exception as e:
        return {{
            "success": False,
            "error": str(e),
            "traceback": traceback.format_exc()
        }}
    
    return {{
        "success": True,
        "result": "Implementation successful"
    }}

if __name__ == "__main__":
    result = test_implementation()
    print(json.dumps(result, indent=2))
""")
        
        experiment_manifest["test_files"].append(str(test_file))
        
        # Save experiment manifest
        manifest_file = experiment_dir / "manifest.json"
        with open(manifest_file, 'w') as f:
            json.dump(experiment_manifest, f, indent=2)
        
        return experiment_id
    
    def execute_experiment(self, experiment_id: str) -> Dict[str, Any]:
        """
        Execute experiment and capture results for learning
        """
        experiment_dir = self.experiments / experiment_id
        manifest_file = experiment_dir / "manifest.json"
        
        if not manifest_file.exists():
            return {"error": "Experiment not found"}
        
        with open(manifest_file, 'r') as f:
            manifest = json.load(f)
        
        results = {
            "experiment_id": experiment_id,
            "execution_time": datetime.now().isoformat(),
            "test_results": [],
            "learning_points": [],
            "success": False
        }
        
        # Execute each test file
        for test_file in manifest["test_files"]:
            try:
                result = subprocess.run(
                    [sys.executable, test_file], 
                    capture_output=True, 
                    text=True,
                    timeout=30
                )
                
                test_result = {
                    "file": test_file,
                    "returncode": result.returncode,
                    "stdout": result.stdout,
                    "stderr": result.stderr,
                    "success": result.returncode == 0
                }
                
                results["test_results"].append(test_result)
                
            except subprocess.TimeoutExpired:
                results["test_results"].append({
                    "file": test_file,
                    "error": "Timeout - execution took too long",
                    "success": False
                })
        
        # Analyze results for learning
        results["success"] = all(test["success"] for test in results["test_results"])
        results["learning_points"] = self._extract_learning_points(results)
        
        # Save results
        results_file = experiment_dir / "results.json"
        with open(results_file, 'w') as f:
            json.dump(results, f, indent=2)
        
        return results
    
    def store_learned_pattern(self, experiment_results: Dict[str, Any], research_plan: Dict[str, Any]) -> str:
        """
        Store successful patterns for future reuse
        """
        if not experiment_results.get("success"):
            return None
        
        pattern_id = f"pattern_{experiment_results['experiment_id']}"
        
        learned_pattern = {
            "id": pattern_id,
            "created": datetime.now().isoformat(),
            "source_experiment": experiment_results["experiment_id"],
            "source_gap": research_plan["gap_id"],
            "pattern_type": self._classify_pattern_type(research_plan),
            "implementation_approach": self._extract_implementation_approach(experiment_results),
            "best_practices": research_plan.get("best_practices", []),
            "code_templates": self._extract_code_templates(experiment_results),
            "success_metrics": experiment_results.get("learning_points", []),
            "reuse_contexts": self._identify_reuse_contexts(research_plan)
        }
        
        # Save learned pattern
        pattern_file = self.patterns / f"{pattern_id}.json"
        with open(pattern_file, 'w') as f:
            json.dump(learned_pattern, f, indent=2)
        
        return pattern_id
    
    def autonomous_learning_cycle(self, initial_task: str) -> Dict[str, Any]:
        """
        Complete autonomous learning cycle for a coding task
        """
        cycle_log = {
            "task": initial_task,
            "started": datetime.now().isoformat(),
            "stages": [],
            "final_status": None
        }
        
        # Stage 1: Identify knowledge gap
        gap = self.identify_knowledge_gap(initial_task)
        cycle_log["stages"].append({"stage": "gap_identification", "result": gap["id"]})
        
        # Stage 2: Research solution
        research = self.research_solution(gap)
        cycle_log["stages"].append({"stage": "research", "result": research["gap_id"]})
        
        # Stage 3: Create and execute experiment
        experiment_id = self.create_experiment(research)
        cycle_log["stages"].append({"stage": "experiment_creation", "result": experiment_id})
        
        results = self.execute_experiment(experiment_id)
        cycle_log["stages"].append({"stage": "experiment_execution", "result": results["success"]})
        
        # Stage 4: Store learning if successful
        if results["success"]:
            pattern_id = self.store_learned_pattern(results, research)
            cycle_log["stages"].append({"stage": "pattern_storage", "result": pattern_id})
            cycle_log["final_status"] = "learned_successfully"
        else:
            # If failed, identify new gaps from the failure
            failure_gap = self.identify_knowledge_gap(
                f"Fix implementation issue: {initial_task}",
                error_context=str(results.get("test_results", []))
            )
            cycle_log["stages"].append({"stage": "failure_analysis", "result": failure_gap["id"]})
            cycle_log["final_status"] = "needs_iteration"
        
        cycle_log["completed"] = datetime.now().isoformat()
        
        # Save cycle log
        cycle_file = self.training_data / f"cycle_{int(time.time())}.json"
        with open(cycle_file, 'w') as f:
            json.dump(cycle_log, f, indent=2)
        
        return cycle_log
    
    def query_learned_patterns(self, task_description: str) -> List[Dict[str, Any]]:
        """
        Find previously learned patterns relevant to a new task
        """
        relevant_patterns = []
        
        # Scan all stored patterns
        for pattern_file in self.patterns.glob("*.json"):
            with open(pattern_file, 'r') as f:
                pattern = json.load(f)
            
            # Simple relevance scoring (can be enhanced with embeddings)
            relevance_score = self._calculate_relevance(task_description, pattern)
            if relevance_score > 0.3:  # Threshold for relevance
                pattern["relevance_score"] = relevance_score
                relevant_patterns.append(pattern)
        
        # Sort by relevance
        relevant_patterns.sort(key=lambda x: x["relevance_score"], reverse=True)
        
        return relevant_patterns
    
    # Helper methods
    def _classify_gap_type(self, task: str, error_context: str) -> str:
        """Classify the type of knowledge gap"""
        if error_context and "import" in error_context.lower():
            return "dependency"
        elif "implement" in task.lower() or "create" in task.lower():
            return "implementation"
        elif "fix" in task.lower() or "debug" in task.lower():
            return "debugging"
        else:
            return "concept"
    
    def _assess_priority(self, task: str) -> str:
        """Assess learning priority"""
        if any(keyword in task.lower() for keyword in ["critical", "urgent", "fix", "error"]):
            return "high"
        elif any(keyword in task.lower() for keyword in ["optimization", "refactor", "improve"]):
            return "medium"
        else:
            return "low"
    
    def _find_similar_patterns(self, task: str) -> List[Dict[str, Any]]:
        """Find similar patterns in existing learned patterns"""
        return self.query_learned_patterns(task)[:3]  # Top 3 similar patterns
    
    def _extract_learning_points(self, results: Dict[str, Any]) -> List[str]:
        """Extract key learning points from experiment results"""
        learning_points = []
        
        for test_result in results.get("test_results", []):
            if test_result["success"]:
                learning_points.append("Implementation executed successfully")
            else:
                if test_result.get("stderr"):
                    learning_points.append(f"Error pattern: {test_result['stderr'][:100]}")
        
        return learning_points
    
    def _classify_pattern_type(self, research_plan: Dict[str, Any]) -> str:
        """Classify the type of learned pattern"""
        task = research_plan.get("task", "").lower()
        if "api" in task:
            return "api_integration"
        elif "database" in task or "db" in task:
            return "data_persistence"
        elif "test" in task:
            return "testing"
        elif "ui" in task or "frontend" in task:
            return "user_interface"
        else:
            return "general"
    
    def _extract_implementation_approach(self, results: Dict[str, Any]) -> str:
        """Extract the successful implementation approach"""
        if results["success"]:
            return "Successful experimental implementation"
        else:
            return "Implementation needs refinement"
    
    def _extract_code_templates(self, results: Dict[str, Any]) -> List[str]:
        """Extract reusable code templates from successful experiments"""
        templates = []
        for test_result in results.get("test_results", []):
            if test_result["success"] and test_result.get("stdout"):
                templates.append(test_result["stdout"])
        return templates
    
    def _identify_reuse_contexts(self, research_plan: Dict[str, Any]) -> List[str]:
        """Identify contexts where this pattern can be reused"""
        task = research_plan.get("task", "")
        contexts = []
        
        # Basic context identification
        if "web" in task.lower():
            contexts.append("web_development")
        if "api" in task.lower():
            contexts.append("api_development")
        if "data" in task.lower():
            contexts.append("data_processing")
        
        return contexts
    
    def _calculate_relevance(self, task_description: str, pattern: Dict[str, Any]) -> float:
        """Calculate relevance score between task and stored pattern"""
        task_words = set(task_description.lower().split())
        pattern_contexts = set()
        
        # Gather pattern context words
        if pattern.get("reuse_contexts"):
            for context in pattern["reuse_contexts"]:
                pattern_contexts.update(context.lower().split("_"))
        
        if pattern.get("pattern_type"):
            pattern_contexts.update(pattern["pattern_type"].lower().split("_"))
        
        # Simple word overlap scoring
        overlap = len(task_words.intersection(pattern_contexts))
        total_words = len(task_words.union(pattern_contexts))
        
        return overlap / total_words if total_words > 0 else 0.0


# Example usage for the autonomous AI
if __name__ == "__main__":
    import sys
    
    coder = AutonomousCoder()
    
    if len(sys.argv) > 1:
        task = " ".join(sys.argv[1:])
        print(f"Starting autonomous learning cycle for: {task}")
        
        # Check for existing patterns first
        existing_patterns = coder.query_learned_patterns(task)
        if existing_patterns:
            print(f"Found {len(existing_patterns)} relevant patterns:")
            for pattern in existing_patterns[:3]:
                print(f"- {pattern['id']}: {pattern.get('pattern_type', 'unknown')} (relevance: {pattern['relevance_score']:.2f})")
        
        # Run learning cycle
        cycle_result = coder.autonomous_learning_cycle(task)
        print(f"Learning cycle completed: {cycle_result['final_status']}")
        print(f"Stages completed: {len(cycle_result['stages'])}")
        
    else:
        print("Usage: python autonomous_coder.py <coding_task_description>")
        print("Example: python autonomous_coder.py 'implement REST API with authentication'") 