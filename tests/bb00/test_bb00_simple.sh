#!/bin/bash
# Test simple para BB_00

OUTPUT_FILE="/tmp/bb00_test_results.txt"

echo "=== TEST DE BB_00_Global_Error_Handler ===" > "$OUTPUT_FILE"
echo "Fecha: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Test 1: Verificar que el workflow existe
echo "📋 Test 1: Verificando existencia del workflow..." >> "$OUTPUT_FILE"
WORKFLOW_DATA=$(curl -s -X GET "http://localhost:5678/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}")

if echo "$WORKFLOW_DATA" | grep -q "BB_00_Global_Error_Handler"; then
    echo "✅ PASS: Workflow BB_00 encontrado" >> "$OUTPUT_FILE"
    
    # Extraer detalles básicos
    echo "" >> "$OUTPUT_FILE"
    echo "Detalles del workflow:" >> "$OUTPUT_FILE"
    echo "$WORKFLOW_DATA" | grep -o '"name":"[^"]*BB_00[^"]*"' >> "$OUTPUT_FILE"
else
    echo "❌ FAIL: Workflow BB_00 NO encontrado" >> "$OUTPUT_FILE"
    exit 1
fi

echo "" >> "$OUTPUT_FILE"
echo "=== FIN DEL TEST ===" >> "$OUTPUT_FILE"

# Mostrar resultados
cat "$OUTPUT_FILE"
