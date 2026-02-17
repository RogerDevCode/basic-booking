#!/usr/bin/env python3
"""
Fix Guard nodes to add proper type validation.
"""

import json
from pathlib import Path

WORKFLOWS_DIR = Path(__file__).parent.parent / "workflows"

# Enhanced Guard code templates
GUARD_TEMPLATES = {
    "BB_03_00_Main": '''const WORKFLOW_ID = 'BB_03_00_Main';
const meta = () => ({ source: 'webhook', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID });
const fail = (code, msg) => [{ json: { success: false, error_code: code, error_message: msg, data: null, _meta: meta() } }];
const ok = (data) => [{ json: { success: true, error_code: null, error_message: null, data, _meta: meta() } }];

try {
  const items = $input.all();
  if (!items?.length) return fail('VAL_NO_INPUT', 'No input received');

  const raw = items[0].json.body || items[0].json;
  const errors = [];
  
  // Type validation
  if (!raw.provider_slug) {
    errors.push('provider_slug is required');
  } else if (typeof raw.provider_slug !== 'string') {
    errors.push('provider_slug must be a string');
  } else if (raw.provider_slug.length > 100) {
    errors.push('provider_slug too long (max 100 chars)');
  }
  
  // target_date validation
  if (raw.target_date) {
    if (typeof raw.target_date !== 'string') {
      errors.push('target_date must be a string');
    } else if (!/^\\d{4}-\\d{2}-\\d{2}$/.test(raw.target_date)) {
      errors.push('target_date must be YYYY-MM-DD format');
    }
  }
  
  // days_range validation
  if (raw.days_range !== undefined) {
    if (typeof raw.days_range !== 'number' || raw.days_range < 1 || raw.days_range > 365) {
      errors.push('days_range must be a number between 1 and 365');
    }
  }
  
  if (errors.length > 0) return fail('VAL_INVALID_INPUT', errors.join('; '));
  
  return ok({
    provider_slug: String(raw.provider_slug),
    target_date: raw.target_date || new Date().toISOString().split('T')[0],
    days_range: raw.days_range || 7
  });
} catch (e) {
  return fail('INTERNAL_ERROR', `${WORKFLOW_ID}: ${e.message}`);
}''',
}

def fix_guard(filepath, workflow_name):
    """Fix Guard node with enhanced validation."""
    with open(filepath, 'r', encoding='utf-8') as f:
        wf = json.load(f)
    
    if workflow_name not in GUARD_TEMPLATES:
        return False
    
    for node in wf['nodes']:
        if node.get('name') == 'Guard' and node.get('type') == 'n8n-nodes-base.code':
            node['parameters']['jsCode'] = GUARD_TEMPLATES[workflow_name]
            print(f"  [FIX] {workflow_name}: Enhanced type validation in Guard")
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(wf, f, indent=2, ensure_ascii=False)
            return True
    
    return False

def main():
    print("Fixing Guard node validations...")
    print("=" * 60)
    
    fixed = 0
    for filepath in sorted(WORKFLOWS_DIR.glob('BB_03_00_Main.json')):
        wf_name = filepath.stem
        if fix_guard(filepath, wf_name):
            fixed += 1
    
    print("=" * 60)
    print(f"Fixed: {fixed} workflows")

if __name__ == '__main__':
    main()
