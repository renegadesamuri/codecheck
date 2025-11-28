#!/usr/bin/env python3
"""
Test script for connectivity agents

Run this to test the mini-agent infrastructure before integrating with the main application.
"""

import asyncio
import logging
import sys
import os

# Add the project root to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)


async def test_agents():
    """Test the connectivity agent system"""

    print("\n" + "="*60)
    print("  TESTING CODECHECK CONNECTIVITY AGENTS")
    print("="*60 + "\n")

    try:
        # Import the connectivity hub
        from agents.mini_agents.agent_hub import ConnectivityHub

        # Initialize hub
        print("📦 Initializing Connectivity Hub...")
        hub = ConnectivityHub()
        print(f"✅ Initialized {len(hub.agents)} agents\n")

        # Run startup tests
        print("🔍 Running startup connectivity tests...\n")
        results = await hub.run_startup_tests()

        # Display results
        for result in results:
            agent_name = result['agent']
            status = result['status']
            critical = result.get('critical', False)

            status_emoji = "✅" if status == 'healthy' else "❌"
            critical_marker = " [CRITICAL]" if critical else ""

            print(f"{status_emoji} {agent_name}{critical_marker}")
            print(f"   Findings: {result.get('findings', 0)}")
            print(f"   Execution time: {result.get('execution_time_ms', 0)}ms")

            # Show errors if any
            if 'errors' in result:
                print("   Errors:")
                for error in result['errors']:
                    print(f"     - {error['title']}")
                    print(f"       {error['description']}")
                    print(f"       Fix: {error['fix']}")

            print()

        # Get current status
        print("\n📊 Getting current system status...\n")
        status = await hub.get_current_status()

        print(f"Overall Status: {status['overall_status'].upper()}\n")

        print("Connections:")
        for conn in status.get('connections', []):
            status_emoji = {
                'healthy': '✅',
                'degraded': '⚠️ ',
                'failed': '❌'
            }.get(conn['status'], '❓')

            latency = f" ({conn['latency_ms']}ms)" if conn['latency_ms'] else ""
            print(f"  {status_emoji} {conn['name']}{latency}")

            if conn['error']:
                print(f"      Error: {conn['error']}")

        print()

        # Generate text report
        print("\n📝 Generating connectivity report...\n")
        report = await hub.generate_report(format='text')
        print(report)

        print("\n" + "="*60)
        print("  TEST COMPLETE")
        print("="*60 + "\n")

        # Check if any critical failures
        critical_failures = [r for r in results if r.get('critical') and r.get('status') == 'failed']
        if critical_failures:
            print("❌ Critical connectivity failures detected!")
            print("   The application should not start until these are resolved.\n")
            return 1
        else:
            print("✅ All critical connections are healthy!")
            print("   The application is ready to start.\n")
            return 0

    except Exception as e:
        logger.error(f"Test failed: {e}", exc_info=True)
        print(f"\n❌ Test failed: {e}\n")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(test_agents())
    sys.exit(exit_code)
