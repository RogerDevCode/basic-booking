#!/usr/bin/env python3
"""
N8N Read Get Workflow

Usage:
    python n8n_read_get.py --id WORKFLOW_ID
    python n8n_read_get.py --name "BB_00_Global_Error_Handler"
    python n8n_read_get.py --id WORKFLOW_ID --format json
    python n8n_read_get.py --id WORKFLOW_ID --nodes
"""

import argparse
import json
import sys
from typing import Optional

import requests

from config import N8NConfig, WORKFLOW_IDS


def get_workflow_by_id(config: N8NConfig, workflow_id: str) -> Optional[dict]:
    """
    Get a workflow by ID

    Args:
        config: N8N configuration
        workflow_id: Workflow ID

    Returns:
        Workflow data or None on error
    """
    try:
        response = requests.get(
            config.workflow_endpoint(workflow_id),
            headers=config.headers,
            timeout=config.timeout,
            verify=config.verify_ssl,
        )

        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error getting workflow: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def get_workflow_by_name(config: N8NConfig, name: str) -> Optional[dict]:
    """
    Get a workflow by name (searches all workflows)

    Args:
        config: N8N configuration
        name: Workflow name (exact match)

    Returns:
        Workflow data or None on error
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

            for w in workflows:
                if w.get("name") == name:
                    return get_workflow_by_id(config, w.get("id"))

            print(f"Workflow '{name}' not found")
            return None
        else:
            print(f"Error listing workflows: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"Error: {e}")
        return None


def format_summary(workflow: dict) -> str:
    """Format workflow as summary"""
    lines = [
        f"ID: {workflow.get('id')}",
        f"Name: {workflow.get('name')}",
        f"Active: {workflow.get('active', False)}",
        f"Created: {workflow.get('createdAt', 'N/A')}",
        f"Updated: {workflow.get('updatedAt', 'N/A')}",
        f"Trigger Count: {workflow.get('triggerCount', 0)}",
    ]

    nodes = workflow.get("nodes", [])
    if nodes:
        lines.append(f"Nodes: {len(nodes)}")
        node_types = {}
        for node in nodes:
            node_type = node.get("type", "unknown")
            node_types[node_type] = node_types.get(node_type, 0) + 1

        lines.append("Node types:")
        for nt, count in sorted(node_types.items()):
            lines.append(f"  - {nt}: {count}")

    return "\n".join(lines)


def format_nodes(workflow: dict) -> str:
    """Format workflow nodes as list"""
    nodes = workflow.get("nodes", [])
    if not nodes:
        return "No nodes found."

    lines = [f"Nodes in '{workflow.get('name')}':", ""]

    for i, node in enumerate(nodes, 1):
        lines.append(f"{i}. {node.get('name')} ({node.get('type')})")
        lines.append(f"   ID: {node.get('id')}")
        lines.append(f"   Position: {node.get('position')}")
        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Get an n8n workflow by ID or name",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --id abc123
  %(prog)s --name "BB_00_Global_Error_Handler"
  %(prog)s --id abc123 --format json
  %(prog)s --id abc123 --nodes
""",
    )

    id_group = parser.add_mutually_exclusive_group(required=True)
    id_group.add_argument("--id", "-i", help="Workflow ID")
    id_group.add_argument("--name", "-n", help="Workflow name (exact match)")

    parser.add_argument(
        "--format",
        choices=["json", "summary", "nodes"],
        default="summary",
        help="Output format: summary (default), json, or nodes",
    )
    parser.add_argument("--url", help="N8N API URL (overrides N8N_API_URL env var)")
    parser.add_argument("--api-key", help="N8N API Key (overrides N8N_API_KEY env var)")

    args = parser.parse_args()

    try:
        config = N8NConfig(api_url=args.url, api_key=args.api_key)
    except ValueError as e:
        print(f"Error: {e}")
        sys.exit(1)

    if args.name:
        workflow = get_workflow_by_name(config, args.name)
    else:
        workflow = get_workflow_by_id(config, args.id)

    if workflow is None:
        sys.exit(1)

    if args.format == "json":
        print(json.dumps(workflow, indent=2))
    elif args.format == "nodes":
        print(format_nodes(workflow))
    else:
        print(format_summary(workflow))


if __name__ == "__main__":
    main()
