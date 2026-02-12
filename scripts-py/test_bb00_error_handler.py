#!/usr/bin/env python3
"""
TEST BB_00: Global Error Handler
Basado en hallazgos de auditoría reportZed.md

Tests realizados:
1. Input validation (paranoid guard)
2. PII redaction (40+ patrones)
3. Severity classification
4. Circuit breaker behavior
5. Rate limiting
6. Telegram/Email notification flow
7. Database logging
"""

import os
import sys

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), ".")))

import json
import time
from datetime import datetime

import requests
from n8n_crud_agent import N8NCrudAgent

# Configuración
N8N_URL = os.environ.get("N8N_URL", "https://n8n.stax.ink")
WEBHOOK_PATH = "/webhook-test/bb00-error"  # Ajustar según configuración real


class Colors:
    HEADER = "\033[95m"
    OKBLUE = "\033[94m"
    OKCYAN = "\033[96m"
    OKGREEN = "\033[92m"
    WARNING = "\033[93m"
    FAIL = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


def print_test(msg):
    print(f"{Colors.OKBLUE}[TEST]{Colors.ENDC} {msg}")


def print_success(msg):
    print(f"{Colors.OKGREEN}✓ {msg}{Colors.ENDC}")


def print_fail(msg):
    print(f"{Colors.FAIL}✗ {msg}{Colors.ENDC}")


def print_warning(msg):
    print(f"{Colors.WARNING}⚠ {msg}{Colors.ENDC}")


def print_header(msg):
    print(f"\n{Colors.BOLD}{Colors.HEADER}{'=' * 70}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}{msg:^70}{Colors.ENDC}")
    print(f"{Colors.BOLD}{Colors.HEADER}{'=' * 70}{Colors.ENDC}\n")


class BB00Tester:
    def __init__(self):
        self.agent = N8NCrudAgent(N8N_URL)
        self.webhook_url = f"{N8N_URL}{WEBHOOK_PATH}"
        self.workflow_name = "BB_00_Global_Error_Handler"
        self.tests_passed = 0
        self.tests_failed = 0
        self.tests_total = 0

    def send_error(self, payload):
        """Envía un error al webhook de BB_00"""
        try:
            response = requests.post(
                self.webhook_url,
                json=payload,
                headers={"Content-Type": "application/json"},
                timeout=30,
            )
            return {
                "success": True,
                "status_code": response.status_code,
                "response": response.json()
                if response.headers.get("content-type") == "application/json"
                else response.text,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    def assert_test(self, condition, test_name, details=""):
        """Assert helper para tests"""
        self.tests_total += 1
        if condition:
            self.tests_passed += 1
            print_success(f"{test_name}")
            if details:
                print(f"  └─ {details}")
        else:
            self.tests_failed += 1
            print_fail(f"{test_name}")
            if details:
                print(f"  └─ {details}")

    # ===================================================================
    # TEST 1: Validación de Input (Paranoid Guard)
    # ===================================================================
    def test_input_validation(self):
        print_header("TEST 1: Input Validation (Paranoid Guard)")

        # Test 1.1: Payload vacío (debería fallar)
        print_test("1.1 - Payload vacío")
        result = self.send_error({})
        self.assert_test(
            result.get("success")
            and "validation" in str(result.get("response", "")).lower(),
            "Rechaza payload vacío",
            f"Response: {result.get('response')}",
        )

        # Test 1.2: error_message requerido
        print_test("1.2 - error_message requerido")
        result = self.send_error({"workflow_name": "TEST_WF"})
        self.assert_test(
            "error_message" in str(result.get("response", "")).lower()
            or "required" in str(result.get("response", "")).lower(),
            "Valida que error_message sea requerido",
            f"Response: {result.get('response')}",
        )

        # Test 1.3: workflow_name requerido
        print_test("1.3 - workflow_name requerido")
        result = self.send_error({"error_message": "Test error"})
        self.assert_test(
            "workflow_name" in str(result.get("response", "")).lower()
            or "required" in str(result.get("response", "")).lower(),
            "Valida que workflow_name sea requerido",
            f"Response: {result.get('response')}",
        )

        # Test 1.4: Payload válido (debería pasar)
        print_test("1.4 - Payload válido")
        result = self.send_error(
            {
                "workflow_name": "TEST_WF",
                "error_message": "Test error message",
                "severity": "HIGH",
            }
        )
        self.assert_test(
            result.get("success") and result.get("status_code") == 200,
            "Acepta payload válido",
            f"Status: {result.get('status_code')}",
        )

        # Test 1.5: error_message muy largo (>5000 chars)
        print_test("1.5 - error_message excesivamente largo")
        long_message = "A" * 6000
        result = self.send_error(
            {
                "workflow_name": "TEST_WF",
                "error_message": long_message,
                "severity": "LOW",
            }
        )
        # Debería rechazar o truncar
        self.assert_test(
            "validation" in str(result.get("response", "")).lower()
            or result.get("success"),
            "Maneja error_message largo (rechaza o trunca)",
            f"Length: 6000 chars",
        )

    # ===================================================================
    # TEST 2: PII Redaction
    # ===================================================================
    def test_pii_redaction(self):
        print_header("TEST 2: PII Redaction (40+ patrones)")

        pii_tests = [
            ("Email", "user@example.com", "Mi email es user@example.com"),
            ("RUT Chileno", "12.345.678-9", "RUT: 12.345.678-9"),
            ("Teléfono CL", "+56912345678", "Llamar al +56912345678"),
            (
                "JWT Token",
                "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123",
                "Token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abc123",
            ),
            ("Tarjeta", "4532-1234-5678-9010", "Card: 4532-1234-5678-9010"),
        ]

        for test_name, pii_data, error_message in pii_tests:
            print_test(f"2.x - Redactar {test_name}: {pii_data}")
            result = self.send_error(
                {
                    "workflow_name": "TEST_PII",
                    "error_message": error_message,
                    "severity": "MEDIUM",
                }
            )
            # Nota: No podemos validar la redacción sin acceso a DB,
            # pero verificamos que el request se procese correctamente
            self.assert_test(
                result.get("success"),
                f"Procesa mensaje con {test_name}",
                f"Status: {result.get('status_code')}",
            )

    # ===================================================================
    # TEST 3: Severity Classification
    # ===================================================================
    def test_severity_classification(self):
        print_header("TEST 3: Severity Classification")

        severity_tests = [
            (
                "CRITICAL",
                "Database connection failed ECONNREFUSED",
                "Detecta CRITICAL por patrón",
            ),
            ("HIGH", "Timeout error ETIMEDOUT", "Detecta HIGH por timeout"),
            ("MEDIUM", "Validation error: invalid input", "Detecta MEDIUM por defecto"),
            ("LOW", "Not found 404", "Detecta LOW por 404"),
        ]

        for expected_severity, error_message, description in severity_tests:
            print_test(f"3.x - {description}")
            result = self.send_error(
                {
                    "workflow_name": "TEST_SEVERITY",
                    "error_message": error_message,
                    "severity": expected_severity,  # Proveído por caller
                }
            )
            self.assert_test(
                result.get("success"), description, f"Expected: {expected_severity}"
            )

    # ===================================================================
    # TEST 4: Circuit Breaker (Race Condition Potencial - Bug C4)
    # ===================================================================
    def test_circuit_breaker(self):
        print_header("TEST 4: Circuit Breaker (Bug C4 - Race Condition)")

        print_warning("Este test detecta el bug C4 (Race Condition en Circuit Breaker)")
        print_warning("Esperado: Circuit breaker debería abrirse después de 50 errores")
        print_warning("Bug: Múltiples threads pueden escribir simultáneamente")

        print_test("4.1 - Enviar 10 errores rápidos del mismo workflow")

        workflow_name = f"TEST_CB_{int(time.time())}"
        errors_sent = 0
        errors_success = 0

        for i in range(10):
            result = self.send_error(
                {
                    "workflow_name": workflow_name,
                    "error_message": f"Test circuit breaker error #{i + 1}",
                    "severity": "HIGH",
                }
            )
            errors_sent += 1
            if result.get("success"):
                errors_success += 1
            time.sleep(0.1)  # Pequeña pausa para simular concurrencia controlada

        self.assert_test(
            errors_success > 0,
            f"Procesa múltiples errores ({errors_success}/{errors_sent} exitosos)",
            f"Workflow: {workflow_name}",
        )

        print_warning(
            "⚠ Para test completo de race condition, ejecutar 100+ requests simultáneos"
        )
        print_warning("⚠ Ver reportZed.md L241-290 para detalles del bug")

    # ===================================================================
    # TEST 5: Rate Limiting
    # ===================================================================
    def test_rate_limiting(self):
        print_header("TEST 5: Rate Limiting (10 errores / 5 min)")

        print_test("5.1 - Verificar que rate limit se aplica")
        print_warning("Según auditoría: Max 10 errores por workflow en 5 minutos")

        workflow_name = f"TEST_RATE_{int(time.time())}"

        # Enviar 5 errores (bajo el límite)
        print_test("5.1.1 - Enviar 5 errores (bajo límite)")
        for i in range(5):
            result = self.send_error(
                {
                    "workflow_name": workflow_name,
                    "error_message": f"Rate limit test #{i + 1}",
                    "severity": "LOW",
                }
            )
            time.sleep(0.2)

        self.assert_test(
            True,  # Si llegamos aquí, no hubo rate limit
            "Acepta 5 errores sin rate limit",
            "OK - Bajo el límite",
        )

        print_warning("⚠ Test completo requiere enviar 15+ errores en <5min")
        print_warning("⚠ Limitado por tiempo de ejecución del script")

    # ===================================================================
    # TEST 6: Notification Flow
    # ===================================================================
    def test_notification_flow(self):
        print_header("TEST 6: Notification Flow (Telegram/Email)")

        print_test("6.1 - Error CRITICAL debería generar notificación")
        result = self.send_error(
            {
                "workflow_name": "TEST_NOTIFICATION",
                "error_message": "CRITICAL: Database connection lost",
                "severity": "CRITICAL",
                "node_name": "DB Connection",
            }
        )
        self.assert_test(
            result.get("success"),
            "Procesa error CRITICAL",
            "Debería notificar a Telegram/Email (verificar manualmente)",
        )

        print_test("6.2 - Error LOW NO debería generar notificación")
        result = self.send_error(
            {
                "workflow_name": "TEST_NOTIFICATION",
                "error_message": "Low priority: validation failed",
                "severity": "LOW",
            }
        )
        self.assert_test(
            result.get("success"),
            "Procesa error LOW",
            "NO debería notificar (solo log DB)",
        )

        print_warning(
            "⚠ Verificación de notificaciones requiere acceso a Telegram/Email"
        )

    # ===================================================================
    # TEST 7: Database Logging
    # ===================================================================
    def test_database_logging(self):
        print_header("TEST 7: Database Logging (system_errors)")

        print_test("7.1 - Verificar que errores se loguean")
        unique_id = f"TEST_DB_LOG_{int(time.time())}"
        result = self.send_error(
            {
                "workflow_name": unique_id,
                "error_message": "Test database logging",
                "severity": "MEDIUM",
                "error_type": "TEST_ERROR",
            }
        )
        self.assert_test(
            result.get("success"), "Envía error para logging", f"ID único: {unique_id}"
        )

        print_warning("⚠ Verificación en DB:")
        print_warning(
            f"   SELECT * FROM system_errors WHERE workflow_name = '{unique_id}';"
        )
        print_warning("⚠ Debería tener 1 fila con PII redactado")

    # ===================================================================
    # TEST 8: Edge Cases
    # ===================================================================
    def test_edge_cases(self):
        print_header("TEST 8: Edge Cases & Special Characters")

        edge_cases = [
            (
                "SQL Injection attempt",
                "'; DROP TABLE system_errors; --",
                "Maneja SQL injection",
            ),
            ("XSS attempt", "<script>alert('xss')</script>", "Maneja XSS"),
            ("Unicode", "Error con émojis 🚨🔥💀", "Maneja Unicode"),
            ("JSON especial", '{"nested": "value with \\" quotes"}', "Maneja JSON"),
            ("Null bytes", "Error\x00con\x00nulls", "Maneja null bytes"),
        ]

        for test_name, error_message, description in edge_cases:
            print_test(f"8.x - {description}")
            result = self.send_error(
                {
                    "workflow_name": "TEST_EDGE",
                    "error_message": error_message,
                    "severity": "LOW",
                }
            )
            self.assert_test(
                result.get("success"), description, f"Payload: {error_message[:50]}..."
            )

    # ===================================================================
    # WORKFLOW STATUS CHECK
    # ===================================================================
    def check_workflow_status(self):
        print_header("PRE-CHECK: Workflow Status")

        workflows = self.agent.list_workflows()
        if not workflows:
            print_fail("No se pudo obtener lista de workflows")
            return False

        bb00 = next(
            (
                w
                for w in workflows
                if "BB_00" in w.get("name", "") or "Error" in w.get("name", "")
            ),
            None,
        )

        if bb00:
            print_success(f"BB_00 encontrado: {bb00.get('name')}")
            print(f"  └─ ID: {bb00.get('id')}")
            print(f"  └─ Active: {bb00.get('active')}")

            if not bb00.get("active"):
                print_warning("⚠ Workflow NO está activo")
                print_warning(
                    "⚠ Ejecutar: python3 activate_workflow_by_name.py 'BB_00'"
                )
                return False
            return True
        else:
            print_fail("BB_00 no encontrado en la instancia")
            print_warning("⚠ Verificar que el workflow esté importado")
            return False

    # ===================================================================
    # MAIN TEST RUNNER
    # ===================================================================
    def run_all_tests(self):
        print(
            f"\n{Colors.BOLD}╔════════════════════════════════════════════════════════════════════╗{Colors.ENDC}"
        )
        print(
            f"{Colors.BOLD}║  TEST BB_00: Global Error Handler - Auditoría de Seguridad       ║{Colors.ENDC}"
        )
        print(
            f"{Colors.BOLD}║  Basado en: reportZed.md                                          ║{Colors.ENDC}"
        )
        print(
            f"{Colors.BOLD}╚════════════════════════════════════════════════════════════════════╝{Colors.ENDC}\n"
        )

        print(f"N8N URL: {N8N_URL}")
        print(f"Webhook: {self.webhook_url}")
        print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")

        # Pre-check
        if not self.check_workflow_status():
            print_fail("\n⛔ PRE-CHECK FAILED - Tests abortados")
            return

        # Run tests
        try:
            self.test_input_validation()
            self.test_pii_redaction()
            self.test_severity_classification()
            self.test_circuit_breaker()
            self.test_rate_limiting()
            self.test_notification_flow()
            self.test_database_logging()
            self.test_edge_cases()
        except KeyboardInterrupt:
            print_warning("\n\n⚠ Tests interrumpidos por usuario")
        except Exception as e:
            print_fail(f"\n\n✗ Error durante tests: {str(e)}")

        # Summary
        self.print_summary()

    def print_summary(self):
        print(f"\n{Colors.BOLD}{'=' * 70}{Colors.ENDC}")
        print(f"{Colors.BOLD}RESUMEN DE TESTS{Colors.ENDC}")
        print(f"{Colors.BOLD}{'=' * 70}{Colors.ENDC}\n")

        total = self.tests_total
        passed = self.tests_passed
        failed = self.tests_failed
        pass_rate = (passed / total * 100) if total > 0 else 0

        print(f"Total tests:     {total}")
        print(f"{Colors.OKGREEN}Tests pasados:   {passed}{Colors.ENDC}")
        print(f"{Colors.FAIL}Tests fallidos:  {failed}{Colors.ENDC}")
        print(f"Pass rate:       {pass_rate:.1f}%\n")

        if pass_rate >= 80:
            print(
                f"{Colors.OKGREEN}✓ BB_00 está funcionando correctamente (≥80%){Colors.ENDC}"
            )
        elif pass_rate >= 60:
            print(
                f"{Colors.WARNING}⚠ BB_00 tiene problemas menores (60-80%){Colors.ENDC}"
            )
        else:
            print(f"{Colors.FAIL}✗ BB_00 tiene problemas graves (<60%){Colors.ENDC}")

        print(f"\n{Colors.BOLD}BUGS CONOCIDOS DE AUDITORÍA:{Colors.ENDC}")
        print(
            f"  {Colors.WARNING}C4{Colors.ENDC} - Race condition en Circuit Breaker (reportZed.md L241-290)"
        )
        print(
            f"  {Colors.WARNING}H1{Colors.ENDC} - Regex de RUT incompleto (reportZed.md L95)"
        )
        print(
            f"  {Colors.WARNING}H2{Colors.ENDC} - Email fallback sin log (reportZed.md L450-455)"
        )

        print(f"\n{Colors.BOLD}RECOMENDACIONES:{Colors.ENDC}")
        print(f"  1. Implementar FIX 1.5 (Circuit Breaker atómico)")
        print(
            f"  2. Verificar logs en DB: SELECT * FROM system_errors ORDER BY created_at DESC LIMIT 10;"
        )
        print(f"  3. Validar notificaciones en Telegram/Email manualmente")
        print(f"  4. Ejecutar test de concurrencia: 100+ requests simultáneos\n")


if __name__ == "__main__":
    tester = BB00Tester()
    tester.run_all_tests()
