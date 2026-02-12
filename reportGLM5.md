# Reporte de Análisis Independiente - AutoAgenda (Basic Booking)

**Fecha:** 2026-02-11  
**Analista:** Revisión basada en GEMINI.md  
**Alcance:** Workflows BB_00 a BB_09, database/schema.sql  

---

## Resumen Ejecutivo

Este análisis independiente del proyecto AutoAgenda ha identificado **2 issues CRÍTICOS**, **4 issues de ALTA severidad**, **3 issues de severidad MEDIA** y **2 issues de BAJA severidad**. El proyecto presenta una arquitectura sólida basada en n8n v2.4.6 con patrones de diseño bien implementados (Saga, Circuit Breaker, Paranoid Guards), pero contiene errores de configuración y seguridad que deben abordarse antes de producción.

---

## Issues Encontrados

| Severidad | Archivo:Línea | Issue |
|-----------|---------------|-------|
| **CRITICAL** | database/schema.sql:408 | JWT Secret hardcodeado en función `create_admin_jwt()` |
| **CRITICAL** | workflows/BB_09_Deep_Link_Redirect.json:2 | Archivo es copia idéntica de BB_08 (error de copy-paste) |
| **HIGH** | workflows/BB_06_Admin_Dashboard.json:145 | JWT Secret hardcodeado como fallback en código |
| **HIGH** | workflows/BB_08_JWT_Auth_Helper.json:30 | JWT Secret hardcodeado como fallback en código |
| **HIGH** | workflows/BB_06_Admin_Dashboard.json:394 | SQL no parametrizado (inyección SQL potencial) |
| **HIGH** | workflows/BB_01_Telegram_Gateway.json | Referencia a workflow obsoleto `BB_03_Availability_Engine` |
| **MEDIUM** | workflows/BB_03_01_InputValidation.json:13 | Webhook v2 (debería ser v1 según SOT) |
| **MEDIUM** | workflows/BB_07_Notification_Retry_Worker.json:77 | Credential ID placeholder sin reemplazar |
| **MEDIUM** | Múltiples workflows | Falta configuración `errorWorkflow` |
| **LOW** | workflows/BB_05_Notification_Engine.json | Posible confusión `professional_id` vs `provider_id` |
| **LOW** | workflows/BB_03_00_Main.json | Placeholders de IDs de sub-workflows no resueltos |

---

## Hallazgos Detallados

### 1. CRITICAL: JWT Secret Hardcodeado en Base de Datos

**Archivo:** [`database/schema.sql:408`](database/schema.sql:408)  
**Confianza:** 99%

**Problema:**
La función `create_admin_jwt()` contiene el secreto JWT hardcodeado:

```sql
CREATE FUNCTION public.create_admin_jwt(p_user_id uuid, p_hours integer) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
    v_payload json;
    -- NOTE: Secret must match N8N env
    v_secret text := 'AutoAgenda_Secret_Key_2026_Secure'; 
BEGIN
    ...
END;
$$;
```

**Por qué importa:**
- El secreto está expuesto en el control de versiones
- Cualquiera con acceso al schema puede generar tokens JWT válidos
- Vulnerabilidad de seguridad crítica que permite suplantación de identidad

**Sugerencia:**
```sql
-- Usar variable de entorno o tabla de configuración segura
v_secret text := current_setting('app.jwt_secret');
```

---

### 2. CRITICAL: BB_09 es Duplicado de BB_08

**Archivo:** [`workflows/BB_09_Deep_Link_Redirect.json:2`](workflows/BB_09_Deep_Link_Redirect.json:2)  
**Confianza:** 100%

**Problema:**
El archivo `BB_09_Deep_Link_Redirect.json` es idéntico a `BB_08_JWT_Auth_Helper.json`. El nombre interno del workflow aún muestra:

```json
{
  "name": "BB_08_JWT_Auth_Helper",
  "nodes": [...]
}
```

**Por qué importa:**
- El workflow BB_09 no existe funcionalmente
- Las funcionalidades de Deep Link Redirect no están implementadas
- Cualquier llamada a BB_09 ejecutará lógica de JWT Auth en su lugar

**Sugerencia:**
Crear el workflow BB_09 con la lógica correcta para deep links de Telegram, incluyendo:
- Redirección a `tg://resolve?domain=BOT_USERNAME`
- Manejo de parámetros de inicio
- Logging de acceso

---

### 3. HIGH: JWT Secret Hardcodeado en Workflows

**Archivos:** 
- [`workflows/BB_06_Admin_Dashboard.json:145`](workflows/BB_06_Admin_Dashboard.json:145)
- [`workflows/BB_08_JWT_Auth_Helper.json:30`](workflows/BB_08_JWT_Auth_Helper.json:30)

**Confianza:** 95%

**Problema:**
Ambos workflows contienen fallback hardcodeado:

```javascript
// BB_06
const secret = process.env.JWT_SECRET || 'AutoAgenda_Secret_Key_2026_Secure';

// BB_08
const secret = $env.JWT_SECRET || 'AutoAgenda_Secret_Key_2026_Secure';
```

**Por qué importa:**
- Si `JWT_SECRET` no está configurado, se usa el secreto hardcodeado
- El mismo secreto está en el código fuente (control de versiones)
- Inconsistencia de seguridad entre entornos

**Sugerencia:**
```javascript
const secret = $env.JWT_SECRET;
if (!secret) {
    throw new Error('JWT_SECRET environment variable is required');
}
```

---

### 4. HIGH: SQL No Parametrizado en BB_06

**Archivo:** [`workflows/BB_06_Admin_Dashboard.json:394`](workflows/BB_06_Admin_Dashboard.json:394)  
**Confianza:** 90%

**Problema:**
La consulta SQL usa interpolación de strings en lugar de parámetros:

```sql
SELECT b.id, b.start_time, b.end_time, b.status, u.first_name, u.last_name, p.name as pro_name
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN professionals p ON b.professional_id = p.id
WHERE b.status != 'cancelled'
AND b.start_time >= '{{ $json.query.start || '2026-01-01' }}'::timestamp
AND b.end_time <= '{{ $json.query.end || '2026-12-31' }}'::timestamp;
```

**Por qué importa:**
- Potencial inyección SQL si los parámetros no son validados
- Viola el estándar SOT-N8N-2.4.6 que requiere SQL parametrizado
- El nodo Postgres v2.4 soporta `queryParameters`

**Sugerencia:**
```sql
-- Usar parámetros con $1, $2
WHERE b.start_time >= $1::timestamp AND b.end_time <= $2::timestamp
```

---

### 5. HIGH: Referencia a Workflow Obsoleto

**Archivo:** [`workflows/BB_01_Telegram_Gateway.json`](workflows/BB_01_Telegram_Gateway.json)  
**Confianza:** 85%

**Problema:**
BB_01 referencia `BB_03_Availability_Engine` que ha sido movido a `workflows/obsolete/`:

```json
// En app_config
"WF_ID_AVAILABILITY_ENGINE": "BB_03_Availability_Engine"
```

**Por qué importa:**
- El workflow obsoleto no debería estar en uso
- La arquitectura actual usa BB_03_00_Main como orquestador
- Posible comportamiento inesperado si el workflow obsoleto se elimina

**Sugerencia:**
Actualizar la referencia para usar el nuevo orquestador BB_03_00_Main.

---

### 6. MEDIUM: Inconsistencia de Versión de Webhook

**Archivo:** [`workflows/BB_03_01_InputValidation.json:13`](workflows/BB_03_01_InputValidation.json:13)  
**Confianza:** 80%

**Problema:**
El nodo Webhook usa `typeVersion: 2`:

```json
{
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 2
}
```

**Por qué importa:**
- Según SOT-N8N-2.4.6, Webhook v1 es la versión estable recomendada
- Inconsistencia con otros workflows que usan v1

**Sugerencia:**
Estandarizar todos los webhooks a v1 según el estándar SOT.

---

### 7. MEDIUM: Placeholder de Credenciales

**Archivo:** [`workflows/BB_07_Notification_Retry_Worker.json:77`](workflows/BB_07_Notification_Retry_Worker.json:77)  
**Confianza:** 85%

**Problema:**
El credential ID de Telegram es un placeholder:

```json
"credentials": {
    "telegramApi": {
        "id": "PLACEHOLDER",
        "name": "Telegram Bot AutoAgenda"
    }
}
```

**Por qué importa:**
- El workflow fallará al ejecutarse
- Indica configuración incompleta

**Sugerencia:**
Reemplazar con el ID de credencial real de n8n.

---

### 8. MEDIUM: Falta errorWorkflow

**Archivos:** BB_01, BB_02, BB_04, BB_05, BB_06, BB_07, BB_08  
**Confianza:** 75%

**Problema:**
La mayoría de workflows no tienen configurado `errorWorkflow`:

```json
"settings": {
    "executionOrder": "v1"
    // Falta: "errorWorkflow": "BB_00_Global_Error_Handler"
}
```

**Por qué importa:**
- Errores no capturados por BB_00_Global_Error_Handler
- Pérdida de trazabilidad y notificaciones de error

**Sugerencia:**
Agregar en settings:
```json
"settings": {
    "executionOrder": "v1",
    "errorWorkflow": "ID_DE_BB_00"
}
```

---

### 9. LOW: Confusión de Nombres de Columna

**Archivo:** [`workflows/BB_05_Notification_Engine.json`](workflows/BB_05_Notification_Engine.json)  
**Confianza:** 70%

**Problema:**
La consulta usa `professional_id` pero la tabla `bookings` tiene `provider_id`:

```sql
JOIN professionals p ON b.professional_id = p.id
```

**Por qué importa:**
- Posible error si la tabla no tiene la columna `professional_id`
- La tabla `bookings` usa `provider_id` según schema.sql

**Nota:** Requiere verificación - puede que exista una vista o la columna fue renombrada.

---

### 10. LOW: Placeholders de Sub-workflows

**Archivo:** [`workflows/BB_03_00_Main.json`](workflows/BB_03_00_Main.json)  
**Confianza:** 75%

**Problema:**
Los IDs de sub-workflows son placeholders:

```javascript
const subWorkflows = {
    inputValidation: 'BB_03_01_InputValidation_ID',
    providerData: 'BB_03_02_ProviderData_ID',
    // ...
};
```

**Por qué importa:**
- Los sub-workflows no se ejecutarán correctamente
- Requiere configuración manual post-importación

---

## Análisis de Base de Datos

### Tablas Principales (15+)

| Tabla | Propósito | Estado |
|-------|-----------|--------|
| `users` | Usuarios globales (clientes/admins) | ✅ OK |
| `providers` | Profesionales/servicios | ✅ OK |
| `bookings` | Reservas | ✅ OK |
| `services` | Servicios ofrecidos | ✅ OK |
| `schedules` | Horarios semanales | ✅ OK |
| `app_config` | Configuración key-value | ✅ OK |
| `notification_queue` | Cola de notificaciones | ✅ OK |
| `security_firewall` | Control de strikes/bloqueos | ✅ OK |
| `audit_logs` | Trazabilidad | ✅ OK |
| `system_errors` | Log de errores | ✅ OK |
| `circuit_breaker_state` | Estado de circuit breaker | ✅ OK |
| `admin_users` | Usuarios admin para dashboard | ✅ OK |
| `admin_sessions` | Sesiones admin | ✅ OK |
| `app_messages` | i18n mensajes | ✅ OK |
| `notification_configs` | Config de notificaciones | ✅ OK |

### Funciones Destacadas

- `acquire_booking_lock()` - Bloqueo advisory para prevenir double-booking
- `check_booking_overlap_with_lock()` - Validación con bloqueo
- `verify_admin_credentials()` - Autenticación de admin
- `queue_notification()` - Encolado con deduplicación

### Problema de Seguridad en Función

La función `create_admin_jwt()` tiene el secreto hardcodeado (ver Issue #1).

---

## Verificación de Versiones de Nodos

| Nodo | Versión Requerida (SOT) | Estado |
|------|------------------------|--------|
| Postgres | v2.4 | ✅ Mayoría OK, algunos SQL no parametrizados |
| Switch | v3 | ✅ OK |
| Code | v2 | ✅ OK |
| Webhook | v1 | ⚠️ Algunos usan v2 |
| Cron | v1 | ✅ OK |
| Telegram | v1.2 | ✅ OK |

---

## Recomendaciones

### Inmediatas (CRÍTICAS)

1. **Eliminar secreto JWT hardcodeado** de `database/schema.sql`
   - Mover a variable de entorno `JWT_SECRET`
   - Actualizar función `create_admin_jwt()` para leer de configuración

2. **Recrear BB_09_Deep_Link_Redirect** 
   - El archivo actual es una copia errónea de BB_08
   - Implementar lógica de deep link para Telegram

### Corto Plazo (ALTA)

3. **Remover fallbacks de JWT Secret** en BB_06 y BB_08
   - Forzar error si la variable de entorno no existe

4. **Parametrizar consultas SQL** en BB_06
   - Usar `queryParameters` del nodo Postgres v2.4

5. **Actualizar referencia a workflow obsoleto** en BB_01
   - Usar BB_03_00_Main como orquestador

### Medio Plazo (MEDIA)

6. **Estandarizar versión de Webhook** a v1 en todos los workflows

7. **Configurar errorWorkflow** en todos los workflows que faltan

8. **Reemplazar placeholders** de credential IDs

---

## Conclusión

El proyecto AutoAgenda presenta una **arquitectura robusta** con patrones de diseño bien implementados:

- ✅ **Saga Pattern** en BB_04 para transacciones ACID
- ✅ **Circuit Breaker** para resiliencia
- ✅ **Paranoid Guards** para validación estricta
- ✅ **PII Redaction** con 40+ patrones
- ✅ **Advisory Locks** para prevenir double-booking

Sin embargo, los **issues de seguridad críticos** (JWT hardcodeado) y el **error de copy-paste** en BB_09 deben resolverse antes de considerar el proyecto listo para producción.

### Recomendación Final

**NEEDS CHANGES** - Se requieren cambios antes de aprobar para producción.

---

*Reporte generado el 2026-02-11 basado en análisis de GEMINI.md y archivos del proyecto.*
