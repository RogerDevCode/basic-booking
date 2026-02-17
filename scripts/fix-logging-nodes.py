#!/usr/bin/env python3
"""
Final fix for logging nodes - add minimal standard contract
"""
import json

def fix_logging_node_bb07():
    """Fix BB_07 Log Summary node"""
    filepath = 'workflows/BB_07_Notification_Retry_Worker.json'
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    for node in data.get('nodes', []):
        if node.get('name') == 'Log Summary':
            # Replace the simple passthrough with standard contract
            new_code = """const WORKFLOW_ID = 'BB_07_Notification_Retry_Worker';

try {
  const items = $input.all();
  
  // Log for debugging
  try {
    const logEntry = {
      timestamp: new Date().toISOString(),
      itemsCount: items.length,
      preview: JSON.stringify(items[0]?.json).slice(0, 200)
    };
    console.log('[WF-OUTPUT]', JSON.stringify(logEntry));
  } catch(e) {}
  
  // Return with standard contract
  return items.map(item => ({
    json: {
      success: true,
      error_code: null,
      error_message: null,
      data: item.json,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }));
} catch (e) {
  return [{
    json: {
      success: false,
      error_code: 'INTERNAL_ERROR',
      error_message: `Unexpected error in ${WORKFLOW_ID}: ${e.message}`,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""
            
            node['parameters']['jsCode'] = new_code
            print("  ✓ Fixed Log Summary in BB_07")
            
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2)
            return True
    
    return False

def fix_logging_node_bb05():
    """Fix BB_05 Log Output node"""
    filepath = 'workflows/BB_05_Notification_Engine.json'
    
    with open(filepath, 'r') as f:
        data = json.load(f)
    
    for node in data.get('nodes', []):
        if node.get('name') == 'Log Output (Respond)':
            # Check current code
            current_code = node.get('parameters', {}).get('jsCode', '')
            
            # If it's a simple passthrough, replace it
            if 'return items' in current_code or 'return $input' in current_code:
                new_code = """const WORKFLOW_ID = 'BB_05_Notification_Engine';

try {
  const items = $input.all();
  
  // Log for debugging
  try {
    const logEntry = {
      timestamp: new Date().toISOString(),
      itemsCount: items.length,
      preview: JSON.stringify(items[0]?.json).slice(0, 200)
    };
    console.log('[WF-OUTPUT]', JSON.stringify(logEntry));
  } catch(e) {}
  
  // Return with standard contract
  return items.map(item => ({
    json: {
      success: true,
      error_code: null,
      error_message: null,
      data: item.json,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }));
} catch (e) {
  return [{
    json: {
      success: false,
      error_code: 'INTERNAL_ERROR',
      error_message: `Unexpected error in ${WORKFLOW_ID}: ${e.message}`,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""
                
                node['parameters']['jsCode'] = new_code
                print("  ✓ Fixed Log Output in BB_05")
                
                with open(filepath, 'w') as f:
                    json.dump(data, f, indent=2)
                return True
    
    return False

def main():
    print("="*60)
    print("Fixing Logging Nodes")
    print("="*60)
    
    print("\nBB_07_Notification_Retry_Worker:")
    fix_logging_node_bb07()
    
    print("\nBB_05_Notification_Engine:")
    fix_logging_node_bb05()
    
    print("\n" + "="*60)
    print("Logging nodes fixed")
    print("="*60)
    
    return 0

if __name__ == '__main__':
    import sys
    sys.exit(main())
