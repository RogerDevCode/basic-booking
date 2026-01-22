import json

TARGET_FILE = "workflows/BB_04_Booking_Transaction.json"

try:
    with open(TARGET_FILE, 'r') as f:
        wf = json.load(f)
    
    # Find Node
    config_node = next((n for n in wf['nodes'] if n['name'] == 'Get Config'), None)
    
    if config_node:
        print("Found 'Get Config' node. Updating query...")
        config_node['parameters']['operation'] = 'executeQuery'
        config_node['parameters']['query'] = "SELECT public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')"
        
        # Remove old where clause stuff if present
        if 'whereClause' in config_node['parameters']:
            del config_node['parameters']['whereClause']
        if 'schema' in config_node['parameters']:
            del config_node['parameters']['schema']
        if 'table' in config_node['parameters']:
            del config_node['parameters']['table']
            
        # Update validation logic to read from new structure
        # The new structure returns [{ get_tenant_config_json: { ... } }]
        # The JS needs to handle this.
        
        # Find Validate Duration Node
        val_node = next((n for n in wf['nodes'] if n['name'] == 'Validate Duration'), None)
        if val_node:
             # Inject Updated JS
             val_node['parameters']['jsCode'] = """
const configItems = $items("Get Config");
// Config comes from function as { get_tenant_config_json: {...} }
const configData = configItems.length > 0 ? configItems[0].json.get_tenant_config_json : {};
const config = configData || { min_duration_min: 15, max_duration_min: 120 };
const input = $node["Guard"].json;

const min = parseInt(config.min_duration_min || 15);
const max = parseInt(config.max_duration_min || 120);
const duration = input.duration_min;

if (duration < min || duration > max) {
    return [{ json: { error: true, message: `Duration ${duration}m out of range (${min}m - ${max}m)`, status: 400 } }];
}
return [{ json: { valid: true, error: false } }];
"""
    
    with open(TARGET_FILE, 'w') as f:
        json.dump(wf, f, indent=2)
        
    print("✅ BB_04 Updated Successfully.")

except Exception as e:
    print(f"❌ Error: {e}")
