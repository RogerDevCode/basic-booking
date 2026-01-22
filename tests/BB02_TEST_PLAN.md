# 🧪 Test Plan: BB_02 Security Firewall - Comprehensive Suite

## Objetivo

Validar exhaustivamente el workflow BB_02 Security Firewall cubriendo:

- ✅ Funcionalidad básica
- ✅ Valores límite (boundary values)
- ✅ Inputs inválidos
- ✅ Ataques de inyección
- ✅ Type confusion
- ✅ Casos extremos

---

## Test Coverage

### **Total: 40 Escenarios**

| Categoría | Tests | Descripción |
|-----------|-------|-------------|
| **BÁSICOS** | 3 | Funcionalidad core (user con/sin RUT) |
| **BOUNDARY** | 6 | Valores límite (min/max telegram_id, RUT) |
| **INVÁLIDOS** | 13 | Validation errors (null, empty, wrong types) |
| **INYECCIÓN** | 7 | Security tests (SQL, XSS, NoSQL, Path Traversal) |
| **TYPE CONFUSION** | 5 | Coerción de tipos (string→number, boolean→number) |
| **EXTREMOS** | 6 | Edge cases (unicode, whitespace, payload size) |

---

## Estructura del Script

**Archivo:** `tests/comprehensive_bb02.sh`

**Función helper:**

```bash
run_test "<nombre>" '<payload_json>' "<expected_status>" "<descripción>"
```

**Output:**

- Muestra request/response de cada test
- Marca PASS (✓) o FAIL (✗)
- Resumen final con estadísticas

---

## Tests Detallados

### CATEGORÍA 1: TESTS BÁSICOS

#### BASIC-01: Usuario válido con RUT

```json
{
  "user": {"telegram_id": 5391760292, "rut": "12345678-9"},
  "routing": {"intent": "cmd_book", "target_date": "2026-01-21"}
}
```

- **Expected:** HTTP 200
- **Valida:** Flujo completo con usuario existente

#### BASIC-02: Usuario válido sin RUT

```json
{
  "user": {"telegram_id": 999888777},
  "routing": {"intent": "cmd_start"}
}
```

- **Expected:** HTTP 200
- **Valida:** Registro de usuario nuevo

#### BASIC-03: Intent vacío (opcional)

```json
{
  "user": {"telegram_id": 123456789},
  "routing": {}
}
```

- **Expected:** HTTP 200
- **Valida:** Campos opcionales

---

### CATEGORÍA 2: BOUNDARY VALUES

#### BOUNDARY-01: telegram_id mínimo (1)

```json
{"user": {"telegram_id": 1}, "routing": {"intent": "test"}}
```

- **Expected:** HTTP 200
- **Valida:** Número positivo mínimo

#### BOUNDARY-02: telegram_id máximo safe integer

```json
{"user": {"telegram_id": 9007199254740991}, "routing": {}}
```

- **Expected:** HTTP 200
- **Valida:** 2^53-1 (máximo JavaScript)

#### BOUNDARY-03: telegram_id = 0 (inválido)

```json
{"user": {"telegram_id": 0}, "routing": {}}
```

- **Expected:** HTTP 400
- **Valida:** Cero debe ser rechazado

#### BOUNDARY-04/05: RUT min/max

- **Min:** `"1-0"` → 200
- **Max:** `"99999999-9"` → 200

#### BOUNDARY-06: Intent con 1 caracter

```json
{"user": {"telegram_id": 123}, "routing": {"intent": "a"}}
```

- **Expected:** HTTP 200

---

### CATEGORÍA 3: INPUTS INVÁLIDOS

#### INVALID-01: user = null

- **Expected:** HTTP 400
- **Error:** "Missing key: user"

#### INVALID-02: user = [] (array)

- **Expected:** HTTP 400
- **Error:** "user must be object"

#### INVALID-04: telegram_id = null

- **Expected:** HTTP 400
- **Error:** "telegram_id is required"

#### INVALID-05: telegram_id = ""

- **Expected:** HTTP 400
- **Error:** "cannot be empty"

#### INVALID-06: telegram_id = "abc123"

- **Expected:** HTTP 400
- **Error:** "must be positive number" (NaN after coercion)

#### INVALID-07: telegram_id negativo

- **Expected:** HTTP 400

#### INVALID-08/09: RUT formato inválido

- Sin guión: "12345678" → 400
- Con letras: "abcd-efgh" → 400

#### INVALID-10: routing = null

- **Expected:** HTTP 400

#### INVALID-11: routing.intent = object

- **Expected:** HTTP 400

#### INVALID-12: routing.intent = ""

- **Expected:** HTTP 400

#### INVALID-13: Payload vacío {}

- **Expected:** HTTP 400

---

### CATEGORÍA 4: ATAQUES DE INYECCIÓN

#### INJECTION-01: SQL en telegram_id

```json
{"user": {"telegram_id": "1 OR 1=1"}, "routing": {}}
```

- **Expected:** HTTP 400 (falla validación numérica)

#### INJECTION-02: SQL en RUT

```json
{"user": {"telegram_id": 123, "rut": "'; DROP TABLE users; --"}, "routing": {}}
```

- **Expected:** HTTP 400 (falla regex)

#### INJECTION-03: XSS en intent

```json
{"routing": {"intent": "<script>alert(1)</script>"}}
```

- **Expected:** HTTP 200 (pasa, pero debe ser escapado)

#### INJECTION-04: Command Injection

```json
{"routing": {"intent": "; rm -rf /"}}
```

- **Expected:** HTTP 200 (pasa validación)

#### INJECTION-05: NoSQL Injection

```json
{"user": {"telegram_id": {"$ne": null}}}
```

- **Expected:** HTTP 400 (objeto no es número)

#### INJECTION-06: Path Traversal

```json
{"user": {"rut": "../../../etc/passwd"}}
```

- **Expected:** HTTP 400 (falla regex RUT)

#### INJECTION-07: Null Byte

```json
{"user": {"telegram_id": "123\u0000admin"}}
```

- **Expected:** HTTP 200 (convierte a número)

---

### CATEGORÍA 5: TYPE CONFUSION

#### TYPECONF-01: String numérico

```json
{"user": {"telegram_id": "5391760292"}}
```

- **Expected:** HTTP 200 (coerción válida)

#### TYPECONF-02: Boolean true

```json
{"user": {"telegram_id": true}}
```

- **Expected:** HTTP 200 (true → 1)

#### TYPECONF-03: Boolean false

```json
{"user": {"telegram_id": false}}
```

- **Expected:** HTTP 400 (false → 0 → inválido)

#### TYPECONF-04: Array [123]

```json
{"user": {"telegram_id": [123]}}
```

- **Expected:** HTTP 200 (array → número)

#### TYPECONF-05: RUT como número

```json
{"user": {"rut": 12345678}}
```

- **Expected:** HTTP 400 (debe ser string)

---

### CATEGORÍA 6: CASOS EXTREMOS

#### EXTREME-01: 100 campos extra

- **Expected:** HTTP 200 (ignorados)

#### EXTREME-02: Emojis

```json
{"routing": {"intent": "🔥💯🚀😎👍"}}
```

- **Expected:** HTTP 200 (UTF-8 válido)

#### EXTREME-03: Whitespace extremo

```json
{"routing": {"intent": "                "}}
```

- **Expected:** HTTP 400 (whitespace puro)

#### EXTREME-04: Intent 1000 chars

- **Expected:** HTTP 200 (sin límite)

#### EXTREME-05: Caracteres de control

```json
{"routing": {"intent": "test\u001f\u0000\u001b"}}
```

- **Expected:** HTTP 200 (pasa validación)

---

## Ejecución

### Prerequisitos

1. Workflow BB_02 importado y activo en n8n
2. `jq` instalado para formateo JSON

### Comando

```bash
cd "/home/manager/Sync/N8N Projects/basic-booking"
./tests/comprehensive_bb02.sh
```

### Output Esperado

```
═══════════════════════════════════════════════════════════════
  BB_02 Security Firewall - COMPREHENSIVE TEST SUITE
═══════════════════════════════════════════════════════════════

═══ CATEGORÍA 1: TESTS BÁSICOS ═══

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test #1: BASIC-01: Usuario válido con RUT
Description: Usuario existente, RUT válido, debe pasar firewall
Expected HTTP Status: 200

Response Body:
{
  "success": true,
  ...
}

Actual HTTP Status: 200
✓ PASS

...
```

---

## Métricas de Éxito

| Métrica | Objetivo | Actual |
|---------|----------|--------|
| **Cobertura de validaciones** | 100% | TBD |
| **Tests ejecutados** | 40 | 40 |
| **Tasa de éxito esperada** | ≥95% | TBD |
| **Bugs encontrados** | Document | TBD |

---

## Bugs Esperados

Basado en análisis de código, estos tests podrían **FALLAR** (esperado):

1. **INJECTION-03 (XSS):** Pasa validación, pero ¿se escapa en DB?
2. **INJECTION-04 (Command):** Pasa validación, ¿se sanitiza después?
3. **EXTREME-03 (Whitespace):** Puede pasar si trim() no está en intent
4. **EXTREME-05 (Control chars):** Pueden causar issues en logs/DB

**Estos fallos indican mejoras necesarias en el workflow.**

---

## Próximos Pasos

1. **Ejecutar suite completa**
2. **Documentar resultados** (pass/fail rate)
3. **Identificar bugs reales**
4. **Crear issues** para fallos encontrados
5. **Mejorar validaciones** según hallazgos
6. **Re-ejecutar** hasta 100% pass rate

---

**Status:** ✅ Test Suite Ready  
**Execution:** Manual (requiere workflow activo en n8n)
