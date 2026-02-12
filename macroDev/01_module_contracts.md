# Paso 1 — Contratos de Módulos (Macro-Workflow)

> Objetivo: definir contratos **estables y testeables** para cada módulo del sistema AutoAgenda (n8n v2.4.6).  
> Formato estándar de respuesta: `{ success, error_code, error_message, data }`.

---

## 0) Convenciones globales (aplican a todo)
- **Formato de retorno**:  
  - `success`: `true | false`  
  - `error_code`: `string | null`  
  - `error_message`: `string | null`  
  - `data`: `object | null`
- **Auditoría**: todo módulo **loggea antes** de decisiones críticas.
- **Paranoid Guard**: validación estricta en la entrada de cada workflow.
- **Timezone**: todos los cálculos en UTC; `TIMEZONE` solo para presentación.
- **SQL**: Postgres v2.4, **parametrizado** (`$1, $2`).

---

## 1) BB_01_Telegram_Gateway (Entry)
**Responsabilidad**: punto único de entrada de mensajes Telegram.  
**Input** (raw):
- `update_id`
- `message.text`
- `message.chat.id`
- `message.from.id`
- `message.date`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "channel": "telegram",
    "user_id": "tg:123",
    "chat_id": "123",
    "text": "/book",
    "raw": {}
  }
}
```

---

## 2) BB_09_Deep_Link_Redirect (Web Entry)
**Responsabilidad**: puente web → bot, genera deep link.  
**Input**:
- `slug`
- `utm` (opcional)

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "channel": "web",
    "slug": "proveedor-x",
    "deep_link": "https://t.me/AutoAgendaBot?start=proveedor-x"
  }
}
```

---

## 3) BB_02_Security_Firewall
**Responsabilidad**: identidad, rate limits, validación comportamiento.  
**Input**:
- `channel`
- `user_id`
- `text`
- `raw`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "authorized": true,
    "risk_score": 0,
    "context": {
      "user_id": "tg:123",
      "provider_slug": "proveedor-x"
    }
  }
}
```

**Errores comunes**:
- `SEC_BLOCKED`
- `SEC_RATE_LIMIT`
- `SEC_INVALID_ID`

---

## 4) Intent Router (Switch v3)
**Responsabilidad**: enrutar intención `/book`, `/availability`, `/cancel`, `/admin`.  
**Input**:
- `text`
- `context`

**Output**:
- Ruta lógica (no cambia el payload).

---

## 5) BB_03_Availability_Engine (Core)
**Responsabilidad**: cálculo de slots de disponibilidad (modular).  
**Input**:
- `provider_slug`
- `date_range`
- `service_id` (si aplica)
- `timezone`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "provider_slug": "proveedor-x",
    "slots": [
      {"start": "2025-01-10T14:00:00Z", "end": "2025-01-10T14:30:00Z"}
    ],
    "max_slots_applied": true
  }
}
```

### Sub‑módulos
- `BB_03_00 Validate Input`
- `BB_03_01 Fetch Provider Config`
- `BB_03_02 Fetch Schedule (GCal)`
- `BB_03_03 Compute Slots`
- `BB_03_04 Range/Max Slots Guard`
- `BB_03_05 Slot Normalization`
- `BB_03_06 Availability Response`

---

## 6) BB_04_Booking_Transaction (Core / Saga)
**Responsabilidad**: crear reserva atómica GCal + DB.  
**Input**:
- `user_id`
- `provider_slug`
- `slot`
- `service_id`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "booking_id": "bk_123",
    "gcal_event_id": "gcal_456",
    "status": "confirmed"
  }
}
```

**Errores comunes**:
- `BOOK_SLOT_TAKEN`
- `BOOK_GCAL_FAIL`
- `BOOK_DB_FAIL`

### Sub‑módulos
- `BB_04_00 Pre-Check + Lock`
- `BB_04_01 Create GCal Event`
- `BB_04_02 Persist Booking`
- `BB_04_03 Commit Saga`
- `BB_04_04 Rollback on Failure`

---

## 7) BB_05_Notification_Engine
**Responsabilidad**: enviar notificaciones async (Telegram/Email).  
**Input**:
- `notification_queue` record

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "sent": true,
    "channel": "telegram"
  }
}
```

---

## 8) BB_07_Notification_Retry_Worker
**Responsabilidad**: reintentos con backoff.  
**Input**:
- `notification_queue` record con `retry_count`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "retry_scheduled": true,
    "next_attempt_at": "2025-01-10T15:00:00Z"
  }
}
```

---

## 9) BB_06_Admin_Dashboard API
**Responsabilidad**: CRUD proveedores, configuración global, auditoría.  
**Input**:
- `jwt`
- `action`
- `payload`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "action": "provider.update",
    "result": "ok"
  }
}
```

---

## 10) BB_08_JWT_Auth_Helper
**Responsabilidad**: generar y validar JWT admin.  
**Input**:
- `admin_id`
- `scopes`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "token": "jwt_xxx",
    "expires_at": "2025-01-10T16:00:00Z"
  }
}
```

---

## 11) BB_00_Global_Error_Handler
**Responsabilidad**: logging central + PII redaction + alertas.  
**Input**:
- `workflow_id`
- `error`
- `context`

**Output**:
```json
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "logged": true,
    "alert_sent": true
  }
}
```

---

## 12) Data Layer (Postgres)
**Responsabilidad**: Source of Truth.  
Tablas clave:
- `users`, `providers`, `bookings`, `app_config`
- `audit_logs`, `security_firewall`
- `notification_queue`, `system_errors`

---

## Checklist de test por módulo (mínimo)
- ✅ input válido → `success=true`
- ✅ input inválido → `success=false` con `error_code`
- ✅ edge case (sin slots, provider inexistente, API down)
- ✅ logs antes de decisión crítica

---