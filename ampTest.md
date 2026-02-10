# AmpTest - Informe de Testing BB_02 → BB_00 → Telegram

**Fecha:** 2026-02-09  
**Thread:** [T-019c44ac-88ed-756e-bdfc-8d5355687267](https://ampcode.com/threads/T-019c44ac-88ed-756e-bdfc-8d5355687267)

## Objetivo

Verificar que un error en BB_02_Security_Firewall active BB_00_Global_Error_Handler y envíe alerta a Telegram.

## Test ejecutado

**Script:** `scripts-py/test_bb02_triggers_bb00.py`

**Estrategia:** Se modificó temporalmente el nodo `DB: Security Check` de BB_02 (query rota + `continueOnFail: false`) para provocar un crash. BB_02 tiene `errorWorkflow: BB_00`, así que n8n activa BB_00 vía Error Trigger automáticamente.

**Resultado:** PASS. BB_00 ejecución #318 status=success. Alerta enviada a Telegram.

## Bug encontrado y corregido

**Nodo:** BB_00 → `Process Merged Data`  
**Bug:** Acceso directo a `$env` sin try-catch. Cuando BB_00 se ejecuta vía Error Trigger, n8n deniega acceso a env vars → BB_00 crasheaba sin enviar la alerta.  
**Fix:** Se envolvió cada acceso a `$env` en try-catch individual con fallback por defecto.

## Cambios permanentes

| Componente | Cambio |
|---|---|
| BB_00 nodo `Process Merged Data` | `$env` con try-catch (bugfix) |
| DB `app_config` | Insertado `BB_00_WORKFLOW_ID = _Za9GzqB2cS9HVwBglt43` |
| `workflows/BB_00_Global_Error_Handler.json` | Actualizado con el fix |

BB_02 no tiene cambios permanentes (restaurado y verificado).

## Pendientes

- BB_02 servidor (28 nodos) difiere del JSON local (25 nodos) — fue editado en n8n post-commit. Exportar versión actual.
- BB_00 no tiene `errorWorkflow` propio configurado — riesgo de loop si BB_00 crashea y se auto-triggerea.
- Validar que las variables de entorno `BB_ERROR_RATE_LIMIT`, `BB_DEFAULT_ADMIN_CHAT_ID`, `N8N_BASE_URL` estén definidas en Docker/n8n para producción.
