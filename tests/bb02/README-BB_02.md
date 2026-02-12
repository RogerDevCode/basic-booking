# BB_02 Security Firewall - Tests & Documentation

## 📋 Descripción

El workflow **BB_02_Security_Firewall** actúa como gateway de seguridad para validar usuarios de Telegram antes de permitir acceso al sistema.

## 🔐 Lógica de Seguridad

### Orden de Evaluación (Prioridad)

1. **Validación de Input** - Verifica estructura del payload
2. **Firewall Block** - Verifica si el usuario está bloqueado
3. **User Ban** - Verifica si el usuario está baneado (soft deleted)
4. **User Exists** - Determina si es usuario nuevo o existente

### Estados Posibles

| Estado | success | access | reason | HTTP |
|--------|---------|--------|--------|------|
| Autorizado | true | granted | AUTHORIZED | 200 |
| Usuario Nuevo | true | granted | NEW_USER | 200 |
| Bloqueado Firewall | false | denied | FIREWALL_BLOCKED | 403 |
| Baneado | false | denied | USER_BANNED | 403 |
| Error Validación | false | error | VALIDATION_FAILED | 400 |
| Error Sistema | false | error | DATABASE_ERROR | 500 |

## 🧪 Tests

### Ejecutar Suite Completa

```bash
# Asegúrate de tener PGPASSWORD configurado
export PGPASSWORD="tu_password"

# Ejecutar tests
./test-db.py