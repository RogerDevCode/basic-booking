import json
import os

# El Snippet de Logging Maestro (Igual que antes)
LOGGING_JS = """const items = $input.all();

function buildSafePreview(data, maxLength = 2000) {
  const raw = JSON.stringify(data);
  if (raw.length <= maxLength) return raw;
  return raw.slice(0, maxLength) + '... [truncated]';
}

const logEntry = {
  timestamp: new Date().toISOString(),
  workflowId: $workflow.id,
  workflowName: $workflow.name,
  executionId: $execution.id,
  nodeId: $node.id,
  nodeName: $node.name,
  itemsCount: items.length,
  outputPreview: buildSafePreview(items.map(i => i.json)),
};

console.log('[WF-OUTPUT]', JSON.stringify(logEntry));
return items;"""

def inject_logger(file_path, target_node_names):
    try:
        with open(file_path, 'r') as f:
            wf = json.load(f)
    except Exception as e:
        print(f"Skipping {file_path}: {e}")
        return

    print(f"Processing {wf['name']}...")
    nodes = wf['nodes']
    connections = wf['connections']
    
    for target_name in target_node_names:
        target_node = next((n for n in nodes if n['name'] == target_name), None)
        if not target_node:
            continue

        logger_name = f"Log Output ({target_name})"
        if any(n['name'] == logger_name for n in nodes):
            continue

        # Create Logger Node
        logger_node = {
            "parameters": { "jsCode": LOGGING_JS },
            "id": f"logger_{target_node['id']}",
            "name": logger_name,
            "type": "n8n-nodes-base.code",
            "typeVersion": 2,
            "position": [target_node['position'][0] - 200, target_node['position'][1]]
        }
        nodes.append(logger_node)

        # Rewire: Source -> Logger -> Target
        for source_name, output_types in connections.items():
            if source_name == logger_name: continue
            for output_type, routes in output_types.items():
                for route in routes:
                    for conn in route:
                        if conn['node'] == target_name:
                            conn['node'] = logger_name

        if logger_name not in connections:
            connections[logger_name] = { "main": [[]] }
        connections[logger_name]["main"][0].append({ "node": target_name, "type": "main", "index": 0 })

    with open(file_path, 'w') as f:
        json.dump(wf, f, indent=2)

# Targets (BB_06 removed, will regenerate)
targets = {
    "workflows/BB_03_Availability_Engine.json": ["Respond Error", "Respond Success"],
    "workflows/BB_04_Booking_Transaction.json": ["Respond Error", "Respond Success"]
}

for path, nodes in targets.items():
    inject_logger(path, nodes)
