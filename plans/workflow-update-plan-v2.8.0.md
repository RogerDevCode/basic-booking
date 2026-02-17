# Plan de Actualización de Workflows a n8n v2.8.0

**Fecha:** 15 de Febrero, 2026
**Versión Origen:** n8n v2.4.6
**Versión Destino:** n8n v2.8.0
**Referencia:** [docs/SOT-N8N-2.8.0.md](../docs/SOT-N8N-2.8.0.md)

---

## Resumen Ejecutivo

Este plan detalla la migración de los workflows del proyecto basic-booking desde n8n v2.4.6 a v2.8.0. La migración incluye actualizaciones de versiones de nodos, cambios en el acceso a variables de entorno, y validación de compatibilidad.

### Impacto Total

| Categoría | Cantidad | Prioridad |
|-----------|----------|-----------|
| Workflows a actualizar | 22 | Alta |
| Nodos Postgres v2.4 → v2.6 | ~15 | Alta |
| Nodos Webhook v1 → v2 | 4 | Media |
| Code Nodes con $env | 1 | Crítica |
| Nodos ya compatibles | ~50+ | - |

---

## 1. Análisis de Workflows

### 1.1 Matrix de Nodos por Workflow

| Workflow | Webhook | Postgres | Code | Switch | Execute WF | Telegram | Otros |
|----------|---------|----------|------|--------|------------|----------|-------|
| BB_00_Global_Error_Handler | - | v2.4 (5) | v2 (12) | v3 (3) | - | v1.2 | Merge v3, Gmail v2.1 |
| BB_01_Telegram_Gateway | v1 ⚠️ | v2.4 (3) | v2 (3) | v3 (2) | v1 | - | Respond v1 |
| BB_02_Security_Firewall | v2.1 ✓ | v2.4 (4) | v2 (10) | v3 (4) | v1.1 | - | Respond v1.5 |
| BB_03_00_Main | v2 ✓ | - | v2 (6) | v3 (5) | v1.1 (5) | - | Merge v3, IF v2.2, Respond v1.1 |
| BB_03_01_InputValidation | - | - | v2 | v3 | - | - | - |
| BB_03_02_ProviderData | - | v2.4 | v2 | v3 | - | - | - |
| BB_03_03_ScheduleConfig | - | v2.4 | v2 | v3 | - | - | - |
| BB_03_04_BookingsData | - | v2.4 | v2 | v3 | - | - | - |
| BB_03_05_CalculateSlots | - | - | v2 | v3 | - | - | - |
| BB_03_06_ValidateConfig | - | - | v2 | v3 | - | - | - |
| BB_04_Main_Orchestrator | v1 ⚠️ | - | - | v3 (2) | v1 (4) | - | Set v3.3, Respond v1 |
| BB_04_Booking_Cancel | - | v2.4 | v2 | - | - | - | - |
| BB_04_Booking_Create | - | v2.4 | v2 | - | - | - | - |
| BB_04_Booking_Reschedule | - | v2.4 | v2 | - | - | - | - |
| BB_04_Booking_Transaction | - | v2.4 | v2 | v3 | - | - | - |
| BB_04_Validate_Input | - | - | v2 | - | - | - | - |
| BB_05_Notification_Engine | v1 ⚠️ | v2.4 (3) | v2 (3) | v3 | - | v1.2 | Cron v1, Respond v1 |
| BB_06_Admin_Dashboard | v1 ⚠️ | v2.4 | v2 | v3 | - | - | - |
| BB_07_Notification_Retry_Worker | - | v2.4 | v2 | - | - | v1.2 | - |
| BB_08_JWT_Auth_Helper | - | - | v2 | - | - | - | - |
| BB_09_Deep_Link_Redirect | - | - | v2 | - | - | - | - |

**Leyenda:**
- ✓ = Ya en versión correcta
- ⚠️ = Requiere actualización
- (n) = Cantidad de nodos

---

## 2. Cambios Requeridos por Tipo de Nodo

### 2.1 Postgres Node: v2.4 → v2.6

**Workflows afectados:** BB_00, BB_01, BB_02, BB_03_02, BB_03_03, BB_03_04, BB_04_Booking_*, BB_05, BB_06, BB_07

**Cambios en JSON:**
```json
// ANTES
"typeVersion": 2.4

// DESPUÉS
"typeVersion": 2.6
```

**Validaciones requeridas:**
- [ ] Verificar que queries con valores falsey (0, null, false) funcionan correctamente
- [ ] Probar `queryParameters` con valores null
- [ ] Validar operaciones INSERT/UPDATE con campos opcionales

### 2.2 Webhook Node: v1 → v2

**Workflows afectados:** BB_01, BB_04_Main_Orchestrator, BB_05, BB_06

**Cambios en JSON:**
```json
// ANTES
{
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 1,
  "parameters": {
    "httpMethod": "POST",
    "path": "telegram-webhook",
    "responseMode": "responseNode"
  }
}

// DESPUÉS
{
  "type": "n8n-nodes-base.webhook",
  "typeVersion": 2,
  "parameters": {
    "httpMethod": "POST",
    "path": "telegram-webhook",
    "responseMode": "responseNode"
  }
}
```

**Notas:**
- `responseMode` ahora soporta `streaming` adicionalmente
- La estructura de `parameters` es compatible entre v1 y v2

### 2.3 Code Node: Acceso a Variables de Entorno

**Workflows afectados:** BB_00_Global_Error_Handler (nodo "Process Merged Data")

**Problema:**
```javascript
// ANTES (n8n < 2.0) - Bloqueado por defecto en 2.8.0
try { envConfig.RATE_LIMIT = parseInt($env.BB_ERROR_RATE_LIMIT) || 10; } catch (e) {}
try { envConfig.ADMIN_CHAT_ID = $env.BB_DEFAULT_ADMIN_CHAT_ID || '5391760292'; } catch (e) {}
```

**Solución:**
```javascript
// DESPUÉS (n8n 2.8.0) - Usar $vars
try { envConfig.RATE_LIMIT = parseInt($vars.BB_ERROR_RATE_LIMIT) || 10; } catch (e) {}
try { envConfig.ADMIN_CHAT_ID = $vars.BB_DEFAULT_ADMIN_CHAT_ID || '5391760292'; } catch (e) {}
```

**Alternativa:** Configurar `N8N_RUNNERS_ALLOW_ENVIRONMENT_VARIABLES=true` en el servidor

---

## 3. Plan de Ejecución

### Fase 1: Preparación (Sin cambios en código)

#### 3.1.1 Configuración de Variables de Workflow
- [ ] Crear variables de workflow en n8n para reemplazar `$env`:
  - `BB_ERROR_RATE_LIMIT`
  - `BB_DEFAULT_ADMIN_CHAT_ID`
  - `BB_DEFAULT_ADMIN_EMAIL`
  - `N8N_BASE_URL`

#### 3.1.2 Backup
- [ ] Exportar todos los workflows actuales
- [ ] Crear snapshot de la base de datos n8n
- [ ] Documentar versiones actuales de nodos

#### 3.1.3 Ambiente de Pruebas
- [ ] Clonar workflows a ambiente de staging
- [ ] Preparar tests de regresión

### Fase 2: Actualización de Nodos Postgres (Prioridad Alta)

#### Orden de actualización:
1. **BB_00_Global_Error_Handler** - Crítico, maneja errores
2. **BB_02_Security_Firewall** - Crítico, seguridad
3. **BB_04_Booking_Transaction** - Crítico, transacciones
4. **BB_03_02_ProviderData** - Alto, datos de proveedores
5. **BB_03_03_ScheduleConfig** - Alto, configuración
6. **BB_03_04_BookingsData** - Alto, reservas
7. **BB_05_Notification_Engine** - Medio, notificaciones
8. **BB_06_Admin_Dashboard** - Medio, administración
9. **BB_07_Notification_Retry_Worker** - Bajo, reintentos
10. **BB_01_Telegram_Gateway** - Bajo, gateway

#### Checklist por workflow:
```
Para cada workflow:
[ ] Cambiar typeVersion de 2.4 a 2.6 en todos los nodos Postgres
[ ] Ejecutar tests de funcionalidad
[ ] Verificar queries con valores null/0/false
[ ] Validar respuestas en casos edge
[ ] Documentar cambios en changelog del workflow
```

### Fase 3: Actualización de Webhooks v1 → v2 (Prioridad Media)

#### Workflows a actualizar:
1. **BB_01_Telegram_Gateway**
2. **BB_04_Main_Orchestrator**
3. **BB_05_Notification_Engine**
4. **BB_06_Admin_Dashboard**

#### Checklist por workflow:
```
Para cada workflow:
[ ] Cambiar typeVersion de 1 a 2 en nodo Webhook
[ ] Verificar que responseMode está correctamente configurado
[ ] Probar webhook con herramientas como Postman/curl
[ ] Validar respuestas HTTP
[ ] Documentar cambios
```

### Fase 4: Migración de Code Nodes con $env (Prioridad Crítica)

#### Workflow afectado: BB_00_Global_Error_Handler

**Nodo:** "Process Merged Data"

**Pasos:**
1. [ ] Crear variables de workflow en n8n:
   - `BB_ERROR_RATE_LIMIT` = 10
   - `BB_DEFAULT_ADMIN_CHAT_ID` = "5391760292"
   - `BB_DEFAULT_ADMIN_EMAIL` = "admin@autoagenda.cl"
   - `N8N_BASE_URL` = "https://n8n.autoagenda.cl"

2. [ ] Actualizar código del nodo:
   ```javascript
   // Reemplazar todas las instancias de $env.XXX por $vars.XXX
   ```

3. [ ] Probar con valores configurados
4. [ ] Validar fallbacks a valores por defecto
5. [ ] Documentar variables requeridas

### Fase 5: Validación Final

#### Tests de Integración:
- [ ] Flujo completo de reserva (BB_01 → BB_02 → BB_03 → BB_04 → BB_05)
- [ ] Manejo de errores (BB_00)
- [ ] Notificaciones (BB_05, BB_07)
- [ ] Dashboard admin (BB_06)

#### Tests de Regresión:
- [ ] Todos los endpoints webhook responden correctamente
- [ ] Queries Postgres retornan datos esperados
- [ ] Telegram envía mensajes correctamente
- [ ] Emails de fallback funcionan

---

## 4. Riesgos y Mitigaciones

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|---------|------------|
| Postgres v2.6 cambia comportamiento de queries | Media | Alto | Testing exhaustivo con valores edge |
| Webhook v2 rompe integraciones existentes | Baja | Alto | Mantener paths de webhook idénticos |
| Variables $env no disponibles | Alta | Crítico | Migrar a $vars antes de actualizar |
| Workflows no importan en nueva versión | Baja | Alto | Mantener backups y versionado |

---

## 5. Rollback Plan

En caso de problemas críticos:

1. **Inmediato:** Revertir typeVersion de nodos afectados a versiones anteriores
2. **Corto plazo:** Restaurar workflows desde backup
3. **Mediano plazo:** Analizar causa raíz y crear plan de corrección

### Puntos de Rollback por Fase:
- **Post-Fase 2:** Backup antes de actualizar Postgres
- **Post-Fase 3:** Backup antes de actualizar Webhooks
- **Post-Fase 4:** Backup antes de migrar Code Nodes

---

## 6. Cronograma Sugerido

| Fase | Duración Estimada | Dependencias |
|------|-------------------|--------------|
| Fase 1: Preparación | - | - |
| Fase 2: Postgres | - | Fase 1 |
| Fase 3: Webhooks | - | Fase 2 |
| Fase 4: Code Nodes | - | Fase 1 |
| Fase 5: Validación | - | Fases 2-4 |

---

## 7. Checklist Final de Migración

### Pre-Migración
- [ ] Backup completo de workflows
- [ ] Variables de workflow configuradas
- [ ] Ambiente de pruebas listo

### Durante Migración
- [ ] Postgres nodes actualizados a v2.6
- [ ] Webhook nodes actualizados a v2
- [ ] Code nodes migrados de $env a $vars
- [ ] Tests de cada workflow ejecutados

### Post-Migración
- [ ] Tests de integración pasando
- [ ] Monitoreo de errores activo
- [ ] Documentación actualizada
- [ ] SOT-N8N-2.4.6.md archivado

---

## 8. Referencias

- [docs/SOT-N8N-2.8.0.md](../docs/SOT-N8N-2.8.0.md) - Fuente de verdad para versiones
- [docs/SolucionFinal-v1.md](../docs/SolucionFinal-v1.md) - Pipeline de desarrollo
- [n8n Breaking Changes](https://docs.n8n.io/2-0-breaking-changes/) - Documentación oficial

---

**Documento creado:** 15 de Febrero, 2026
**Autor:** Kilo Code Architect
**Estado:** Pendiente de aprobación
