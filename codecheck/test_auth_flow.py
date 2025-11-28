"""
Test script for Auth Flow Testing Agent

Tests the auth flow tester directly.
"""

import asyncio
import sys
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from agents.mini_agents.auth_flow_tester import AuthFlowTesterAgent


async def main():
    print("=" * 60)
    print("  AUTH FLOW TESTING AGENT")
    print("=" * 60)
    print()

    # Create agent
    agent = AuthFlowTesterAgent()

    print(f"🔐 Testing {agent.name} agent...")
    print()

    # Execute checks
    result = await agent.execute(run_type='manual')

    print(f"✅ Execution completed in {result.execution_time_ms}ms")
    print()

    # Display results
    print(f"Total findings: {len(result.findings)}")
    print(f"Remediations: {result.remediations_count}")
    print()

    if result.findings:
        # Categorize by severity
        from agents.mini_agents.base_agent import FindingSeverity

        critical = [f for f in result.findings if f.severity == FindingSeverity.CRITICAL]
        warnings = [f for f in result.findings if f.severity == FindingSeverity.WARNING]
        info = [f for f in result.findings if f.severity == FindingSeverity.INFO]

        if critical:
            print(f"🚨 CRITICAL ISSUES ({len(critical)}):")
            print("-" * 60)
            for finding in critical:
                print(f"\n{finding.title}")
                print(f"  Category: {finding.category}")
                print(f"  Description: {finding.description}")
                print(f"  Fix: {finding.fix_action}")

        if warnings:
            print(f"\n⚠️  WARNINGS ({len(warnings)}):")
            print("-" * 60)
            for finding in warnings:
                print(f"\n{finding.title}")
                print(f"  Category: {finding.category}")
                print(f"  Description: {finding.description}")
                print(f"  Fix: {finding.fix_action}")

        if info:
            print(f"\nℹ️  INFORMATION ({len(info)}):")
            print("-" * 60)
            for finding in info:
                print(f"\n{finding.title}")
                print(f"  Description: {finding.description}")
                print(f"  Fix: {finding.fix_action}")

        print()
        print("=" * 60)
    else:
        print("✅ No authentication security issues found!")
        print("=" * 60)


if __name__ == '__main__':
    asyncio.run(main())
