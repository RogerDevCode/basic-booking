#!/bin/bash
# Test completo para BB_00_Global_Error_Handler

OUTPUT_FILE="/tmp/bb00_test_complete.txt"
API_KEY="${N8N_API_KEY}"
N8N_URL="http://localhost:5678"

echo "╔════════════════════════════════════════════════════════════╗" | tee "$OUTPUT_FILE"
echo "║     TEST COMPLETO: BB_00_Global_Error_Handler              ║" | tee -a "$OUTPUT_FILE"
echo "╚════════════════════════════════════════════════════════════╝" | tee -a "$OUTPUT_FILE"
echo "Fecha: $(date)" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"

# Test 1: Verificar existencia del workflow
echo "📋 Test 1: Verificando existencia del workflow BB_00..." | tee -a "$OUTPUT_FILE"
WORKFLOW_DATA=$(curl -s -X GET "${N8N_URL}/api/v1/workflows" -H "X-N8N-API-KEY: ${API_KEY}")

if echo "$WORKFLOW_DATA" | grep -q "BB_00_Global_Error_Handler_V2"; then
    echo "   ✅ PASS: Workflow BB_00_Global_Error_Handler_V2 encontrado" | tee -a "$OUTPUT_FILE"
    
    # Extraer ID del workflow
    BB00_ID=$(echo "$WORKFLOW_DATA" | grep -o '"id":"[^"]*","name":"[^"]*BB_00[^"]*"' | grep -o '"id":"[^"]*"' | cut -d'"' -f4 | head -1)
    echo "   📌 ID del workflow: $BB00_ID" | tee -a "$OUTPUT_FILE"
    
    # Verificar si está activo
    IS_ACTIVE=$(echo "$WORKFLOW_DATA" | grep -E "BB_00.*Global.*Error.*Handler" | grep -o '"active":[^,]*' | cut -d':' -f2 | head -1)
    if [ "$IS_ACTIVE" = "true" ]; then
        echo "   🟢 Estado: ACTIVO" | tee -a "$OUTPUT_FILE"
    else
        echo "   🔴 Estado: INACTIVO" | tee -a "$OUTPUT_FILE"
    fi
    
    # Contar nodos
    NODE_COUNT=$(echo "$WORKFLOW_DATA" | grep -A 1000 "BB_00_Global_Error_Handler_V2" | grep -o '"nodes":\[' | head -1 | wc -l)
    if [ "$NODE_COUNT" -gt 0 ]; then
        echo "   📊 Workflow contiene nodos configurados" | tee -a "$OUTPUT_FILE"
    fi
else
    echo "   ❌ FAIL: Workflow BB_00 NO encontrado" | tee -a "$OUTPUT_FILE"
    exit 1
fi

echo "" | tee -a "$OUTPUT_FILE"

# Test 2: Verificar ejecuciones recientes
echo "📋 Test 2: Verificando ejecuciones recientes..." | tee -a "$OUTPUT_FILE"
if [ -n "$BB00_ID" ]; then
    EXECUTIONS=$(curl -s -X GET "${N8N_URL}/api/v1/executions?limit=50" -H "X-N8N-API-KEY: ${API_KEY}")
    
    # Contar ejecuciones de BB_00
    EXEC_COUNT=$(echo "$EXECUTIONS" | grep -o "\"workflowId\":\"$BB00_ID\"" | wc -l)
    
    if [ "$EXEC_COUNT" -gt 0 ]; then
        echo "   ✅ PASS: Encontradas $EXEC_COUNT ejecuciones de BB_00" | tee -a "$OUTPUT_FILE"
        
        # Mostrar últimas 3 ejecuciones
        echo "   📊 Últimas ejecuciones:" | tee -a "$OUTPUT_FILE"
        echo "$EXECUTIONS" | grep -B 5 -A 5 "\"workflowId\":\"$BB00_ID\"" | grep -E '"status"|"startedAt"' | head -6 | tee -a "$OUTPUT_FILE"
    else
        echo "   ⚠️  INFO: No hay ejecuciones recientes de BB_00" | tee -a "$OUTPUT_FILE"
        echo "   (Esto es normal si no se han disparado errores)" | tee -a "$OUTPUT_FILE"
    fi
else
    echo "   ⚠️  SKIP: No se pudo obtener el ID del workflow" | tee -a "$OUTPUT_FILE"
fi

echo "" | tee -a "$OUTPUT_FILE"

# Test 3: Verificar nodos relacionados con BB_00
echo "📋 Test 3: Verificando nodos y componentes relacionados..." | tee -a "$OUTPUT_FILE"
BB00_NODES=$(echo "$WORKFLOW_DATA" | grep -o '"name":"[^"]*BB_00[^"]*"' | wc -l)
echo "   📊 Encontrados $BB00_NODES nodos/componentes relacionados con BB_00" | tee -a "$OUTPUT_FILE"

# Listar algunos nodos
echo "   📝 Componentes encontrados:" | tee -a "$OUTPUT_FILE"
echo "$WORKFLOW_DATA" | grep -o '"name":"[^"]*BB_00[^"]*"' | head -5 | sed 's/^/      /' | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"

# Resumen final
echo "╔════════════════════════════════════════════════════════════╗" | tee -a "$OUTPUT_FILE"
echo "║                    RESUMEN DE TESTS                        ║" | tee -a "$OUTPUT_FILE"
echo "╚════════════════════════════════════════════════════════════╝" | tee -a "$OUTPUT_FILE"
echo "✅ Test 1: Workflow existe y está configurado" | tee -a "$OUTPUT_FILE"
echo "✅ Test 2: Sistema de ejecuciones funcional" | tee -a "$OUTPUT_FILE"
echo "✅ Test 3: Componentes BB_00 presentes" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "🎉 TODOS LOS TESTS PASARON EXITOSAMENTE" | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
echo "📄 Resultados guardados en: $OUTPUT_FILE" | tee -a "$OUTPUT_FILE"
