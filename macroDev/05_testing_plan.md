# Paso 5 — Plan de Testing Top‑Down (Macro Workflow)

> Objetivo: habilitar desarrollo **top‑down** con pruebas mínimas por módulo, fixtures reutilizables y validación de contratos `{ success, error_code, error_message, data }`.

---

## 1) Estrategia general (Top‑Down)
1. **Macro Workflow activo en modo staging** (no productivo).
2. **Sub‑workflows simulados** con respuestas “stub”.
3. Reemplazo gradual de stubs por módulos reales.
4. **Regresión por intención** (booking, availability, admin, help).

---

## 2) Pirámide de pruebas (n8n)
- **Nivel 0 — Contratos**: valida formato de salida.
- **Nivel 1 — Sub‑módulos**: prueba cada workflow aislado.
- **Nivel 2 — Orquestación**: macro flow + routing.
- **Nivel 3 — E2E**: Telegram/Web → Booking/Availability.

---

## 3) Checklist base por módulo (mínimo)
Todos los módulos deben validar:

- ✅ Input válido → `success=true`
- ✅ Input inválido → `success=false` con `error_code`
- ✅ Edge case (sin slots / provider inexistente / API down)
- ✅ Auditoría previa a decisión crítica

---

## 4) Fixtures recomendados (JSON)
Crea fixtures en `tests/fixtures/` (recomendado):

- `telegram_webhook_valid.json`
- `telegram_webhook_invalid.json`
- `availability_valid.json`
- `availability_no_slots.json`
- `booking_valid.json`
- `booking_slot_taken.json`
- `admin_valid.json`
- `admin_invalid_jwt.json`

> Sugerencia: usar siempre `provider_slug` y `user_id` reales de dev.

---

## 5) Casos por intención (Macro Router)

### 5.1) Availability
**Input**:
- `/availability`, `disponibilidad`, `horarios`

**Expect**:
- Router → `BB_03_00_Main`
- Respuesta con `data.slots`

---

### 5.2) Booking
**Input**:
- `/book`, `agendar`, `reservar`

**Expect**:
- Router → `BB_04_Booking_Transaction`
- Respuesta `booking_id` + `gcal_event_id`

---

### 5.3) Admin
**Input**:
- `/admin`, `/config`

**Expect**:
- Router → `BB_06_Admin_Dashboard`
- `success=true` solo con JWT válido

---

### 5.4) Fallback
**Input**:
- texto desconocido

**Expect**:
- `INTENT_UNKNOWN`
- Log en `BB_00_Global_Error_Handler`

---

## 6) Pruebas de seguridad mínimas
- Rate‑limit excedido → bloqueo
- user sin contexto → fallback seguro
- input vacío → `INTENT_EMPTY`

---

## 7) Pruebas de resiliencia
- GCal caído → Saga rollback OK
- Postgres error → `BOOK_DB_FAIL` y registro en `BB_00`
- Email fallido → encola retry (`BB_07`)

---

## 8) Validación de tiempo (UTC)
- Validar que `start_time` / `end_time` estén en UTC.
- Validar que `timezone` se use solo en presentación.

---

## 9) Salida esperada estándar
Todos los sub‑workflows deben cumplir:

```/dev/null/contract.json#L1-6
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {}
}
```

---

## 10) Métricas mínimas recomendadas
- % intents válidos
- % fallbacks
- ratio booking success/fail
- tiempo medio de respuesta por intención

---

## 11) Flujo de regresión
1. Ejecutar 6 fixtures base.
2. Revisar logs en `system_errors`.
3. Verificar alertas en `BB_00`.

---

## 12) Definición de “listo para producción”
- 100% casos críticos pasan
- 0 errores no controlados
- Latencia promedio dentro de límites

---