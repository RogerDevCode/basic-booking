#!/usr/bin/env python3
"""
N8N Read List Workflows

Usage:
    python n8n_read_list.py
    python n8n_read_list.py --active
    python n8n_read_list.py --inactive
    python n8n_read_list.py --filter "BB_"
    python n8n_read_list.py --format table
    python n8n_read_list.py --format json
"""

import argparse
import json
import sys
from typing import Optional, List

import requests

from config import N8NConfig


def list_workflows(
    config: N8NConfig,
    active_only: bool = False,
    inactive_only: bool = False,
    name_filter: Optional[str] = None,
) -> Optional[List[dict]]:
    """
    List workflows from n8n

    Args:
        config: N8N configuration
        active_only: Only return active workflows
        inactive_only: Only return inactive workflows
        name_filter: Filter workflows by name (case-insensitive)

    Returns:
        List of workflows or None on error
    """
    try:
        response = requests.get(
            config.workflow_endpoint(),
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            data = response.json()
            workflows = data.get("data", [])

            if active_only:
                workflows = [w for w in workflows if w.get("active", False)]
            elif inactive_only:
                workflows = [w for w in workflows if not w.get("active", False)]

            if name_filter:
                filter_lower = name_filter.lower()
                workflows = [
                    w for w in workflows if filter_lower in w.get("name", "").lower()
                ]

            return workflows
        else:
            print(f"Error listing workflows: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def format_table(workflows: List[dict]) -> str:
    """Format workflows as ASCII table"""
    if not workflows:
        return "No workflows found."

    max_id_len = max(len(str(w.get("id", ""))) for w in workflows)
    max_name_len = max(len(w.get("name", "")) for w in workflows)

    id_len = max(max_id_len, 2)
    name_len = max(max_name_len, 4)

    header = f"{'ID':<{id_len}} | {'Name':<{name_len}} | Status"
    separator = f"{'-' * id_len}-+-{'-' * name_len}-+-{'-' * 8}"

    lines = [separator, header, separator]

    for w in workflows:
        workflow_id = str(w.get("id", ""))
        name = w.get("name", "")
        status = "ACTIVE  " if w.get("active", False) else "INACTIVE"
        lines.append(f"{workflow_id:<{id_len}} | {name:<{name_len}} | {status}")

    lines.append(separator)
    lines.append(f"Total: {len(workflows)} workflow(s)")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="List n8n workflows",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s
  %(prog)s --active
  %(prog)s --inactive
  %(prog)s --filter "BB_"
  %(prog)s --format json
  %(prog)s --format table --active
""",
    )

    filter_group = parser.add_mutually_exclusive_group()
    filter_group.add_argument(
        "--active", action="store_true", help="Show only active workflows"
    )
    filter_group.add_argument(
        "--inactive", action="store_true", help="Show only inactive workflows"
    )

    parser.add_argument(
        "--filter",
        "-f",
        help="Filter workflows by name (case-insensitive substring match)",
    )
    parser.add_argument(
        "--format",
        choices=["table", "json", "ids", "names"],
        default="table",
        help="Output format: table (default), json, ids, or names",
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    workflows = list_workflows(
        config=config,
        active_only=args.active,
        inactive_only=args.inactive,
        name_filter=args.filter,
    )

    if workflows is None:
        sys.exit(1)

    if args.format == "json":
        print(json.dumps(workflows, indent=2))
    elif args.format == "ids":
        for w in workflows:
            print(w.get("id"))
    elif args.format == "names":
        for w in workflows:
            print(w.get("name"))
    else:
        print(format_table(workflows))


if __name__ == "__main__":
    main()
