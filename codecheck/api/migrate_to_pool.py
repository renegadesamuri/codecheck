#!/usr/bin/env python3
"""
Migration Script: Transition from Direct Connections to Connection Pool

This script helps identify places in your code that need to be updated
to use the new connection pool.

Usage:
    python migrate_to_pool.py [path_to_your_code.py]

It will:
1. Scan for old connection patterns
2. Suggest replacements
3. Show side-by-side comparisons
"""

import sys
import re
from pathlib import Path


class ConnectionPatternMigrator:
    """Helps migrate from direct connections to connection pool"""

    def __init__(self):
        self.patterns = {
            'direct_connect': {
                'pattern': r'psycopg2\.connect\(',
                'description': 'Direct psycopg2.connect() call',
                'suggestion': 'Use get_db() context manager or execute_query()'
            },
            'manual_close': {
                'pattern': r'conn\.close\(\)',
                'description': 'Manual connection close',
                'suggestion': 'Remove - connection pool handles this automatically'
            },
            'manual_commit': {
                'pattern': r'conn\.commit\(\)',
                'description': 'Manual commit',
                'suggestion': 'Optional - context manager commits automatically'
            },
            'manual_rollback': {
                'pattern': r'conn\.rollback\(\)',
                'description': 'Manual rollback',
                'suggestion': 'Optional - context manager rolls back on exception'
            },
            'get_db_connection': {
                'pattern': r'def get_db_connection\(',
                'description': 'Old get_db_connection() function',
                'suggestion': 'Replace with connection pool get_db()'
            }
        }

    def scan_file(self, filepath: Path) -> dict:
        """Scan a file for patterns that need migration"""
        if not filepath.exists():
            return {'error': f'File not found: {filepath}'}

        try:
            content = filepath.read_text()
            lines = content.split('\n')

            findings = []
            for line_num, line in enumerate(lines, 1):
                for pattern_name, pattern_info in self.patterns.items():
                    if re.search(pattern_info['pattern'], line):
                        findings.append({
                            'line_number': line_num,
                            'line_content': line.strip(),
                            'pattern': pattern_name,
                            'description': pattern_info['description'],
                            'suggestion': pattern_info['suggestion']
                        })

            return {
                'filepath': str(filepath),
                'total_findings': len(findings),
                'findings': findings
            }

        except Exception as e:
            return {'error': f'Error reading file: {e}'}

    def generate_migration_examples(self):
        """Generate before/after migration examples"""
        examples = []

        # Example 1: Simple query
        examples.append({
            'title': 'Simple SELECT Query',
            'before': '''
# OLD: Direct connection
conn = get_db_connection()
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM table WHERE id = %s", (id,))
        result = cursor.fetchone()
finally:
    conn.close()
''',
            'after': '''
# NEW: Connection pool
from database import get_db

with get_db(read_only=True) as cur:
    cur.execute("SELECT * FROM table WHERE id = %s", (id,))
    result = cur.fetchone()
''',
            'benefits': [
                'Automatic connection management',
                'No manual close needed',
                'Thread-safe pooling',
                'Connection reuse'
            ]
        })

        # Example 2: Multiple queries
        examples.append({
            'title': 'Execute Multiple Queries',
            'before': '''
# OLD: Direct connection
conn = get_db_connection()
try:
    with conn.cursor(cursor_factory=RealDictCursor) as cursor:
        cursor.execute("SELECT * FROM table1")
        results1 = cursor.fetchall()

        cursor.execute("SELECT * FROM table2")
        results2 = cursor.fetchall()
finally:
    conn.close()
''',
            'after': '''
# NEW: Connection pool (Option 1 - Helper)
from database import execute_query

results1 = execute_query("SELECT * FROM table1", read_only=True)
results2 = execute_query("SELECT * FROM table2", read_only=True)

# NEW: Connection pool (Option 2 - Context Manager)
from database import get_db

with get_db(read_only=True) as cur:
    cur.execute("SELECT * FROM table1")
    results1 = cur.fetchall()

    cur.execute("SELECT * FROM table2")
    results2 = cur.fetchall()
''',
            'benefits': [
                'Cleaner code',
                'Automatic resource cleanup',
                'Built-in error handling'
            ]
        })

        # Example 3: Transaction
        examples.append({
            'title': 'Transaction with Multiple Operations',
            'before': '''
# OLD: Manual transaction
conn = get_db_connection()
try:
    cursor = conn.cursor()
    cursor.execute("INSERT INTO table1 (...) VALUES (...)", (...))
    cursor.execute("UPDATE table2 SET ... WHERE ...", (...))
    conn.commit()
except Exception as e:
    conn.rollback()
    raise
finally:
    conn.close()
''',
            'after': '''
# NEW: Automatic transaction
from database import get_db

with get_db(read_only=False) as cur:
    cur.execute("INSERT INTO table1 (...) VALUES (...)", (...))
    cur.execute("UPDATE table2 SET ... WHERE ...", (...))
    # Automatically commits on success, rolls back on exception
''',
            'benefits': [
                'Automatic commit on success',
                'Automatic rollback on error',
                'No manual transaction management',
                'Cleaner error handling'
            ]
        })

        # Example 4: FastAPI endpoint
        examples.append({
            'title': 'FastAPI Endpoint',
            'before': '''
# OLD: FastAPI endpoint
@app.get("/items")
async def get_items():
    conn = get_db_connection()
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cursor:
            cursor.execute("SELECT * FROM items")
            items = cursor.fetchall()
            return {"items": items}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()
''',
            'after': '''
# NEW: FastAPI endpoint with pool
from database import execute_query, DatabaseQueryError

@app.get("/items")
async def get_items():
    try:
        items = execute_query("SELECT * FROM items", read_only=True)
        return {"items": items}
    except DatabaseQueryError as e:
        raise HTTPException(status_code=500, detail=str(e))
''',
            'benefits': [
                'Much cleaner code',
                'Better error handling',
                'Connection pooling built-in',
                'Easier to read and maintain'
            ]
        })

        return examples

    def print_findings(self, results: dict):
        """Print findings in a readable format"""
        if 'error' in results:
            print(f"❌ {results['error']}")
            return

        print(f"\n📄 File: {results['filepath']}")
        print(f"🔍 Found {results['total_findings']} patterns to migrate\n")

        if results['total_findings'] == 0:
            print("✅ No migration patterns found - file looks good!")
            return

        for finding in results['findings']:
            print(f"  Line {finding['line_number']}: {finding['description']}")
            print(f"    Code: {finding['line_content']}")
            print(f"    💡 Suggestion: {finding['suggestion']}")
            print()

    def print_examples(self, examples: list):
        """Print migration examples"""
        print("\n" + "="*80)
        print("MIGRATION EXAMPLES")
        print("="*80 + "\n")

        for i, example in enumerate(examples, 1):
            print(f"\n{'='*80}")
            print(f"Example {i}: {example['title']}")
            print('='*80)

            print("\n📌 BEFORE (Old Pattern):")
            print("-" * 80)
            print(example['before'])

            print("\n✨ AFTER (New Pattern with Connection Pool):")
            print("-" * 80)
            print(example['after'])

            print("\n🎯 Benefits:")
            for benefit in example['benefits']:
                print(f"  ✓ {benefit}")
            print()


def main():
    """Main migration helper"""
    migrator = ConnectionPatternMigrator()

    print("="*80)
    print("DATABASE CONNECTION POOL MIGRATION HELPER")
    print("="*80)

    # If file path provided, scan it
    if len(sys.argv) > 1:
        filepath = Path(sys.argv[1])
        results = migrator.scan_file(filepath)
        migrator.print_findings(results)

        if results.get('total_findings', 0) > 0:
            print("\n💡 See migration examples below for how to update your code:")
    else:
        print("\nUsage: python migrate_to_pool.py [path_to_file.py]")
        print("\nNo file specified - showing migration examples:\n")

    # Always show examples
    examples = migrator.generate_migration_examples()
    migrator.print_examples(examples)

    # Print quick reference
    print("\n" + "="*80)
    print("QUICK REFERENCE")
    print("="*80)
    print("""
Import statements:
    from database import get_db, execute_query, execute_transaction

Simple query:
    results = execute_query("SELECT * FROM table", read_only=True)

Query with context manager:
    with get_db(read_only=True) as cur:
        cur.execute("SELECT * FROM table")
        results = cur.fetchall()

Insert/Update:
    with get_db(read_only=False) as cur:
        cur.execute("INSERT INTO table (...) VALUES (...)", (...))

Transaction:
    with get_db(read_only=False) as cur:
        cur.execute("INSERT ...")
        cur.execute("UPDATE ...")
        # Auto-commits on success, auto-rollbacks on error

Health check:
    from database import database_health_check
    health = database_health_check()

Shutdown (on app exit):
    from database import shutdown_database
    shutdown_database()
""")

    print("\n📚 For more information:")
    print("  - Full documentation: DATABASE_POOL_README.md")
    print("  - Quick start guide: QUICK_START.md")
    print("  - Integration example: main_with_pool.py")
    print("  - Test examples: test_database.py")
    print("\n")


if __name__ == '__main__':
    main()
