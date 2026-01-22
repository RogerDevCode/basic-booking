#!/bin/bash
#
# COMPREHENSIVE TEST SUITE: BB_02 Security Firewall
# Cubre: Básicos, Boundary Values, Inválidos, Inyección, Type Confusion, Extremos
#

set -e

BASE_URL="${N8N_BASE_URL:-https://n8n.stax.ink}"
ENDPOINT="/webhook/test/firewall"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function
run_test() {
    local test_name="$1"
    local payload="$2"
    local expected_status="$3"
    local description="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Test #${TOTAL_TESTS}: ${test_name}${NC}"
    echo -e "${BLUE}Description:${NC} ${description}"
    echo -e "${BLUE}Expected HTTP Status:${NC} ${expected_status}"
    echo ""
    
    response=$(curl -X POST "${BASE_URL}${ENDPOINT}" \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        -w "\n__STATUS_CODE__:%{http_code}" \
        -s)
    
    status_code=$(echo "$response" | grep "__STATUS_CODE__" | cut -d: -f2)
    body=$(echo "$response" | grep -v "__STATUS_CODE__")
    
    echo -e "${BLUE}Response Body:${NC}"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    echo -e "\n${BLUE}Actual HTTP Status:${NC} ${status_code}"
    
    if [ "$status_code" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL (Expected ${expected_status}, got ${status_code})${NC}"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    echo ""
    sleep 0.5  # Rate limiting friendly
}

echo "═══════════════════════════════════════════════════════════════"
echo "  BB_02 Security Firewall - COMPREHENSIVE TEST SUITE"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# ===================================================================
# CATEGORÍA 1: TESTS BÁSICOS (Funcionalidad Core)
# ===================================================================
echo -e "${GREEN}═══ CATEGORÍA 1: TESTS BÁSICOS ═══${NC}\n"

run_test "BASIC-01: Usuario válido con RUT" \
'{"user":{"telegram_id":5391760292,"rut":"12345678-9"},"routing":{"intent":"cmd_book","target_date":"2026-01-21"}}' \
"200" \
"Usuario existente, RUT válido, debe pasar firewall"

run_test "BASIC-02: Usuario válido sin RUT" \
'{"user":{"telegram_id":999888777},"routing":{"intent":"cmd_start"}}' \
"200" \
"Usuario nuevo sin RUT, debe permitir registro"

run_test "BASIC-03: Intent vacío (opcional)" \
'{"user":{"telegram_id":123456789},"routing":{}}' \
"200" \
"Routing.intent es opcional, debe pasar"

# ===================================================================
# CATEGORÍA 2: BOUNDARY VALUES (Valores Límite)
# ===================================================================
echo -e "\n${GREEN}═══ CATEGORÍA 2: BOUNDARY VALUES ═══${NC}\n"

run_test "BOUNDARY-01: telegram_id mínimo (1)" \
'{"user":{"telegram_id":1},"routing":{"intent":"test"}}' \
"200" \
"El número 1 es el mínimo positivo válido"

run_test "BOUNDARY-02: telegram_id máximo safe integer" \
'{"user":{"telegram_id":9007199254740991},"routing":{"intent":"test"}}' \
"200" \
"2^53-1 es el máximo safe integer en JavaScript"

run_test "BOUNDARY-03: telegram_id = 0 (inválido)" \
'{"user":{"telegram_id":0},"routing":{"intent":"test"}}' \
"400" \
"Cero no es un telegram_id válido"

run_test "BOUNDARY-04: RUT mínimo válido" \
'{"user":{"telegram_id":123,"rut":"1-0"},"routing":{}}' \
"200" \
"RUT más corto posible con formato válido"

run_test "BOUNDARY-05: RUT máximo válido" \
'{"user":{"telegram_id":123,"rut":"99999999-9"},"routing":{}}' \
"200" \
"RUT chileno de 8 dígitos + verificador"

run_test "BOUNDARY-06: Intent con 1 caracter" \
'{"user":{"telegram_id":123},"routing":{"intent":"a"}}' \
"200" \
"String mínimo no vacío"

# ===================================================================
# CATEGORÍA 3: INPUTS INVÁLIDOS (Validation Tests)
# ===================================================================
echo -e "\n${GREEN}═══ CATEGORÍA 3: INPUTS INVÁLIDOS ═══${NC}\n"

run_test "INVALID-01: user = null" \
'{"user":null,"routing":{}}' \
"400" \
"Campo user es requerido"

run_test "INVALID-02: user = [] (array)" \
'{"user":[],"routing":{}}' \
"400" \
"User debe ser objeto, no array"

run_test "INVALID-03: user = string" \
'{"user":"not an object","routing":{}}' \
"400" \
"User debe ser objeto, no string"

run_test "INVALID-04: telegram_id = null" \
'{"user":{"telegram_id":null},"routing":{}}' \
"400" \
"telegram_id es requerido, no puede ser null"

run_test "INVALID-05: telegram_id = empty string" \
'{"user":{"telegram_id":""},"routing":{}}' \
"400" \
"String vacío debe ser rechazado"

run_test "INVALID-06: telegram_id = NaN string" \
'{"user":{"telegram_id":"abc123"},"routing":{}}' \
"400" \
"String no numérico debe fallar validación"

run_test "INVALID-07: telegram_id negativo" \
'{"user":{"telegram_id":-99999},"routing":{}}' \
"400" \
"Números negativos no son IDs válidos"

run_test "INVALID-08: RUT formato inválido" \
'{"user":{"telegram_id":123,"rut":"12345678"},"routing":{}}' \
"400" \
"RUT sin guión debe ser rechazado"

run_test "INVALID-09: RUT con letras" \
'{"user":{"telegram_id":123,"rut":"abcd-efgh"},"routing":{}}' \
"400" \
"RUT debe tener formato 12345678-K"

run_test "INVALID-10: routing = null" \
'{"user":{"telegram_id":123},"routing":null}' \
"400" \
"Routing es requerido"

run_test "INVALID-11: routing.intent = object" \
'{"user":{"telegram_id":123},"routing":{"intent":{"nested":"object"}}}' \
"400" \
"Intent debe ser string, no objeto"

run_test "INVALID-12: routing.intent = empty string" \
'{"user":{"telegram_id":123},"routing":{"intent":""}}' \
"400" \
"Intent no puede ser string vacío si se provee"

run_test "INVALID-13: Payload completamente vacío" \
'{}' \
"400" \
"Objeto vacío debe fallar validación de campos requeridos"

# ===================================================================
# CATEGORÍA 4: ATAQUES DE INYECCIÓN (Security Tests)
# ===================================================================
echo -e "\n${GREEN}═══ CATEGORÍA 4: ATAQUES DE INYECCIÓN ═══${NC}\n"

run_test "INJECTION-01: SQL Injection en telegram_id" \
'{"user":{"telegram_id":"1 OR 1=1"},"routing":{}}' \
"400" \
"SQL injection debe fallar validación numérica"

run_test "INJECTION-02: SQL Injection en RUT" \
'{"user":{"telegram_id":123,"rut":"'"'"'; DROP TABLE users; --"},"routing":{}}' \
"400" \
"SQL injection en RUT debe fallar regex"

run_test "INJECTION-03: XSS en intent" \
'{"user":{"telegram_id":123},"routing":{"intent":"<script>alert(1)</script>"}}' \
"200" \
"XSS pasa validación pero debe ser escapado en DB/output"

run_test "INJECTION-04: Command Injection" \
'{"user":{"telegram_id":123},"routing":{"intent":"; rm -rf /"}}' \
"200" \
"Command injection pasa (es solo string), debe ser sanitizado en uso"

run_test "INJECTION-05: NoSQL Injection" \
'{"user":{"telegram_id":{"$ne":null}},"routing":{}}' \
"400" \
"Objeto en telegram_id debe fallar validación de tipo"

run_test "INJECTION-06: Path Traversal" \
'{"user":{"telegram_id":123,"rut":"../../../etc/passwd"},"routing":{}}' \
"400" \
"Path traversal debe fallar regex de RUT"

run_test "INJECTION-07: Null Byte Injection" \
'{"user":{"telegram_id":"123\u0000admin"},"routing":{}}' \
"400" \
"Null byte en número causa NaN, debe ser rechazado por seguridad"

# ===================================================================
# CATEGORÍA 5: TYPE CONFUSION (Coerción de Tipos)
# ===================================================================
echo -e "\n${GREEN}═══ CATEGORÍA 5: TYPE CONFUSION ═══${NC}\n"

run_test "TYPECONF-01: telegram_id como string numérico" \
'{"user":{"telegram_id":"5391760292"},"routing":{}}' \
"200" \
"String numérico debe convertirse correctamente"

run_test "TYPECONF-02: telegram_id = true" \
'{"user":{"telegram_id":true},"routing":{}}' \
"200" \
"Boolean true se convierte a 1 (válido)"

run_test "TYPECONF-03: telegram_id = false" \
'{"user":{"telegram_id":false},"routing":{}}' \
"400" \
"Boolean false se convierte a 0 (inválido)"

run_test "TYPECONF-04: telegram_id = array con número" \
'{"user":{"telegram_id":[123]},"routing":{}}' \
"200" \
"Array [123] se convierte a número 123"

run_test "TYPECONF-05: RUT como número" \
'{"user":{"telegram_id":123,"rut":12345678},"routing":{}}' \
"400" \
"Número debe fallar validación de tipo string"

# ===================================================================
# CATEGORÍA 6: CASOS EXTREMOS (Edge Cases)
# ===================================================================
echo -e "\n${GREEN}═══ CATEGORÍA 6: CASOS EXTREMOS ═══${NC}\n"

# Generate valid JSON with 100 extra fields using Python
PAYLOAD_35=$(python3 << 'EOFPYTHON'
import json
payload = {"user": {"telegram_id": 123}, "routing": {}}
for i in range(1, 101):
    payload["user"][f"extra_{i}"] = f"value_{i}"
print(json.dumps(payload))
EOFPYTHON
)

run_test "EXTREME-01: 100 campos extra en payload" \
"${PAYLOAD_35}" \
"200" \
"Campos extra deben ser ignorados"

run_test "EXTREME-02: Unicode extremo (emojis)" \
'{"user":{"telegram_id":123},"routing":{"intent":"🔥💯🚀😎👍"}}' \
"200" \
"Emojis deben ser aceptados como strings UTF-8"

run_test "EXTREME-03: Whitespace extremo" \
'{"user":{"telegram_id":"    123    "},"routing":{"intent":"                "}}' \
"400" \
"Whitespace puro en intent debe ser rechazado"

run_test "EXTREME-04: Intent muy largo (1000 chars)" \
"{\"user\":{\"telegram_id\":123},\"routing\":{\"intent\":\"$(printf 'a%.0s' {1..1000})\"}}" \
"200" \
"String muy largo debe ser aceptado (sin límite definido)"

run_test "EXTREME-05: Caracteres de control" \
'{"user":{"telegram_id":123},"routing":{"intent":"test\u001f\u0000\u001b"}}' \
"200" \
"Caracteres de control pasan validación pero pueden causar problemas"

# ===================================================================
# RESUMEN FINAL
# ===================================================================
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "  RESUMEN DE EJECUCIÓN"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo -e "Total de tests ejecutados: ${BLUE}${TOTAL_TESTS}${NC}"
echo -e "Tests exitosos (PASS):     ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Tests fallidos (FAIL):     ${RED}${FAILED_TESTS}${NC}"
echo ""

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ TODOS LOS TESTS PASARON${NC}"
    exit 0
else
    PASS_RATE=$(awk "BEGIN {printf \"%.1f\", ($PASSED_TESTS/$TOTAL_TESTS)*100}")
    echo -e "${YELLOW}⚠ Tasa de éxito: ${PASS_RATE}%${NC}"
    echo -e "${RED}✗ Hay ${FAILED_TESTS} test(s) fallido(s) que requieren atención${NC}"
    exit 1
fi
