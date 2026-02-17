#!/usr/bin/env python3
"""
N8N Read Executions

Usage:
    python n8n_read_executions.py
    python n8n_read_executions.py --workflow WORKFLOW_ID
    python n8n_read_executions.py --execution EXECUTION_ID
    python n8n_read_executions.py --workflow WORKFLOW_ID --limit 20
    python n8n_read_executions.py --status error
"""

import argparse
import json
import sys
from typing import Optional, List
from datetime import datetime

import requests

from config import N8NConfig


def list_executions(
    config: N8NConfig,
    workflow_id: Optional[str] = None,
    limit: int = 10,
    status: Optional[str] = None,
) -> Optional[List[dict]]:
    """
    List executions from n8n

    Args:
        config: N8N configuration
        workflow_id: Filter by workflow ID
        limit: Maximum number of executions
        status: Filter by status (success, error, running, waiting)

    Returns:
        List of executions or None on error
    """
    try:
        params = {"limit": limit, "includeData": "true"}
        if workflow_id:
            params["workflowId"] = workflow_id

        response = requests.get(
            config.execution_endpoint(),
            headers=config.headers,
            params=params,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            data = response.json()
            executions = data.get("data", [])

            if status:
                executions = [e for e in executions if e.get("status") == status]

            return executions
        else:
            print(f"Error listing executions: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def get_execution(config: N8NConfig, execution_id: str) -> Optional[dict]:
    """
    Get a specific execution by ID

    Args:
        config: N8N configuration
        execution_id: Execution ID

    Returns:
        Execution data or None on error
    """
    try:
        response = requests.get(
            f"{config.execution_endpoint(execution_id)}?includeData=true",
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error getting execution: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def format_execution_summary(execution: dict) -> str:
    """Format execution as summary"""
    status = execution.get("status", "unknown")
    status_emoji = {"success": "✓", "error": "✗", "running": "⏳", "waiting": "⏸"}.get(
        status, "?"
    )

    lines = [
        f"Execution ID: {execution.get('id')}",
        f"Status: {status_emoji} {status}",
        f"Workflow ID: {execution.get('workflowId')}",
        f"Mode: {execution.get('mode', 'N/A')}",
        f"Started: {execution.get('startedAt', 'N/A')}",
        f"Stopped: {execution.get('stoppedAt', 'N/A')}",
    ]

    if status == "error":
        error = execution.get("error", {})
        if error:
            lines.append(f"Error: {error.get('message', str(error))}")

    return "\n".join(lines)


def format_executions_table(executions: List[dict]) -> str:
    """Format executions as table"""
    if not executions:
        return "No executions found."

    lines = [
        f"{'ID':<12} | {'Status':<8} | {'Workflow':<20} | {'Started':<20}",
        f"{'-' * 12}-+-{'-' * 8}-+-{'-' * 20}-+-{'-' * 20}",
    ]

    for e in executions:
        exec_id = str(e.get("id", ""))[:12]
        status = e.get("status", "")[:8]
        workflow = str(e.get("workflowId", ""))[:20]
        started = (e.get("startedAt") or "")[:19].replace("T", " ")
        lines.append(f"{exec_id:<12} | {status:<8} | {workflow:<20} | {started:<20}")

    lines.append(f"\nTotal: {len(executions)} execution(s)")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Get n8n executions",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s
  %(prog)s --workflow abc123
  %(prog)s --execution exec456
  %(prog)s --workflow abc123 --limit 20
  %(prog)s --status error
""",
    )

    target_group = parser.add_mutually_exclusive_group()
    target_group.add_argument(
        "--workflow", "-w", help="Filter executions by workflow ID"
    )
    target_group.add_argument("--execution", "-e", help="Get specific execution by ID")

    parser.add_argument(
        "--limit",
        "-l",
        type=int,
        default=10,
        help="Maximum number of executions to return (default: 10)",
    )
    parser.add_argument(
        "--status",
        "-s",
        choices=["success", "error", "running", "waiting"],
        help="Filter by execution status",
    )
    parser.add_argument(
        "--format",
        choices=["table", "json", "summary"],
        default="table",
        help="Output format: table (default), json, or summary",
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    if args.execution:
        execution = get_execution(config, args.execution)
        if execution is None:
            sys.exit(1)

        if args.format == "json":
            print(json.dumps(execution, indent=2))
        else:
            print(format_execution_summary(execution))
    else:
        executions = list_executions(
            config=config,
            workflow_id=args.workflow,
            limit=args.limit,
            status=args.status,
        )

        if executions is None:
            sys.exit(1)

        if args.format == "json":
            print(json.dumps(executions, indent=2))
        else:
            print(format_executions_table(executions))


if __name__ == "__main__":
    main()
