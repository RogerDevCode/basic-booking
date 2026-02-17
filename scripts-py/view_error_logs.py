#!/usr/bin/env python3
"""
View error logs from the database
Usage: python view_error_logs.py [--limit 10] [--id 123]
"""

import argparse
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime

# Database configuration
DB_CONFIG = {
    "host": "ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech",
    "database": "neondb",
    "user": "neondb_owner",
    "password": "npg_S4woXq3lxJjd"
}

def get_connection():
    """Create database connection"""
    return psycopg2.connect(**DB_CONFIG)

def view_error_logs(limit=10, execution_id=None):
    """Query and display error logs"""
    conn = get_connection()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    try:
        if execution_id:
            query = """
                SELECT id, workflow_name, error_type, error_message, 
                       severity, environment, metadata, created_at, updated_at
                FROM error_handling.error_logs
                WHERE execution_id = %s OR id = %s
                ORDER BY created_at DESC
            """
            cur.execute(query, (execution_id, execution_id))
        else:
            query = """
                SELECT id, workflow_name, error_type, error_message, 
                       severity, environment, metadata, created_at, updated_at
                FROM error_handling.error_logs
                ORDER BY created_at DESC
                LIMIT %s
            """
            cur.execute(query, (limit,))
        
        rows = cur.fetchall()
        
        if not rows:
            print("No error logs found.")
            return
        
        print(f"\n{'='*80}")
        print(f"ERROR LOGS - {len(rows)} record(s)")
        print(f"{'='*80}\n")
        
        for row in rows:
            print(f"📋 ID: {row['id']}")
            print(f"   Workflow: {row['workflow_name']}")
            print(f"   Type: {row['error_type']}")
            print(f"   Severity: {row['severity']} | Environment: {row['environment']}")
            print(f"   Message: {row['error_message'][:100]}...")
            print(f"   Created: {row['created_at']}")
            
            # Show metadata if available
            if row['metadata']:
                import json
                try:
                    meta = json.loads(row['metadata']) if isinstance(row['metadata'], str) else row['metadata']
                    print(f"   Metadata:")
                    print(f"      - Execution ID: {meta.get('execution_id', 'N/A')}")
                    print(f"      - Workflow ID: {meta.get('workflow_id', 'N/A')}")
                    print(f"      - Timestamp: {meta.get('timestamp', 'N/A')}")
                except:
                    pass
            
            print(f"{'-'*80}\n")
        
        # Summary statistics
        cur.execute("""
            SELECT 
                COUNT(*) as total,
                COUNT(DISTINCT workflow_name) as workflows,
                COUNT(DISTINCT severity) as severity_levels,
                MIN(created_at) as first_log,
                MAX(created_at) as last_log
            FROM error_handling.error_logs
        """)
        stats = cur.fetchone()
        
        print(f"{'='*80}")
        print("SUMMARY")
        print(f"{'='*80}")
        print(f"Total Records: {stats['total']}")
        print(f"Unique Workflows: {stats['workflows']}")
        print(f"Severity Levels: {stats['severity_levels']}")
        print(f"First Log: {stats['first_log']}")
        print(f"Last Log: {stats['last_log']}")
        
    finally:
        cur.close()
        conn.close()

def main():
    parser = argparse.ArgumentParser(description="View error logs from database")
    parser.add_argument("--limit", "-l", type=int, default=10, help="Number of records to show")
    parser.add_argument("--id", "-i", type=str, help="Filter by execution ID or log ID")
    parser.add_argument("--json", "-j", action="store_true", help="Output as JSON")
    
    args = parser.parse_args()
    
    if args.json:
        conn = get_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        query = """
            SELECT * FROM error_handling.error_logs
            ORDER BY created_at DESC
            LIMIT %s
        """
        cur.execute(query, (args.limit,))
        rows = cur.fetchall()
        import json
        # Convert datetime to string
        for row in rows:
            for key, value in row.items():
                if isinstance(value, datetime):
                    row[key] = value.isoformat()
        print(json.dumps(rows, indent=2, default=str))
        cur.close()
        conn.close()
    else:
        view_error_logs(limit=args.limit, execution_id=args.id)

if __name__ == "__main__":
    main()
