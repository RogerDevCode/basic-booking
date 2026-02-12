# Fixtures — Guía de uso

Este directorio contiene **fixtures JSON** para pruebas rápidas de workflows y del macro‑workflow.

## ¿Qué hay aquí?
- `telegram_webhook_valid.json`
- `telegram_webhook_invalid.json`
- `availability_valid.json`
- `availability_no_slots.json`
- `booking_valid.json`
- `booking_slot_taken.json`
- `admin_valid.json`
- `admin_invalid_jwt.json`

## Uso manual en n8n (rápido)
1. Abre el workflow que quieres probar.
2. Agrega un **Set** o **Code** al inicio.
3. Pega el contenido del fixture como payload.
4. Ejecuta el flujo y verifica la salida.

## Uso con Execute Workflow
1. En el flujo de test, usa **Execute Workflow**.
2. Activa **Input data** y pasa el JSON del fixture.
3. Verifica que la salida cumpla el contrato:
   `{ success, error_code, error_message, data }`.

## Fixtures sugeridos por módulo
- **Entrada Telegram**: `telegram_webhook_valid.json`
- **Availability**: `availability_valid.json`, `availability_no_slots.json`
- **Booking**: `booking_valid.json`, `booking_slot_taken.json`
- **Admin**: `admin_valid.json`, `admin_invalid_jwt.json`

## Notas
- Ajusta `provider_slug`, `user_id` y fechas para tu entorno local.
- Mantén UTC para `start/end` y usa `timezone` solo para presentación.
- Los fixtures son **base** y pueden duplicarse para casos específicos.
