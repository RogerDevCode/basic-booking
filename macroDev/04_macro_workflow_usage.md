# Paso 4 — Uso e Importación del Macro Workflow

> Archivo macro: `macroDev/03_macro_workflow_blueprint.json`  
> Objetivo: importar el macro‑workflow en n8n y usarlo como orquestador top‑down.

---

## 1) Importación en n8n
1. Abre n8n → **Workflows** → **Import from File**.
2. Selecciona `macroDev/03_macro_workflow_blueprint.json`.
3. Verifica versiones de nodos según `docs/SOT-N8N-2.4.6.md`.

> Recomendación: importarlo como **Disabled** y activar cuando tengas los sub‑workflows listos.

---

## 2) Entradas soportadas (macro workflow)
El macro puede ser ejecutado:
- **Webhook** (`POST /macro-entry`)
- **Execute Workflow** (sub‑workflow)

### Payload esperado (mínimo)
```/dev/null/macro-input.json#L1-16
{
  "text": "/availability",
  "channel": "telegram",
  "user_id": "tg:123",
  "chat_id": "123",
  "context": {
    "provider_slug": "proveedor-x"
  }
}
```

---

## 3) Normalización de intención
El nodo **Normalize Intent** agrega:
- `data.intent` (booking / availability / admin / help / cancel / reschedule / unknown)

Esto alimenta el **Intent Router (Switch v3)**.

---

## 4) Workflows llamados por el macro
| Intent | Workflow | Notas |
|---|---|---|
| `availability` | `BB_03_00_Main` | Debe aceptar payload con `provider_slug` y rango/fecha |
| `booking` | `BB_04_Booking_Transaction` | Debe aceptar slot validado |
| `admin` | `BB_06_Admin_Dashboard` | Solo admin con JWT válido |
| fallback | `BB_00_Global_Error_Handler` | Log + alerta |

---

## 5) Contratos mínimos esperados por sub‑workflows
Todos deben responder:
```/dev/null/contract.json#L1-6
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {}
}
```

---

## 6) Reglas de compatibilidad (SOT)
Validado con `docs/SOT-N8N-2.4.6.md`:
- **Webhook v1**
- **Switch v3**
- **Code v2**
- **Execute Workflow v1**

---

## 7) Checklist antes de activar
- [ ] `BB_02_Security_Firewall` devuelve payload normalizado
- [ ] `BB_03_00_Main` acepta inputs definidos
- [ ] `BB_04_Booking_Transaction` mantiene patrón Saga
- [ ] `BB_06_Admin_Dashboard` responde con contrato estándar
- [ ] `BB_00_Global_Error_Handler` activo y enlazado

---

## 8) Notas de operación
- Si el `intent` es `unknown`, se retorna error y se loggea en `BB_00`.
- El macro es **orquestador**, no contiene lógica de negocio.
- Ideal para desarrollo **top‑down** y testing modular.

---