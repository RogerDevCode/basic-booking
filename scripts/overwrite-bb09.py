#!/usr/bin/env python3
import json

# Correct content for BB_09
# Based on Step 619 but adding standard contract fields
bb09_content = {
  "name": "BB_09_Deep_Link_Redirect",
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
        "jsCode": """const WORKFLOW_ID = 'BB_09_Deep_Link_Redirect';

try {
    const input = $input.item.json;
    
    // Check for Authorization header
    const authHeader = input.headers?.authorization || input.headers?.Authorization;
    
    if (!authHeader) {
        return [{
            json: {
                success: false,
                error_code: 'MISSING_AUTH_HEADER',
                error_message: 'UNAUTHORIZED: Missing Authorization header',
                data: { status: 401 },
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
                error_code: 'INVALID_AUTH_FORMAT',
                error_message: 'UNAUTHORIZED: Authorization header must start with Bearer',
                data: { status: 401 },
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
                error_code: 'EMPTY_TOKEN',
                error_message: 'UNAUTHORIZED: Token is empty',
                data: { status: 401 },
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
            error_code: 'VALIDATION_ERROR',
            error_message: 'JWT validation error: ' + e.message,
            data: { status: 500 },
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
        "jsCode": """const WORKFLOW_ID = 'BB_09_Deep_Link_Redirect';

try {
    const token = $json.data.token;
    const secret = $vars.JWT_SECRET || 'AutoAgenda_Secret_Key_2026_Secure';
    
    // Split JWT into parts
    const parts = token.split('.');
    if (parts.length !== 3) {
        throw new Error('Invalid JWT format');
    }
    
    // Decode payload (middle part)
    const payload = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
    
    // Verify expiry
    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
        return [{
            json: {
                success: false,
                error_code: 'TOKEN_EXPIRED',
                error_message: 'UNAUTHORIZED: Token has expired',
                data: { status: 401 },
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
                error_code: 'INSUFFICIENT_PERMISSIONS',
                error_message: 'FORBIDDEN: Admin access required',
                data: { status: 403 },
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
            error_code: 'INVALID_TOKEN',
            error_message: 'UNAUTHORIZED: Invalid token - ' + e.message,
            data: { status: 401 },
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
    },
    {
      "parameters": {
        "mode": "rules",
        "rules": {
          "values": [
            {
              "outputKey": "error",
              "conditions": {
                "options": {
                  "caseSensitive": True,
                  "version": 3
                },
                "conditions": [
                  {
                    "id": "check-error",
                    "leftValue": "={{ $json.success }}",
                    "operator": {
                      "type": "boolean",
                      "operation": "false"
                    }
                  }
                ],
                "combinator": "and"
              }
            }
          ]
        },
        "options": {
          "fallbackOutput": 1
        }
      },
      "id": "check_valid",
      "name": "Token Valid?",
      "type": "n8n-nodes-base.switch",
      "typeVersion": 3,
      "position": [600, 100]
    },
    {
      "parameters": {
        "jsCode": """const WORKFLOW_ID = 'BB_09_Deep_Link_Redirect';

try {
  const errorData = $json;
  return [{
      json: {
          success: false,
          error_code: errorData.error_code || 'PROCESSING_ERROR',
          error_message: errorData.error_message || 'Unknown error',
          data: errorData.data || null,
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
      },
      "id": "return_error",
      "name": "Return Error",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [800, 200]
    },
    {
      "parameters": {
        "jsCode": """const WORKFLOW_ID = 'BB_09_Deep_Link_Redirect';

try {
  const user = $json.data.user;
  return [{
      json: {
          success: true,
          error_code: null,
          error_message: null,
          data: {
              authenticated: true,
              user: user,
              message: 'Authentication successful'
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
      },
      "id": "return_success",
      "name": "Return Success",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [800, 0]
    }
  ],
  "connections": {
    "Execute Workflow Trigger": {
      "main": [[{"node": "Extract Token", "type": "main", "index": 0}]]
    },
    "Extract Token": {
      "main": [[{"node": "Verify Token", "type": "main", "index": 0}]]
    },
    "Verify Token": {
      "main": [[{"node": "Token Valid?", "type": "main", "index": 0}]]
    },
    "Token Valid?": {
      "main": [
        [{"node": "Return Error", "type": "main", "index": 0}],
        [{"node": "Return Success", "type": "main", "index": 0}]
      ]
    }
  },
  "settings": {
    "executionOrder": "v1",
    "saveManualExecutions": True,
    "callerPolicy": "workflowsFromSameOwner",
    "errorWorkflow": "BB_00_Global_Error_Handler"
  }
}

path = 'workflows/BB_09_Deep_Link_Redirect.json'
with open(path, 'w') as f:
    json.dump(bb09_content, f, indent=2)
print("✓ Overwrote BB_09")
