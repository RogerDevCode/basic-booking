#!/usr/bin/env python3
"""
N8N Delete Workflow

Usage:
    python n8n_delete.py --id WORKFLOW_ID
    python n8n_delete.py --id WORKFLOW_ID --force
    python n8n_delete.py --name "Test_Workflow"
    python n8n_delete.py --id WORKFLOW_ID --deactivate-first
"""

import argparse
import json
import sys
from typing import Optional, List

import requests

from config import N8NConfig


def delete_workflow(config: N8NConfig, workflow_id: str) -> bool:
    """
    Delete a workflow

    Args:
        config: N8N configuration
        workflow_id: Workflow ID

    Returns:
        True on success, False on error
    """
    try:
        response = requests.delete(
            config.workflow_endpoint(workflow_id),
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            return True
        else:
            print(
                f"Error deleting workflow {workflow_id}: {response.status_code} - {response.text}"
            )
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False


def deactivate_workflow(config: N8NConfig, workflow_id: str) -> bool:
    """Deactivate a workflow before deletion"""
    try:
        response = requests.post(
            f"{config.workflow_endpoint(workflow_id)}/deactivate",
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )
        return response.status_code == 200
    except:
        return False


def get_workflow(config: N8NConfig, workflow_id: str) -> Optional[dict]:
    """Get workflow details"""
    try:
        response = requests.get(
            config.workflow_endpoint(workflow_id),
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            return response.json()
        return None
    except:
        return None


def list_workflows(
    config: N8NConfig, name_filter: Optional[str] = None
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


def confirm_delete(workflow_name: str, workflow_id: str, is_active: bool) -> bool:
    """Ask user for confirmation"""
    print(f"\nAbout to DELETE workflow:")
    print(f"  Name: {workflow_name}")
    print(f"  ID: {workflow_id}")
    print(f"  Status: {'ACTIVE' if is_active else 'INACTIVE'}")
    print()

    response = input("Are you sure? Type 'yes' to confirm: ")
    return response.lower() == "yes"


def main():
    parser = argparse.ArgumentParser(
        description="Delete an n8n workflow",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --id abc123
  %(prog)s --id abc123 --force
  %(prog)s --name "Test_Workflow"
  %(prog)s --id abc123 --deactivate-first
""",
    )

    target_group = parser.add_mutually_exclusive_group(required=True)
    target_group.add_argument("--id", "-i", help="Workflow ID to delete")
    target_group.add_argument(
        "--name", "-n", help="Workflow name to delete (exact match)"
    )

    parser.add_argument(
        "--force", "-f", action="store_true", help="Skip confirmation prompt"
    )
    parser.add_argument(
        "--deactivate-first",
        action="store_true",
        help="Deactivate workflow before deletion",
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    workflow_id = args.id
    workflow_name = None

    if args.name:
        workflows = list_workflows(config)
        if workflows is None:
            sys.exit(1)

        for w in workflows:
            if w.get("name") == args.name:
                workflow_id = w.get("id")
                workflow_name = w.get("name")
                break

        if not workflow_id:
            print(f"Error: Workflow '{args.name}' not found")
            sys.exit(1)

    workflow = get_workflow(config, workflow_id)
    if workflow:
        workflow_name = workflow.get("name", "Unknown")
        is_active = workflow.get("active", False)
    else:
        workflow_name = "Unknown"
        is_active = False

    if not args.force:
        if not confirm_delete(workflow_name, workflow_id, is_active):
            print("Cancelled.")
            sys.exit(0)

    if args.deactivate_first and is_active:
        print(f"Deactivating workflow first...")
        deactivate_workflow(config, workflow_id)

    print(f"Deleting workflow '{workflow_name}' ({workflow_id})...")

    if delete_workflow(config, workflow_id):
        print("Success! Workflow deleted.")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
