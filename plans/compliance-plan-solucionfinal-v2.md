# Plan de Implementación de Políticas - SolucionFinal v2.0

# ESTRATEGIA: BOTTOM-UP VALIDATION

**Fecha:** 15 de Febrero, 2026  
**Alcance:** 22 workflows BB_*  
**Referencia:** docs/SolucionFinal-v2.md, docs/SOT-N8N-2.8.0.md  
**Versión:** 2.1 - Bottom-Up Strategy

---

## Resumen Ejecutivo

| Política | Cumplimiento Actual | Estado |
|----------|---------------------|--------|
| Contrato Estándar Output | 0/19 workflows | ❌ CRÍTICO |
| Validación Manual (sin require) | 0/19 workflows | ❌ ALTO |
| Credenciales Hardcodeadas | 2 workflows con JWT_SECRET | ⚠️ URGENTE |
| Try-Catch en Code Nodes | Parcial | ⚠️ ALTO |
| errorWorkflow Configurado | 0/22 workflows | ❌ CRÍTICO |
| Versionado en Código | 1/19 workflows (BB_00) | ❌ BAJO |

---

## ANÁLISIS: TOP-DOWN vs BOTTOM-UP

### Comparación de Estrategias

| Aspecto        | Top-Down                                | Bottom-Up                                    |
|----------------|----------------------------------------|----------------------------------------------|
| Inicia desde   | Orchestrators (BB_03_00, BB_04_Main)   | Sub-workflows sin dependencias               |
| Ventaja        | Ves integración completa primero       | Cada pieza funciona antes de integrar        |
| Desventaja     | Sub-workflows rotos causan cascada     | Más trabajo inicial sin ver resultado        |
| Testing        | Difícil (dependencias no listas)       | Fácil (cada pieza es independiente)          |
| Rollback       | Complejo                               | Simple (pieza por pieza)                     |

### RECOMENDACIÓN: BOTTOM-UP

**RAZÓN:** El proyecto AutoAgenda tiene dependencias claras en árbol. Si se corrigen las hojas primero, cuando se llegue a los orchestrators ya se confía en todo lo que llaman.

### Diagrama de Dependencias

```
                    ┌──────────────────────┐
                    │ BB_10_Macro_Blueprint │ ← ÚLTIMO
                    └──────────┬───────────┘
                               │
          ┌────────────────────┼────────────────────┐
          │                    │                    │
          ▼                    ▼                    ▼
   ┌─────────────┐    ┌─────────────┐     ┌─────────────┐
   │BB_03_00_Main│    │BB_04_Main   │     │BB_06_Admin  │
   └──────┬──────┘    └──────┬──────┘     └─────────────┘
          │                  │                    ▲
    ┌─────┼─────┐      ┌─────┼─────┐              │
    │     │     │      │     │     │              │
    ▼     ▼     ▼      ▼     ▼     ▼              │
 BB_03  BB_03  BB_03  BB_04  BB_04  BB_04         │
  _01    _02    _05   _Val  _Book  _Trans        │
    │     │     │      │     │     │              │
    └─────┴─────┴──────┴─────┴─────┴──────────────┘
                       ▲
                       │
              EMPEZAR AQUÍ (hojas)
```

---

## ORDEN DE VALIDACIÓN BOTTOM-UP

### FASE 1: FUNDAMENTOS (Sin dependencias)

| #  | Workflow                     | Criticidad | Dependencias | Esfuerzo |
|----|------------------------------|------------|--------------|----------|
| 1  | BB_00_Global_Error_Handler   | HIGH       | Ninguna      | Bajo     |
| 2  | BB_08_JWT_Auth_Helper        | MEDIUM     | Ninguna      | Bajo     |

**NOTA:** BB_00 es especial - no necesita single output (es el error handler), pero debe estar listo para que otros lo configuren en errorWorkflow.

**Checklist Fase 1:**

- [ ] BB_00: Verificar que funciona correctamente como error handler
- [ ] BB_00: Configurar variables: JWT_SECRET, BB_ERROR_RATE_LIMIT, BB_DEFAULT_ADMIN_CHAT_ID, BB_DEFAULT_ADMIN_EMAIL, N8N_BASE_URL
- [ ] BB_08: Eliminar JWT_SECRET hardcodeado → usar solo `$vars.JWT_SECRET`
- [ ] BB_08: Implementar contrato estándar (single output)
- [ ] BB_08: Agregar try-catch completo
- [ ] BB_08: Configurar errorWorkflow = "BB_00_Global_Error_Handler"
- [ ] Testing: Verificar autenticación JWT funciona

---

### FASE 2: SUB-WORKFLOWS AVAILABILITY (Hojas)

| #  | Workflow                    | Dependencias | Qué validar                    |
|----|-----------------------------|--------------|---------------------------------|
| 3  | BB_03_01_InputValidation    | Ninguna      | Single output, contrato estándar|
| 4  | BB_03_02_ProviderData       | Ninguna      | Single output, try-catch        |
| 5  | BB_03_03_ScheduleConfig     | Ninguna      | Single output, try-catch        |
| 6  | BB_03_04_BookingsData       | Ninguna      | Single output, try-catch        |
| 7  | BB_03_05_CalculateSlots     | Ninguna      | Single output, try-catch        |
| 8  | BB_03_06_ValidateConfig     | Ninguna      | Single output, try-catch        |

**Checklist Fase 2:**
Para cada workflow (BB_03_01 → BB_03_06):

- [ ] Eliminar `return [output0, output1]` (dual output)
- [ ] Eliminar `require('ajv')` o cualquier `require()`
- [ ] Agregar try-catch envolviendo TODO el código
- [ ] Definir `const WORKFLOW_ID = '{nombre}'` al inicio
- [ ] Implementar contrato estándar: `{ success, error_code, error_message, data, _meta }`
- [ ] Validar input vacío/null
- [ ] Validar tipos incorrectos
- [ ] Validar campos requeridos
- [ ] Configurar errorWorkflow = "BB_00_Global_Error_Handler"
- [ ] Test con input válido → success: true
- [ ] Test con input vacío → success: false, error_code
- [ ] Test con input inválido → success: false, error_code

---

### FASE 3: SUB-WORKFLOWS BOOKING (Hojas)

| #  | Workflow                    | Dependencias  | Qué validar                    |
|----|-----------------------------|---------------|---------------------------------|
| 9  | BB_04_Validate_Input        | Ninguna       | Single output, contrato         |
| 10 | BB_04_Booking_Create        | BB_00 (config)| Single output, try-catch        |
| 11 | BB_04_Booking_Cancel        | BB_00 (config)| Single output, try-catch        |
| 12 | BB_04_Booking_Reschedule    | BB_00 (config)| Single output, try-catch        |

**Checklist Fase 3:**
Para cada workflow (BB_04_Validate → BB_04_Reschedule):

- [ ] Eliminar dual output
- [ ] Eliminar require()
- [ ] Agregar try-catch completo
- [ ] Definir WORKFLOW_ID
- [ ] Implementar contrato estándar
- [ ] Validaciones manuales (sin AJV)
- [ ] Configurar errorWorkflow
- [ ] Tests: válido, vacío, inválido

---

### FASE 4: NOTIFICATIONS (Hojas)

| #  | Workflow                    | Dependencias | Qué validar                         |
|----|-----------------------------|--------------|------------------------------------|
| 13 | BB_07_Notification_Retry    | Ninguna      | Single output                       |
| 14 | BB_05_Notification_Engine   | BB_07        | Single output, Switch después de BB_07|

**Checklist Fase 4:**

- [ ] BB_07: Implementar contrato estándar
- [ ] BB_07: Try-catch completo
- [ ] BB_07: Configurar errorWorkflow
- [ ] BB_07: Tests completos
- [ ] BB_05: Implementar contrato estándar
- [ ] BB_05: Switch Node después de llamar a BB_07
- [ ] BB_05: Configurar errorWorkflow
- [ ] BB_05: Tests de integración con BB_07

---

### FASE 5: ORCHESTRATORS (Dependen de hojas)

| #  | Workflow                    | Dependencias              | Qué validar                      |
|----|-----------------------------|-----------------------------|----------------------------------|
| 15 | BB_03_00_Main               | BB_03_01-06                 | Switch después de CADA Execute WF|
| 16 | BB_04_Booking_Transaction   | BB_04_Create/Cancel         | Switch después de Execute WF     |
| 17 | BB_04_Main_Orchestrator     | BB_04_Validate, BB_04_Trans | Switches                         |
| 18 | BB_06_Admin_Dashboard       | BB_08                       | Switch después de BB_08          |

**Prerequisitos Fase 5:**

- ✅ TODAS las hojas (Fases 2-4) validadas
- ✅ BB_00 y BB_08 funcionando

**Checklist Fase 5:**
Para cada orchestrator:

- [ ] Verificar que TODOS los sub-workflows llamados están validados
- [ ] Agregar Switch Node después de CADA Execute Workflow
- [ ] Switch evalúa `$json.success === false`
- [ ] Output 0 (Error) → Manejo de error
- [ ] Output 1 (Fallback) → Continuar flujo
- [ ] Response final usa contrato estándar
- [ ] Configurar errorWorkflow
- [ ] Tests de integración completos

**Validación específica BB_03_00_Main:**

- [ ] Switch después de BB_03_01_InputValidation
- [ ] Switch después de BB_03_02_ProviderData
- [ ] Switch después de BB_03_03_ScheduleConfig
- [ ] Switch después de BB_03_04_BookingsData
- [ ] Switch después de BB_03_05_CalculateSlots
- [ ] Switch después de BB_03_06_ValidateConfig

**Validación específica BB_04_Main_Orchestrator:**

- [ ] Switch después de BB_04_Validate_Input
- [ ] Switch después de BB_04_Booking_Transaction

**Validación específica BB_06_Admin_Dashboard:**

- [ ] Eliminar JWT_SECRET hardcodeado
- [ ] Switch después de BB_08_JWT_Auth_Helper

---

### FASE 6: ENTRY POINTS (Últimos)

| #  | Workflow                    | Dependencias               | Qué validar      |
|----|-----------------------------|----------------------------|------------------|
| 19 | BB_02_Security_Firewall     | BB_00 (config)             | Single output    |
| 20 | BB_09_Deep_Link_Redirect    | BB_10                      | Single output    |
| 21 | BB_01_Telegram_Gateway      | BB_10                      | Single output    |
| 22 | BB_10_Macro_Blueprint       | BB_02, BB_03_00, BB_04, BB_06 | Todos los Switches |

**Prerequisitos Fase 6:**

- ✅ TODOS los orchestrators (Fase 5) validados
- ✅ TODOS los sub-workflows validados

**Checklist Fase 6:**

- [ ] BB_02: Implementar contrato estándar
- [ ] BB_02: Configurar errorWorkflow
- [ ] BB_09: Implementar contrato estándar
- [ ] BB_09: Switch después de llamar a BB_10
- [ ] BB_01: Implementar contrato estándar
- [ ] BB_01: Switch después de llamar a BB_10
- [ ] BB_10: Switches después de BB_02, BB_03_00, BB_04_Main, BB_06
- [ ] BB_10: Tests end-to-end completos

---

## CONTRATO ESTÁNDAR UNIFICADO

Todo workflow y sub-workflow DEBE retornar este esquema:

```javascript
{
  "success": boolean,              // true = éxito, false = error
  "error_code": string | null,     // Código de error si success=false
  "error_message": string | null,  // Mensaje legible si success=false
  "data": object | null,           // Datos útiles si success=true
  "_meta": {
    "source": string,              // "webhook" | "subworkflow" | "orchestrator"
    "timestamp": string,           // ISO8601
    "workflow_id": string          // Nombre del workflow (ej: "BB_03_01")
  }
}
```

---

## CATÁLOGO DE ERROR CODES

### VALIDACIÓN (VAL_*)

- `VAL_NO_INPUT` → No se recibió input
- `VAL_INVALID_EMAIL` → Formato de email inválido
- `VAL_MISSING_FIELD` → Campo requerido faltante
- `VAL_INVALID_DATE` → Formato de fecha inválido
- `VAL_OUT_OF_RANGE` → Valor fuera de rango permitido
- `VAL_INVALID_FORMAT` → Formato general inválido

### BASE DE DATOS (DB_*)

- `DB_CONNECTION_FAILED` → Fallo de conexión a DB
- `DB_QUERY_FAILED` → Query falló
- `DB_NOT_FOUND` → Registro no encontrado
- `DB_CONSTRAINT` → Violación de constraint

### SEGURIDAD (SEC_*)

- `SEC_UNAUTHORIZED` → Usuario no autorizado
- `SEC_BLOCKED` → Usuario bloqueado
- `SEC_RATE_LIMIT` → Rate limit excedido
- `SEC_INVALID_TOKEN` → Token inválido

### BOOKING (BOOK_*)

- `BOOK_SLOT_TAKEN` → Slot ya reservado
- `BOOK_GCAL_FAILED` → Fallo sincronización GCal
- `BOOK_PROVIDER_NA` → Proveedor no disponible

### SISTEMA (SYS_*)

- `SYS_TIMEOUT` → Timeout de operación
- `SYS_EXTERNAL_API` → API externa falló
- `INTERNAL_ERROR` → Error interno inesperado

### ORQUESTACIÓN (ORCH_*)

- `ORCH_SUBWF_FAILED` → Sub-workflow falló
- `ORCH_PREP_ERROR` → Error preparando input
- `ORCH_FORMAT_ERROR` → Error formateando output

---

## FUNCIONES HELPER DE VALIDACIÓN (Sin require)

Como N8N Code Node NO soporta require(), usar estas funciones:

```javascript
// EMAIL
const isValidEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

// TELÉFONO (E.164)
const isValidPhone = (phone) => /^\+?[1-9]\d{1,14}$/.test(phone);

// UUID
const isValidUUID = (uuid) => 
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid);

// FECHA ISO8601
const isValidISO8601 = (date) => !isNaN(Date.parse(date));

// FECHA YYYY-MM-DD
const isValidDate = (date) => /^\d{4}-\d{2}-\d{2}$/.test(date) && !isNaN(Date.parse(date));

// SLUG (lowercase, hyphens)
const isValidSlug = (slug) => /^[a-z0-9][a-z0-9-]*[a-z0-9]$/.test(slug);

// RANGO NUMÉRICO
const isInRange = (num, min, max) => typeof num === 'number' && num >= min && num <= max;

// ENUM
const isValidEnum = (value, options) => options.includes(value);

// STRING NO VACÍO
const isNonEmptyString = (str) => typeof str === 'string' && str.trim().length > 0;

// ARRAY
const isValidArray = (arr) => Array.isArray(arr);

// OBJETO
const isValidObject = (obj) => obj !== null && typeof obj === 'object' && !Array.isArray(obj);
```

---

## TEMPLATE DE CODE NODE (v2.0)

```javascript
/**
 * {NOMBRE_DEL_WORKFLOW}
 * Versión: v{VERSION}
 * Descripción: {DESCRIPCION}
 * 
 * INPUT:  { campo1, campo2, ... }
 * OUTPUT: { success, error_code, error_message, data, _meta }
 */
const WORKFLOW_ID = '{NOMBRE_DEL_WORKFLOW}';

// ═══ PATRONES DE VALIDACIÓN ═══
const isValidEmail = (email) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
const isValidUUID = (uuid) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid);
const isValidISO8601 = (date) => !isNaN(Date.parse(date));
const isNonEmptyString = (str) => typeof str === 'string' && str.trim().length > 0;

try {
  // ═══ VALIDACIÓN DE ENTRADA ═══
  const items = $input.all();
  
  if (!items || items.length === 0) {
    return [{
      json: {
        success: false,
        error_code: 'VAL_NO_INPUT',
        error_message: 'No input data received',
        data: null,
        _meta: {
          source: '{SOURCE_TYPE}',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }

  const raw = items[0].json.body || items[0].json;
  const errors = [];

  // ═══ VALIDACIONES ESPECÍFICAS ═══
  // Agregar validaciones según caso de uso
  
  if (!raw.campo_requerido) {
    errors.push('campo_requerido is required');
  }
  
  // ... más validaciones ...

  // ═══ RETORNO DE ERRORES DE VALIDACIÓN ═══
  if (errors.length > 0) {
    return [{
      json: {
        success: false,
        error_code: 'VAL_INVALID_INPUT',
        error_message: errors.join('; '),
        data: null,
        _meta: {
          source: '{SOURCE_TYPE}',
          timestamp: new Date().toISOString(),
          workflow_id: WORKFLOW_ID
        }
      }
    }];
  }

  // ═══ LÓGICA DE NEGOCIO ═══
  const result = {
    // ... procesar datos ...
  };

  // ═══ RETORNO EXITOSO ═══
  return [{
    json: {
      success: true,
      error_code: null,
      error_message: null,
      data: result,
      _meta: {
        source: '{SOURCE_TYPE}',
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
        source: '{SOURCE_TYPE}',
        timestamp: new Date().toISOString(),
        workflow_id: WORKFLOW_ID
      }
    }
  }];
}
```

---

## CONFIGURACIÓN DE WORKFLOW OBLIGATORIA

Todo workflow DEBE incluir esta configuración en settings:

```json
{
  "settings": {
    "executionOrder": "v1",
    "saveManualExecutions": true,
    "callerPolicy": "workflowsFromSameOwner",
    "errorWorkflow": "BB_00_Global_Error_Handler"
  }
}
```

**NOTA IMPORTANTE:**

- errorWorkflow se configura por NOMBRE del workflow
- Asegurarse que BB_00_Global_Error_Handler existe antes de importar otros workflows
- BB_00 se llama AUTOMÁTICAMENTE por N8N cuando hay errores no capturados
- NUNCA llamar a BB_00 directamente via Execute Workflow

---

## SWITCH NODE TEMPLATE (Para routing de errores)

Después de CADA Code Node o Execute Workflow, usar Switch:

```json
{
  "name": "Switch: Success?",
  "type": "n8n-nodes-base.switch",
  "typeVersion": 3,
  "parameters": {
    "rules": {
      "values": [
        {
          "conditions": {
            "options": {
              "caseSensitive": true,
              "leftValue": "",
              "typeValidation": "strict",
              "version": 2
            },
            "conditions": [
              {
                "id": "check-error",
                "leftValue": "={{ $json.success }}",
                "rightValue": false,
                "operator": {
                  "type": "boolean",
                  "operation": "equals"
                }
              }
            ],
            "combinator": "and"
          },
          "renameOutput": true,
          "outputKey": "Error"
        }
      ]
    },
    "options": {
      "fallbackOutput": "extra"
    }
  }
}
```

**Conexiones:**

- Output 0 (Error): → Manejo de error (respond 400, retry, fallback)
- Output 1 (Fallback/Success): → Continuar flujo normal

---

## MANEJO DE ERRORES POR NIVELES

### NIVEL 1: TRY-CATCH EN CODE NODE (Primera línea de defensa)

- Capturar TODOS los errores posibles
- Retornar `{ success: false, error_code: '...', ... }`
- BB_00 NO se llama (error controlado)
- Workflow CONTINÚA ejecutándose

### NIVEL 2: SWITCH/IF NODE (Routing de errores)

- Evaluar `$json.success` después de cada paso
- Error (success=false) → Path de error
- Success (success=true) → Continuar flujo
- Orchestrator decide: retry, abort, o fallback

### NIVEL 3: BB_00_GLOBAL_ERROR_HANDLER (Red de seguridad)

- Llamado AUTOMÁTICAMENTE por N8N cuando hay crash
- Solo para errores NO CAPTURADOS (bugs, undefined, etc.)
- Registra en DB y notifica admin
- Workflow ORIGINAL se marca como FALLIDO
- NO hay continuación después de BB_00

### Flujo de Decisión

```
┌─────────────────────────────────────────────────────────────┐
│ ¿Error en Code Node?                                        │
│                                                             │
│   ┌──────────┐                                              │
│   │ ¿Hay     │                                              │
│   │try-catch?│                                              │
│   └────┬─────┘                                              │
│        │                                                    │
│   SÍ   │    NO                                              │
│   ▼    │    ▼                                               │
│ Return │  Crash                                             │
│success:│    │                                               │
│ false  │    ▼                                               │
│   │    │ BB_00 llamado                                      │
│   │    │ automáticamente                                    │
│   │    │    │                                               │
│   │    │    ▼                                               │
│   │    │ Workflow FALLA                                     │
│   │    │ (no continúa)                                      │
│   ▼    │                                                    │
│ Workflow continúa                                           │
│ Switch detecta success=false                                │
│ Orchestrator maneja error                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## REGLAS PROHIBIDAS (NUNCA HACER)

1. **NUNCA usar dual output:**
   - ❌ `return [validItems, errorItems];`
   - ✅ `return [{ json: { success: true/false, ... } }];`

2. **NUNCA usar require():**
   - ❌ `const Ajv = require('ajv');`
   - ✅ Usar validación manual con funciones helper

3. **NUNCA llamar directamente a BB_00:**
   - ❌ Execute Workflow → BB_00_Global_Error_Handler
   - ✅ Configurar en settings.errorWorkflow

4. **NUNCA omitir try-catch:**
   - ❌ `const result = riskyOperation();`
   - ✅ `try { const result = riskyOperation(); } catch (e) { ... }`

5. **NUNCA omitir _meta:**
   - ❌ `return [{ json: { success: true, data: {...} } }];`
   - ✅ `return [{ json: { success: true, data: {...}, _meta: {...} } }];`

6. **NUNCA hardcodear credenciales:**
   - ❌ `const API_KEY = "sk-xxx";`
   - ✅ `const API_KEY = $credentials.openai.apiKey;`

---

## TIEMPO ESTIMADO DE VALIDACIÓN

| Fase | Workflows | Tiempo por WF | Total    |
|------|-----------|---------------|----------|
| 1    | 2         | 15 min        | 30 min   |
| 2    | 6         | 20 min        | 2 hrs    |
| 3    | 4         | 20 min        | 1.5 hrs  |
| 4    | 2         | 20 min        | 40 min   |
| 5    | 4         | 30 min        | 2 hrs    |
| 6    | 4         | 25 min        | 1.5 hrs  |
| TOTAL| 22        | -             | ~8 hrs   |

---

## CRONOGRAMA DE IMPLEMENTACIÓN BOTTOM-UP

| Fase | Workflows | Duración | Dependencias | Estado |
|------|-----------|----------|--------------|--------|
| **Fase 1: Fundamentos** | BB_00, BB_08 | 30 min | Ninguna | PENDIENTE |
| **Fase 2: Availability Leaves** | BB_03_01-06 | 2 hrs | Fase 1 | PENDIENTE |
| **Fase 3: Booking Leaves** | BB_04_Val, Create, Cancel, Reschedule | 1.5 hrs | Fase 1 | PENDIENTE |
| **Fase 4: Notifications** | BB_07, BB_05 | 40 min | Fase 1 | PENDIENTE |
| **Fase 5: Orchestrators** | BB_03_00, BB_04_Trans, BB_04_Main, BB_06 | 2 hrs | Fases 2-4 | PENDIENTE |
| **Fase 6: Entry Points** | BB_02, BB_09, BB_01, BB_10 | 1.5 hrs | Fase 5 | PENDIENTE |
| **TOTAL** | 22 workflows | ~8 hrs | - | - |

---

## CHECKLIST DE VALIDACIÓN POR WORKFLOW

Para cada workflow, verificar los siguientes puntos:

### 1. CÓDIGO

- [ ] Eliminar `return [output0, output1]` (dual output)
- [ ] Eliminar `require('ajv')` o cualquier `require()`
- [ ] Agregar try-catch envolviendo TODO el código
- [ ] Definir `const WORKFLOW_ID = '{nombre}'` al inicio

### 2. CONTRATO DE SALIDA

- [ ] Retorna `{ success, error_code, error_message, data, _meta }`
- [ ] `_meta` incluye: source, timestamp, workflow_id
- [ ] Todos los return (success y error) usan el mismo schema

### 3. VALIDACIONES

- [ ] Usar funciones helper manuales (NO AJV)
- [ ] Validar input vacío/null
- [ ] Validar tipos incorrectos
- [ ] Validar campos requeridos

### 4. CONFIGURACIÓN

- [ ] settings.errorWorkflow = "BB_00_Global_Error_Handler"
- [ ] Outputs = 1 (single output)

### 5. CONEXIONES (si es orchestrator)

- [ ] Switch Node después de CADA Execute Workflow
- [ ] Switch evalúa `$json.success === false`
- [ ] Output 0 (Error) → Manejo de error
- [ ] Output 1 (Fallback) → Continuar flujo

### 6. TESTING

- [ ] Test con input válido → success: true
- [ ] Test con input vacío → success: false, error_code
- [ ] Test con input inválido → success: false, error_code
- [ ] Test de integración (si aplica)

---

## DEVIL'S ADVOCATE CHECKLIST (Para cada workflow)

Antes de marcar un workflow como validado, verificar:

### 1. PATRÓN DE SALIDA

- [ ] ¿El código usa single output?
- [ ] ¿Retorna SIEMPRE el contrato estándar?
- [ ] ¿Incluye success, error_code, error_message, data?
- [ ] ¿Incluye _meta con source, timestamp, workflow_id?

### 2. MANEJO DE ERRORES

- [ ] ¿Hay try-catch envolviendo TODO el código?
- [ ] ¿El catch retorna contrato estándar con success:false?
- [ ] ¿Se usa require() o import? → RECHAZAR
- [ ] ¿Se llama directamente a BB_00? → RECHAZAR

### 3. ROBUSTEZ

- [ ] ¿Qué pasa con input vacío?
- [ ] ¿Qué pasa con input null?
- [ ] ¿Qué pasa con tipos incorrectos?
- [ ] ¿Qué pasa con campos extra?

### 4. CONFIGURACIÓN

- [ ] ¿settings.errorWorkflow = "BB_00_Global_Error_Handler"?
- [ ] ¿Hay Switch Node después de cada Execute Workflow?

**RESULTADO:**

- [APTO] → Proceder a producción
- [RECHAZAR] → Corregir violaciones antes de continuar

---

## VARIABLES DE WORKFLOW REQUERIDAS

| Variable | Workflows | Valor |
|----------|-----------|-------|
| JWT_SECRET | BB_06, BB_08, BB_00 | (valor seguro) |
| BB_ERROR_RATE_LIMIT | BB_00 | 10 |
| BB_DEFAULT_ADMIN_CHAT_ID | BB_00 | "5391760292" |
| BB_DEFAULT_ADMIN_EMAIL | BB_00 | "<admin@autoagenda.cl>" |
| N8N_BASE_URL | BB_00 | "<https://n8n.autoagenda.cl>" |

---

## PROCESO DE VALIDACIÓN PASO A PASO

### PASO 1: Exportar Todos los Workflows

Desde tu instancia N8N:

- UI: Workflows → Seleccionar → Export → JSON

O via API (si tienes acceso):

```bash
curl -X GET "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: tu-api-key" \
  | jq '.data[] | {id, name}' > workflow-list.json
```

### PASO 2: Crear Matriz de Estado

| # | Workflow                     | Estado | Dual Output | require() | try-catch | _meta | errorWF | Switches |
|---|------------------------------|--------|-------------|-----------|-----------|-------|---------|----------|
| 1 | BB_00_Global_Error_Handler   | ⏳     | N/A         | ❓        | ❓        | ❓    | N/A     | N/A      |
| 2 | BB_03_01_InputValidation     | ⏳     | ❓          | ❓        | ❓        | ❓    | ❓      | N/A      |
| 3 | BB_03_02_ProviderData        | ⏳     | ❓          | ❓        | ❓        | ❓    | ❓      | N/A      |
| ... | ...                        | ...    | ...         | ...       | ...       | ...   | ...     | ...      |

**Estados:** ⏳ Pendiente | 🔄 En progreso | ✅ Validado | ❌ Requiere fix

### PASO 3: Validar Cada Workflow (Bottom-Up)

Para cada workflow, en orden:

#### Validando: BB_03_01_InputValidation

1. Exportar JSON actual
2. Revisar con checklist
3. Identificar violaciones:
   - [ ] Dual output → Eliminar
   - [ ] require() → Reemplazar con validación manual
   - [ ] Sin try-catch → Agregar
   - [ ] Sin _meta → Agregar
   - [ ] Sin errorWorkflow → Configurar

4. Aplicar correcciones
5. Re-importar
6. Probar:
   - curl con input válido
   - curl con input vacío
   - curl con input inválido

7. Marcar como ✅ en matriz

### PASO 4: Validar Orchestrators

Después de que TODAS las hojas estén validadas:

#### Validando: BB_03_00_Main (Orchestrator)

**Prerequisitos:**

- [x] BB_03_01 validado
- [x] BB_03_02 validado
- [x] BB_03_03 validado
- [x] BB_03_04 validado
- [x] BB_03_05 validado
- [x] BB_03_06 validado

**Validación específica de orchestrator:**

1. Cada Execute Workflow tiene Switch después
2. Switch evalúa $json.success
3. Path de error maneja correctamente
4. Path de success continúa al siguiente paso
5. Response final usa contrato estándar

---

## RIESGOS Y MITIGACIONES

| Riesgo | Probabilidad | Mitigación |
|--------|--------------|------------|
| Switch Nodes rompen flujo existente | Media | Documentar conexiones antes |
| JWT_SECRET no configurado | Alta | Verificar antes de eliminar fallback |
| Regresión en validaciones | Media | Tests exhaustivos por workflow |
| errorWorkflow no existe | Baja | Verificar BB_00 existe antes de importar |

---

**Documento actualizado:** 15 de Febrero, 2026  
**Autor:** Kilo Code Architect  
**Estado:** PENDIENTE DE APROBACIÓN  
**Versión:** 2.1 - Bottom-Up Strategy (basado en SolucionFinal-v2.md y SOT-N8N-2.8.0.md)
