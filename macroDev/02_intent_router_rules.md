# Paso 2 — Reglas del Intent Router (Switch v3)

> Objetivo: definir reglas claras de enrutamiento para comandos e intenciones, manteniendo un flujo **estable, testeable y compatible con n8n v2.4.6**.

---

## 0) Principios base (SOT-N8N-2.4.6)
- **Switch v3 obligatorio**, con **fallback** configurado.
- **Type checking estricto**: castear texto antes de comparar.
- **Guard Node** siempre antes del Router.
- **Retorno unificado**: `{ success, error_code, error_message, data }`.

---

## 1) Entradas esperadas del Router
**Payload mínimo**:
```/dev/null/payload.json#L1-18
{
  "success": true,
  "error_code": null,
  "error_message": null,
  "data": {
    "channel": "telegram|web",
    "user_id": "tg:123",
    "chat_id": "123",
    "text": "/book",
    "context": {
      "provider_slug": "proveedor-x"
    }
  }
}
```

---

## 2) Normalización previa (recomendado)
Antes del Switch, normaliza el texto:

- `intent_text = lower(trim(text))`
- Remueve múltiples espacios
- Si texto es vacío → fallback con `INTENT_EMPTY`

---

## 3) Matriz de enrutamiento (prioridad alta → baja)

### 3.1) Booking
**Reglas de match**:
- `/book`
- `/agendar`
- `agendar`
- `reservar`
- `book`

**Ruta**: `BB_04_Booking_Transaction`

---

### 3.2) Availability
**Reglas de match**:
- `/availability`
- `/disponibilidad`
- `disponibilidad`
- `horarios`
- `horas`
- `slots`

**Ruta**: `BB_03_Availability_Engine`

---

### 3.3) Cancelación
**Reglas de match**:
- `/cancel`
- `/cancelar`
- `cancelar`
- `anular`

**Ruta**: `BB_04_Booking_Transaction` (modo `cancel`)

---

### 3.4) Reprogramación
**Reglas de match**:
- `/reschedule`
- `/reprogramar`
- `reprogramar`
- `cambiar hora`

**Ruta**: `BB_04_Booking_Transaction` (modo `reschedule`)

---

### 3.5) Admin / Configuración
**Reglas de match**:
- `/admin`
- `/config`
- `/providers`
- `/dashboard`

**Ruta**: `BB_06_Admin_Dashboard`

> Nota: solo si `context.role === "admin"` o token válido.

---

### 3.6) Ayuda / FAQ
**Reglas de match**:
- `/help`
- `/ayuda`
- `ayuda`
- `faq`

**Ruta**: Respuesta informativa (template estático)

---

## 4) Fallback (obligatorio)
**Condición**: no match en ninguna regla.  
**Acción**:
- Loggear evento (audit)
- Responder con guía básica
- `error_code = INTENT_UNKNOWN`

**Salida fallback recomendada**:
```/dev/null/fallback.json#L1-13
{
  "success": false,
  "error_code": "INTENT_UNKNOWN",
  "error_message": "No se reconoció el comando.",
  "data": {
    "suggestions": ["/book", "/availability", "/help"]
  }
}
```

---

## 5) Reglas de seguridad adicionales
- Si `context.provider_slug` no existe → derivar a `/help`
- Si el usuario está bloqueado (`security_firewall`) → ruta a `BB_00_Global_Error_Handler`
- Si rate limit excedido → mensaje de espera + audit log

---

## 6) Checklist de tests mínimos
- ✅ `/book` → Booking
- ✅ `/availability` → Availability
- ✅ `texto desconocido` → Fallback
- ✅ `admin sin rol` → Acceso denegado
- ✅ `texto vacío` → INTENT_EMPTY

---

## 7) Ejemplo de condiciones (Switch v3)
> Usar **casteo string** y comparación exacta.
```/dev/null/switch-rules.txt#L1-6
{{ $json.data.text.toString().trim().toLowerCase() === '/book' }}
{{ $json.data.text.toString().trim().toLowerCase() === 'agendar' }}
{{ $json.data.text.toString().trim().toLowerCase() === '/availability' }}
```

---

## 8) Notas de mantenimiento
- Todas las nuevas intenciones deben agregarse aquí primero.
- Evitar regex complejos en el Switch; usar normalización previa.
- Mantener lista de intents documentada en `docs/`.

---