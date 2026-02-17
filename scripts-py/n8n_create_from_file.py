#!/usr/bin/env python3
"""
N8N Create Workflow from File

Usage:
    python n8n_create_from_file.py --file workflow.json
    python n8n_create_from_file.py --file workflow.json --activate
    python n8n_create_from_file.py --file workflow.json --name "My Workflow"
    python n8n_create_from_file.py --file workflow.json --activate --tag "production"
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional

import requests

from config import N8NConfig, WORKFLOWS_DIR


def create_workflow(
    config: N8NConfig,
    workflow_data: dict,
    name: Optional[str] = None,
    activate: bool = False,
    tags: Optional[list] = None,
) -> Optional[dict]:
    """
    Create a workflow in n8n

    Args:
        config: N8N configuration
        workflow_data: Workflow definition dict
        name: Override workflow name
        activate: Activate after creation
        tags: Tags to apply

    Returns:
        Created workflow data or None on error
    """
    if name:
        workflow_data["name"] = name

    if tags:
        workflow_data["tags"] = [{"name": tag} for tag in tags]

    try:
        response = requests.post(
            config.workflow_endpoint(),
            headers=config.headers,
            json=workflow_data,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code in [200, 201]:
            created = response.json()
            workflow_id = created.get("id")

            if activate and workflow_id:
                activate_url = f"{config.workflow_endpoint(workflow_id)}/activate"
                activate_resp = requests.post(
                    activate_url,
                    headers=config.headers,
                    timeout=config.timeout,
                    verify=config.verify_ssl,
                )
                if activate_resp.status_code == 200:
                    created["activated"] = True
                else:
                    print(
                        f"Warning: Workflow created but activation failed: {activate_resp.text}"
                    )
                    created["activated"] = False

            return created
        else:
            print(f"Error creating workflow: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(
        description="Create an n8n workflow from a JSON file",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --file workflow.json
  %(prog)s --file workflow.json --activate
  %(prog)s --file workflows/BB_00_Global_Error_Handler.json --name "Copy of BB_00"
  %(prog)s --file workflow.json --tag production --tag critical
""",
    )

    parser.add_argument(
        "--file",
        "-f",
        required=True,
        help="Path to JSON file containing workflow definition",
    )
    parser.add_argument("--name", "-n", help="Override workflow name")
    parser.add_argument(
        "--activate", "-a", action="store_true", help="Activate workflow after creation"
    )
    parser.add_argument(
        "--tag",
        "-t",
        action="append",
        dest="tags",
        help="Add tag to workflow (can be used multiple times)",
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")
    parser.add_argument(
        "--output",
        "-o",
        choices=["json", "id", "name"],
        default="json",
        help="Output format: json (default), id, or name",
    )

    args = parser.parse_args()

    file_path = Path(args.file)
    if not file_path.is_absolute():
        file_path = WORKFLOWS_DIR / file_path

    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    print(f"Loading workflow from: {file_path}")
    with open(file_path, "r", encoding="utf-8") as f:
        workflow_data = json.load(f)

    original_name = workflow_data.get("name", "Unknown")
    print(f"Original name: {original_name}")

    if "id" in workflow_data:
        print("Note: Removing existing ID (n8n will assign a new one)")
        del workflow_data["id"]

    print(f"Creating workflow in n8n at: {config.api_url}")

    result = create_workflow(
        config=config,
        workflow_data=workflow_data,
        name=args.name,
        activate=args.activate,
        tags=args.tags,
    )

    if result:
        workflow_id = result.get("id")
        workflow_name = result.get("name")

        if args.output == "id":
            print(workflow_id)
        elif args.output == "name":
            print(workflow_name)
        else:
            print(f"\nSuccess! Created workflow:")
            print(f"  ID: {workflow_id}")
            print(f"  Name: {workflow_name}")
            if args.activate:
                print(f"  Activated: {result.get('activated', False)}")
            print(f"\nFull response:")
            print(json.dumps(result, indent=2))
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
