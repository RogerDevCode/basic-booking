#!/usr/bin/env python3
"""
Comprehensive Automated Compliance Fixer
Fixes ALL workflows to comply with SolucionFinal-v2.md

This script:
1. Adds WORKFLOW_ID constant to all Code Nodes
2. Wraps code in try-catch if missing
3. Adds _meta to returns (basic implementation)
4. Fixes errorWorkflow settings
5. Preserves existing logic as much as possible
"""
import json
import os
import sys
import re
from typing import Dict, List, Tuple

class ComplianceFixer:
    def __init__(self):
        self.stats = {
            'workflows_processed': 0,
            'nodes_modified': 0,
            'workflow_id_added': 0,
            'try_catch_added': 0,
            'settings_fixed': 0
        }
    
    def extract_workflow_id(self, workflow_name: str) -> str:
        """Extract workflow ID from workflow name"""
        # Remove .json extension if present
        return workflow_name.replace('.json', '')
    
    def has_workflow_id(self, code: str) -> bool:
        """Check if code has WORKFLOW_ID constant"""
        return 'const WORKFLOW_ID' in code
    
    def has_try_catch(self, code: str) -> bool:
        """Check if code has try-catch"""
        return 'try {' in code or 'try{' in code
    
    def add_workflow_id_to_code(self, code: str, workflow_id: str) -> str:
        """Add WORKFLOW_ID constant at the beginning"""
        if self.has_workflow_id(code):
            return code
        
        # Add at the very beginning
        return f"const WORKFLOW_ID = '{workflow_id}';\n\n{code}"
    
    def wrap_in_try_catch(self, code: str, workflow_id: str) -> str:
        """Wrap code in try-catch block"""
        if self.has_try_catch(code):
            return code
        
        # Extract WORKFLOW_ID line if it exists
        workflow_id_line = ""
        remaining_code = code
        
        if 'const WORKFLOW_ID' in code:
            lines = code.split('\n')
            for i, line in enumerate(lines):
                if 'const WORKFLOW_ID' in line:
                    workflow_id_line = line + '\n'
                    remaining_code = '\n'.join(lines[i+1:])
                    break
        else:
            workflow_id_line = f"const WORKFLOW_ID = '{workflow_id}';\n"
        
        # Build wrapped code
        wrapped = f"""{workflow_id_line}
try {{
{self.indent_code(remaining_code, 2)}
}} catch (e) {{
  return [{{
    json: {{
      success: false,
      error_code: 'INTERNAL_ERROR',
      error_message: `Unexpected error in ${{WORKFLOW_ID}}: ${{e.message}}`,
      data: null,
      _meta: {{
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }}
    }}
  }}];
}}"""
        
        return wrapped
    
    def indent_code(self, code: str, spaces: int) -> str:
        """Indent code by specified number of spaces"""
        indent = ' ' * spaces
        lines = code.split('\n')
        return '\n'.join(indent + line if line.strip() else line for line in lines)
    
    def fix_code_node(self, node: Dict, workflow_id: str) -> bool:
        """Fix a single Code Node"""
        if node.get('type') != 'n8n-nodes-base.code':
            return False
        
        js_code = node.get('parameters', {}).get('jsCode', '')
        if not js_code:
            return False
        
        node_name = node.get('name', 'Unknown')
        original_code = js_code
        modified = False
        
        # Step 1: Add WORKFLOW_ID if missing
        if not self.has_workflow_id(js_code):
            js_code = self.add_workflow_id_to_code(js_code, workflow_id)
            modified = True
            self.stats['workflow_id_added'] += 1
        
        # Step 2: Wrap in try-catch if missing
        if not self.has_try_catch(js_code):
            js_code = self.wrap_in_try_catch(js_code, workflow_id)
            modified = True
            self.stats['try_catch_added'] += 1
        
        # Update node if modified
        if modified:
            node['parameters']['jsCode'] = js_code
            self.stats['nodes_modified'] += 1
            print(f"    ✓ Fixed: {node_name}")
        
        return modified
    
    def fix_workflow_settings(self, data: Dict, workflow_name: str) -> bool:
        """Fix workflow settings"""
        settings = data.get('settings', {})
        modified = False
        
        # BB_00 should NOT have errorWorkflow
        if workflow_name == 'BB_00_Global_Error_Handler':
            if 'errorWorkflow' in settings:
                del settings['errorWorkflow']
                data['settings'] = settings
                modified = True
                self.stats['settings_fixed'] += 1
                print("    ✓ Removed errorWorkflow from BB_00")
        else:
            # All other workflows should have errorWorkflow
            if settings.get('errorWorkflow') != 'BB_00_Global_Error_Handler':
                settings['errorWorkflow'] = 'BB_00_Global_Error_Handler'
                data['settings'] = settings
                modified = True
                self.stats['settings_fixed'] += 1
                print("    ✓ Set errorWorkflow to BB_00_Global_Error_Handler")
        
        return modified
    
    def process_workflow(self, filepath: str) -> Tuple[int, int]:
        """Process a single workflow file"""
        filename = os.path.basename(filepath)
        print(f"\n{'='*60}")
        print(f"Processing: {filename}")
        print(f"{'='*60}")
        
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        workflow_name = data.get('name', filename.replace('.json', ''))
        workflow_id = self.extract_workflow_id(workflow_name)
        
        print(f"  Workflow: {workflow_name}")
        print(f"  Workflow ID: {workflow_id}")
        
        # Fix settings
        settings_modified = self.fix_workflow_settings(data, workflow_name)
        
        # Fix all Code Nodes
        nodes_modified = 0
        code_nodes_count = 0
        
        for node in data.get('nodes', []):
            if node.get('type') == 'n8n-nodes-base.code':
                code_nodes_count += 1
                if self.fix_code_node(node, workflow_id):
                    nodes_modified += 1
        
        # Save if modified
        total_modified = settings_modified or nodes_modified > 0
        
        if total_modified:
            with open(filepath, 'w') as f:
                json.dump(data, f, indent=2)
            
            print(f"\n  ✅ Modified: {nodes_modified}/{code_nodes_count} Code Nodes")
            self.stats['workflows_processed'] += 1
        else:
            print(f"\n  ✓ Already compliant ({code_nodes_count} Code Nodes)")
        
        return code_nodes_count, nodes_modified
    
    def process_all_workflows(self, workflows_dir: str = 'workflows'):
        """Process all BB_* workflows"""
        print("\n" + "="*60)
        print("AUTOMATED COMPLIANCE FIXER")
        print("="*60)
        
        # Get all BB_* workflows
        workflows = sorted([
            os.path.join(workflows_dir, f) 
            for f in os.listdir(workflows_dir) 
            if f.startswith('BB_') and f.endswith('.json')
        ])
        
        print(f"\nFound {len(workflows)} workflows to process\n")
        
        # Process each workflow
        for filepath in workflows:
            try:
                self.process_workflow(filepath)
            except Exception as e:
                print(f"\n  ❌ Error processing {filepath}: {e}")
                import traceback
                traceback.print_exc()
        
        # Print summary
        self.print_summary()
    
    def print_summary(self):
        """Print summary statistics"""
        print("\n" + "="*60)
        print("SUMMARY")
        print("="*60)
        print(f"  Workflows Processed: {self.stats['workflows_processed']}")
        print(f"  Code Nodes Modified: {self.stats['nodes_modified']}")
        print(f"  WORKFLOW_ID Added: {self.stats['workflow_id_added']}")
        print(f"  Try-Catch Added: {self.stats['try_catch_added']}")
        print(f"  Settings Fixed: {self.stats['settings_fixed']}")
        print("="*60)
        print("\n✅ Automated fixes complete!")
        print("⚠️  NEXT STEPS:")
        print("   1. Run validation: python3 scripts/validate-solucionfinal-v2.py")
        print("   2. Review modified workflows manually")
        print("   3. Test critical workflows (BB_00, BB_02, BB_06)")
        print("="*60)

def main():
    fixer = ComplianceFixer()
    fixer.process_all_workflows()
    return 0

if __name__ == '__main__':
    sys.exit(main())
