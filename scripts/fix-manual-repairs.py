#!/usr/bin/env python3
"""
FIX MANUAL REPAIRS
Overwrites specific corrupted nodes in BB_04 and BB_06 with clean code.
"""
import json
import os

def fix_workflow_nodes():
    # BB_04 Guard
    bb04_path = 'workflows/BB_04_Booking_Transaction.json'
    if os.path.exists(bb04_path):
        with open(bb04_path, 'r') as f:
            data = json.load(f)
        
        guard_code = """const WORKFLOW_ID = 'BB_04_Booking_Transaction';

try {
    const input = $input.item.json;
    const errors = [];
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

    if (!input.provider_id || !uuidRegex.test(input.provider_id)) errors.push("Invalid provider_id");
    if (!input.user_id || !uuidRegex.test(input.user_id)) errors.push("Invalid user_id");
    
    // safe date parsing
    const start = new Date(input.start_time);
    const end = new Date(input.end_time);
    
    if (!input.start_time || isNaN(start.getTime())) errors.push("Invalid start_time format");
    if (!input.end_time || isNaN(end.getTime())) errors.push("Invalid end_time format");
    if (start.getTime() >= end.getTime()) errors.push("start_time must be strictly before end_time");

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
    
    // Pass through valid input
    return [{
        json: input
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
            if node['name'] == 'Guard':
                node['parameters']['jsCode'] = guard_code
                modified = True
                print("Fixed BB_04 Guard")
        
        if modified:
            with open(bb04_path, 'w') as f:
                json.dump(data, f, indent=2)

    # BB_06 Nodes
    bb06_path = 'workflows/BB_06_Admin_Dashboard.json'
    if os.path.exists(bb06_path):
        with open(bb06_path, 'r') as f:
            data = json.load(f)
            
        sign_jwt_code = """const WORKFLOW_ID = 'BB_06_Admin_Dashboard';

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

  // Manual HMAC-SHA256 implementation using Web Crypto API (available in N8N)
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(unsigned);

  // Use SubtleCrypto for HMAC (available in N8N runtime)
  const crypto = globalThis.crypto;
  
  return crypto.subtle.importKey(
    'raw',
    keyData,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  ).then(key => {
    return crypto.subtle.sign('HMAC', key, messageData);
  }).then(signature => {
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
  }).catch(e => {
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
  });

} catch (e) {
  return [{
    json: {
      success: false,
      error_code: 'INTERNAL_ERROR',
      error_message: `Unexpected error in ${WORKFLOW_ID}: ${e.message}`,
      data: null,
      _meta: {
        source: 'admin_dashboard',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""

        auth_check_code = """const WORKFLOW_ID = 'BB_06_Admin_Dashboard';

try {
    const headers = $input.all()[0].json.headers || {};
    const authHeader = headers['authorization'] || headers['Authorization'];

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return [{ json: { 
            success: false, 
            error_code: 'MISSING_AUTH_HEADER', 
            error_message: 'Processing error', 
            data: null,
            authenticated: false, 
            error: true, 
            status: 401, 
            message: "MISSING_AUTH_HEADER",
            _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }
        }}];
    }

    const token = authHeader.split(' ')[1];
    const parts = token.split('.');
    if (parts.length !== 3) {
        return [{ json: { 
            success: false, 
            error_code: 'INVALID_TOKEN_FORMAT', 
            error_message: 'Processing error', 
            data: null,
            authenticated: false, 
            error: true, 
            status: 401, 
            message: "BAD_FORMAT",
            _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }
        }}];
    }
    
    const payload = parts[1];
    
    // Manual Base64Url to Base64 conversion + Padding
    let b64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) {
        b64 += '=';
    }
    
    const decodedStr = Buffer.from(b64, 'base64').toString('utf8');
    const decoded = JSON.parse(decodedStr);
    
    // Expiration Check
    if (decoded.exp && Date.now() >= decoded.exp * 1000) {
        return [{ json: { 
            success: false, 
            error_code: 'TOKEN_EXPIRED', 
            error_message: 'Processing error', 
            data: null,
            authenticated: false, 
            error: true, 
            status: 401, 
            message: "EXPIRED",
            _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }
        }}];
    }
    
    // Role Check
    if (decoded.role !== 'admin') {
        return [{ json: { 
            success: false, 
            error_code: 'INSUFFICIENT_PERMISSIONS', 
            error_message: 'Processing error', 
            data: null,
            authenticated: false, 
            error: true, 
            status: 403, 
            message: "FORBIDDEN",
            _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }
        }}];
    }

    // Success
    return [{ json: { 
        success: true, 
        error_code: null, 
        error_message: null, 
        data: { user: decoded },
        authenticated: true, 
        user: decoded, 
        error: false,
        _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }
    }}];

} catch (e) {
    return [{ json: { 
        success: false, 
        error_code: 'INTERNAL_ERROR', 
        error_message: `Unexpected error in ${WORKFLOW_ID}: ${e.message}`, 
        data: null,
        authenticated: false, 
        error: true, 
        status: 401, 
        message: "DECODE_FAIL: " + e.message,
        _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID }
    }}];
}"""

        modified = False
        for node in data['nodes']:
            if node['name'] == 'Code: Sign JWT':
                node['parameters']['jsCode'] = sign_jwt_code
                modified = True
                print("Fixed BB_06 Code: Sign JWT")
            elif node['name'] in ['Auth: Stats', 'Auth: Calendar', 'Auth: Config']:
                node['parameters']['jsCode'] = auth_check_code
                modified = True
                print(f"Fixed BB_06 {node['name']}")
        
        if modified:
            with open(bb06_path, 'w') as f:
                json.dump(data, f, indent=2)

if __name__ == '__main__':
    fix_workflow_nodes()
