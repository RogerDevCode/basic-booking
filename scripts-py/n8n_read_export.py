#!/usr/bin/env python3
"""
N8N Read Export Workflow

Usage:
    python n8n_read_export.py --id WORKFLOW_ID --output workflow.json
    python n8n_read_export.py --name "BB_00_Global_Error_Handler" --output workflow.json
    python n8n_read_export.py --all --output-dir ./exports/
    python n8n_read_export.py --filter "BB_" --output-dir ./exports/
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Optional, List

import requests

from config import N8NConfig, WORKFLOWS_DIR


def export_workflow(config: N8NConfig, workflow_id: str, output_path: Path) -> bool:
    """
    Export a workflow to JSON file

    Args:
        config: N8N configuration
        workflow_id: Workflow ID
        output_path: Output file path

    Returns:
        True on success, False on error
    """
    try:
        response = requests.get(
            config.workflow_endpoint(workflow_id),
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            workflow = response.json()

            output_path.parent.mkdir(parents=True, exist_ok=True)

            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(workflow, f, indent=2, ensure_ascii=False)

            return True
        else:
            print(f"Error getting workflow: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False


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


def sanitize_filename(name: str) -> str:
    """Convert workflow name to safe filename"""
    safe = "".join(c if c.isalnum() or c in " _-" else "_" for c in name)
    return safe.strip().replace(" ", "_")


def main():
    parser = argparse.ArgumentParser(
        description="Export n8n workflows to JSON files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --id abc123 --output workflow.json
  %(prog)s --name "BB_00" --output workflow.json
  %(prog)s --all --output-dir ./exports/
  %(prog)s --filter "BB_" --output-dir ./workflows/
""",
    )

    target_group = parser.add_mutually_exclusive_group(required=True)
    target_group.add_argument("--id", "-i", help="Export workflow by ID")
    target_group.add_argument(
        "--name", "-n", help="Export workflow by name (exact match)"
    )
    target_group.add_argument(
        "--all", "-a", action="store_true", help="Export all workflows"
    )
    target_group.add_argument(
        "--filter", "-f", help="Export workflows matching name filter"
    )

    parser.add_argument(
        "--output", "-o", help="Output file path (required for single workflow export)"
    )
    parser.add_argument(
        "--output-dir", help="Output directory (required for --all or --filter)"
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    if args.all or args.filter:
        if not args.output_dir:
            print("Error: --output-dir is required for --all or --filter")
            sys.exit(1)

        output_dir = Path(args.output_dir)
        workflows = list_workflows(config, args.filter)

        if workflows is None:
            sys.exit(1)

        success_count = 0
        for w in workflows:
            workflow_id = w.get("id")
            workflow_name = w.get("name", "unnamed")
            filename = f"{sanitize_filename(workflow_name)}.json"
            output_path = output_dir / filename

            print(f"Exporting: {workflow_name} -> {output_path}")
            if export_workflow(config, workflow_id, output_path):
                success_count += 1

        print(f"\nExported {success_count}/{len(workflows)} workflows")

    elif args.id:
        if not args.output:
            print("Error: --output is required for single workflow export")
            sys.exit(1)

        output_path = Path(args.output)
        print(f"Exporting workflow {args.id} to {output_path}")

        if export_workflow(config, args.id, output_path):
            print("Success!")
        else:
            sys.exit(1)

    elif args.name:
        if not args.output:
            print("Error: --output is required for single workflow export")
            sys.exit(1)

        workflows = list_workflows(config)
        if workflows is None:
            sys.exit(1)

        workflow_id = None
        for w in workflows:
            if w.get("name") == args.name:
                workflow_id = w.get("id")
                break

        if not workflow_id:
            print(f"Error: Workflow '{args.name}' not found")
            sys.exit(1)

        output_path = Path(args.output)
        print(f"Exporting workflow '{args.name}' to {output_path}")

        if export_workflow(config, workflow_id, output_path):
            print("Success!")
        else:
            sys.exit(1)


if __name__ == "__main__":
    main()
