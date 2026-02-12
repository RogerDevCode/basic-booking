#!/bin/bash
# Script para probar todos los escenarios de error de BB_00

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   Test Automatizado: BB_00 - Todos los Escenarios         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Configuración
WEBHOOK_URL="${N8N_URL:-http://localhost:5678}/webhook/test-bb00-enhanced"
WAIT_TIME=3

# Array de tipos de test
declare -a test_types=(
    "critical_error:💥 Error Crítico"
    "validation_error:⚠️ Error de Validación"
    "timeout_error:⏱️ Error de Timeout"
    "null_reference:🔍 Referencia Nula"
    "unknown_type:❓ Tipo Desconocido"
)

echo "🎯 URL del webhook: $WEBHOOK_URL"
echo "⏱️  Tiempo de espera entre tests: ${WAIT_TIME}s"
echo ""

# Contador de tests
total_tests=${#test_types[@]}
current_test=0

# Ejecutar cada tipo de test
for test_info in "${test_types[@]}"; do
    IFS=':' read -r test_type description <<< "$test_info"
    ((current_test++))
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 Test $current_test/$total_tests: $description"
    echo "   Tipo: $test_type"
    echo ""
    
    # Ejecutar el test
    response=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"test_type\": \"$test_type\", \"message\": \"Test automatizado - $description\"}")
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    # Verificar respuesta
    if [ "$http_code" -eq 500 ] || [ "$http_code" -eq 400 ]; then
        echo "   ✅ Test ejecutado (HTTP $http_code - Error esperado)"
    elif [ "$http_code" -eq 200 ]; then
        echo "   ⚠️  Test ejecutado pero sin error (HTTP 200)"
        echo "   Respuesta: $body"
    else
        echo "   ❌ Error inesperado (HTTP $http_code)"
        echo "   Respuesta: $body"
    fi
    
    if [ $current_test -lt $total_tests ]; then
        echo ""
        echo "   ⏳ Esperando ${WAIT_TIME}s antes del siguiente test..."
        sleep $WAIT_TIME
        echo ""
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  Tests Completados                         ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Total de tests ejecutados: $total_tests"
echo ""
echo "🔍 Verificando ejecuciones de BB_00..."
echo ""

# Verificar ejecuciones de BB_00 (si N8N_API_KEY está disponible)
if [ -n "$N8N_API_KEY" ]; then
    BB00_EXECUTIONS=$(curl -s -X GET "${N8N_URL:-http://localhost:5678}/api/v1/executions?limit=20" \
        -H "X-N8N-API-KEY: ${N8N_API_KEY}" | \
        grep -c "BB_00_Global_Error_Handler" || echo "0")
    
    echo "✅ Ejecuciones de BB_00 en las últimas 20: $BB00_EXECUTIONS"
    
    if [ "$BB00_EXECUTIONS" -ge "$total_tests" ]; then
        echo "🎉 ¡Éxito! BB_00 capturó los errores correctamente"
    else
        echo "⚠️  Advertencia: Se esperaban al menos $total_tests ejecuciones"
    fi
else
    echo "⚠️  N8N_API_KEY no configurada - no se puede verificar ejecuciones"
    echo "   Verifica manualmente en n8n UI:"
    echo "   1. Abre BB_00_Global_Error_Handler_V2"
    echo "   2. Ve a la pestaña 'Executions'"
    echo "   3. Deberías ver $total_tests nuevas ejecuciones"
fi

echo ""
echo "✅ Script completado"
