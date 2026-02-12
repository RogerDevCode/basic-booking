#!/bin/bash
# Script simple para probar BB_00 usando el workflow Test_BB00 existente

echo "╔════════════════════════════════════════════════════════════╗"
echo "║        Test Live de BB_00_Global_Error_Handler             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

N8N_URL="${N8N_URL:-http://localhost:5678}"
BB00_ID="_Za9GzqB2cS9HVwBglt43"
TEST_WF_ID="HzI1o1ZSBLrCType"

# Verificar que N8N_API_KEY esté configurada
if [ -z "$N8N_API_KEY" ]; then
    echo "❌ Error: N8N_API_KEY no está configurada"
    echo "   Ejecuta: export N8N_API_KEY=tu_api_key"
    exit 1
fi

# Step 1: Verificar BB_00
echo "📋 Step 1: Verificando BB_00..."
BB00_STATUS=$(curl -s "$N8N_URL/api/v1/workflows/$BB00_ID" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | \
    python3 -c "import json, sys; d=json.load(sys.stdin); print(f'{d[\"name\"]}|{d.get(\"active\", False)}')" 2>/dev/null)

if [ -z "$BB00_STATUS" ]; then
    echo "   ❌ No se pudo obtener información de BB_00"
    exit 1
fi

IFS='|' read -r BB00_NAME BB00_ACTIVE <<< "$BB00_STATUS"
echo "   ✅ BB_00 encontrado: $BB00_NAME"
echo "   Estado: $([ "$BB00_ACTIVE" = "True" ] && echo "🟢 Activo" || echo "🔴 Inactivo")"

# Step 2: Contar ejecuciones actuales
echo ""
echo "📋 Step 2: Contando ejecuciones actuales de BB_00..."
EXECS_BEFORE=$(curl -s "$N8N_URL/api/v1/executions?limit=50" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | \
    grep -c "\"workflowId\":\"$BB00_ID\"" || echo "0")
echo "   Ejecuciones actuales: $EXECS_BEFORE"

# Step 3: Ejecutar el workflow de test manualmente desde n8n UI
echo ""
echo "📋 Step 3: Disparando test..."
echo "   ⚠️  Nota: Debes ejecutar el workflow Test_BB00 manualmente desde n8n UI"
echo "   URL: $N8N_URL/workflow/$TEST_WF_ID"
echo ""
echo "   Opciones para ejecutar el test:"
echo "   1. Abre la URL arriba y haz clic en 'Execute Workflow'"
echo "   2. O ejecuta este comando en otra terminal:"
echo ""
echo "      # Opción A: Ejecutar desde n8n UI (recomendado)"
echo "      xdg-open $N8N_URL/workflow/$TEST_WF_ID"
echo ""
echo "   Presiona ENTER cuando hayas ejecutado el workflow..."
read -r

# Step 4: Esperar procesamiento
echo ""
echo "📋 Step 4: Esperando a que BB_00 procese..."
echo "   ⏳ Esperando 3 segundos..."
sleep 3

# Step 5: Verificar nuevas ejecuciones
echo ""
echo "📋 Step 5: Verificando nuevas ejecuciones de BB_00..."
EXECS_AFTER=$(curl -s "$N8N_URL/api/v1/executions?limit=50" \
    -H "X-N8N-API-KEY: $N8N_API_KEY" | \
    grep -c "\"workflowId\":\"$BB00_ID\"" || echo "0")

NEW_EXECS=$((EXECS_AFTER - EXECS_BEFORE))

echo "   Ejecuciones antes: $EXECS_BEFORE"
echo "   Ejecuciones después: $EXECS_AFTER"
echo "   Nuevas ejecuciones: $NEW_EXECS"

echo ""
if [ "$NEW_EXECS" -gt 0 ]; then
    echo "✅ ¡ÉXITO! BB_00 capturó el error"
    echo ""
    echo "   📊 Detalles de la última ejecución:"
    curl -s "$N8N_URL/api/v1/executions?limit=10" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" | \
        python3 -c "
import json, sys
data = json.load(sys.stdin)
bb00_execs = [e for e in data['data'] if e.get('workflowId') == '$BB00_ID']
if bb00_execs:
    latest = bb00_execs[0]
    print(f'      ID: {latest[\"id\"]}')
    print(f'      Status: {latest[\"status\"]}')
    print(f'      Inicio: {latest.get(\"startedAt\", \"N/A\")[:19]}')
    if latest['status'] == 'success':
        print('\n🎉 ¡PERFECTO! BB_00 procesó el error exitosamente')
    else:
        print(f'\n⚠️  BB_00 terminó con status: {latest[\"status\"]}')
" 2>/dev/null
else
    echo "❌ FALLO: BB_00 no registró nuevas ejecuciones"
    echo ""
    echo "   Verifica manualmente:"
    echo "   $N8N_URL/workflow/$BB00_ID"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
