#!/usr/bin/env python3
"""
N8N Update Deactivate Workflow

Usage:
    python n8n_update_deactivate.py --id WORKFLOW_ID
    python n8n_update_deactivate.py --name "BB_00_Global_Error_Handler"
    python n8n_update_deactivate.py --filter "Test_" --all
"""

import argparse
import json
import sys
from typing import Optional, List

import requests

from config import N8NConfig


def deactivate_workflow(config: N8NConfig, workflow_id: str) -> bool:
    """
    Deactivate a workflow

    Args:
        config: N8N configuration
        workflow_id: Workflow ID

    Returns:
        True on success, False on error
    """
    try:
        response = requests.post(
            f"{config.workflow_endpoint(workflow_id)}/deactivate",
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            return True
        else:
            print(
                f"Error deactivating workflow {workflow_id}: {response.status_code} - {response.text}"
            )
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False


def list_workflows(
    config: N8NConfig, name_filter: Optional[str] = None, active_only: bool = True
) -> Optional[List[dict]]:
    """List workflows with optional filter"""
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


def main():
    parser = argparse.ArgumentParser(
        description="Deactivate n8n workflows",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --id abc123
  %(prog)s --name "BB_00_Global_Error_Handler"
  %(prog)s --filter "Test_" --all
""",
    )

    target_group = parser.add_mutually_exclusive_group(required=True)
    target_group.add_argument("--id", "-i", help="Workflow ID to deactivate")
    target_group.add_argument(
        "--name", "-n", help="Workflow name to deactivate (exact match)"
    )
    target_group.add_argument(
        "--filter",
        "-f",
        help="Deactivate all workflows matching name filter (requires --all)",
    )

    parser.add_argument(
        "--all",
        "-a",
        action="store_true",
        help="Deactivate all matching workflows (use with --filter)",
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    if args.filter and not args.all:
        print("Error: --filter requires --all to deactivate multiple workflows")
        sys.exit(1)

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    if args.id:
        print(f"Deactivating workflow {args.id}...")
        if deactivate_workflow(config, args.id):
            print("Success! Workflow deactivated.")
        else:
            sys.exit(1)

    elif args.name:
        workflows = list_workflows(config, active_only=True)
        if workflows is None:
            sys.exit(1)

        workflow_id = None
        for w in workflows:
            if w.get("name") == args.name:
                workflow_id = w.get("id")
                break

        if not workflow_id:
            print(f"Error: Active workflow '{args.name}' not found")
            sys.exit(1)

        print(f"Deactivating workflow '{args.name}' ({workflow_id})...")
        if deactivate_workflow(config, workflow_id):
            print("Success! Workflow deactivated.")
        else:
            sys.exit(1)

    elif args.filter:
        workflows = list_workflows(config, args.filter, active_only=True)
        if workflows is None:
            sys.exit(1)

        if not workflows:
            print(f"No active workflows found matching '{args.filter}'")
            sys.exit(0)

        success_count = 0
        for w in workflows:
            workflow_id = w.get("id")
            workflow_name = w.get("name")
            print(f"Deactivating: {workflow_name} ({workflow_id})...")
            if deactivate_workflow(config, workflow_id):
                success_count += 1

        print(f"\nDeactivated {success_count}/{len(workflows)} workflows")


if __name__ == "__main__":
    main()
