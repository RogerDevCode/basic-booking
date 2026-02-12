# 🎯 PLAN DE ACCIÓN DETALLADO - AutoAgenda Critical Fixes

**Documento complementario a:** `reportZed.md`  
**Fecha:** 2024-01-15  
**Duración estimada total:** 3-4 semanas  
**Esfuerzo:** ~120 horas de desarrollo + testing

---

## 📋 ÍNDICE DE FIXES

### 🔴 P0 - Críticos (8 bugs)
- [FIX 1.1](#fix-11-bb_08---jwt-verificación-real) BB_08 - JWT Verificación Real
- [FIX 1.2](#fix-12-bb_04---transaction-serializable) BB_04 - Transaction SERIALIZABLE
- [FIX 1.3](#fix-13-bb_02---parametrizar-queries) BB_02 - Parametrizar Queries
- [FIX 1.4](#fix-14-bb_05bb_07---crear-notification_queue) BB_05/BB_07 - Crear notification_queue
- [FIX 1.5](#fix-15-bb_00---atomic-circuit-breaker) BB_00 - Atomic Circuit Breaker
- [FIX 1.6](#fix-16-bb_04---rollback-con-compensación) BB_04 - Rollback con Compensación
- [FIX 1.7](#fix-17-bb_05---eliminar-función-fantasma) BB_05 - Eliminar Función Fantasma
- [FIX 1.8](#fix-18-bb_08---eliminar-secret-hardcodeado) BB_08 - Eliminar Secret Hardcodeado

### 🟡 P1 - Altos (12 bugs)
- FIX 2.1 a 2.12 (ver sección P1)

---

## 🔥 FASE 1: FIXES CRÍTICOS (P0) - DÍAS 1-4

### FIX 1.1: BB_08 - JWT Verificación Real
**Tiempo:** 4 horas  
**Riesgo:** Alto (autenticación completa)  
**Dependencias:** Ninguna

#### PASO 1.1.1: Instalar Librería jsonwebtoken
```bash
# En servidor n8n o Docker container
cd /usr/local/lib/node_modules/n8n
npm install jsonwebtoken@9.0.2

# Verificar instalación
node -e "console.log(require('jsonwebtoken').version)"
# Output esperado: 9.0.2
```

#### PASO 1.1.2: Configurar JWT_SECRET en Variables de Entorno
```bash
# Generar secret seguro (32 bytes hex)
openssl rand -hex 32
# Output ejemplo: a1b2c3d4e5f6...

# Agregar a .env de n8n
echo "JWT_SECRET=a1b2c3d4e5f6..." >> /path/to/n8n/.env

# Reiniciar n8n
systemctl restart n8n
# O en Docker:
docker-compose restart n8n
```

#### PASO 1.1.3: Modificar BB_08_JWT_Auth_Helper.json

**ARCHIVO:** `workflows/BB_08_JWT_Auth_Helper.json`

**Buscar nodo:** `Verify Token` (id: `verify_token`)

**REEMPLAZAR código completo del nodo:**
```javascript
/**
 * JWT VERIFICATION - SECURE VERSION
 * Usa librería jsonwebtoken con verificación HMAC real
 */
try {
    const jwt = require('jsonwebtoken');
    const token = $json.token;
    
    // Obtener secret de env (SIN fallback)
    const secret = process.env.JWT_SECRET;
    
    if (!secret) {
        throw new Error('JWT_SECRET not configured in environment');
    }
    
    // Verificar firma y decodificar (esto valida HMAC)
    const payload = jwt.verify(token, secret, {
        algorithms: ['HS256'], // Solo aceptar HMAC-SHA256
        clockTolerance: 30 // 30 segundos de tolerancia
    });
    
    // Validar campos requeridos
    if (!payload.user_id || !payload.email || !payload.role) {
        throw new Error('Missing required claims in token');
    }
    
    // Validar role (solo admin)
    if (payload.role !== 'admin') {
        return [{
            json: {
                error: true,
                status: 403,
                message: 'FORBIDDEN: Admin access required',
                code: 'INSUFFICIENT_PERMISSIONS'
            }
        }];
    }
    
    // Validar issued_at no sea futuro
    if (payload.iat && payload.iat > Math.floor(Date.now() / 1000) + 30) {
        throw new Error('Token issued in the future');
    }
    
    // Token válido
    return [{
        json: {
            valid: true,
            user: {
                id: payload.user_id,
                email: payload.email,
                role: payload.role
            },
            token_exp: payload.exp,
            token_iat: payload.iat
        }
    }];
    
} catch (e) {
    // Errores de jsonwebtoken
    const errorMap = {
        'TokenExpiredError': { code: 'TOKEN_EXPIRED', status: 401 },
        'JsonWebTokenError': { code: 'INVALID_TOKEN', status: 401 },
        'NotBeforeError': { code: 'TOKEN_NOT_YET_VALID', status: 401 }
    };
    
    const errorInfo = errorMap[e.name] || { code: 'INVALID_TOKEN', status: 401 };
    
    return [{
        json: {
            error: true,
            status: errorInfo.status,
            message: 'UNAUTHORIZED: ' + (e.message || 'Invalid token'),
            code: errorInfo.code
        }
    }];
}
```

#### PASO 1.1.4: Testing
```bash
# Test 1: Token válido
curl -X POST http://localhost:5678/webhook-test/bb08-auth \
  -H "Authorization: Bearer $(node -e "
    const jwt = require('jsonwebtoken');
    console.log(jwt.sign(
      { user_id: 'test-123', email: 'admin@test.com', role: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    ));
  ")"
# Esperado: { "valid": true, "user": {...} }

# Test 2: Token con firma inválida (debería FALLAR)
curl -X POST http://localhost:5678/webhook-test/bb08-auth \
  -H "Authorization: Bearer eyJhbGci.eyJyb2xlIjoiYWRtaW4ifQ.FAKE"
# Esperado: { "error": true, "code": "INVALID_TOKEN" }

# Test 3: Token expirado
curl -X POST http://localhost:5678/webhook-test/bb08-auth \
  -H "Authorization: Bearer $(node -e "
    const jwt = require('jsonwebtoken');
    console.log(jwt.sign(
      { user_id: 'test-123', email: 'admin@test.com', role: 'admin' },
      process.env.JWT_SECRET,
      { expiresIn: '-1h' }
    ));
  ")"
# Esperado: { "error": true, "code": "TOKEN_EXPIRED" }

# Test 4: Role no-admin
curl -X POST http://localhost:5678/webhook-test/bb08-auth \
  -H "Authorization: Bearer $(node -e "
    const jwt = require('jsonwebtoken');
    console.log(jwt.sign(
      { user_id: 'test-123', email: 'user@test.com', role: 'user' },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    ));
  ")"
# Esperado: { "error": true, "code": "INSUFFICIENT_PERMISSIONS" }
```

#### PASO 1.1.5: Deployment
```bash
# 1. Guardar cambios
git add workflows/BB_08_JWT_Auth_Helper.json
git commit -m "FIX P0: BB_08 - Implement real JWT verification with jsonwebtoken"

# 2. Importar a n8n
# Via UI: Settings → Import from File → BB_08_JWT_Auth_Helper.json
# O via API:
curl -X POST http://localhost:5678/api/v1/workflows/import \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -F "file=@workflows/BB_08_JWT_Auth_Helper.json"

# 3. Activar workflow
# Via UI: Open BB_08 → Set to Active
```

#### PASO 1.1.6: Validación Post-Deploy
```bash
# Verificar en logs que JWT_SECRET está configurado
docker logs n8n_container 2>&1 | grep "JWT_SECRET"
# NO debería mostrar el valor, solo confirmar que existe

# Test end-to-end: Login + API call
TOKEN=$(curl -X POST http://n8n.domain.com/webhook/admin-v3/api/login \
  -d '{"email":"admin@autoagenda.com","password":"secure123"}' | jq -r '.token')

curl http://n8n.domain.com/webhook/admin-v3/api/stats \
  -H "Authorization: Bearer $TOKEN"
# Esperado: Stats del sistema (no error 401)
```

---

### FIX 1.2: BB_04 - Transaction SERIALIZABLE
**Tiempo:** 6 horas  
**Riesgo:** Alto (afecta todas las reservas)  
**Dependencias:** Ninguna

#### PASO 1.2.1: Crear Función PostgreSQL Atómica

**ARCHIVO NUEVO:** `database/migrations/003_atomic_booking_lock.sql`

```sql
-- ============================================
-- ATOMIC BOOKING LOCK FUNCTION
-- Previene race conditions en reservas
-- ============================================

CREATE OR REPLACE FUNCTION public.atomic_booking_check_and_lock(
    p_provider_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ,
    p_user_id UUID,
    p_service_id UUID DEFAULT NULL
) RETURNS TABLE(
    is_available BOOLEAN,
    conflict_count INTEGER,
    lock_acquired BOOLEAN
) 
LANGUAGE plpgsql
AS $$
BEGIN
    -- Usar advisory lock basado en provider_id + start_time
    -- Convierte UUID a bigint para pg_advisory_xact_lock
    PERFORM pg_advisory_xact_lock(
        ('x' || substring(p_provider_id::text, 1, 8))::bit(32)::bigint,
        EXTRACT(EPOCH FROM p_start_time)::bigint
    );
    
    -- Verificar conflictos DESPUÉS de obtener lock
    RETURN QUERY
    SELECT 
        (COUNT(*) = 0) AS is_available,
        COUNT(*)::INTEGER AS conflict_count,
        TRUE AS lock_acquired
    FROM bookings
    WHERE provider_id = p_provider_id
      AND start_time < p_end_time
      AND end_time > p_start_time
      AND status IN ('pending', 'confirmed')
      AND deleted_at IS NULL;
    
    -- Lock se libera automáticamente al final de la transacción
END;
$$;

-- Índice optimizado para búsqueda de conflictos
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_conflict_check
ON bookings (provider_id, start_time, end_time, status)
WHERE deleted_at IS NULL AND status IN ('pending', 'confirmed');

-- Comentarios
COMMENT ON FUNCTION public.atomic_booking_check_and_lock IS 
'Verifica disponibilidad de slot con lock atómico. Previene double booking.';
```

#### PASO 1.2.2: Ejecutar Migration
```bash
# Conectar a DB
psql $DATABASE_URL

# Ejecutar migration
\i database/migrations/003_atomic_booking_lock.sql

# Verificar función creada
\df atomic_booking_check_and_lock
```

#### PASO 1.2.3: Modificar BB_04_Booking_Transaction.json

**ARCHIVO:** `workflows/BB_04_Booking_Transaction.json`

**NODO A REEMPLAZAR:** `db_lock` (línea ~667)

**ANTES:**
```json
{
  "operation": "executeQuery",
  "query": "SELECT COUNT(*) FROM bookings WHERE provider_id = $1 AND start_time < $2 AND end_time > $3 AND status IN ('pending', 'confirmed')",
  "queryParameters": {
    "values": [
      { "value": "={{ $json.provider_id }}" },
      { "value": "={{ $json.end_time }}" },
      { "value": "={{ $json.start_time }}" }
    ]
  }
}
```

**DESPUÉS:**
```json
{
  "operation": "executeQuery",
  "query": "SELECT * FROM public.atomic_booking_check_and_lock($1, $2, $3, $4, $5);",
  "queryParameters": {
    "values": [
      { "value": "={{ $json.provider_id }}" },
      { "value": "={{ $json.start_time }}" },
      { "value": "={{ $json.end_time }}" },
      { "value": "={{ $json.user_id }}" },
      { "value": "={{ $json.service_id || null }}" }
    ]
  }
}
```

**NODO A MODIFICAR:** `check_lock` (switch después de db_lock)

**Cambiar condición:**
```json
{
  "leftValue": "={{ $json.is_available }}",
  "operator": {
    "type": "boolean",
    "operation": "false"
  }
}
```

#### PASO 1.2.4: Testing de Concurrencia
```bash
# Script de test concurrente
# ARCHIVO NUEVO: tests/test_concurrent_booking.sh

#!/bin/bash
PROVIDER_ID="550e8400-e29b-41d4-a716-446655440000"
START_TIME="2024-02-01T10:00:00Z"
END_TIME="2024-02-01T11:00:00Z"

# Lanzar 10 requests simultáneos
for i in {1..10}; do
  (
    USER_ID="user-$i"
    curl -X POST http://localhost:5678/webhook/bb04-book \
      -H "Content-Type: application/json" \
      -d "{
        \"provider_id\": \"$PROVIDER_ID\",
        \"user_id\": \"$USER_ID\",
        \"start_time\": \"$START_TIME\",
        \"end_time\": \"$END_TIME\"
      }" &
  )
done

wait

# Verificar cuántos bookings se crearon
psql $DATABASE_URL -c "
  SELECT COUNT(*), array_agg(user_id) 
  FROM bookings 
  WHERE provider_id = '$PROVIDER_ID' 
    AND start_time = '$START_TIME'
    AND status = 'confirmed';
"
# Esperado: COUNT = 1 (solo uno debe tener éxito)
```

#### PASO 1.2.5: Validación
```bash
# Test 1: Verificar que solo 1 booking se crea
./tests/test_concurrent_booking.sh
# Resultado esperado: "count | 1"

# Test 2: Verificar lock se libera
psql $DATABASE_URL -c "SELECT * FROM pg_locks WHERE locktype = 'advisory';"
# Debe estar vacío (locks liberados)

# Test 3: Performance (latencia)
time curl -X POST http://localhost:5678/webhook/bb04-book -d '{...}'
# Esperado: < 500ms (aceptable con lock)
```

---

### FIX 1.3: BB_02 - Parametrizar Queries
**Tiempo:** 2 horas  
**Riesgo:** Medio (bien contenido)  
**Dependencias:** Ninguna

#### PASO 1.3.1: Identificar Queries Vulnerables

**ARCHIVO:** `workflows/BB_02_Security_Firewall.json`

**Queries a modificar:**
1. Nodo `DB: Security Check` (línea ~119)
2. Nodo `Audit: Log Access Attempt` (línea ~169)
3. Nodo `DB: Update Strike` (línea ~307)

#### PASO 1.3.2: Reemplazar Query #1 - Security Check

**ANTES:**
```json
{
  "operation": "executeQuery",
  "query": "SELECT * FROM security_firewall WHERE entity_id = '{{ $json.entity_id }}'"
}
```

**DESPUÉS:**
```json
{
  "operation": "executeQuery",
  "query": "SELECT * FROM security_firewall WHERE entity_id = $1",
  "options": {
    "queryParameters": {
      "values": [
        { "value": "={{ $json.entity_id }}" }
      ]
    }
  }
}
```

#### PASO 1.3.3: Reemplazar Query #2 - Audit Log

**ANTES:**
```json
{
  "query": "INSERT INTO audit_logs (table_name, record_id, action, event_data, ...) VALUES ('security_firewall', '{{ $json.entity_id }}', 'ACCESS_CHECK', ...)"
}
```

**DESPUÉS:**
```json
{
  "query": "INSERT INTO audit_logs (table_name, record_id, action, event_data, performed_by, created_at) VALUES ($1, $2, $3, $4::jsonb, $5, NOW()) RETURNING id",
  "options": {
    "queryParameters": {
      "values": [
        { "value": "security_firewall" },
        { "value": "={{ $json.entity_id }}" },
        { "value": "ACCESS_CHECK" },
        { "value": "={{ JSON.stringify({ workflow: 'BB_02_Security_Firewall', ...}) }}" },
        { "value": "system" }
      ]
    }
  }
}
```

#### PASO 1.3.4: Testing SQL Injection
```bash
# Test 1: Payload SQL Injection clásico
curl -X POST http://localhost:5678/webhook/security-v3 \
  -d '{"entity_id": "telegram:123\" OR \"1\"=\"1"}'
# Esperado: { "access": "denied" } o "authorized" legítimo
# NO debe devolver múltiples filas

# Test 2: Payload con comentarios SQL
curl -X POST http://localhost:5678/webhook/security-v3 \
  -d '{"entity_id": "telegram:123--"}'
# Esperado: Sin error, manejo correcto

# Test 3: Verificar en DB que se guardó literal
psql $DATABASE_URL -c "
  SELECT entity_id FROM audit_logs 
  WHERE event_data->>'workflow' = 'BB_02_Security_Firewall' 
  ORDER BY created_at DESC LIMIT 5;
"
# Debe mostrar: telegram:123" OR "1"="1 (como string, no ejecutado)
```

---

### FIX 1.4: BB_05/BB_07 - Crear notification_queue
**Tiempo:** 4 horas  
**Riesgo:** Bajo (nueva feature)  
**Dependencias:** Ninguna

#### PASO 1.4.1: Crear Tabla notification_queue

**ARCHIVO NUEVO:** `database/migrations/004_notification_queue.sql`

```sql
-- ============================================
-- NOTIFICATION QUEUE TABLE
-- Sistema de retry para notificaciones fallidas
-- ============================================

CREATE TABLE IF NOT EXISTS public.notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL, -- telegram_id
    message TEXT NOT NULL,
    notification_type VARCHAR(20) CHECK (notification_type IN ('reminder_24h', 'reminder_2h', 'confirmation', 'cancellation')),
    priority INTEGER DEFAULT 1 CHECK (priority BETWEEN 1 AND 10),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'expired')),
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    error_message TEXT,
    last_attempt_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,
    sent_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_nq_status_retry ON notification_queue(status, retry_count, next_retry_at)
WHERE status = 'pending' AND retry_count < max_retries;

CREATE INDEX idx_nq_booking ON notification_queue(booking_id);
CREATE INDEX idx_nq_user ON notification_queue(user_id);
CREATE INDEX idx_nq_expires ON notification_queue(expires_at)
WHERE status IN ('pending', 'failed');

-- Trigger para updated_at
CREATE TRIGGER trg_notification_queue_updated_at
BEFORE UPDATE ON notification_queue
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Función para calcular next_retry_at (exponential backoff)
CREATE OR REPLACE FUNCTION calculate_next_retry(
    p_retry_count INTEGER
) RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
AS $$
BEGIN
    -- Exponential backoff: 5s, 30s, 5m, 30m, 2h
    RETURN NOW() + CASE p_retry_count
        WHEN 0 THEN INTERVAL '5 seconds'
        WHEN 1 THEN INTERVAL '30 seconds'
        WHEN 2 THEN INTERVAL '5 minutes'
        WHEN 3 THEN INTERVAL '30 minutes'
        ELSE INTERVAL '2 hours'
    END;
END;
$$;

-- View para monitoreo
CREATE OR REPLACE VIEW v_notification_queue_stats AS
SELECT 
    status,
    notification_type,
    COUNT(*) as count,
    AVG(retry_count) as avg_retries,
    MAX(created_at) as last_created
FROM notification_queue
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY status, notification_type;

COMMENT ON TABLE public.notification_queue IS 
'Cola de notificaciones con sistema de retry exponencial. Alimentado por BB_05, procesado por BB_07.';
```

#### PASO 1.4.2: Ejecutar Migration
```bash
psql $DATABASE_URL < database/migrations/004_notification_queue.sql

# Verificar tabla creada
psql $DATABASE_URL -c "\d notification_queue"
```

#### PASO 1.4.3: Modificar BB_05 - Insertar en Queue si Falla

**ARCHIVO:** `workflows/BB_05_Notification_Engine.json`

**AGREGAR NODO NUEVO después de `Telegram` (nodo `tg`):**

Nombre del nodo: `Handle Telegram Failures`

```json
{
  "parameters": {
    "jsCode": "const items = $input.all();\nconst failures = [];\n\nfor (const item of items) {\n  // Si Telegram falló\n  if (item.json.error || !item.json.message_id) {\n    const originalData = $node['Prep Universal'].all().find(\n      prep => prep.json.telegram_id === item.json.chat?.id\n    );\n    \n    if (originalData) {\n      failures.push({\n        json: {\n          booking_id: originalData.json.booking_id,\n          user_id: originalData.json.telegram_id,\n          message: originalData.json.text,\n          notification_type: originalData.json.r_type === 'r1' ? 'reminder_24h' : 'reminder_2h',\n          error_message: item.json.error?.message || 'Unknown Telegram error',\n          retry_count: 0,\n          next_retry_at: new Date(Date.now() + 5000).toISOString()\n        }\n      });\n    }\n  }\n}\n\nreturn failures.length > 0 ? failures : [{ json: { no_failures: true } }];"
  },
  "type": "n8n-nodes-base.code",
  "typeVersion": 2
}
```

**AGREGAR NODO NUEVO después de `Handle Telegram Failures`:**

Nombre: `Insert Into Notification Queue`

```json
{
  "parameters": {
    "operation": "insert",
    "schema": "public",
    "table": "notification_queue",
    "columns": {
      "mappingMode": "defineBelow",
      "value": {
        "booking_id": "={{ $json.booking_id }}",
        "user_id": "={{ $json.user_id }}",
        "message": "={{ $json.message }}",
        "notification_type": "={{ $json.notification_type }}",
        "error_message": "={{ $json.error_message }}",
        "retry_count": "={{ $json.retry_count }}",
        "next_retry_at": "={{ $json.next_retry_at }}",
        "status": "pending"
      }
    }
  },
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.4
}
```

#### PASO 1.4.4: Modificar BB_07 - Usar Tabla Real

**ARCHIVO:** `workflows/BB_07_Notification_Retry_Worker.json`

**Nodo `Fetch Pending` ya está correcto, pero agregar:**

```json
{
  "operation": "executeQuery",
  "query": "SELECT * FROM notification_queue WHERE status = 'pending' AND retry_count < max_retries AND (next_retry_at IS NULL OR next_retry_at <= NOW()) AND expires_at > NOW() ORDER BY priority DESC, created_at ASC LIMIT 50"
}
```

**Nodo `Mark Sent` modificar:**
```json
{
  "operation": "update",
  "query": "UPDATE notification_queue SET status = 'sent', sent_at = NOW(), updated_at = NOW() WHERE id = $1",
  "queryParameters": {
    "values": [{ "value": "={{ $json.id }}" }]
  }
}
```

**Nodo `Mark Failed` modificar:**
```json
{
  "operation": "update",
  "query": "UPDATE notification_queue SET status = CASE WHEN retry_count + 1 >= max_retries THEN 'failed' ELSE 'pending' END, retry_count = retry_count + 1, error_message = $2, last_attempt_at = NOW(), next_retry_at = calculate_next_retry(retry_count + 1), updated_at = NOW() WHERE id = $1",
  "queryParameters": {
    "values": [
      { "value": "={{ $json.id }}" },
      { "value": "={{ $json.error_message }}" }
    ]
  }
}
```

#### PASO 1.4.5: Testing
```bash
# Test 1: Insertar notificación manualmente
psql $DATABASE_URL -c "
INSERT INTO notification_queue (booking_id, user_id, message, notification_type)
VALUES (
  (SELECT id FROM bookings LIMIT 1),
  123456789,
  'Test notification',
  'reminder_24h'
);
"

# Test 2: Ejecutar BB_07 manualmente
curl -X POST http://localhost:5678/webhook-test/bb07-retry

# Test 3: Verificar estado cambió
psql $DATABASE_URL -c "
SELECT status, retry_count, sent_at 
FROM notification_queue 
ORDER BY created_at DESC LIMIT 5;
"
```

---

### FIX 1.5: BB_00 - Atomic Circuit Breaker
**Tiempo:** 8 horas  
**Riesgo:** Alto (sistema crítico)  
**Dependencias:** Ninguna

#### PASO 1.5.1: Crear Tabla para Circuit Breaker State

**ARCHIVO NUEVO:** `database/migrations/005_circuit_breaker.sql`

```sql
-- ============================================
-- CIRCUIT BREAKER STATE TABLE
-- Reemplaza función volátil con tabla persistente
-- ============================================

CREATE TABLE IF NOT EXISTS public.circuit_breaker_state (
    workflow_name VARCHAR(200) PRIMARY KEY,
    is_open BOOLEAN DEFAULT FALSE,
    failure_count INTEGER DEFAULT 0,
    last_failure_at TIMESTAMPTZ,
    opened_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    window_start TIMESTAMPTZ DEFAULT NOW(),
    max_failures INTEGER DEFAULT 50,
    window_minutes INTEGER DEFAULT 5,
    cooldown_minutes INTEGER DEFAULT 15,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsqueda rápida
CREATE INDEX idx_cb_state_open ON circuit_breaker_state(is_open, workflow_name);

-- Función atómica para verificar y actualizar
CREATE OR REPLACE FUNCTION public.circuit_breaker_check_and_record(
    p_workflow_name VARCHAR(200),
    p_max_failures INTEGER DEFAULT 50,
    p_window_minutes INTEGER DEFAULT 5,
    p_cooldown_minutes INTEGER DEFAULT 15
) RETURNS TABLE(
    is_open BOOLEAN,
    failure_count INTEGER,
    can_attempt BOOLEAN,
    next_attempt_at TIMESTAMPTZ,
    current_state VARCHAR(20)
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_state RECORD;
    v_window_start TIMESTAMPTZ;
BEGIN
    -- Lock para este workflow (advisory lock)
    PERFORM pg_advisory_xact_lock(hashtext(p_workflow_name));
    
    -- Calcular ventana de tiempo actual
    v_window_start := NOW() - (p_window_minutes || ' minutes')::INTERVAL;
    
    -- Obtener o crear estado
    SELECT * INTO v_state
    FROM circuit_breaker_state
    WHERE workflow_name = p_workflow_name;
    
    IF NOT FOUND THEN
        -- Primera vez, crear registro
        INSERT INTO circuit_breaker_state (
            workflow_name, max_failures, window_minutes, cooldown_minutes
        ) VALUES (
            p_workflow_name, p_max_failures, p_window_minutes, p_cooldown_minutes
        )
        RETURNING * INTO v_state;
    END IF;
    
    -- Verificar si debe resetear ventana
    IF v_state.window_start < v_window_start THEN
        UPDATE circuit_breaker_state
        SET 
            failure_count = 1,
            window_start = NOW(),
            last_failure_at = NOW(),
            updated_at = NOW()
        WHERE workflow_name = p_workflow_name
        RETURNING * INTO v_state;
    ELSE
        -- Incrementar contador en ventana actual
        UPDATE circuit_breaker_state
        SET 
            failure_count = failure_count + 1,
            last_failure_at = NOW(),
            updated_at = NOW()
        WHERE workflow_name = p_workflow_name
        RETURNING * INTO v_state;
    END IF;
    
    -- Verificar si debe abrir circuit breaker
    IF v_state.failure_count >= p_max_failures AND NOT v_state.is_open THEN
        UPDATE circuit_breaker_state
        SET 
            is_open = TRUE,
            opened_at = NOW(),
            updated_at = NOW()
        WHERE workflow_name = p_workflow_name
        RETURNING * INTO v_state;
    END IF;
    
    -- Verificar si debe cerrar circuit breaker (cooldown pasó)
    IF v_state.is_open AND v_state.opened_at < (NOW() - (p_cooldown_minutes || ' minutes')::INTERVAL) THEN
        UPDATE circuit_breaker_state
        SET 
            is_open = FALSE,
            failure_count = 0,
            closed_at = NOW(),
            window_start = NOW(),
            updated_at = NOW()
        WHERE workflow_name = p_workflow_name
        RETURNING * INTO v_state;
    END IF;
    
    -- Retornar estado actual
    RETURN QUERY
    SELECT 
        v_state.is_open,
        v_state.failure_count,
        NOT v_state.is_open AS can_attempt,
        CASE 
            WHEN v_state.is_open THEN v_state.opened_at + (p_cooldown_minutes || ' minutes')::INTERVAL
            ELSE NULL
        END AS next_attempt_at,
        CASE 
            WHEN v_state.is_open THEN 'OPEN'
            WHEN v_state.failure_count >= p_max_failures * 0.8 THEN 'HALF_OPEN'
            ELSE 'CLOSED'
        END AS current_state;
END;
$$;

-- Función para resetear circuit breaker manualmente
CREATE OR REPLACE FUNCTION public.reset_circuit_breaker(
    p_workflow_name VARCHAR(200)
) RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE circuit_breaker_state
    SET 
        is_open = FALSE,
        failure_count = 0,
        closed_at = NOW(),
        window_start = NOW(),
        updated_at = NOW()
    WHERE workflow_name = p_workflow_name;
    
    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION circuit_breaker_check_and_record IS 
'Verifica y actualiza estado del circuit breaker de forma atómica. Auto-cierra después de cooldown.';
```

#### PASO 1.5.2: Ejecutar Migration
```bash
psql $DATABASE_URL < database/migrations/005_circuit_breaker.sql

# Verificar tabla y funciones
psql $DATABASE_URL -c "\d circuit_breaker_state"
psql $DATABASE_URL -c "\df circuit_breaker_check_and_record"
```

#### PASO 1.5.3: Modificar BB_00 - Usar Nueva Función
**ARCHIVO:** `workflows/BB_00_Global_Error_Handler.json`

**NODO:** `Check Circuit Breaker`

**ANTES:**
```sql
SELECT is_open, current_state, failure_count, can_attempt, next_attempt_at 
FROM public.check_circuit_breaker('{{ $json.workflow.name }}', 50, 5, 15)
```

**DESPUÉS:**
```sql
SELECT * FROM public.circuit_breaker_check_and_record($1, $2, $3, $4)
```

**AGREGAR queryParameters:**
```json
{
  "queryParameters": {
    "values": [
      { "value": "={{ $json.workflow.name }}" },
      { "value": "50" },
      { "value": "5" },
      { "value": "15" }
    ]
  }
}
```

#### PASO 1.5.4: Testing de Concurrencia
```bash
# Script de test: Simular 100 errores simultáneos
# ARCHIVO NUEVO: tests/test_circuit_breaker.sh

#!/bin/bash
WORKFLOW="BB_TEST_CIRCUIT"

# Resetear estado
psql $DATABASE_URL -c "SELECT reset_circuit_breaker('$WORKFLOW');"

# Lanzar 100 errores concurrentes
for i in {1..100}; do
  (
    curl -X POST http://localhost:5678/webhook/bb00-error \
      -H "Content-Type: application/json" \
      -d "{
        \"workflow_name\": \"$WORKFLOW\",
        \"error_message\": \"Test error $i\",
        \"severity\": \"HIGH\"
      }" > /dev/null 2>&1 &
  )
done

wait

# Verificar estado final
psql $DATABASE_URL -c "
  SELECT 
    workflow_name, 
    is_open, 
    failure_count, 
    opened_at 
  FROM circuit_breaker_state 
  WHERE workflow_name = '$WORKFLOW';
"
# Esperado: is_open=true, failure_count=50 (no más)
```

#### PASO 1.5.5: Agregar Script de Monitoreo
```bash
# Script para admin: Monitorear circuit breakers
# ARCHIVO NUEVO: scripts/monitor_circuit_breakers.sh

#!/bin/bash
psql $DATABASE_URL -c "
SELECT 
    workflow_name,
    CASE 
        WHEN is_open THEN '🔴 OPEN'
        WHEN failure_count > max_failures * 0.8 THEN '🟡 WARNING'
        ELSE '🟢 CLOSED'
    END as status,
    failure_count || '/' || max_failures as failures,
    CASE 
        WHEN is_open THEN 
            'Reabre en: ' || EXTRACT(EPOCH FROM (opened_at + (cooldown_minutes || ' minutes')::INTERVAL - NOW())) || 's'
        ELSE 'OK'
    END as info,
    last_failure_at
FROM circuit_breaker_state
ORDER BY is_open DESC, failure_count DESC;
"
```

#### PASO 1.5.6: Validación
```bash
# Test 1: Verificar atomicidad
./tests/test_circuit_breaker.sh
# Debe mostrar: failure_count exactamente 50

# Test 2: Verificar auto-cierre
psql $DATABASE_URL -c "
  UPDATE circuit_breaker_state 
  SET opened_at = NOW() - INTERVAL '20 minutes' 
  WHERE workflow_name = 'BB_TEST_CIRCUIT';
"

# Simular un error más (debería resetear)
curl -X POST http://localhost:5678/webhook/bb00-error \
  -d '{"workflow_name":"BB_TEST_CIRCUIT","error_message":"Test"}'

psql $DATABASE_URL -c "
  SELECT is_open, failure_count 
  FROM circuit_breaker_state 
  WHERE workflow_name = 'BB_TEST_CIRCUIT';
"
# Esperado: is_open=false, failure_count=1 (reseteado)
```

---

### FIX 1.6: BB_04 - Rollback con Compensación
**Tiempo:** 6 horas  
**Riesgo:** Alto (afecta integridad de datos)  
**Dependencias:** Ninguna

#### PASO 1.6.1: Crear Tabla de Compensación
**ARCHIVO NUEVO:** `database/migrations/006_booking_compensation.sql`

```sql
-- ============================================
-- BOOKING COMPENSATION LOG
-- Registra eventos "zombie" que necesitan limpieza manual
-- ============================================

CREATE TABLE IF NOT EXISTS public.booking_compensation_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID, -- Puede ser NULL si no llegó a insertarse
    user_id UUID REFERENCES users(id),
    provider_id UUID REFERENCES providers(id),
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    gcal_event_id VARCHAR(255),
    compensation_type VARCHAR(50) CHECK (compensation_type IN ('gcal_orphan', 'db_orphan', 'both_failed')),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'failed')),
    error_context JSONB,
    resolution_notes TEXT,
    retry_count INTEGER DEFAULT 0,
    last_retry_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_compensation_status ON booking_compensation_log(status, created_at);
CREATE INDEX idx_compensation_gcal ON booking_compensation_log(gcal_event_id) WHERE gcal_event_id IS NOT NULL;

-- View para dashboard de compensaciones pendientes
CREATE OR REPLACE VIEW v_compensation_pending AS
SELECT 
    id,
    compensation_type,
    CONCAT(TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI'), ' - ', provider_id) as description,
    retry_count,
    EXTRACT(EPOCH FROM (NOW() - created_at))/3600 as hours_pending,
    created_at
FROM booking_compensation_log
WHERE status = 'pending'
ORDER BY created_at ASC;

COMMENT ON TABLE booking_compensation_log IS 
'Registro de inconsistencias DB↔GCal que requieren compensación manual o automática.';
```

#### PASO 1.6.2: Ejecutar Migration
```bash
psql $DATABASE_URL < database/migrations/006_booking_compensation.sql
```

#### PASO 1.6.3: Modificar BB_04 - Agregar Nodo de Compensación
**ARCHIVO:** `workflows/BB_04_Booking_Transaction.json`

**AGREGAR NODO NUEVO después del nodo `rollback` (cuando rollback falla):**

Nombre: `Log Compensation Needed`

```json
{
  "parameters": {
    "operation": "insert",
    "schema": "public",
    "table": "booking_compensation_log",
    "columns": {
      "mappingMode": "defineBelow",
      "value": {
        "user_id": "={{ $node['Guard'].json.user_id }}",
        "provider_id": "={{ $node['Guard'].json.provider_id }}",
        "start_time": "={{ $node['Guard'].json.start_time }}",
        "end_time": "={{ $node['Guard'].json.end_time }}",
        "gcal_event_id": "={{ $node['gcal'].json.id }}",
        "compensation_type": "gcal_orphan",
        "error_context": "={{ JSON.stringify({ rollback_error: $json.error, gcal_response: $node['gcal'].json, retry_attempts: 3 }) }}"
      }
    },
    "options": {}
  },
  "id": "log_compensation",
  "name": "Log Compensation Needed",
  "type": "n8n-nodes-base.postgres",
  "typeVersion": 2.4,
  "position": [1100, 500],
  "credentials": {
    "postgres": {
      "id": "99BnrzwZQDhYU6Ly",
      "name": "Postgres Booking"
    }
  },
  "continueOnFail": true
}
```

**MODIFICAR conexiones del nodo `rollback`:**
- Si rollback SUCCESS → Continuar flujo normal
- Si rollback FAIL → `Log Compensation Needed` → Notificar Admin

#### PASO 1.6.4: Crear Workflow de Compensación Automática
**ARCHIVO NUEVO:** `workflows/BB_10_Compensation_Worker.json`

```json
{
  "name": "BB_10_Compensation_Worker",
  "nodes": [
    {
      "parameters": {
        "rule": {
          "interval": [
            {
              "field": "hours",
              "hoursInterval": 1
            }
          ]
        }
      },
      "id": "cron_compensation",
      "name": "Cron Every Hour",
      "type": "n8n-nodes-base.cron",
      "typeVersion": 1,
      "position": [0, 0]
    },
    {
      "parameters": {
        "operation": "executeQuery",
        "query": "SELECT * FROM booking_compensation_log WHERE status = 'pending' AND retry_count < 5 ORDER BY created_at ASC LIMIT 20"
      },
      "id": "fetch_pending",
      "name": "Fetch Pending Compensations",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.4,
      "position": [200, 0]
    },
    {
      "parameters": {
        "jsCode": "const items = $input.all();\nif (items.length === 0) return [];\n\nreturn items.map(item => ({\n  json: {\n    ...item.json,\n    google_calendar_id: item.json.error_context?.gcal_calendar_id || 'primary'\n  }\n}));"
      },
      "id": "prep_retry",
      "name": "Prepare Retry",
      "type": "n8n-nodes-base.code",
      "typeVersion": 2,
      "position": [400, 0]
    },
    {
      "parameters": {
        "operation": "delete",
        "calendar": "={{ $json.google_calendar_id }}",
        "eventId": "={{ $json.gcal_event_id }}"
      },
      "id": "delete_gcal",
      "name": "Delete GCal Event",
      "type": "n8n-nodes-base.googleCalendar",
      "typeVersion": 1,
      "position": [600, 0],
      "continueOnFail": true,
      "retryOnFail": {
        "enabled": true,
        "maxRetries": 2,
        "waitBetweenRetries": 5000
      }
    },
    {
      "parameters": {
        "operation": "update",
        "schema": "public",
        "table": "booking_compensation_log",
        "columns": {
          "mappingMode": "defineBelow",
          "value": {
            "status": "={{ $json.error ? 'pending' : 'resolved' }}",
            "retry_count": "={{ $node['Prepare Retry'].json.retry_count + 1 }}",
            "last_retry_at": "={{ $now.toISO() }}",
            "resolved_at": "={{ $json.error ? null : $now.toISO() }}",
            "resolution_notes": "={{ $json.error ? 'Retry failed: ' + $json.error.message : 'Auto-resolved by BB_10' }}"
          }
        },
        "whereClause": {
          "values": [
            {
              "column": "id",
              "operator": "equal",
              "value": "={{ $node['Prepare Retry'].json.id }}"
            }
          ]
        }
      },
      "id": "update_status",
      "name": "Update Status",
      "type": "n8n-nodes-base.postgres",
      "typeVersion": 2.4,
      "position": [800, 0]
    }
  ],
  "connections": {
    "Cron Every Hour": {
      "main": [[{"node": "Fetch Pending Compensations"}]]
    },
    "Fetch Pending Compensations": {
      "main": [[{"node": "Prepare Retry"}]]
    },
    "Prepare Retry": {
      "main": [[{"node": "Delete GCal Event"}]]
    },
    "Delete GCal Event": {
      "main": [[{"node": "Update Status"}]]
    }
  },
  "settings": {
    "executionOrder": "v1"
  }
}
```

#### PASO 1.6.5: Testing
```bash
# Test 1: Simular rollback fallido
# Insertar compensación manualmente
psql $DATABASE_URL -c "
INSERT INTO booking_compensation_log (
  user_id, provider_id, start_time, end_time, gcal_event_id, compensation_type
) VALUES (
  (SELECT id FROM users LIMIT 1),
  (SELECT id FROM providers LIMIT 1),
  NOW() + INTERVAL '1 day',
  NOW() + INTERVAL '1 day' + INTERVAL '1 hour',
  'fake_event_id_12345',
  'gcal_orphan'
);
"

# Test 2: Ejecutar BB_10 manualmente
# (Importar workflow BB_10 primero)
curl -X POST http://localhost:5678/webhook-test/bb10-compensation

# Test 3: Verificar estado cambió
psql $DATABASE_URL -c "
SELECT status, retry_count, resolution_notes 
FROM booking_compensation_log 
ORDER BY created_at DESC LIMIT 5;
"
```

#### PASO 1.6.6: Dashboard de Monitoreo
```bash
# Script para admin
# ARCHIVO: scripts/check_compensations.sh

#!/bin/bash
echo "📊 COMPENSACIONES PENDIENTES:"
psql $DATABASE_URL -c "
SELECT 
    COUNT(*) FILTER (WHERE hours_pending < 1) as \"<1h\",
    COUNT(*) FILTER (WHERE hours_pending BETWEEN 1 AND 24) as \"1-24h\",
    COUNT(*) FILTER (WHERE hours_pending > 24) as \">24h (⚠️)\",
    COUNT(*) as total
FROM v_compensation_pending;
"

echo ""
echo "🔴 CASOS CRÍTICOS (>24h pendientes):"
psql $DATABASE_URL -c "
SELECT * FROM v_compensation_pending 
WHERE hours_pending > 24 
LIMIT 10;
"
```

---

### FIX 1.7: BB_05 - Eliminar Función Fantasma
**Tiempo:** 2 horas  
**Riesgo:** Bajo (simplificación)  
**Dependencias:** Ninguna

#### PASO 1.7.1: Modificar Query de BB_05
**ARCHIVO:** `workflows/BB_05_Notification_Engine.json`

**NODO:** `Fetch` (línea ~44)

**ANTES:**
```sql
WITH config_json AS (
    SELECT public.get_tenant_config_json('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') as data
),
config AS (
    SELECT 
        (data->>'reminder_1_hours')::int * INTERVAL '1 hour' as r1_delta,
        (data->>'reminder_2_hours')::int * INTERVAL '1 hour' as r2_delta,
        (data->>'is_active')::boolean as is_active,
        (data->>'TIMEZONE') as timezone
    FROM config_json
)
SELECT b.id as booking_id, u.telegram_id, u.first_name, b.start_time, p.name as pro_name, c.timezone,
    CASE 
        WHEN b.reminder_1_sent_at IS NULL AND b.start_time <= (NOW() + c.r1_delta) AND b.start_time > (NOW() + c.r2_delta) THEN 'r1'
        WHEN b.reminder_2_sent_at IS NULL AND b.start_time <= (NOW() + c.r2_delta) THEN 'r2'
    END as r_type
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN professionals p ON b.professional_id = p.id
CROSS JOIN config c
WHERE c.is_active = TRUE 
  AND b.status = 'confirmed' 
  AND b.start_time > NOW()
  AND ((b.reminder_1_sent_at IS NULL AND b.start_time <= (NOW() + c.r1_delta))
       OR (b.reminder_2_sent_at IS NULL AND b.start_time <= (NOW() + c.r2_delta)))
LIMIT 50;
```

**DESPUÉS:**
```sql
WITH config AS (
    SELECT 
        COALESCE((SELECT value::int FROM app_config WHERE key = 'REMINDER_1_HOURS'), 24) as r1_hours,
        COALESCE((SELECT value::int FROM app_config WHERE key = 'REMINDER_2_HOURS'), 2) as r2_hours,
        COALESCE((SELECT value::boolean FROM app_config WHERE key = 'NOTIFICATIONS_ENABLED'), true) as is_active,
        COALESCE((SELECT value FROM app_config WHERE key = 'TIMEZONE'), 'America/Santiago') as timezone
)
SELECT 
    b.id as booking_id, 
    u.telegram_id, 
    u.first_name, 
    b.start_time, 
    p.name as pro_name, 
    c.timezone,
    CASE 
        WHEN b.reminder_1_sent_at IS NULL 
             AND b.start_time <= (NOW() + (c.r1_hours || ' hours')::INTERVAL)
             AND b.start_time > (NOW() + (c.r2_hours || ' hours')::INTERVAL) 
        THEN 'r1'
        WHEN b.reminder_2_sent_at IS NULL 
             AND b.start_time <= (NOW() + (c.r2_hours || ' hours')::INTERVAL) 
        THEN 'r2'
    END as r_type
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN providers p ON b.provider_id = p.id
CROSS JOIN config c
WHERE c.is_active = TRUE 
  AND b.status = 'confirmed' 
  AND b.start_time > NOW()
  AND (
      (b.reminder_1_sent_at IS NULL AND b.start_time <= (NOW() + (c.r1_hours || ' hours')::INTERVAL))
      OR (b.reminder_2_sent_at IS NULL AND b.start_time <= (NOW() + (c.r2_hours || ' hours')::INTERVAL))
  )
ORDER BY b.start_time ASC
LIMIT 50;
```

#### PASO 1.7.2: Agregar Valores de Config a DB
```bash
psql $DATABASE_URL -c "
INSERT INTO app_config (key, value, category, description)
VALUES 
  ('REMINDER_1_HOURS', '24', 'notifications', 'Horas antes para primer recordatorio'),
  ('REMINDER_2_HOURS', '2', 'notifications', 'Horas antes para segundo recordatorio'),
  ('NOTIFICATIONS_ENABLED', 'true', 'notifications', 'Sistema de notificaciones activo')
ON CONFLICT (key) DO NOTHING;
"
```

#### PASO 1.7.3: Testing
```bash
# Test 1: Verificar query ejecuta sin error
curl -X POST http://localhost:5678/webhook/notify-batch

# Test 2: Verificar config se lee correctamente
psql $DATABASE_URL -c "
WITH config AS (
    SELECT 
        COALESCE((SELECT value::int FROM app_config WHERE key = 'REMINDER_1_HOURS'), 24) as r1_hours,
        COALESCE((SELECT value::int FROM app_config WHERE key = 'REMINDER_2_HOURS'), 2) as r2_hours
)
SELECT * FROM config;
"
# Esperado: r1_hours=24, r2_hours=2
```

---

### FIX 1.8: BB_08 - Eliminar Secret Hardcodeado
**Tiempo:** 1 hora  
**Riesgo:** Bajo (ya cubierto en FIX 1.1)  
**Dependencias:** FIX 1.1 completado

#### PASO 1.8.1: Verificar FIX 1.1 Implementado
```bash
# Verificar que JWT_SECRET existe en env
docker exec n8n_container env | grep JWT_SECRET
# Debe mostrar: JWT_SECRET=<valor>

# Verificar que workflow usa librería
grep -A 10 "require('jsonwebtoken')" workflows/BB_08_JWT_Auth_Helper.json
# Debe existir la línea
```

#### PASO 1.8.2: Agregar Validación de Startup
**ARCHIVO NUEVO:** `scripts/validate_env.sh`

```bash
#!/bin/bash
# Script de validación de variables de entorno críticas

REQUIRED_VARS=(
  "JWT_SECRET"
  "DATABASE_URL"
  "TELEGRAM_BOT_TOKEN"
  "GOOGLE_CLIENT_ID"
  "GOOGLE_CLIENT_SECRET"
)

MISSING=()

for VAR in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!VAR}" ]; then
    MISSING+=("$VAR")
  fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ ERROR: Faltan variables de entorno críticas:"
  printf '  - %s\n' "${MISSING[@]}"
  echo ""
  echo "🔧 Solución: Agregar a .env o docker-compose.yml"
  exit 1
else
  echo "✅ Todas las variables de entorno críticas están configuradas"
  exit 0
fi
```

#### PASO 1.8.3: Integrar en Docker Compose
**ARCHIVO:** `docker-compose.yml`

Agregar healthcheck:
```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    environment:
      - JWT_SECRET=${JWT_SECRET:?JWT_SECRET is required}
      - DATABASE_URL=${DATABASE_URL}
      # ... otros env vars
    healthcheck:
      test: ["CMD", "/bin/sh", "-c", "test -n \"$JWT_SECRET\""]
      interval: 30s
      timeout: 10s
      retries: 3
```

#### PASO 1.8.4: Documentar en README
**ARCHIVO:** `README.md`

Agregar sección:
```markdown
## 🔐 Variables de Entorno Requeridas

**CRÍTICAS** (sistema no inicia sin ellas):
- `JWT_SECRET`: Secret para firma de tokens (min 32 caracteres hex)
- `DATABASE_URL`: Conexión a PostgreSQL
- `TELEGRAM_BOT_TOKEN`: Token del bot de Telegram

**Generación de JWT_SECRET:**
```bash
openssl rand -hex 32
```

**NO** usar valores por defecto en producción.
```

---

## 🟡 FASE 2: FIXES ALTOS (P1) - SEMANA 2

### FIX 2.1: BB_00 - Mejorar Regex de RUT
**Tiempo:** 1 hora  
**Riesgo:** Bajo

```javascript
// ANTES
if (/^\d{1,2}\.?\d{3}\.?\d{3}[-]?[0-9kK]$/.test(val)) {

// DESPUÉS
const rutClean = val.replace(/\./g, '').replace(/\s/g, '');
if (/^\d{7,8}[-]?[0-9kK]$/.test(rutClean)) {
  redactedCount++;
  return '**.***.' + val.slice(-4);
}
```

---

### FIX 2.2: BB_00 - Email Fallback con Log
**Tiempo:** 2 horas  
**Riesgo:** Bajo

Agregar nodo después de `Send Email Fallback`:
```json
{
  "name": "Log Email Result",
  "type": "n8n-nodes-base.postgres",
  "parameters": {
    "operation": "insert",
    "table": "system_errors",
    "columns": {
      "workflow_name": "BB_00_Email_Fallback",
      "error_message": "={{ $json.error ? 'Email failed: ' + $json.error.message : 'Email sent successfully' }}",
      "severity": "={{ $json.error ? 'CRITICAL' : 'LOW' }}"
    }
  }
}
```

---

### FIX 2.3: BB_02 - UPDATE Atómico para Strikes
**Tiempo:** 3 horas  
**Riesgo:** Medio

```sql
-- Reemplazar lógica de strikes con UPDATE atómico
UPDATE security_firewall
SET 
  strike_count = CASE 
    WHEN strike_count + 1 >= 3 THEN 3
    ELSE strike_count + 1
  END,
  is_blocked = CASE 
    WHEN strike_count + 1 >= 3 THEN TRUE
    ELSE FALSE
  END,
  blocked_until = CASE 
    WHEN strike_count + 1 >= 3 THEN NOW() + INTERVAL '7 days'
    ELSE blocked_until
  END,
  updated_at = NOW()
WHERE entity_id = $1
RETURNING strike_count, is_blocked, blocked_until;
```

---

### FIX 2.4: BB_03 - Validar end_time NOT NULL
**Tiempo:** 1 hora  
**Riesgo:** Bajo

```sql
-- En BB_03_02_ProviderData
SELECT ... FROM schedules s
WHERE s.provider_id = $1
  AND s.is_active = true
  AND s.end_time IS NOT NULL  -- ✅ AGREGAR
```

---

### FIX 2.5: BB_03 - Validar Service Duration Múltiplos
**Tiempo:** 2 horas  
**Riesgo:** Bajo

```javascript
// En BB_03_02_ProviderData, nodo Process
if (serviceDuration && serviceDuration % slotDuration !== 0) {
  return [{
    json: {
      success: false,
      error_code: 'INVALID_SERVICE_DURATION',
      error_message: `Service duration (${serviceDuration}min) must be multiple of slot duration (${slotDuration}min)`,
      data: null
    }
  }];
}
```

---

### FIX 2.6: BB_04 - Validar Duration Match
**Tiempo:** 2 horas  
**Riesgo:** Medio

```javascript
// Agregar en nodo Guard
const startMs = new Date(start_time).getTime();
const endMs = new Date(end_time).getTime();
const actualDurationMin = (endMs - startMs) / 60000;

if (Math.abs(actualDurationMin - duration) > 1) {
  return [{
    json: {
      error: true,
      error_code: 'DURATION_MISMATCH',
      error_message: `Declared duration (${duration}min) doesn't match time range (${actualDurationMin}min)`
    }
  }];
}
```

---

### FIX 2.7: BB_04 - Validar GCal event_id
**Tiempo:** 1 hora  
**Riesgo:** Bajo

```javascript
// Agregar nodo después de gcal
if (!$json.id || $json.id === '') {
  throw new Error('Google Calendar did not return event ID');
}
return [{ json: $json }];
```

---

### FIX 2.8: BB_05 - UPDATE con RETURNING
**Tiempo:** 2 horas  
**Riesgo:** Bajo

```sql
-- Reemplazar nodos Mark R1/R2
UPDATE bookings 
SET reminder_1_sent_at = NOW() 
WHERE id = $1 
RETURNING id, reminder_1_sent_at;
```

Agregar validación:
```javascript
if (!$json.id) {  throw new Error('UPDATE did not return ID - reminder may not have been marked');
}
```

---

### FIX 2.9 a 2.12: Resumen Rápido
**Tiempo total:** 8 horas  

**2.9 - BB_06: Validar JWT en todos los endpoints** (2h)
- Agregar nodo "Call BB_08" antes de cada operación sensible
- Validar respuesta `authenticated: true`

**2.10 - BB_08: Validar iat futuro** (1h)
- Ya incluido en FIX 1.1

**2.11 - BB_01: Validar formato de slug** (2h)
```javascript
if (!/^[a-z0-9-]{3,50}$/.test(slug)) {
  return [{ json: { error: true, message: 'Invalid slug format' } }];
}
```

**2.12 - BB_03: Validar date_range < booking_window** (3h)
```javascript
const daysRange = Math.min(
  scheduleData.days_range || windowDays, 
  windowDays
);

if (daysRange > windowDays) {
  return [{
    json: {
      success: false,
      error_code: 'DATE_RANGE_EXCEEDED',
      error_message: `Cannot query more than ${windowDays} days ahead`,
      data: null
    }
  }];
}
```

---

## 🔵 FASE 3: FIXES MEDIOS (P2) - MES 2

### FIX 3.1: Implementar Cache con Redis
**Tiempo:** 16 horas  
**Dependencias:** Redis instalado

#### PASO 3.1.1: Instalar Redis
```bash
# Docker Compose
cat >> docker-compose.yml << 'EOF'
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes

volumes:
  redis_data:
EOF

docker-compose up -d redis
```

#### PASO 3.1.2: Modificar BB_03 para usar Cache
```javascript
// Nuevo nodo al inicio de BB_03_00_Main
const redis = require('redis');
const client = redis.createClient({ url: process.env.REDIS_URL });

const cacheKey = `slots:${$json.provider_id}:${$json.target_date}`;
const cached = await client.get(cacheKey);

if (cached) {
  return [{ json: JSON.parse(cached) }];
}

// ... lógica normal ...

// Al final, guardar en cache (TTL 60s)
await client.setEx(cacheKey, 60, JSON.stringify(result));
```

---

### FIX 3.2: Agregar Métricas (Prometheus)
**Tiempo:** 12 horas  

```javascript
// ARCHIVO NUEVO: scripts/metrics_exporter.js
const express = require('express');
const client = require('prom-client');

const register = new client.Registry();

const errorCounter = new client.Counter({
  name: 'bb_errors_total',
  help: 'Total errors by workflow and severity',
  labelNames: ['workflow', 'severity'],
  registers: [register]
});

// Endpoint /metrics
app.get('/metrics', async (req, res) => {
  const metrics = await register.metrics();
  res.set('Content-Type', register.contentType);
  res.end(metrics);
});
```

---

### FIX 3.3: Rate Limiting en Endpoints
**Tiempo:** 8 horas  

```javascript
// Middleware para BB_06
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 60 * 1000, // 1 minuto
  max: 30, // 30 requests
  message: { error: true, code: 'RATE_LIMIT_EXCEEDED' }
});

// Aplicar a webhooks de BB_06
```

---

### FIX 3.4 a 3.15: Resumen Ejecutivo

| Fix | Descripción | Tiempo | Prioridad |
|-----|-------------|--------|-----------|
| 3.4 | CORS headers en BB_06 | 2h | P2 |
| 3.5 | Paginación en API | 4h | P2 |
| 3.6 | Backoff exponencial configurable | 2h | P2 |
| 3.7 | Error messages menos verbosos | 2h | P2 |
| 3.8 | Audit log de redirects BB_09 | 3h | P2 |
| 3.9 | Health checks para todos los WFs | 6h | P2 |
| 3.10 | Encrypt secrets en JSON | 8h | P2 |
| 3.11 | Multi-timezone support | 10h | P3 |
| 3.12 | Pre-cálculo de slots | 12h | P3 |
| 3.13 | Idempotencia con request_id | 6h | P3 |
| 3.14 | Confirmación de lectura Telegram | 4h | P3 |
| 3.15 | Auto-unban después de N días | 4h | P2 |

---

## 📊 CRONOGRAMA GENERAL

### Semana 1: Preparación + P0 Críticos (1-5)
```
Día 1 (Lunes):
- ✅ FASE 0: Backups y comunicación (2h)
- ✅ FIX 1.1: BB_08 JWT (4h)
- ✅ FIX 1.2: BB_04 SERIALIZABLE (Inicio, 2h)

Día 2 (Martes):
- ✅ FIX 1.2: BB_04 SERIALIZABLE (Completar + Testing, 4h)
- ✅ FIX 1.3: BB_02 Parametrizar (2h)

Día 3 (Miércoles):
- ✅ FIX 1.4: notification_queue (4h)
- ✅ FIX 1.7: BB_05 Función fantasma (2h)

Día 4 (Jueves):
- ✅ FIX 1.5: Circuit Breaker atómico (8h)

Día 5 (Viernes):
- ✅ FIX 1.6: Compensación (4h)
- ✅ FIX 1.8: Validación env (1h)
- ✅ Testing integral de P0 (3h)
```

### Semana 2: P1 Altos (2.1-2.12)
```
Total: 25 horas de desarrollo
Distribución: 5h/día durante 5 días
```

### Semanas 3-4: P2 Medios (3.1-3.15)
```
Total: 63 horas de desarrollo
Distribución selectiva según prioridad de negocio
```

---

## ✅ CHECKLIST POST-DEPLOYMENT

### Validación Técnica
- [ ] Todos los tests de P0 pasan (8/8)
- [ ] Zero SQL injections detectadas (security scan)
- [ ] Zero race conditions en test de concurrencia (100 users)
- [ ] JWT verification funciona correctamente
- [ ] Circuit breaker se abre y cierra automáticamente
- [ ] notification_queue se procesa correctamente
- [ ] Compensaciones se resuelven automáticamente

### Validación de Negocio
- [ ] Double booking: 0 casos en 7 días
- [ ] Notificaciones: >95% tasa de envío
- [ ] Latencia de booking: <500ms p95
- [ ] Uptime: >99.9% durante 7 días
- [ ] Eventos zombie en GCal: 0 nuevos casos

### Documentación
- [ ] README actualizado con nuevas env vars
- [ ] CHANGELOG.md con todos los fixes
- [ ] Scripts de monitoreo documentados
- [ ] Runbook de emergencia actualizado

### Monitoreo
- [ ] Alertas configuradas para:
  - Circuit breakers abiertos
  - Compensaciones pendientes >24h
  - Tasa de errores >1% 
  - notification_queue con >100 pending
- [ ] Dashboard de métricas activo
- [ ] Logs centralizados funcionando

---

## 🚨 ROLLBACK PLAN

### Trigger de Rollback
Ejecutar si:
- Tasa de errores >5% durante 10 minutos
- >10 double bookings en 1 hora
- Circuit breaker de workflow crítico abierto >30min
- Database deadlocks >10/min

### Procedimiento
```bash
# 1. STOP n8n
docker-compose stop n8n

# 2. Restore workflows
cd workflows/backup_$(date +%Y%m%d)/
for file in *.json; do
  curl -X POST http://localhost:5678/api/v1/workflows/import \
    -H "X-N8N-API-KEY: $N8N_API_KEY" \
    -F "file=@$file"
done

# 3. Rollback DB migrations (si es necesario)
psql $DATABASE_URL < database/rollback_migrations.sql

# 4. Restart n8n
docker-compose up -d n8n

# 5. Verificar funcionalidad básica
./scripts/smoke_test.sh
```

---

## 📞 CONTACTOS DE EMERGENCIA

**Durante Deployment:**
- Lead Developer: [NOMBRE] - [TELÉFONO]
- DBA: [NOMBRE] - [TELÉFONO]
- DevOps: [NOMBRE] - [TELÉFONO]

**Post-Deployment (On-Call):**
- Semana 1: [NOMBRE] - [TELÉFONO]
- Semana 2: [NOMBRE] - [TELÉFONO]

---

## 📈 MÉTRICAS DE ÉXITO

### KPIs Técnicos
| Métrica | Actual | Objetivo Post-Fix | Medición |
|---------|--------|-------------------|----------|
| Double bookings | 2-3/semana | 0/mes | DB query |
| Race conditions | Frecuentes | 0 detectadas | Load test |
| SQL injections | Vulnerables | 0 vulnerabilidades | Security scan |
| JWT bypass | Posible | Imposible | Penetration test |
| Notificaciones fallidas | ~30% | <5% | notification_queue stats |
| Latencia p95 booking | ~800ms | <500ms | APM |
| Circuit breaker efectivo | No | Sí | Stress test |

### KPIs de Negocio
| Métrica | Actual | Objetivo | Medición |
|---------|--------|----------|----------|
| Uptime | ~97% | >99.9% | Monitoring |
| No-show rate | ~25% | <15% | Analytics |
| User satisfaction | N/A | >4.5/5 | Survey |
| Admin manual interventions | ~10/día | <1/semana | Support tickets |

---

## 🎓 LECCIONES APRENDIDAS

### Para Futuros Proyectos
1. **Implementar tests desde día 1**: Coverage actual ~15% es inaceptable
2. **Code review obligatorio**: SQL injection pasó desapercibido
3. **Security audit antes de MVP**: JWT sin verificación es red flag 🚩
4. **DB migrations versionadas**: Funciones fantasma indican falta de control
5. **Monitoring desde el inicio**: Circuit breaker roto sin detección

### Deuda Técnica Restante (Post-Fixes)
- Tests automatizados (E2E, integration, unit)
- CI/CD pipeline
- Staging environment
- Load testing regular
- Security scanning automático
- Documentation completa de APIs

---

## 📚 RECURSOS ADICIONALES

### Scripts Útiles
- `scripts/validate_env.sh` - Validar env vars al inicio
- `scripts/monitor_circuit_breakers.sh` - Estado de CBs
- `scripts/check_compensations.sh` - Compensaciones pendientes
- `tests/test_concurrent_booking.sh` - Test de race conditions
- `tests/test_circuit_breaker.sh` - Test de CB

### Queries de Monitoreo
```sql
-- Double bookings
SELECT provider_id, start_time, COUNT(*) 
FROM bookings 
WHERE status='confirmed' AND deleted_at IS NULL
GROUP BY provider_id, start_time 
HAVING COUNT(*) > 1;

-- Compensaciones críticas
SELECT * FROM v_compensation_pending 
WHERE hours_pending > 24;

-- Circuit breakers abiertos
SELECT * FROM circuit_breaker_state 
WHERE is_open = TRUE;

-- Notificaciones atascadas
SELECT COUNT(*) 
FROM notification_queue 
WHERE status='pending' AND retry_count >= max_retries;
```

---

## ✨ CONCLUSIÓN

Este plan de acción cubre **8 bugs críticos (P0)**, **12 bugs altos (P1)** y **15 mejoras medias (P2/P3)**.

**Esfuerzo total estimado:**
- P0: ~35 horas (1 semana)
- P1: ~25 horas (1 semana)
- P2/P3: ~63 horas (2 semanas)
- **TOTAL: ~120 horas** (~3-4 semanas con 1 developer full-time)

**Recomendación Final:**
1. ⛔ **NO deployar a producción** hasta completar al menos P0
2. 🔥 **Priorizar FIX 1.1, 1.2, 1.3** (seguridad + double booking)
3. 📊 **Implementar monitoring** en paralelo a los fixes
4. 🧪 **Testing exhaustivo** antes de cada deployment
5. 📖 **Documentar TODO** para futuros maintainers

---

**Documento generado por:** Sistema de Análisis Automatizado  
**Fecha:** 2024-01-15  
**Versión:** 1.0  
**Próxima revisión:** Post-deployment P0 (Día 6)
