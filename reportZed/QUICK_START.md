# ⚡ QUICK START - Fixes Críticos P0

> **Para desarrolladores con prisa**  
> Ejecuta estos comandos en orden para fix los 8 bugs críticos

---

## 🚨 ANTES DE EMPEZAR

```bash
# 1. BACKUP COMPLETO
pg_dump $DATABASE_URL > backup_$(date +%Y%m%d).sql
cd workflows && cp -r *.json backup_$(date +%Y%m%d)/ && cd ..
git commit -am "BACKUP: Pre-critical-fixes"

# 2. Variables requeridas
echo "JWT_SECRET=$(openssl rand -hex 32)" >> .env
echo "ADMIN_EMAIL=tu@email.com" >> .env
echo "ADMIN_TELEGRAM_CHAT_ID=123456789" >> .env

# 3. Reiniciar n8n
docker-compose restart n8n
```

---

## 🔥 FIX 1: JWT SEGURO (30 minutos)

### Instalar librería
```bash
docker exec n8n_container npm install jsonwebtoken@9.0.2
```

### Modificar BB_08
Abrir `workflows/BB_08_JWT_Auth_Helper.json`

Buscar nodo `Verify Token`, reemplazar jsCode con:
```javascript
const jwt = require('jsonwebtoken');
const token = $json.token;
const secret = process.env.JWT_SECRET;

if (!secret) throw new Error('JWT_SECRET not configured');

try {
  const payload = jwt.verify(token, secret, { algorithms: ['HS256'] });
  
  if (payload.role !== 'admin') {
    return [{ json: { error: true, status: 403, code: 'INSUFFICIENT_PERMISSIONS' } }];
  }
  
  return [{ json: { valid: true, user: payload } }];
} catch (e) {
  return [{ json: { error: true, status: 401, code: 'INVALID_TOKEN' } }];
}
```

### Test
```bash
curl -H "Authorization: Bearer FAKE_TOKEN" \
  http://localhost:5678/webhook-test/bb08-auth
# Esperado: {"error":true,"code":"INVALID_TOKEN"}
```

---

## 🔥 FIX 2: DOUBLE BOOKING (60 minutos)

### Crear función SQL
```bash
psql $DATABASE_URL << 'SQL'
CREATE OR REPLACE FUNCTION atomic_booking_check_and_lock(
    p_provider_id UUID,
    p_start_time TIMESTAMPTZ,
    p_end_time TIMESTAMPTZ
) RETURNS TABLE(is_available BOOLEAN, conflict_count INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM pg_advisory_xact_lock(
        hashtext(p_provider_id::text || p_start_time::text)
    );
    
    RETURN QUERY
    SELECT 
        (COUNT(*) = 0) AS is_available,
        COUNT(*)::INTEGER AS conflict_count
    FROM bookings
    WHERE provider_id = p_provider_id
      AND start_time < p_end_time
      AND end_time > p_start_time
      AND status IN ('pending', 'confirmed')
      AND deleted_at IS NULL;
END;
$$;
SQL
```

### Modificar BB_04
Nodo `db_lock`: cambiar query a:
```sql
SELECT * FROM atomic_booking_check_and_lock($1, $2, $3)
```

Agregar queryParameters:
```json
{
  "values": [
    {"value": "={{ $json.provider_id }}"},
    {"value": "={{ $json.start_time }}"},
    {"value": "={{ $json.end_time }}"}
  ]
}
```

### Test
```bash
# Lanzar 10 bookings simultáneos (ver tests/test_concurrent_booking.sh)
for i in {1..10}; do
  curl -X POST http://localhost:5678/webhook/bb04-book \
    -d '{"provider_id":"xxx","start_time":"2024-02-01T10:00:00Z",...}' &
done
wait

# Verificar solo 1 se creó
psql $DATABASE_URL -c "SELECT COUNT(*) FROM bookings WHERE start_time='2024-02-01T10:00:00Z'"
# Esperado: 1
```

---

## 🔥 FIX 3: SQL INJECTION (20 minutos)

### Modificar BB_02
Buscar TODOS los nodos con `executeQuery`, cambiar:

**ANTES:**
```sql
WHERE entity_id = '{{ $json.entity_id }}'
```

**DESPUÉS:**
```sql
WHERE entity_id = $1
```

Agregar queryParameters:
```json
{
  "queryParameters": {
    "values": [{"value": "={{ $json.entity_id }}"}]
  }
}
```

### Test
```bash
curl -X POST http://localhost:5678/webhook/security-v3 \
  -d '{"entity_id":"telegram:123\" OR \"1\"=\"1"}'
# Esperado: Manejo correcto (no bypass)
```

---

## 🔥 FIX 4: NOTIFICATION QUEUE (40 minutos)

### Crear tabla
```bash
psql $DATABASE_URL << 'SQL'
CREATE TABLE notification_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID REFERENCES bookings(id),
    user_id BIGINT NOT NULL,
    message TEXT NOT NULL,
    notification_type VARCHAR(20),
    status VARCHAR(20) DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX ON notification_queue(status, retry_count);
SQL
```

### Agregar config
```bash
psql $DATABASE_URL << 'SQL'
INSERT INTO app_config (key, value, category) VALUES
('REMINDER_1_HOURS', '24', 'notifications'),
('REMINDER_2_HOURS', '2', 'notifications'),
('NOTIFICATIONS_ENABLED', 'true', 'notifications');
SQL
```

### Modificar BB_05
Reemplazar query del nodo `Fetch`:
```sql
WITH config AS (
    SELECT 
        COALESCE((SELECT value::int FROM app_config WHERE key='REMINDER_1_HOURS'), 24) as r1_hours,
        COALESCE((SELECT value::int FROM app_config WHERE key='REMINDER_2_HOURS'), 2) as r2_hours
)
SELECT b.id as booking_id, u.telegram_id, u.first_name, b.start_time, p.name as pro_name,
    CASE 
        WHEN b.reminder_1_sent_at IS NULL AND b.start_time <= (NOW() + (c.r1_hours || ' hours')::INTERVAL) THEN 'r1'
        WHEN b.reminder_2_sent_at IS NULL AND b.start_time <= (NOW() + (c.r2_hours || ' hours')::INTERVAL) THEN 'r2'
    END as r_type
FROM bookings b
JOIN users u ON b.user_id = u.id
JOIN providers p ON b.provider_id = p.id
CROSS JOIN config c
WHERE b.status = 'confirmed' AND b.start_time > NOW()
LIMIT 50;
```

---

## 🔥 FIX 5-8: RÁPIDO (30 minutos total)

### FIX 5: Circuit Breaker
```bash
psql $DATABASE_URL << 'SQL'
CREATE TABLE circuit_breaker_state (
    workflow_name VARCHAR(200) PRIMARY KEY,
    is_open BOOLEAN DEFAULT FALSE,
    failure_count INTEGER DEFAULT 0,
    last_failure_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
SQL
```

### FIX 6: Compensación
```bash
psql $DATABASE_URL << 'SQL'
CREATE TABLE booking_compensation_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gcal_event_id VARCHAR(255),
    compensation_type VARCHAR(50),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);
SQL
```

### FIX 7: Ya cubierto en FIX 4

### FIX 8: Ya cubierto en FIX 1

---

## ✅ VALIDACIÓN FINAL

```bash
# Test 1: JWT funciona
curl -H "Authorization: Bearer $(node -e "const j=require('jsonwebtoken');console.log(j.sign({role:'admin'},process.env.JWT_SECRET))")" \
  http://localhost:5678/webhook-test/bb08-auth
# Esperado: {"valid":true}

# Test 2: No double booking
./tests/test_concurrent_booking.sh

# Test 3: SQL injection bloqueado
curl -d '{"entity_id":"x OR 1=1"}' http://localhost:5678/webhook/security-v3

# Test 4: Notificaciones funcionan
curl -X POST http://localhost:5678/webhook/notify-batch

# Test 5: Tablas creadas
psql $DATABASE_URL -c "\dt notification_queue"
psql $DATABASE_URL -c "\dt circuit_breaker_state"
```

---

## 🚨 ROLLBACK (Si algo falla)

```bash
# 1. Restore DB
psql $DATABASE_URL < backup_$(date +%Y%m%d).sql

# 2. Restore workflows
cd workflows/backup_$(date +%Y%m%d)/
for f in *.json; do
  curl -X POST http://localhost:5678/api/v1/workflows/import \
    -H "X-N8N-API-KEY: $API_KEY" -F "file=@$f"
done

# 3. Reiniciar
docker-compose restart n8n
```

---

## 📞 AYUDA

**Errores comunes:**
- `JWT_SECRET not found`: Agregar a `.env` y reiniciar
- `relation does not exist`: Ejecutar migrations SQL
- `jsonwebtoken not found`: `npm install` en container

**Documentación completa:**
- Análisis: `reportZed.md`
- Plan detallado: `reportZed_ActionPlan.md`
- Índice: `README_AUDIT.md`
