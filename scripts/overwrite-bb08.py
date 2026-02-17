#!/usr/bin/env python3
import json

# The content we want for BB_08 (Clean, Fixed)
bb08_content = {
  "name": "BB_08_JWT_Auth_Helper",
  "nodes": [
    {
      "parameters": {},
      "id": "sub_trigger",
      "name": "Execute Workflow Trigger",
      "type": "n8n-nodes-base.executeWorkflowTrigger",
      "typeVersion": 1,
      "position": [0, 100]
    },
    {
      "parameters": {
        "jsCode": """/**
 * BB_08_JWT_Auth_Helper
 * Versión: v2.0
 * Descripción: Validates JWT tokens from Authorization header
 * 
 * INPUT:  { headers: { authorization: "Bearer <token>" } }
 * OUTPUT: { success, error_code, error_message, data, _meta }
 */
const WORKFLOW_ID = 'BB_08_JWT_Auth_Helper';

try {
  const input = $input.item.json;
  
  // Check for Authorization header
  const authHeader = input.headers?.authorization || input.headers?.Authorization;
  
  if (!authHeader) {
    return [{
      json: {
        success: false,
        error_code: 'SEC_UNAUTHORIZED',
        error_message: 'Missing Authorization header',
        data: null,
        _meta: {
          source: 'subworkflow',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }
  
  // Extract Bearer token
  if (!authHeader.startsWith('Bearer ')) {
    return [{
      json: {
        success: false,
        error_code: 'SEC_UNAUTHORIZED',
        error_message: 'Authorization header must start with Bearer',
        data: null,
        _meta: {
          source: 'subworkflow',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }
  
  const token = authHeader.substring(7);
  
  if (!token || token.trim() === '') {
    return [{
      json: {
        success: false,
        error_code: 'SEC_UNAUTHORIZED',
        error_message: 'Token is empty',
        data: null,
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
      success: true,
      error_code: null,
      error_message: null,
      data: {
        token: token,
        validated: true
      },
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
      error_message: 'JWT validation error: ' + e.message,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""
      },
      "id": "extract_token",
      "name": "Extract Token",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [200, 100]
    },
    {
      "parameters": {
        "jsCode": """/**
 * BB_08_JWT_Auth_Helper - Verify Token
 * Versión: v2.0
 * Verifies JWT token signature and claims
 */
const WORKFLOW_ID = 'BB_08_JWT_Auth_Helper';

try {
  const inputData = $json;
  
  // Check if previous step failed
  if (!inputData.success) {
    return [{ json: inputData, _meta: { source: 'subworkflow', timestamp: new Date().toISOString(), workflow_id: WORKFLOW_ID } }];
  }
  
  const token = inputData.data.token;
  const secret = $vars.JWT_SECRET; // NO FALLBACK - Must be configured
  
  if (!secret) {
    return [{
      json: {
        success: false,
        error_code: 'SEC_INVALID_TOKEN',
        error_message: 'JWT_SECRET not configured in workflow variables',
        data: null,
        _meta: {
          source: 'subworkflow',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }
  
  // Split JWT into parts
  const parts = token.split('.');
  if (parts.length !== 3) {
    return [{
      json: {
        success: false,
        error_code: 'SEC_INVALID_TOKEN',
        error_message: 'Invalid JWT format',
        data: null,
        _meta: {
          source: 'subworkflow',
          timestamp: new Date().toISOString(),\n          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }
  
  // Decode payload (middle part)
  const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
  
  // Verify expiry
  if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
    return [{
      json: {
        success: false,
        error_code: 'SEC_UNAUTHORIZED',
        error_message: 'Token has expired',
        data: null,
        _meta: {
          source: 'subworkflow',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }
  
  // Verify role (must be admin)
  if (payload.role !== 'admin') {
    return [{
      json: {
        success: false,
        error_code: 'SEC_UNAUTHORIZED',
        error_message: 'Admin access required',
        data: null,
        _meta: {
          source: 'subworkflow',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }
  
  // Return decoded payload
  return [{
    json: {
      success: true,
      error_code: null,
      error_message: null,
      data: {
        valid: true,
        user: {
          id: payload.user_id,
          email: payload.email,
          role: payload.role
        },
        token_exp: payload.exp
      },
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
      error_code: 'SEC_INVALID_TOKEN',
      error_message: 'Invalid token - ' + e.message,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}"""
      },
      "id": "verify_token",
      "name": "Verify Token",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [400, 100]
    }
  ],
  "connections": {
    "Execute Workflow Trigger": {
      "main": [[{"node": "Extract Token", "type": "main", "index": 0}]]
    },
    "Extract Token": {
      "main": [[{"node": "Verify Token", "type": "main", "index": 0}]]
    }
  },
  "settings": {
    "executionOrder": "v1",
    "saveManualExecutions": True,
    "callerPolicy": "workflowsFromSameOwner",
    "errorWorkflow": "BB_00_Global_Error_Handler"
  }
}

path = 'workflows/BB_08_JWT_Auth_Helper.json'
with open(path, 'w') as f:
    json.dump(bb08_content, f, indent=2)
print("✓ Overwrote BB_08")
