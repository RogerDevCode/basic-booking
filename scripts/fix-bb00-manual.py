#!/usr/bin/env python3
"""
FIX BB_00 MANUAL
Overwrites specific corrupted nodes in BB_00 with known-good, clean code.
"""
import json
import os

def fix_bb00_nodes():
    path = 'workflows/BB_00_Global_Error_Handler.json'
    if not os.path.exists(path): return

    with open(path, 'r') as f:
        data = json.load(f)

    # 1. Redact PII
    redact_pii_code = """const WORKFLOW_ID = 'BB_00_Global_Error_Handler';

// ============================================
// REDACT PII - V2 Protección de Datos Sensibles
// 40+ patrones, bloquea si falla críticamente
// ============================================

try {
  const item = $input.first();
  
  if (!item || !item.json) {
    return [{ json: { 
      redact_error: 'NO_INPUT', 
      redaction_failed: true,
      block_send: true,
      timestamp: new Date().toISOString(),
      success: true,
      error_code: null,
      error_message: null,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }
  
  const sensitivePatterns = [
    'email', 'e-mail', 'correo', 'mail',
    'phone', 'telefono', 'celular', 'movil', 'mobile', 'fono',
    'name', 'nombre', 'first_name', 'last_name', 'apellido', 'full_name',
    'rut', 'dni', 'cedula', 'passport', 'pasaporte', 'ssn', 'social_security',
    'address', 'direccion', 'domicilio', 'street', 'calle',
    'birthdate', 'fecha_nacimiento', 'dob', 'birthday',
    'telegram_id', 'telegram_user', 'chat_id', 'user_id', 'customer_id',
    'account_id', 'client_id', 'member_id',
    'password', 'passwd', 'pwd', 'contrasena', 'clave', 'pass',
    'token', 'access_token', 'refresh_token', 'auth_token', 'bearer', 'jwt',
    'secret', 'api_key', 'apikey', 'private_key', 'secret_key', 'encryption_key',
    'authorization', 'auth_header', 'x-api-key', 'x-auth-token',
    'credentials', 'credential',
    'credit_card', 'card_number', 'tarjeta', 'cvv', 'cvc', 'ccv', 'card_exp',
    'bank_account', 'cuenta_bancaria', 'iban', 'swift', 'routing_number',
    'payment', 'billing',
    'session_id', 'session_token', 'cookie', 'csrf', 'xsrf',
    'ip_address', 'ip_addr', 'client_ip', 'remote_addr', 'x_forwarded', 'x-real-ip'
  ];
  
  let redactedCount = 0;
  let redactionErrors = [];
  
  function shouldRedact(key) {
    if (!key || typeof key !== 'string') return false;
    const lowerKey = key.toLowerCase().replace(/[-_]/g, '');
    return sensitivePatterns.some(pattern => {
      const normalizedPattern = pattern.toLowerCase().replace(/[-_]/g, '');
      return lowerKey.includes(normalizedPattern);
    });
  }
  
  function redactValue(val) {
    if (val === null || val === undefined) return val;
    const str = String(val);
    if (str.length === 0) return str;
    redactedCount++;
    if (str.length <= 4) return '****';
    if (str.length <= 8) return str.substring(0, 1) + '****' + str.substring(str.length - 1);
    return str.substring(0, 2) + '****' + str.substring(str.length - 2);
  }
  
  function processValue(val, key, path = '') {
    try {
      if (val === null || val === undefined) return val;
      
      if (shouldRedact(key)) {
        return redactValue(val);
      }
      
      if (Array.isArray(val)) {
        return val.map((item, idx) => processValue(item, String(idx), `${path}[${idx}]`));
      }
      
      if (typeof val === 'object') {
        const result = {};
        for (const k of Object.keys(val)) {
          result[k] = processValue(val[k], k, `${path}.${k}`);
        }
        return result;
      }
      
      if (typeof val === 'string') {
        if (/^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$/.test(val)) {
          redactedCount++;
          return redactValue(val);
        }
        if (/^eyJ[A-Za-z0-9-_]+\\.[A-Za-z0-9-_]+\\.[A-Za-z0-9-_]*$/.test(val)) {
          redactedCount++;
          return val.substring(0, 10) + '...REDACTED_JWT';
        }
        const cleanedNum = val.replace(/[\\s-]/g, '');
        if (/^\\d{13,19}$/.test(cleanedNum)) {
          redactedCount++;
          return '****-****-****-' + cleanedNum.slice(-4);
        }
        if (/^\\d{1,2}\\.?\\d{3}\\.?\\d{3}[-]?[0-9kK]$/.test(val.replace(/\\s/g, ''))) {
          redactedCount++;
          return '**.***.' + val.slice(-4);
        }
        if (/^\\+?56\\d{9}$/.test(val.replace(/[\\s-]/g, ''))) {
          redactedCount++;
          return '+56****' + val.slice(-4);
        }
      }
      
      return val;
    } catch (innerError) {
      redactionErrors.push({ path, error: innerError.message });
      return '[REDACTION_ERROR]';
    }
  }
  
  const safeData = processValue(JSON.parse(JSON.stringify(item.json)), 'root');
  const criticalFailure = redactionErrors.length > 5;
  
  return [{ json: {
    ...safeData,
    _redaction_meta: {
      redacted_count: redactedCount,
      errors: redactionErrors.length > 0 ? redactionErrors.slice(0, 5) : undefined,
      critical_failure: criticalFailure,
      block_send: criticalFailure
    },
    success: true,
    error_code: null,
    error_message: null,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
  
} catch (e) {
  return [{ json: {
    redact_error: 'REDACTION_FAILED: ' + (e.message || 'Unknown'),
    source: $input.first()?.json?.source || 'unknown',
    is_valid: false,
    _redaction_meta: {
      critical_failure: true,
      block_send: true,
      error: e.message
    },
    timestamp: new Date().toISOString(),
    success: false,
    error_code: 'REDACTION_ERROR',
    error_message: e.message,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
}"""

    # 2. Classify Severity
    classify_severity_code = """const WORKFLOW_ID = 'BB_00_Global_Error_Handler';

// ============================================
// CLASSIFY SEVERITY - V2
// ============================================

try {
  const item = $input.first();
  
  if (!item || !item.json) {
    return [{ json: {
      severity: 'HIGH',
      severity_reason: 'COULD_NOT_PARSE',
      timestamp: new Date().toISOString(),
      success: true,
      error_code: null,
      error_message: null,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }
  
  const json = item.json;
  
  if (json._redaction_meta?.critical_failure) {
    return [{ json: {
      ...json,
      severity: 'CRITICAL',
      severity_reason: 'REDACTION_CRITICAL_FAILURE',
      success: true,
      error_code: null,
      error_message: null,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }
  
  const errorType = json.error?.type || '';
  const errorMessage = (json.error?.message || '').toLowerCase();
  const workflowName = (json.workflow?.name || '').toLowerCase();
  const providedSeverity = json.context?.provided_severity;
  
  let severity = 'MEDIUM';
  let severityReason = 'DEFAULT';
  
  if (providedSeverity && ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'].includes(providedSeverity.toUpperCase())) {
    severity = providedSeverity.toUpperCase();
    severityReason = 'PROVIDED_BY_CALLER';
  } else {
    const criticalPatterns = [
      'database', 'db connection', 'postgres', 'connection refused',
      'econnrefused', 'authentication failed', 'credential',
      'out of memory', 'disk full', 'fatal', 'panic',
      'ssl', 'certificate', 'permission denied', 'access denied',
      'data corruption', 'integrity', 'deadlock', 'lock timeout',
      'heap', 'stack overflow', 'segmentation fault', 'core dump'
    ];
    
    const highPatterns = [
      'timeout', 'etimedout', 'unauthorized', '401', '403',
      'rate limit', 'too many requests', '429',
      'internal server error', '500', 'bad gateway', '502',
      'service unavailable', '503', 'telegram', 'payment',
      'booking', 'reservation', 'appointment', 'transaction',
      'webhook failed', 'api error', 'external service'
    ];
    
    const lowPatterns = [
      'not found', '404', 'validation', 'invalid input',
      'bad request', '400', 'duplicate', 'already exists',
      'user cancelled', 'cancelled by user', 'no data',
      'empty response', 'missing field', 'format error'
    ];
    
    const criticalWorkflows = [
      'auth', 'payment', 'error_handler', 'bb_00', 'bb_01', 'bb_02',
      'security', 'firewall', 'transaction', 'booking'
    ];
    
    const matchesPatterns = (patterns) => {
      return patterns.some(p => 
        errorMessage.includes(p) || errorType.toLowerCase().includes(p)
      );
    };
    
    if (matchesPatterns(criticalPatterns)) {
      severity = 'CRITICAL';
      severityReason = 'CRITICAL_PATTERN_MATCH';
    } else if (matchesPatterns(highPatterns)) {
      severity = 'HIGH';
      severityReason = 'HIGH_PATTERN_MATCH';
    } else if (matchesPatterns(lowPatterns)) {
      severity = 'LOW';
      severityReason = 'LOW_PATTERN_MATCH';
    }
    
    if (criticalWorkflows.some(w => workflowName.includes(w))) {
      if (severity === 'LOW') {
        severity = 'MEDIUM';
        severityReason = 'CRITICAL_WORKFLOW_UPGRADE';
      } else if (severity === 'MEDIUM') {
        severity = 'HIGH';
        severityReason = 'CRITICAL_WORKFLOW_UPGRADE';
      }
    }
    
    if (json.source === 'error_trigger' && severity === 'LOW') {
      severity = 'MEDIUM';
      severityReason = 'ERROR_TRIGGER_MINIMUM';
    }
  }
  
  return [{ json: {
    ...json,
    severity: severity,
    severity_reason: severityReason,
    success: true,
    error_code: null,
    error_message: null,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
  
} catch (e) {
  const inputData = $input.first()?.json || {};
  return [{ json: {
    ...inputData,
    severity: 'HIGH',
    severity_reason: 'CLASSIFICATION_ERROR: ' + (e.message || 'Unknown'),
    success: false,
    error_code: 'CLASSIFICATION_ERROR',
    error_message: e.message,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
}"""

    # 3. Process Merged Data
    process_merged_code = """const WORKFLOW_ID = 'BB_00_Global_Error_Handler';

// ============================================
// PROCESS MERGED DATA - V2
// Circuit Breaker + Config + Rate Limit
// ============================================

try {
  const items = $input.all();
  const TIMEZONE = 'America/Santiago';

  let envConfig = {
    RATE_LIMIT: 10,
    ADMIN_CHAT_ID: '5391760292',
    ADMIN_EMAIL: 'admin@autoagenda.cl',
    N8N_BASE_URL: 'https://n8n.autoagenda.cl',
    TELEGRAM_ENABLED: true,
    EMAIL_ENABLED: true,
    TIMEZONE: TIMEZONE
  };
  
  try { envConfig.RATE_LIMIT = parseInt($vars.BB_ERROR_RATE_LIMIT) || 10; } catch (e) {}
  try { envConfig.ADMIN_CHAT_ID = $vars.BB_DEFAULT_ADMIN_CHAT_ID || '5391760292'; } catch (e) {}
  try { envConfig.ADMIN_EMAIL = $vars.BB_DEFAULT_ADMIN_EMAIL || 'admin@autoagenda.cl'; } catch (e) {}
  try { envConfig.N8N_BASE_URL = $vars.N8N_BASE_URL || 'https://n8n.autoagenda.cl'; } catch (e) {}

  if (!items || items.length === 0) {
    return [{ json: {
      can_send_telegram: true,
      can_send_email: false,
      admin_chat_id: envConfig.ADMIN_CHAT_ID,
      admin_email: envConfig.ADMIN_EMAIL,
      rate_limit_exceeded: false,
      circuit_breaker_open: false,
      error_count_5min: 0,
      db_unreachable: true,
      system_warning: 'DB_UNREACHABLE_NO_ITEMS',
      severity: 'CRITICAL',
      severity_reason: 'DB_FAILURE',
      success: true,
      error_code: null,
      error_message: null,
      data: null,
      _meta: {
        source: 'subworkflow',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }}];
  }

  let errorData = null;
  let configMap = {};
  let errorCount = 0;
  let circuitBreakerOpen = false;
  let circuitBreakerState = 'CLOSED';
  let dbErrors = [];

  for (const item of items) {
    if (!item || !item.json) continue;
    const json = item.json;

    if (json.error || (json.message && typeof json.message === 'string' &&
        (json.message.includes('error') || json.message.includes('ECONNREFUSED')))) {
      dbErrors.push(json.message || json.error || 'Unknown DB error');
      continue;
    }

    if (json.key && json.value !== undefined) {
      configMap[json.key] = json.value;
      continue;
    }

    if (json.error_count !== undefined) {
      errorCount = parseInt(json.error_count) || 0;
      continue;
    }

    if (json.is_open !== undefined || json.current_state !== undefined) {
      circuitBreakerOpen = json.is_open === true;
      circuitBreakerState = json.current_state || 'UNKNOWN';
      if (json.failure_count) {
        errorCount = Math.max(errorCount, parseInt(json.failure_count) || 0);
      }
      continue;
    }

    if (json.workflow || json.source || json.error) {
      errorData = json;
    }
  }

  if (!errorData) {
    errorData = items.find(i => i?.json?.workflow || i?.json?.source)?.json || {};
  }

  const finalConfig = {
    adminChatId: configMap['ADMIN_TELEGRAM_CHAT_ID'] || envConfig.ADMIN_CHAT_ID,
    adminEmail: configMap['ADMIN_EMAIL'] || envConfig.ADMIN_EMAIL,
    n8nBaseUrl: configMap['N8N_BASE_URL'] || envConfig.N8N_BASE_URL,
    timezone: configMap['TIMEZONE'] || envConfig.TIMEZONE,
    telegramEnabled: configMap['TELEGRAM_NOTIFICATIONS_ENABLED'] !== 'false',
    emailEnabled: configMap['EMAIL_NOTIFICATIONS_ENABLED'] !== 'false',
    rateLimit: envConfig.RATE_LIMIT
  };

  const dbUnreachable = dbErrors.length >= 2;
  let finalSeverity = errorData.severity || 'MEDIUM';
  let severityReason = errorData.severity_reason || 'DEFAULT';
  let systemWarning = null;

  if (dbUnreachable) {
    finalSeverity = 'CRITICAL';
    severityReason = 'DB_UNREACHABLE';
    systemWarning = '\u26a0\ufe0f DB UNREACHABLE: ' + dbErrors.slice(0, 2).join('; ');
    console.error('BB_00: Database unreachable!', dbErrors);
  }

  if (circuitBreakerOpen && finalSeverity !== 'CRITICAL') {
    systemWarning = '\ud83d\udd0c Circuit Breaker OPEN para: ' + (errorData.workflow?.name || 'Unknown');
    console.warn('BB_00: Circuit breaker is OPEN');
  }

  const rateLimitExceeded = errorCount >= finalConfig.rateLimit;
  
  const canSendTelegram = finalConfig.telegramEnabled && 
    ((finalSeverity === 'CRITICAL') || (!rateLimitExceeded && !circuitBreakerOpen));
  
  const canSendEmail = finalConfig.emailEnabled && (finalSeverity === 'CRITICAL');

  return [{ json: {
    ...errorData,
    severity: finalSeverity,
    severity_reason: severityReason,
    admin_chat_id: finalConfig.adminChatId,
    admin_email: finalConfig.adminEmail,
    n8n_base_url: finalConfig.n8nBaseUrl,
    timezone: finalConfig.timezone,
    error_count_5min: errorCount,
    rate_limit: finalConfig.rateLimit,
    rate_limit_exceeded: rateLimitExceeded,
    circuit_breaker_open: circuitBreakerOpen,
    circuit_breaker_state: circuitBreakerState,
    can_send_telegram: canSendTelegram,
    can_send_email: canSendEmail,
    telegram_enabled: finalConfig.telegramEnabled,
    email_enabled: finalConfig.emailEnabled,
    db_unreachable: dbUnreachable,
    db_errors: dbErrors.length > 0 ? dbErrors : undefined,
    system_warning: systemWarning,
    success: true,
    error_code: null,
    error_message: null,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];

} catch (e) {
  const fallbackData = $input.first()?.json || {};
  console.error('BB_00: Process Merged Data CRITICAL FAILURE:', e.message);

  return [{ json: {
    ...fallbackData,
    severity: 'CRITICAL',
    severity_reason: 'PROCESS_EXCEPTION',
    admin_chat_id: '5391760292',
    admin_email: 'admin@autoagenda.cl',
    error_count_5min: 0,
    rate_limit: 10,
    rate_limit_exceeded: false,
    circuit_breaker_open: false,
    can_send_telegram: true,
    can_send_email: true,
    db_unreachable: true,
    system_warning: '\u26a0\ufe0f PROCESS_EXCEPTION: ' + (e.message || 'Unknown'),
    success: false,
    error_code: 'PROCESS_EXCEPTION',
    error_message: e.message,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
}"""

    # 4. Prepare DB Insert
    prepare_db_code = """const WORKFLOW_ID = 'BB_00_Global_Error_Handler';

try {

  // ============================================
  // PREPARE DB INSERT
  // ============================================

  const json = $input.first()?.json || {};

  const workflowName = (json.workflow?.name || 'UNKNOWN').replace(/'/g, "''");
  const executionId = (json.execution?.id || 'UNKNOWN').replace(/'/g, "''");
  const errorType = (json.error?.type || 'UNKNOWN').replace(/'/g, "''");
  const severity = json.severity || 'MEDIUM';
  const errorMessage = (json.error?.message || 'UNKNOWN').substring(0, 2000).replace(/'/g, "''");
  const errorStack = JSON.stringify(json.error?.stack || []).replace(/'/g, "''");
  const errorContext = JSON.stringify({
    source: json.source,
    severity_reason: json.severity_reason,
    last_node: json.execution?.last_node,
    context: json.context,
    system_warning: json.system_warning,
    rate_limit_exceeded: json.rate_limit_exceeded,
    circuit_breaker_state: json.circuit_breaker_state
  }).replace(/'/g, "''");
  const userId = json.user_id || null;

  return [{ json: {
    ...json,
    _db_params: {
      workflow_name: workflowName,
      execution_id: executionId,
      error_type: errorType,
      severity: severity,
      error_message: errorMessage,
      error_stack: errorStack,
      error_context: errorContext,
      user_id: userId
    },
    success: true,
    error_code: null,
    error_message: null,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
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

    # 5. Handle DB Result
    handle_db_code = """const WORKFLOW_ID = 'BB_00_Global_Error_Handler';

try {

  // ============================================
  // HANDLE DB RESULT
  // ============================================

  const items = $input.all();
  const mainData = items.find(i => i?.json?.workflow || i?.json?.source)?.json || items[0]?.json || {};
  const dbResult = items.find(i => i?.json?.error_id !== undefined)?.json || {};

  const dbSuccess = dbResult.error_id && !dbResult.error;
  const dbError = !dbSuccess ? (dbResult.message || dbResult.error || 'Unknown DB error') : null;

  if (!dbSuccess) {
    console.error('BB_00: Log to DB failed:', dbError);
  }

  return [{ json: {
    ...mainData,
    db_logged: dbSuccess,
    db_error_id: dbResult.error_id || null,
    db_error: dbError,
    success: true,
    error_code: null,
    error_message: null,
    data: null,
    _meta: {
      source: 'subworkflow',
      timestamp: new Date().toISOString(),
      workflow_id: WORKFLOW_ID
    }
  }}];
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
        if node['name'] == 'Redact PII':
            node['parameters']['jsCode'] = redact_pii_code
            modified = True
            print("Fixed Redact PII")
        elif node['name'] == 'Classify Severity':
            node['parameters']['jsCode'] = classify_severity_code
            modified = True
            print("Fixed Classify Severity")
        elif node['name'] == 'Process Merged Data':
            node['parameters']['jsCode'] = process_merged_code
            modified = True
            print("Fixed Process Merged Data")
        elif node['name'] == 'Prepare DB Insert':
            node['parameters']['jsCode'] = prepare_db_code
            modified = True
            print("Fixed Prepare DB Insert")
        elif node['name'] == 'Handle DB Result':
            node['parameters']['jsCode'] = handle_db_code
            modified = True
            print("Fixed Handle DB Result")
            
    if modified:
        with open(path, 'w') as f:
            json.dump(data, f, indent=2)

if __name__ == '__main__':
    fix_bb00_nodes()
