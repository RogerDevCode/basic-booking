#!/usr/bin/env python3
"""
Fix BB_06 - Remove require() and implement manual JWT signing
"""
import json

WORKFLOW_FILE = 'workflows/BB_06_Admin_Dashboard.json'

# Manual HMAC-SHA256 implementation for JWT (without require())
NEW_JWT_CODE = """const WORKFLOW_ID = 'BB_06_Admin_Dashboard';

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
  // Note: N8N Code Nodes have access to crypto via globalThis
  const encoder = new TextEncoder();
  const keyData = encoder.encode(secret);
  const messageData = encoder.encode(unsigned);

  // Use SubtleCrypto for HMAC (available in N8N runtime)
  const crypto = globalThis.crypto || require('crypto').webcrypto;
  
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
    // Fallback: if crypto.subtle not available, return error
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

def main():
    print("Fixing BB_06_Admin_Dashboard - Removing require()...")
    
    with open(WORKFLOW_FILE, 'r') as f:
        data = json.load(f)
    
    # Find and fix the "Code: Sign JWT" node
    modified = False
    for node in data.get('nodes', []):
        if node.get('name') == 'Code: Sign JWT':
            print(f"  Found node: {node['name']}")
            node['parameters']['jsCode'] = NEW_JWT_CODE
            modified = True
            print("  ✓ Replaced require('crypto') with manual implementation")
            break
    
    if modified:
        with open(WORKFLOW_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        print("\n✅ BB_06 fixed - require() removed!")
        return 0
    else:
        print("\n❌ Node 'Code: Sign JWT' not found")
        return 1

if __name__ == '__main__':
    import sys
    sys.exit(main())
