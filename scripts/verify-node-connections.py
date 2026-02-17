#!/usr/bin/env python3
"""
Verify node connections to detect orphaned or isolated nodes
"""
import json
import os
import sys

def analyze_connections(data):
    """Analyze node connections in a workflow"""
    nodes = {node['name']: node for node in data.get('nodes', [])}
    connections = data.get('connections', {})
    
    # Track which nodes have incoming and outgoing connections
    has_incoming = set()
    has_outgoing = set()
    
    # Analyze connections
    for source_node, outputs in connections.items():
        if source_node in nodes:
            has_outgoing.add(source_node)
        
        for output_type, output_list in outputs.items():
            for output_connections in output_list:
                for conn in output_connections:
                    target_node = conn.get('node')
                    if target_node in nodes:
                        has_incoming.add(target_node)
    
    # Find issues
    issues = []
    
    # Find nodes without incoming connections (except triggers/webhooks)
    for node_name, node in nodes.items():
        node_type = node.get('type', '')
        
        # Skip triggers and webhooks (they don't need incoming connections)
        if 'trigger' in node_type.lower() or 'webhook' in node_type.lower():
            continue
        
        if node_name not in has_incoming:
            issues.append({
                'type': 'no_incoming',
                'node': node_name,
                'node_type': node_type
            })
    
    # Find nodes without outgoing connections (except response nodes)
    for node_name, node in nodes.items():
        node_type = node.get('type', '')
        
        # Skip response nodes (they don't need outgoing connections)
        if 'respond' in node_type.lower() or node_name.lower().startswith('respond'):
            continue
        
        if node_name not in has_outgoing:
            issues.append({
                'type': 'no_outgoing',
                'node': node_name,
                'node_type': node_type
            })
    
    return issues

def verify_workflow(filepath):
    """Verify a single workflow"""
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    workflow_name = data.get('name', os.path.basename(filepath))
    issues = analyze_connections(data)
    
    return workflow_name, issues

def main():
    workflows_dir = 'workflows'
    all_issues = {}
    
    print("Verifying Node Connections...")
    print("=" * 60)
    
    for filename in sorted(os.listdir(workflows_dir)):
        if filename.startswith('BB_') and filename.endswith('.json'):
            filepath = os.path.join(workflows_dir, filename)
            workflow_name, issues = verify_workflow(filepath)
            if issues:
                all_issues[workflow_name] = issues
    
    # Report
    if all_issues:
        total = sum(len(issues) for issues in all_issues.values())
        print(f"\n⚠️  Found {total} connection issues:\n")
        
        for workflow_name, issues in all_issues.items():
            print(f"\n{workflow_name}:")
            for issue in issues:
                if issue['type'] == 'no_incoming':
                    print(f"  - Node '{issue['node']}' ({issue['node_type']}): No incoming connections (orphaned)")
                elif issue['type'] == 'no_outgoing':
                    print(f"  - Node '{issue['node']}' ({issue['node_type']}): No outgoing connections (isolated)")
        
        return 1
    else:
        print("\n✅ All nodes are properly connected!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
