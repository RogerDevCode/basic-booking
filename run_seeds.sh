#!/usr/bin/env bash

# ============================================================================
# SEED DATA RUNNER - Ejecuta scripts SQL en Neon DB (1 a la vez)
# ============================================================================

NEON_URL="postgresql://neondb_owner@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
SEEDS_DIR="$(dirname "$0")/database/seeds"

echo "============================================================"
echo "SEED DATA RUNNER - BasicBooking"
echo "============================================================"
echo ""

run_script() {
    local script="$1"
    local path="${SEEDS_DIR}/${script}"
    
    if [[ ! -f "$path" ]]; then
        echo "  [SKIP] $script - archivo no encontrado"
        return 1
    fi
    
    echo "  Ejecutando: $script"
    
    if psql "$NEON_URL" -f "$path" 2>&1; then
        echo "  [OK] $script"
        return 0
    else
        echo "  [ERROR] $script"
        return 1
    fi
}

echo "Ejecutando scripts de seed data:"
echo ""

success=0
total=11

# 01_users.sql
run_script "01_users.sql" && ((success++)) || true
echo ""

# 02_providers.sql
run_script "02_providers.sql" && ((success++)) || true
echo ""

# 03_services.sql
run_script "03_services.sql" && ((success++)) || true
echo ""

# 04_schedules.sql
run_script "04_schedules.sql" && ((success++)) || true
echo ""

# 05_bookings.sql
run_script "05_bookings.sql" && ((success++)) || true
echo ""

# 06_firewall.sql
run_script "06_firewall.sql" && ((success++)) || true
echo ""

# 07_notifications.sql
run_script "07_notifications.sql" && ((success++)) || true
echo ""

# 08_circuit_breaker.sql
run_script "08_circuit_breaker.sql" && ((success++)) || true
echo ""

# 09_system_errors.sql
run_script "09_system_errors.sql" && ((success++)) || true
echo ""

# 10_audit_logs.sql
run_script "10_audit_logs.sql" && ((success++)) || true
echo ""

# 11_verify.sql
run_script "11_verify.sql" && ((success++)) || true
echo ""

echo "============================================================"
echo "Completado: $success/$total scripts exitosos"
echo "============================================================"
