#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../scripts-py')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
BB_02_Security_Firewall - Comprehensive Test Suite
Pruebas exhaustivas de validación, límites y casos edge

Ejecutar: python3 test_bb02_comprehensive.py
"""

import json
import sys
from datetime import datetime
from typing import Optional, Dict, Any, List, Tuple
from dataclasses import dataclass

# ============================================
# CONFIGURACIÓN
# ============================================

N8N_BASE_URL = "https://n8n.stax.ink"
WEBHOOK_PATH = "/webhook/689841d2-b2a8-4329-b118-4e8675a810be"
REQUEST_TIMEOUT = 30
VERIFY_SSL = True

try:
    import requests
except ImportError:
    print("❌ Módulo 'requests' no instalado")
    print("   Ejecutar: sudo apt install python3-requests")
    sys.exit(1)

# ============================================
# COLORES
# ============================================

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    RESET = '\033[0m'
    BOLD = '\033[1m'

# ============================================
# DATACLASSES PARA TESTS
# ============================================

@dataclass
class TestCase:
    id: str
    name: str
    category: str
    payload: Dict[str, Any]
    expected_success: bool
    expected_access: str
    expected_reason: str
    validation_func: Optional[callable] = None
    description: str = ""

# ============================================
# HELPERS
# ============================================

WEBHOOK_URL = f"{N8N_BASE_URL}{WEBHOOK_PATH}"

def print_header(text: str, char: str = "="):
    print(f"\n{Colors.BOLD}{Colors.BLUE}{char*70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{text.center(70)}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.BLUE}{char*70}{Colors.RESET}\n")

def print_category(text: str):
    print(f"\n{Colors.BOLD}{Colors.MAGENTA}{'─'*70}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}📂 {text}{Colors.RESET}")
    print(f"{Colors.BOLD}{Colors.MAGENTA}{'─'*70}{Colors.RESET}")

def print_test(test_id: str, name: str):
    print(f"\n{Colors.CYAN}▶ [{test_id}] {name}{Colors.RESET}")

def print_pass(msg: str = "PASS"):
    print(f"  {Colors.GREEN}✓ {msg}{Colors.RESET}")

def print_fail(msg: str = "FAIL"):
    print(f"  {Colors.RED}✗ {msg}{Colors.RESET}")

def print_info(msg: str):
    print(f"  {Colors.YELLOW}ℹ {msg}{Colors.RESET}")

def print_warning(msg: str):
    print(f"  {Colors.YELLOW}⚠️  {msg}{Colors.RESET}")

def send_request(payload: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Envía request y retorna respuesta estructurada."""
    try:
        response = requests.post(
            WEBHOOK_URL,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=REQUEST_TIMEOUT,
            verify=VERIFY_SSL
        )
        
        try:
            body = response.json()
        except json.JSONDecodeError:
            body = {"raw_response": response.text, "parse_error": True}
        
        return {
            "status_code": response.status_code,
            "body": body,
            "success": True
        }
        
    except Exception as e:
        print_fail(f"Request failed: {e}")
        return None

def validate_response_structure(response: Dict[str, Any], test: TestCase) -> Tuple[bool, List[str]]:
    """Valida la estructura completa de la respuesta."""
    errors = []
    body = response.get("body", {})
    
    # Validar campos obligatorios
    required_fields = ["success", "access", "timestamp"]
    for field in required_fields:
        if field not in body:
            errors.append(f"Campo obligatorio '{field}' faltante")
    
    # Validar success
    if body.get("success") != test.expected_success:
        errors.append(f"success = {body.get('success')} (expected: {test.expected_success})")
    
    # Validar access
    if body.get("access") != test.expected_access:
        errors.append(f"access = '{body.get('access')}' (expected: '{test.expected_access}')")
    
    # Validar reason
    if body.get("reason") != test.expected_reason:
        errors.append(f"reason = '{body.get('reason')}' (expected: '{test.expected_reason}')")
    
    # Validaciones específicas por tipo de acceso
    if test.expected_access == "granted":
        if "security" not in body or not isinstance(body["security"], dict):
            errors.append("Campo 'security' faltante o inválido en acceso granted")
        else:
            sec = body["security"]
            required_sec = ["telegram_id", "entity_id", "status"]
            for field in required_sec:
                if field not in sec:
                    errors.append(f"security.{field} faltante")
    
    elif test.expected_access == "denied":
        if "error_message" not in body:
            errors.append("Campo 'error_message' faltante en acceso denied")
    
    elif test.expected_access == "error":
        if "error_message" not in body:
            errors.append("Campo 'error_message' faltante en error")
        if test.expected_reason == "VALIDATION_FAILED":
            if "validation_errors" not in body:
                errors.append("Campo 'validation_errors' faltante en validación")
    
    # Validación custom si existe
    if test.validation_func:
        custom_errors = test.validation_func(body)
        if custom_errors:
            errors.extend(custom_errors)
    
    return len(errors) == 0, errors

# ============================================
# FUNCIONES DE VALIDACIÓN CUSTOM
# ============================================

def validate_new_user(body: Dict) -> List[str]:
    """Validaciones específicas para NEW_USER."""
    errors = []
    sec = body.get("security", {})
    
    if sec.get("user_id") is not None:
        errors.append("NEW_USER debe tener user_id = null")
    if sec.get("role") != "guest":
        errors.append("NEW_USER debe tener role = 'guest'")
    if sec.get("status") != "new":
        errors.append("NEW_USER debe tener status = 'new'")
    if body.get("next_step") != "register":
        errors.append("NEW_USER debe tener next_step = 'register'")
    
    return errors

def validate_authorized_user(body: Dict) -> List[str]:
    """Validaciones específicas para AUTHORIZED."""
    errors = []
    sec = body.get("security", {})
    
    if sec.get("status") != "active":
        errors.append("AUTHORIZED debe tener status = 'active'")
    if body.get("next_step") != "authorized":
        errors.append("AUTHORIZED debe tener next_step = 'authorized'")
    
    return errors

def validate_routing_preserved(body: Dict) -> List[str]:
    """Valida que routing se preserve correctamente."""
    errors = []
    routing = body.get("routing", {})
    
    if not isinstance(routing, dict):
        errors.append("routing debe ser un objeto")
    
    return errors

# ============================================
# DEFINICIÓN DE TESTS
# ============================================

def get_all_tests() -> List[TestCase]:
    """Retorna lista completa de tests organizados por categoría."""
    
    tests = []
    
    # ========================================
    # CATEGORÍA 1: VALIDACIÓN DE ENTRADA
    # ========================================
    
    # Payload vacío/inválido
    tests.extend([
        TestCase(
            id="V01",
            name="Payload completamente vacío",
            category="Validación Entrada",
            payload={},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
            description="Request sin datos debe fallar"
        ),
        TestCase(
            id="V02",
            name="Payload null",
            category="Validación Entrada",
            payload=None,
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="V03",
            name="user faltante",
            category="Validación Entrada",
            payload={"other_field": "value"},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="V04",
            name="user = null",
            category="Validación Entrada",
            payload={"user": None},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="V05",
            name="user como array",
            category="Validación Entrada",
            payload={"user": []},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="V06",
            name="user como string",
            category="Validación Entrada",
            payload={"user": "invalid"},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
    ])
    
    # ========================================
    # CATEGORÍA 2: VALIDACIÓN telegram_id
    # ========================================
    
    tests.extend([
        TestCase(
            id="T01",
            name="telegram_id faltante",
            category="Validación telegram_id",
            payload={"user": {}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T02",
            name="telegram_id = null",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": None}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T03",
            name="telegram_id = 0",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 0}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T04",
            name="telegram_id negativo",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": -123}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T05",
            name="telegram_id muy pequeño (< 10)",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 5}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T06",
            name="telegram_id en límite inferior válido",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 10}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="T07",
            name="telegram_id normal (9 dígitos)",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 123456789}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="T08",
            name="telegram_id grande (12 dígitos)",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 999888777666}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="T09",
            name="telegram_id excede límite",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 99999999999999}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T10",
            name="telegram_id como string numérico válido",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": "777888999"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="T11",
            name="telegram_id string no numérico",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": "abc123"}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T12",
            name="telegram_id con espacios",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": " 123456789 "}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="T13",
            name="telegram_id float",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": 123.456}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="T14",
            name="telegram_id boolean",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": True}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="T15",
            name="telegram_id objeto",
            category="Validación telegram_id",
            payload={"user": {"telegram_id": {"value": 123}}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
    ])
    
    # ========================================
    # CATEGORÍA 3: VALIDACIÓN first_name
    # ========================================
    
    tests.extend([
        TestCase(
            id="F01",
            name="first_name vacío",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100100, "first_name": ""}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="F02",
            name="first_name solo espacios",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100101, "first_name": "   "}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="F03",
            name="first_name normal",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100102, "first_name": "Juan"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="F04",
            name="first_name con acentos",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100103, "first_name": "José María"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="F05",
            name="first_name muy largo (>255)",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100104, "first_name": "A" * 300}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="F06",
            name="first_name en límite (255)",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100105, "first_name": "B" * 255}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="F07",
            name="first_name no string (número)",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100106, "first_name": 12345}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="F08",
            name="first_name con emojis",
            category="Validación first_name",
            payload={"user": {"telegram_id": 100100107, "first_name": "Juan 😊"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
    ])
    
    # ========================================
    # CATEGORÍA 4: VALIDACIÓN username
    # ========================================
    
    tests.extend([
        TestCase(
            id="U01",
            name="username vacío",
            category="Validación username",
            payload={"user": {"telegram_id": 200200200, "username": ""}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="U02",
            name="username solo espacios",
            category="Validación username",
            payload={"user": {"telegram_id": 200200201, "username": "   "}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="U03",
            name="username válido simple",
            category="Validación username",
            payload={"user": {"telegram_id": 200200202, "username": "test_user"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="U04",
            name="username con números",
            category="Validación username",
            payload={"user": {"telegram_id": 200200203, "username": "user123"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="U05",
            name="username con guiones (inválido)",
            category="Validación username",
            payload={"user": {"telegram_id": 200200204, "username": "user-name"}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="U06",
            name="username con espacios (inválido)",
            category="Validación username",
            payload={"user": {"telegram_id": 200200205, "username": "user name"}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="U07",
            name="username muy largo (>32)",
            category="Validación username",
            payload={"user": {"telegram_id": 200200206, "username": "a" * 50}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="U08",
            name="username en límite (32)",
            category="Validación username",
            payload={"user": {"telegram_id": 200200207, "username": "b" * 32}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="U09",
            name="username con caracteres especiales",
            category="Validación username",
            payload={"user": {"telegram_id": 200200208, "username": "user@123"}},
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="U10",
            name="username solo underscore",
            category="Validación username",
            payload={"user": {"telegram_id": 200200209, "username": "___"}},
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
    ])
    
    # ========================================
    # CATEGORÍA 5: VALIDACIÓN routing
    # ========================================
    
    tests.extend([
        TestCase(
            id="R01",
            name="routing como objeto válido",
            category="Validación routing",
            payload={
                "user": {"telegram_id": 300300300},
                "routing": {"action": "book", "provider_id": "test-123"}
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=lambda b: validate_new_user(b) + validate_routing_preserved(b)
        ),
        TestCase(
            id="R02",
            name="routing vacío",
            category="Validación routing",
            payload={
                "user": {"telegram_id": 300300301},
                "routing": {}
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="R03",
            name="routing como array (inválido)",
            category="Validación routing",
            payload={
                "user": {"telegram_id": 300300302},
                "routing": []
            },
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="R04",
            name="routing como string (inválido)",
            category="Validación routing",
            payload={
                "user": {"telegram_id": 300300303},
                "routing": "invalid"
            },
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="R05",
            name="routing con datos complejos",
            category="Validación routing",
            payload={
                "user": {"telegram_id": 300300304},
                "routing": {
                    "action": "custom",
                    "data": {"nested": {"key": "value"}},
                    "array": [1, 2, 3]
                }
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
    ])
    
    # ========================================
    # CATEGORÍA 6: CASOS COMBINADOS
    # ========================================
    
    tests.extend([
        TestCase(
            id="C01",
            name="Payload completo válido",
            category="Casos Combinados",
            payload={
                "user": {
                    "telegram_id": 400400400,
                    "first_name": "Test User",
                    "username": "test_user_complete"
                },
                "routing": {
                    "action": "full_test",
                    "metadata": {"test_id": "C01"}
                }
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=lambda b: validate_new_user(b) + validate_routing_preserved(b)
        ),
        TestCase(
            id="C02",
            name="Campos extra no documentados",
            category="Casos Combinados",
            payload={
                "user": {"telegram_id": 400400401},
                "extra_field": "should be ignored",
                "another": {"nested": "data"}
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="C03",
            name="telegram_id en diferentes formatos válidos",
            category="Casos Combinados",
            payload={
                "user": {"telegram_id": "  888999000  "},  # String con espacios
                "routing": {"action": "test"}
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
    ])
    
    # ========================================
    # CATEGORÍA 7: CASOS EDGE/LÍMITE
    # ========================================
    
    tests.extend([
        TestCase(
            id="E01",
            name="Múltiples errores de validación",
            category="Casos Edge",
            payload={
                "user": {
                    "telegram_id": "invalid",
                    "first_name": "",
                    "username": "user-with-invalid@chars"
                }
            },
            expected_success=False,
            expected_access="error",
            expected_reason="VALIDATION_FAILED",
        ),
        TestCase(
            id="E02",
            name="Valores en límites exactos",
            category="Casos Edge",
            payload={
                "user": {
                    "telegram_id": 9999999999999,  # Max permitido
                    "first_name": "X" * 255,  # Max length
                    "username": "y" * 32  # Max length
                }
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="E03",
            name="Caracteres Unicode extremos",
            category="Casos Edge",
            payload={
                "user": {
                    "telegram_id": 500500500,
                    "first_name": "名前 🚀 Имя",
                    "username": "user_unicode_123"
                }
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
        TestCase(
            id="E04",
            name="JSON profundamente anidado en routing",
            category="Casos Edge",
            payload={
                "user": {"telegram_id": 500500501},
                "routing": {
                    "level1": {
                        "level2": {
                            "level3": {
                                "level4": {
                                    "data": "deep"
                                }
                            }
                        }
                    }
                }
            },
            expected_success=True,
            expected_access="granted",
            expected_reason="NEW_USER",
            validation_func=validate_new_user
        ),
    ])
    
    return tests

# ============================================
# EJECUTOR DE TESTS
# ============================================

def run_test(test: TestCase) -> bool:
    """Ejecuta un test individual y retorna True si pasa."""
    print_test(test.id, test.name)
    if test.description:
        print_info(test.description)
    
    # Enviar request
    response = send_request(test.payload)
    if not response:
        print_fail("No se pudo enviar request")
        return False
    
    # Mostrar respuesta resumida
    body = response.get("body", {})
    print_info(f"Status: {response.get('status_code')}")
    print_info(f"Response: success={body.get('success')}, access={body.get('access')}, reason={body.get('reason')}")
    
    # Validar estructura
    passed, errors = validate_response_structure(response, test)
    
    if passed:
        print_pass("Test PASSED")
        return True
    else:
        print_fail("Test FAILED")
        for error in errors:
            print_fail(f"  - {error}")
        return False

def run_all_tests():
    """Ejecuta todos los tests y genera reporte."""
    print_header("BB_02 COMPREHENSIVE TEST SUITE")
    print(f"Target: {WEBHOOK_URL}")
    print(f"Time: {datetime.now().isoformat()}\n")
    
    tests = get_all_tests()
    
    # Agrupar por categoría
    categories = {}
    for test in tests:
        if test.category not in categories:
            categories[test.category] = []
        categories[test.category].append(test)
    
    # Ejecutar por categoría
    results = {}
    for category, category_tests in categories.items():
        print_category(category)
        
        for test in category_tests:
            try:
                results[test.id] = run_test(test)
            except Exception as e:
                print_fail(f"Exception: {e}")
                results[test.id] = False
    
    # Reporte final
    print_header("REPORTE FINAL", "=")
    
    # Por categoría
    for category, category_tests in categories.items():
        passed = sum(1 for t in category_tests if results.get(t.id, False))
        total = len(category_tests)
        pct = (passed / total * 100) if total > 0 else 0
        
        status_color = Colors.GREEN if pct == 100 else Colors.YELLOW if pct >= 70 else Colors.RED
        print(f"\n{Colors.BOLD}{category}{Colors.RESET}")
        print(f"  {status_color}{passed}/{total} passed ({pct:.1f}%){Colors.RESET}")
    
    # Global
    total_passed = sum(1 for v in results.values() if v)
    total_tests = len(results)
    pct_global = (total_passed / total_tests * 100) if total_tests > 0 else 0
    
    print(f"\n{Colors.BOLD}TOTAL GLOBAL{Colors.RESET}")
    print(f"  Tests ejecutados: {total_tests}")
    print(f"  {Colors.GREEN}Pasados: {total_passed}{Colors.RESET}")
    print(f"  {Colors.RED}Fallidos: {total_tests - total_passed}{Colors.RESET}")
    print(f"  Cobertura: {pct_global:.1f}%")
    
    # Tests fallidos detalle
    failed_tests = [tid for tid, passed in results.items() if not passed]
    if failed_tests:
        print(f"\n{Colors.RED}Tests Fallidos:{Colors.RESET}")
        for tid in failed_tests:
            test = next((t for t in tests if t.id == tid), None)
            if test:
                print(f"  [{tid}] {test.name}")
    
    # Conclusión
    print()
    if pct_global == 100:
        print(f"{Colors.GREEN}✅ TODOS LOS TESTS PASARON - WORKFLOW LISTO PARA PRODUCCIÓN{Colors.RESET}")
        return 0
    elif pct_global >= 90:
        print(f"{Colors.YELLOW}⚠️  Mayoría de tests pasados - Revisar fallos antes de producción{Colors.RESET}")
        return 1
    else:
        print(f"{Colors.RED}❌ MÚLTIPLES FALLOS - NO LISTO PARA PRODUCCIÓN{Colors.RESET}")
        return 1

# ============================================
# MAIN
# ============================================

if __name__ == "__main__":
    sys.exit(run_all_tests())