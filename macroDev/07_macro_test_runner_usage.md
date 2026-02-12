# Paso 7 — Uso del Macro Test Runner

> Archivo: `macroDev/06_macro_test_runner.json`  
> Objetivo: ejecutar fixtures en cadena contra el macro‑workflow y revisar resultados.

---

## 1) Importación
1. Abre n8n → **Workflows** → **Import from File**.
2. Selecciona `macroDev/06_macro_test_runner.json`.
3. Mantén el workflow **Disabled** hasta que `BB_10_Macro_Workflow_Blueprint` esté importado.

---

## 2) Pre‑requisitos
- `BB_10_Macro_Workflow_Blueprint` importado y activo.
- Sub‑workflows disponibles:
  - `BB_03_00_Main`
  - `BB_04_Booking_Transaction`
  - `BB_06_Admin_Dashboard`
  - `BB_00_Global_Error_Handler`
- Credenciales y DB disponibles en el entorno local.

---

## 3) Cómo ejecutarlo
1. Abre `BB_10_Macro_Test_Runner`.
2. Presiona **Execute Workflow** (Manual Trigger).
3. Observa la salida del nodo **Collect Result**.

---

## 4) Qué valida
- Enrutamiento correcto según intención.
- Respuesta con contrato `{ success, error_code, error_message, data }`.
- Casos de error controlados (fallback / auth / slot taken).

---

## 5) Ajustes recomendados
- Cambia `provider_slug`, fechas y `user_id` en el nodo **Build Fixtures**.
- Ajusta `service_id` si tu catálogo lo requiere.
- Si falla un caso, revisa logs en `BB_00_Global_Error_Handler`.

---

## 6) Criterio de éxito
- Todas las pruebas críticas terminan con salida estructurada.
- Ninguna ejecución queda sin respuesta o con error no controlado.

---