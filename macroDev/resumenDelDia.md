# Resumen del Día (MacroDev)

Proyecto: AutoAgenda (n8n v2.4.6, Postgres Neon, Telegram/Web, GCal).  
Objetivo: macro‑workflow top‑down + testing modular.

## Estado actual
- Carpeta creada: `macroDev/`.
- Paso 1: contratos por módulo.
  - `macroDev/01_module_contracts.md`
- Paso 2: reglas de intent router (Switch v3 + fallback).
  - `macroDev/02_intent_router_rules.md`
- Paso 3: macro workflow JSON (orquestador real).
  - `macroDev/03_macro_workflow_blueprint.json`
  - Incluye Guard → Firewall → Normalize Intent → Router → BB_03_00_Main / BB_04 / BB_06 + fallback BB_00.
- Paso 4: guía de uso/importación.
  - `macroDev/04_macro_workflow_usage.md`
- Paso 5: plan de testing top‑down.
  - `macroDev/05_testing_plan.md`
- Paso 6: fixtures base creados.
  - `tests/fixtures/*.json` + `tests/fixtures/README.md`
- Paso 7: test runner (n8n JSON) + uso.
  - `macroDev/06_macro_test_runner.json`
  - `macroDev/07_macro_test_runner_usage.md`

## Notas técnicas
- Compatibilidad SOT: Webhook v1, Switch v3, Code v2, Execute Workflow v1.
- Fixtures usan `provider_slug`, `user_id`, fechas UTC.

## Pendientes
- Ajustar payloads del macro a contratos reales (BB_03_00_Main, BB_04, BB_06).
- Validar intent “cancel/reschedule/help” en macro si se requiere.
- Probar importación en n8n y ejecutar test runner.
- considera el caso de reagenda, por parte del usuario, del proveedor o del administrador

Qué voy a implementar en `BB_04_Booking_Transaction`

### ✅ Entrada esperada (extendida)
- `action`: `"booking" | "cancel" | "reschedule"`
- `booking_id` (para cancel/reschedule)
- `user_id` / `provider_id` (validación extra)
- `new_slot` (para reschedule)

### ✅ Flujo nuevo (resumen)
- **Guard**: si `action=booking` → flujo actual.  
- **Cancel**:
  - Buscar booking por `booking_id` + validar owner.
  - Eliminar GCal si existe.
  - `UPDATE bookings SET status='cancelled'`.
- **Reschedule**:
  - Buscar booking.
  - Eliminar GCal anterior.
  - Crear nuevo evento GCal.
  - Insertar nuevo booking `confirmed`.
  - Actualizar booking anterior `status='rescheduled'`.
