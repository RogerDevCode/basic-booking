#!/usr/bin/env python3
"""
FIX REMAINING MANUAL 4
Cleanup ghost lines in BB_00 Strict Input Validation.
"""
import json
import os

def fix_workflow_nodes():
    path_bb00 = 'workflows/BB_00_Global_Error_Handler.json'
    if not os.path.exists(path_bb00): return

    with open(path_bb00, 'r') as f:
        data = json.load(f)
        
    # Strict Input Validation
    strict_val_code = """const WORKFLOW_ID = 'BB_00_Global_Error_Handler';

// ============================================
// STRICT INPUT VALIDATION - V2
// Valida datos de llamadas manuales
// Error Trigger siempre pasa (es automático de n8n)
// ============================================

try {
  const item = $input.first();
  const TIMEZONE = 'America/Santiago';
  
  const getTimestamp = () => {
    return new Date().toLocaleString('sv-SE', { timeZone: TIMEZONE }).replace(' ', 'T') + 'Z';
  };
  
  if (!item || !item.json) {
    return [{ json: {
      valid: false,
      validation_error: true,
      error_code: 'NO_INPUT_DATA',
      error_message: 'El payload está vacío o es inválido',
      timestamp: getTimestamp(),
      success: true,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }
  
  const json = item.json;
  
  // CASO 1: Error Trigger (automático de n8n)
  if (json.execution && json.workflow) {
    return [{ json: {
      ...json,
      valid: true,
      source: 'error_trigger',
      validation_passed: true,
      received_at: getTimestamp(),
      success: true,
      data: null,
      error_code: null,
      error_message: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }
  
  // CASO 2: Llamada Manual - Validación Estricta
  const validationErrors = [];
  
  const errorMsg = json.error_message || json.errorMessage || json.message;
  if (!errorMsg) {
    validationErrors.push('error_message es requerido');
  } else if (typeof errorMsg !== 'string') {
    validationErrors.push('error_message debe ser string');
  } else if (errorMsg.trim().length === 0) {
    validationErrors.push('error_message no puede estar vacío');
  } else if (errorMsg.length > 5000) {
    validationErrors.push('error_message excede 5000 caracteres');
  }
  
  const workflowName = json.workflow_name || json.workflowName;
  if (!workflowName) {
    validationErrors.push('workflow_name es requerido');
  } else if (typeof workflowName !== 'string') {
    validationErrors.push('workflow_name debe ser string');
  } else if (workflowName.trim().length === 0) {
    validationErrors.push('workflow_name no puede estar vacío');
  } else if (workflowName.length > 200) {
    validationErrors.push('workflow_name excede 200 caracteres');
  }
  
  if (json.severity !== undefined && json.severity !== null) {
    const validSeverities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
    const severityUpper = String(json.severity).toUpperCase();
    if (!validSeverities.includes(severityUpper)) {
      validationErrors.push('severity debe ser: CRITICAL, HIGH, MEDIUM o LOW');
    }
  }
  
  if (json.user_id !== undefined && json.user_id !== null && json.user_id !== '') {
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(String(json.user_id))) {
      validationErrors.push('user_id debe ser un UUID válido');
    }
  }
  
  if (json.error_type !== undefined && json.error_type !== null) {
    if (typeof json.error_type !== 'string') {
      validationErrors.push('error_type debe ser string');
    } else if (json.error_type.length > 100) {
      validationErrors.push('error_type excede 100 caracteres');
    }
  }
  
  if (validationErrors.length > 0) {
    return [{ json: {
      valid: false,
      validation_error: true,
      error_code: 'VALIDATION_FAILED',
      error_message: 'Validación fallida: ' + validationErrors.join('; '),
      validation_errors: validationErrors,
      received_fields: Object.keys(json),
      timestamp: getTimestamp(),
      success: true,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }
  
  return [{ json: {
    ...json,
    valid: true,
    source: 'execute_workflow',
    validation_passed: true,
    received_at: getTimestamp(),
    success: true,
    data: null,
    error_code: null,
    error_message: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
  
} catch (e) {
  return [{ json: {
    valid: false,
    validation_error: true,
    error_code: 'VALIDATION_EXCEPTION',
    error_message: 'Error interno de validación: ' + (e.message || 'Unknown'),
    timestamp: new Date().toISOString(),
    success: true,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
}"""

    modified = False
    for node in data['nodes']:
        if node['name'] == 'Strict Input Validation':
            node['parameters']['jsCode'] = strict_val_code
            modified = True
            print("Fixed BB_00 Strict Input Validation")
    
    if modified:
        with open(path_bb00, 'w') as f:
            json.dump(data, f, indent=2)

if __name__ == '__main__':
    fix_workflow_nodes()
