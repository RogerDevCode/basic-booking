#!/usr/bin/env python3
"""
N8N Update Workflow from File

Usage:
    python n8n_update_from_file.py --id WORKFLOW_ID --file workflow.json
    python n8n_update_from_file.py --id WORKFLOW_ID --file workflow.json --activate
"""

import argparse
import json
import sys
from pathlib import Path

import requests

from config import N8NConfig, WORKFLOWS_DIR


def update_workflow(
    config: N8NConfig, workflow_id: str, workflow_data: dict, activate: bool = False
) -> bool:
    """
    Update a workflow in n8n

    Args:
        config: N8N configuration
        workflow_id: Workflow ID to update
        workflow_data: New workflow definition
        activate: Activate after update

    Returns:
        True on success, False on error
    """
    try:
        response = requests.put(
            config.workflow_endpoint(workflow_id),
            headers=config.headers,
            json=workflow_data,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            if activate:
                activate_url = f"{config.workflow_endpoint(workflow_id)}/activate"
                activate_resp = requests.post(
                    activate_url,
                    headers=config.headers,
                    timeout=config.timeout,
                    verify=config.verify_ssl,
                )
                if activate_resp.status_code != 200:
                    print(
                        f"Warning: Workflow updated but activation failed: {activate_resp.text}"
                    )
                    return False

            return True
        else:
            print(f"Error updating workflow: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Update an n8n workflow from a JSON file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --id abc123 --file workflow.json
  %(prog)s --id abc123 --file workflow.json --activate
""",
    )

    parser.add_argument("--id", "-i", required=True, help="Workflow ID to update")
    parser.add_argument(
        "--file",
        "-f",
        required=True,
        help="Path to JSON file containing updated workflow definition",
    )
    parser.add_argument(
        "--activate", "-a", action="store_true", help="Activate workflow after update"
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    file_path = Path(args.file)
    if not file_path.is_absolute():
        file_path = WORKFLOWS_DIR / file_path

    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    print(f"Loading workflow from: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        workflow_data = json.load(f)

    print(f"Updating workflow {args.id}...")

    if update_workflow(config, args.id, workflow_data, args.activate):
        print("Success! Workflow updated.")
        if args.activate:
            print("Workflow activated.")
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
