#!/usr/bin/env python3
"""
FIX REMAINING MANUAL 2
Overwrites specific corrupted nodes in BB_04_Validate, BB_03, BB_06 with clean code.
"""
import json
import os

def fix_workflow_nodes():
    # 1. BB_04_Validate_Input -> Validate Logic
    path_bb04_val = 'workflows/BB_04_Validate_Input.json'
    if os.path.exists(path_bb04_val):
        with open(path_bb04_val, 'r') as f:
            data = json.load(f)
            
        validate_logic_code = """const WORKFLOW_ID = 'BB_04_Validate_Input';

try {
    const allItems = $input.all();
    if (!allItems || allItems.length === 0) {
        return [{
            json: {
                success: false,
                error_code: 'NO_DATA',
                error_message: 'No input data received',
                data: null,
                _meta: {
                    source: 'subworkflow',
                    timestamp: new Date().toISOString(),
                    workflow_id: WORKFLOW_ID
                }
            }
        }];
    }

    const root = allItems[0].json || {};
    const input = root.body ? root.body : root;
    
    const errors = [];
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const validActions = ['booking', 'cancel', 'reschedule'];

    // Validar action
    if (!input.action || !validActions.includes(input.action)) {
        errors.push("Invalid action: " + input.action);
    }

    // Validar UUIDs base
    if (!input.user_id || !uuidRegex.test(input.user_id)) {
        errors.push("Invalid user_id format");
    }
    
    if (!input.provider_id || !uuidRegex.test(input.provider_id)) {
        errors.push("Invalid provider_id format");
    }

    // Validaciones específicas por acción
    if (input.action === 'booking') {
        if (!input.start_time || !input.end_time) {
            errors.push("Missing start_time or end_time");
        } else {
            const start = new Date(input.start_time);
            const end = new Date(input.end_time);
            
            if (isNaN(start.getTime())) errors.push("Invalid start_time format");
            if (isNaN(end.getTime())) errors.push("Invalid end_time format");
            if (start.getTime() >= end.getTime()) errors.push("start_time must be before end_time");
            
            input.duration_min = (end - start) / (1000 * 60);
        }
        input.service_id = input.service_id || null;
    }

    if (input.action === 'cancel') {
        if (!input.booking_id || !uuidRegex.test(input.booking_id)) {
            errors.push("Invalid booking_id format");
        }
    }

    if (input.action === 'reschedule') {
        if (!input.booking_id || !uuidRegex.test(input.booking_id)) {
            errors.push("Invalid booking_id format");
        }
        
        if (!input.new_start_time || !input.new_end_time) {
            errors.push("Missing new_start_time or new_end_time");
        } else {
            const newStart = new Date(input.new_start_time);
            const newEnd = new Date(input.new_end_time);
            
            if (isNaN(newStart.getTime())) errors.push("Invalid new_start_time format");
            if (isNaN(newEnd.getTime())) errors.push("Invalid new_end_time format");
            if (newStart.getTime() >= newEnd.getTime()) errors.push("new_start_time must be before new_end_time");
            
            input.new_duration_min = (newEnd - newStart) / (1000 * 60);
        }
        input.service_id = input.service_id || null;
    }

    if (errors.length > 0) {
        return [{
            json: {
                success: false,
                error_code: 'VALIDATION_ERROR',
                error_message: errors.join(', '),
                data: { errors },
                _meta: {
                    source: 'subworkflow',
                    timestamp: new Date().toISOString(),
                    workflow_id: WORKFLOW_ID
                }
            }
        }];
    }

    // Success
    return [{
        json: {
            ...input,
            success: true,
            error_code: null,
            error_message: null,
            data: { input },
            validated: true,
            _meta: {
                source: 'subworkflow',
                timestamp: new Date().toISOString(),
                workflow_id: WORKFLOW_ID
            }
        }
    }];

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
        
        modified = False
        for node in data['nodes']:
            if node['name'] == 'Validate Logic':
                node['parameters']['jsCode'] = validate_logic_code
                modified = True
                print("Fixed BB_04_Validate_Input Validate Logic")
        
        if modified:
            with open(path_bb04_val, 'w') as f:
                json.dump(data, f, indent=2)

    # 2. BB_03_02_ProviderData -> Paranoid Guard
    path_bb03_02 = 'workflows/BB_03_02_ProviderData.json'
    if os.path.exists(path_bb03_02):
        with open(path_bb03_02, 'r') as f:
            data = json.load(f)
            
        paranoid_guard_code = """const WORKFLOW_ID = 'BB_03_02_ProviderData';

try {
  const input = $input.item.json;
  const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
  const errors = [];

  if (!input.provider_id || !UUID_REGEX.test(input.provider_id)) {
    errors.push('provider_id must be a valid UUID v4');
  }

  if (input.service_id && !UUID_REGEX.test(input.service_id)) {
    errors.push('service_id must be a valid UUID v4');
  }

  if (errors.length > 0) {
    return [{
      json: {
        success: false,
        error_code: 'VALIDATION_FAILED',
        error_message: errors.join('; '),
        data: null,
        _guard_failed: true,
        _meta: {
            source: 'subworkflow',
            timestamp: new Date().toISOString(),
            workflow_id: WORKFLOW_ID
        }
      }
    }];
  }

  return [{
    json: {
      provider_id: input.provider_id,
      service_id: input.service_id || null,
      _guard_passed: true,
      success: true,
      error_code: null,
      error_message: null,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];

} catch (e) {
  return [{
    json: {
      success: false,
      error_code: 'INTERNAL_ERROR',
      error_message: 'Paranoid Guard error: ' + e.message,
      data: null,
      _guard_failed: true,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""
        
        modified = False
        for node in data['nodes']:
            if node['name'] == 'Paranoid Guard':
                node['parameters']['jsCode'] = paranoid_guard_code
                modified = True
                print("Fixed BB_03_02 Paranoid Guard")
        
        if modified:
            with open(path_bb03_02, 'w') as f:
                json.dump(data, f, indent=2)

    # 3. BB_06_Admin_Dashboard -> Code: Sign JWT
    path_bb06 = 'workflows/BB_06_Admin_Dashboard.json'
    if os.path.exists(path_bb06):
        with open(path_bb06, 'r') as f:
            data = json.load(f)
            
        # Using Async/Await pattern to avoid brace issues in promises
        sign_jwt_code = """const WORKFLOW_ID = 'BB_06_Admin_Dashboard';

// Use async processing
(async () => {
    try {
      const user = $input.all()[0].json;

      // This secret must match verified env in Docker
      const secret = process.env.JWT_SECRET || 'AutoAgenda_Secret_Key_2026_Secure';

      const header = { alg: 'HS256', typ: 'JWT' };
      const payload = {
          user_id: user.user_id,
          tenant_id: user.tenant_id,
          role: user.role,
          exp: Math.floor(Date.now() / 1000) + (24 * 60 * 60)
      };

      // Base64URL encoding helper
      const base64Url = (obj) => {
        const json = JSON.stringify(obj);
        const base64 = Buffer.from(json).toString('base64');
        return base64.replace(/=/g, '').replace(/\\+/g, '-').replace(/\\//g, '_');
      };

      // Create unsigned token
      const unsigned = base64Url(header) + '.' + base64Url(payload);

      // Manual HMAC-SHA256 implementation using Web Crypto API
      const encoder = new TextEncoder();
      const keyData = encoder.encode(secret);
      const messageData = encoder.encode(unsigned);

      const crypto = globalThis.crypto;
      
      const key = await crypto.subtle.importKey(
        'raw',
        keyData,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign']
      );
      
      const signature = await crypto.subtle.sign('HMAC', key, messageData);
      
      const base64Sig = Buffer.from(signature).toString('base64');
      const urlSafeSig = base64Sig.replace(/=/g, '').replace(/\\+/g, '-').replace(/\\//g, '_');
      const token = unsigned + '.' + urlSafeSig;
        
      return [{ 
        json: { 
            token: token,
            success: true,
            error_code: null,
            error_message: null,
            data: { token },
            _meta: {
              source: 'admin_dashboard',
              timestamp: new Date().toISOString(),
              workflow_id: WORKFLOW_ID
            }
        } 
      }];

    } catch (e) {
      return [{
        json: {
          success: false,
          error_code: 'JWT_SIGN_ERROR',
          error_message: `JWT signing failed: ${e.message}`,
          data: null,
          _meta: {
            source: 'admin_dashboard',
            timestamp: new Date().toISOString(),
            workflow_id: WORKFLOW_ID
          }
        }
      }];
    }
})();"""

        modified = False
        for node in data['nodes']:
            if node['name'] == 'Code: Sign JWT':
                node['parameters']['jsCode'] = sign_jwt_code
                modified = True
                print("Fixed BB_06 Code: Sign JWT")
        
        if modified:
            with open(path_bb06, 'w') as f:
                json.dump(data, f, indent=2)

    # 4. BB_03_00_Main -> Prep: 03 Input
    path_bb03_00 = 'workflows/BB_03_00_Main.json'
    if os.path.exists(path_bb03_00):
        with open(path_bb03_00, 'r') as f:
            data = json.load(f)
            
        prep_03_code = """const WORKFLOW_ID = 'BB_03_00_Main';

// Prepare input for Schedule Config
// Merge provider data with original input parameters
try {
  const providerData = $input.item.json.data;
  const originalInput = $('01: Input Validation').item.json.data;

  // We need to pass data to next step
  const nextInput = {
      ...providerData,
      target_date: originalInput.target_date,
      days_range: originalInput.days_range
  };

  return [{
    json: {
      ...nextInput,
      success: true,
      error_code: null,
      error_message: null,
      data: nextInput,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
} catch (e) {
  return [{
    json: {
      success: false,
      error_code: 'INTERNAL_ERROR',
      error_message: 'Error preparing schedule input: ' + e.message,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""
        
        modified = False
        for node in data['nodes']:
            if node['name'] == 'Prep: 03 Input':
                node['parameters']['jsCode'] = prep_03_code
                modified = True
                print("Fixed BB_03_00 Prep: 03 Input")
        
        if modified:
            with open(path_bb03_00, 'w') as f:
                json.dump(data, f, indent=2)

if __name__ == '__main__':
    fix_workflow_nodes()
