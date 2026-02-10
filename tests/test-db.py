#!/usr/bin/env python3
"""
BB_02 - Suite Completa de Tests
Combinatoria exhaustiva de escenarios de seguridad

Ejecutar: python3 test-db.py
"""

import json
import sys
from datetime import datetime, timedelta, timezone
from typing import Optional, Dict, Any, List
import os

# ============================================
# CONFIGURACIÓN
# ============================================

N8N_BASE_URL = "http://localhost:5678"
WEBHOOK_PATH = "/webhook/689841d2-b2a8-4329-b118-4e8675a810be"

DB_CONFIG = {
    "host": "ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech",
    "port": 5432,
    "database": "neondb",
    "user": "neondb_owner",
    "password": os.getenv("PGPASSWORD", ""),
    "sslmode": "require"
}

# IDs de prueba - rango reservado 800800XXX y 999999XXX
TEST_TELEGRAM_IDS = list(range(800800800, 800800830)) + list(range(999999990, 999999999))

# ============================================
# IMPORTS
# ============================================

try:
    import requests
except ImportError:
    print("❌ pip install requests")
    sys.exit(1)

try:
    import psycopg2
    from psycopg2.extras import RealDictCursor
except ImportError:
    print("❌ pip install psycopg2-binary")
    sys.exit(1)

# ============================================
# COLORES Y UTILIDADES
# ============================================

class C:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'

def header(t): 
    print(f"\n{C.BOLD}{C.BLUE}{'='*70}\n{t.center(70)}\n{'='*70}{C.RESET}\n")

def subheader(t):
    print(f"\n{C.BOLD}{C.CYAN}{'─'*70}\n{t}\n{'─'*70}{C.RESET}")

def ok(m): 
    print(f"  {C.GREEN}✓ {m}{C.RESET}")

def fail(m): 
    print(f"  {C.RED}✗ {m}{C.RESET}")

def warn(m):
    print(f"  {C.YELLOW}⚠ {m}{C.RESET}")

def info(m): 
    print(f"  {C.DIM}ℹ {m}{C.RESET}")

def debug(m):
    print(f"  {C.MAGENTA}🔍 {m}{C.RESET}")

# ============================================
# TEST DATA MANAGER
# ============================================

class TestDataManager:
    """Gestiona datos de prueba en PostgreSQL."""
    
    def __init__(self, db_config):
        self.config = db_config
        self.conn = None
    
    def connect(self):
        """Conectar a PostgreSQL."""
        try:
            self.conn = psycopg2.connect(**self.config)
            ok("Conectado a PostgreSQL")
            return True
        except Exception as e:
            fail(f"No se pudo conectar a PostgreSQL: {e}")
            return False
    
    def cleanup(self):
        """Limpiar todos los datos de prueba."""
        if not self.conn:
            return
        
        cur = self.conn.cursor()
        try:
            cur.execute("""
                DELETE FROM security_firewall 
                WHERE entity_id LIKE 'telegram:800800%' 
                   OR entity_id LIKE 'telegram:999999%'
            """)
            cur.execute("""
                DELETE FROM users 
                WHERE telegram_id >= 800800800 AND telegram_id <= 800800899
                   OR telegram_id >= 999999900 AND telegram_id <= 999999999
            """)
            self.conn.commit()
        except Exception as e:
            self.conn.rollback()
            fail(f"Error en cleanup: {e}")
        finally:
            cur.close()
    
    def create_user(self, telegram_id: int, first_name: str, role: str = "user", 
                    deleted_at: bool = False) -> Optional[str]:
        """Crear un usuario de prueba."""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        try:
            if deleted_at:
                cur.execute("""
                    INSERT INTO users (telegram_id, first_name, role, deleted_at)
                    VALUES (%s, %s, %s, NOW())
                    RETURNING id
                """, (telegram_id, first_name, role))
            else:
                cur.execute("""
                    INSERT INTO users (telegram_id, first_name, role)
                    VALUES (%s, %s, %s)
                    RETURNING id
                """, (telegram_id, first_name, role))
            
            result = cur.fetchone()
            self.conn.commit()
            return result["id"]
        except Exception as e:
            self.conn.rollback()
            fail(f"Error creando usuario: {e}")
            return None
        finally:
            cur.close()
    
    def create_firewall_entry(self, telegram_id: int, is_blocked: bool = False,
                               blocked_until: Optional[datetime] = None,
                               strike_count: int = 0) -> Optional[str]:
        """Crear entrada de firewall."""
        cur = self.conn.cursor(cursor_factory=RealDictCursor)
        try:
            entity_id = f"telegram:{telegram_id}"
            cur.execute("""
                INSERT INTO security_firewall (entity_id, is_blocked, blocked_until, strike_count)
                VALUES (%s, %s, %s, %s)
                RETURNING id
            """, (entity_id, is_blocked, blocked_until, strike_count))
            
            result = cur.fetchone()
            self.conn.commit()
            return result["id"]
        except Exception as e:
            self.conn.rollback()
            fail(f"Error creando firewall entry: {e}")
            return None
        finally:
            cur.close()
    
    def close(self):
        """Cerrar conexión."""
        if self.conn:
            self.conn.close()

# ============================================
# HTTP CLIENT
# ============================================

def send_request(payload: Dict[str, Any], timeout: int = 30) -> Optional[Dict[str, Any]]:
    """Envía request al webhook."""
    try:
        response = requests.post(
            f"{N8N_BASE_URL}{WEBHOOK_PATH}",
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=timeout
        )
        
        return {
            "status_code": response.status_code,
            "body": response.json() if response.text else {}
        }
    except requests.exceptions.ConnectionError:
        fail(f"No se pudo conectar a {N8N_BASE_URL}")
        return None
    except requests.exceptions.Timeout:
        fail(f"Timeout después de {timeout}s")
        return None
    except Exception as e:
        fail(f"Request error: {e}")
        return None

# ============================================
# TEST FRAMEWORK
# ============================================

class TestResult:
    def __init__(self, name: str, category: str):
        self.name = name
        self.category = category
        self.passed = False
        self.errors = []
        self.response = None
        self.duration_ms = 0

class TestRunner:
    def __init__(self, db: TestDataManager):
        self.db = db
        self.results: List[TestResult] = []
        self.current_test: Optional[TestResult] = None
    
    def run_test(self, name: str, category: str, setup_fn, test_fn) -> bool:
        """Ejecuta un test individual."""
        import time
        
        self.current_test = TestResult(name, category)
        print(f"\n{C.CYAN}▶ [{category}] {name}{C.RESET}")
        
        try:
            # Setup
            setup_fn()
            
            # Execute
            start = time.time()
            passed = test_fn()
            self.current_test.duration_ms = int((time.time() - start) * 1000)
            
            self.current_test.passed = passed
            
            if passed:
                ok(f"PASSED ({self.current_test.duration_ms}ms)")
            else:
                for err in self.current_test.errors:
                    fail(err)
                    
        except Exception as e:
            self.current_test.passed = False
            self.current_test.errors.append(f"Exception: {str(e)}")
            fail(f"Exception: {e}")
        
        self.results.append(self.current_test)
        return self.current_test.passed
    
    def assert_equals(self, actual, expected, field: str):
        """Verifica igualdad."""
        if actual != expected:
            self.current_test.errors.append(f"{field}: expected {expected}, got {actual}")
            return False
        return True
    
    def assert_not_null(self, value, field: str):
        """Verifica no nulo."""
        if value is None:
            self.current_test.errors.append(f"{field} should not be null")
            return False
        return True
    
    def assert_null(self, value, field: str):
        """Verifica nulo."""
        if value is not None:
            self.current_test.errors.append(f"{field} should be null, got {value}")
            return False
        return True
    
    def assert_contains(self, text: str, substring: str, field: str):
        """Verifica que contiene substring."""
        if substring not in (text or ""):
            self.current_test.errors.append(f"{field} should contain '{substring}'")
            return False
        return True
    
    def assert_greater_than(self, actual, expected, field: str):
        """Verifica mayor que."""
        if actual <= expected:
            self.current_test.errors.append(f"{field}: expected > {expected}, got {actual}")
            return False
        return True
    
    def get_summary(self) -> Dict[str, Any]:
        """Obtiene resumen de resultados."""
        categories = {}
        for r in self.results:
            if r.category not in categories:
                categories[r.category] = {"passed": 0, "failed": 0, "tests": []}
            
            if r.passed:
                categories[r.category]["passed"] += 1
            else:
                categories[r.category]["failed"] += 1
            
            categories[r.category]["tests"].append(r)
        
        return {
            "total": len(self.results),
            "passed": sum(1 for r in self.results if r.passed),
            "failed": sum(1 for r in self.results if not r.passed),
            "categories": categories
        }

# ============================================
# TEST SUITES
# ============================================

def run_validation_tests(runner: TestRunner, db: TestDataManager):
    """Tests de validación de input."""
    
    subheader("📋 VALIDATION TESTS")
    
    # Test 1: Sin campo user
    def test_missing_user():
        response = send_request({})
        if not response:
            return False
        
        body = response["body"]
        runner.current_test.response = body
        
        return all([
            runner.assert_equals(body.get("success"), False, "success"),
            runner.assert_equals(body.get("access"), "error", "access"),
            runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason"),
            runner.assert_contains(body.get("error_message", ""), "user", "error_message")
        ])
    
    runner.run_test("Missing user field", "VALIDATION", lambda: None, test_missing_user)
    
    # Test 2: User no es objeto
    def test_user_not_object():
        response = send_request({"user": "string"})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("success"), False, "success"),
            runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
        ])
    
    runner.run_test("User is not object", "VALIDATION", lambda: None, test_user_not_object)
    
    # Test 3: User es array
    def test_user_is_array():
        response = send_request({"user": [1, 2, 3]})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("User is array", "VALIDATION", lambda: None, test_user_is_array)
    
    # Test 4: telegram_id faltante
    def test_missing_telegram_id():
        response = send_request({"user": {"first_name": "Test"}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason"),
            runner.assert_contains(body.get("error_message", ""), "telegram_id", "error_message")
        ])
    
    runner.run_test("Missing telegram_id", "VALIDATION", lambda: None, test_missing_telegram_id)
    
    # Test 5: telegram_id null
    def test_null_telegram_id():
        response = send_request({"user": {"telegram_id": None}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Null telegram_id", "VALIDATION", lambda: None, test_null_telegram_id)
    
    # Test 6: telegram_id string no numérico
    def test_non_numeric_telegram_id():
        response = send_request({"user": {"telegram_id": "abc123"}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason"),
            runner.assert_contains(body.get("error_message", ""), "numérico", "error_message")
        ])
    
    runner.run_test("Non-numeric telegram_id", "VALIDATION", lambda: None, test_non_numeric_telegram_id)
    
    # Test 7: telegram_id = 0
    def test_zero_telegram_id():
        response = send_request({"user": {"telegram_id": 0}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Zero telegram_id", "VALIDATION", lambda: None, test_zero_telegram_id)
    
    # Test 8: telegram_id negativo
    def test_negative_telegram_id():
        response = send_request({"user": {"telegram_id": -12345}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Negative telegram_id", "VALIDATION", lambda: None, test_negative_telegram_id)
    
    # Test 9: telegram_id muy pequeño
    def test_too_small_telegram_id():
        response = send_request({"user": {"telegram_id": 5}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Too small telegram_id (<10)", "VALIDATION", lambda: None, test_too_small_telegram_id)
    
    # Test 10: telegram_id string numérico válido
    def test_string_telegram_id():
        response = send_request({"user": {"telegram_id": "999999990"}})
        if not response:
            return False
        
        body = response["body"]
        # Debería funcionar - string numérico es válido
        return runner.assert_equals(body.get("access"), "granted", "access")
    
    runner.run_test("String numeric telegram_id (valid)", "VALIDATION", lambda: None, test_string_telegram_id)
    
    # Test 11: first_name vacío
    def test_empty_first_name():
        response = send_request({"user": {"telegram_id": 999999991, "first_name": ""}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Empty first_name", "VALIDATION", lambda: None, test_empty_first_name)
    
    # Test 12: first_name solo espacios
    def test_whitespace_first_name():
        response = send_request({"user": {"telegram_id": 999999991, "first_name": "   "}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Whitespace-only first_name", "VALIDATION", lambda: None, test_whitespace_first_name)
    
    # Test 13: username con caracteres inválidos
    def test_invalid_username():
        response = send_request({"user": {"telegram_id": 999999991, "username": "user@name!"}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason"),
            runner.assert_contains(body.get("error_message", ""), "caracteres inválidos", "error_message")
        ])
    
    runner.run_test("Invalid username characters", "VALIDATION", lambda: None, test_invalid_username)
    
    # Test 14: username válido
    def test_valid_username():
        response = send_request({"user": {"telegram_id": 999999991, "username": "valid_user123"}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("access"), "granted", "access")
    
    runner.run_test("Valid username", "VALIDATION", lambda: None, test_valid_username)
    
    # Test 15: routing no es objeto
    def test_invalid_routing():
        response = send_request({"user": {"telegram_id": 999999991}, "routing": "invalid"})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "VALIDATION_FAILED", "reason")
    
    runner.run_test("Invalid routing (not object)", "VALIDATION", lambda: None, test_invalid_routing)


def run_new_user_tests(runner: TestRunner, db: TestDataManager):
    """Tests de usuarios nuevos."""
    
    subheader("👤 NEW USER TESTS")
    
    # Test 1: Usuario completamente nuevo
    def test_new_user():
        response = send_request({"user": {"telegram_id": 999999992, "first_name": "New User"}})
        if not response:
            return False
        
        body = response["body"]
        runner.current_test.response = body
        
        return all([
            runner.assert_equals(body.get("success"), True, "success"),
            runner.assert_equals(body.get("access"), "granted", "access"),
            runner.assert_equals(body.get("reason"), "NEW_USER", "reason"),
            runner.assert_equals(body.get("next_step"), "register", "next_step"),
            runner.assert_equals(body.get("security", {}).get("status"), "new", "status"),
            runner.assert_null(body.get("security", {}).get("user_id"), "user_id"),
            runner.assert_equals(body.get("security", {}).get("role"), "guest", "role")
        ])
    
    runner.run_test("Completely new user", "NEW_USER", lambda: None, test_new_user)
    
    # Test 2: Usuario nuevo con firewall entry pero sin bloqueo
    def setup_user_with_firewall():
        db.create_firewall_entry(800800810, is_blocked=False, strike_count=2)
    
    def test_new_user_with_firewall():
        response = send_request({"user": {"telegram_id": 800800810}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "NEW_USER", "reason"),
            runner.assert_equals(body.get("security", {}).get("strike_count"), 2, "strike_count")
        ])
    
    runner.run_test("New user with firewall entry (no block)", "NEW_USER", 
                    setup_user_with_firewall, test_new_user_with_firewall)


def run_authorized_user_tests(runner: TestRunner, db: TestDataManager):
    """Tests de usuarios autorizados."""
    
    subheader("✅ AUTHORIZED USER TESTS")
    
    # Test 1: Usuario básico autorizado
    def setup_basic_user():
        db.create_user(800800811, "Basic User", "user")
    
    def test_basic_authorized():
        response = send_request({"user": {"telegram_id": 800800811}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("success"), True, "success"),
            runner.assert_equals(body.get("access"), "granted", "access"),
            runner.assert_equals(body.get("reason"), "AUTHORIZED", "reason"),
            runner.assert_equals(body.get("next_step"), "authorized", "next_step"),
            runner.assert_equals(body.get("security", {}).get("status"), "active", "status"),
            runner.assert_not_null(body.get("security", {}).get("user_id"), "user_id"),
            runner.assert_equals(body.get("security", {}).get("role"), "user", "role")
        ])
    
    runner.run_test("Basic authorized user", "AUTHORIZED", setup_basic_user, test_basic_authorized)
    
    # Test 2: Usuario admin
    def setup_admin_user():
        db.create_user(800800812, "Admin User", "admin")
    
    def test_admin_user():
        response = send_request({"user": {"telegram_id": 800800812}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "AUTHORIZED", "reason"),
            runner.assert_equals(body.get("security", {}).get("role"), "admin", "role")
        ])
    
    runner.run_test("Admin user", "AUTHORIZED", setup_admin_user, test_admin_user)
    
    # Test 3: Usuario con strikes pero no bloqueado
    def setup_user_with_strikes():
        db.create_user(800800813, "User With Strikes", "user")
        db.create_firewall_entry(800800813, is_blocked=False, strike_count=3)
    
    def test_user_with_strikes():
        response = send_request({"user": {"telegram_id": 800800813}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "AUTHORIZED", "reason"),
            runner.assert_equals(body.get("security", {}).get("strike_count"), 3, "strike_count")
        ])
    
    runner.run_test("User with strikes (not blocked)", "AUTHORIZED", 
                    setup_user_with_strikes, test_user_with_strikes)
    
    # Test 4: Usuario con bloqueo expirado
    def setup_user_expired_block():
        db.create_user(800800814, "Expired Block User", "user")
        expired_time = datetime.now(timezone.utc) - timedelta(hours=1)
        db.create_firewall_entry(800800814, is_blocked=True, blocked_until=expired_time, strike_count=5)
    
    def test_user_expired_block():
        response = send_request({"user": {"telegram_id": 800800814}})
        if not response:
            return False
        
        body = response["body"]
        # Bloqueo expirado = debería poder acceder
        return all([
            runner.assert_equals(body.get("success"), True, "success"),
            runner.assert_equals(body.get("reason"), "AUTHORIZED", "reason")
        ])
    
    runner.run_test("User with expired block", "AUTHORIZED", 
                    setup_user_expired_block, test_user_expired_block)


def run_banned_user_tests(runner: TestRunner, db: TestDataManager):
    """Tests de usuarios baneados."""
    
    subheader("🚫 BANNED USER TESTS")
    
    # Test 1: Usuario baneado básico
    def setup_banned_user():
        db.create_user(800800815, "Banned User", "user", deleted_at=True)
    
    def test_banned_user():
        response = send_request({"user": {"telegram_id": 800800815}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("success"), False, "success"),
            runner.assert_equals(body.get("access"), "denied", "access"),
            runner.assert_equals(body.get("reason"), "USER_BANNED", "reason"),
            runner.assert_contains(body.get("error_message", ""), "suspendido permanentemente", "error_message"),
            runner.assert_equals(body.get("security", {}).get("status"), "banned", "status")
        ])
    
    runner.run_test("Banned user (soft deleted)", "BANNED", setup_banned_user, test_banned_user)
    
    # Test 2: Usuario baneado que también tiene bloqueo de firewall
    def setup_banned_and_blocked():
        db.create_user(800800816, "Banned And Blocked", "user", deleted_at=True)
        blocked_until = datetime.now(timezone.utc) + timedelta(hours=2)
        db.create_firewall_entry(800800816, is_blocked=True, blocked_until=blocked_until)
    
    def test_banned_and_blocked():
        response = send_request({"user": {"telegram_id": 800800816}})
        if not response:
            return False
        
        body = response["body"]
        # Firewall se evalúa primero, luego banned
        reason = body.get("reason")
        return reason in ["FIREWALL_BLOCKED", "USER_BANNED"]
    
    runner.run_test("Banned user with firewall block", "BANNED", 
                    setup_banned_and_blocked, test_banned_and_blocked)
    
    # Test 3: Admin baneado
    def setup_banned_admin():
        db.create_user(800800817, "Banned Admin", "admin", deleted_at=True)
    
    def test_banned_admin():
        response = send_request({"user": {"telegram_id": 800800817}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "USER_BANNED", "reason")
    
    runner.run_test("Banned admin user", "BANNED", setup_banned_admin, test_banned_admin)


def run_firewall_blocked_tests(runner: TestRunner, db: TestDataManager):
    """Tests de usuarios bloqueados por firewall."""
    
    subheader("🔥 FIREWALL BLOCKED TESTS")
    
    # Test 1: Usuario bloqueado activo
    def setup_blocked_user():
        db.create_user(800800818, "Blocked User", "user")
        blocked_until = datetime.now(timezone.utc) + timedelta(hours=2)
        db.create_firewall_entry(800800818, is_blocked=True, blocked_until=blocked_until, strike_count=3)
    
    def test_blocked_user():
        response = send_request({"user": {"telegram_id": 800800818}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("success"), False, "success"),
            runner.assert_equals(body.get("access"), "denied", "access"),
            runner.assert_equals(body.get("reason"), "FIREWALL_BLOCKED", "reason"),
            runner.assert_not_null(body.get("blocked_until"), "blocked_until"),
            runner.assert_equals(body.get("strike_count"), 3, "strike_count"),
            runner.assert_equals(body.get("security", {}).get("status"), "blocked", "status")
        ])
    
    runner.run_test("Actively blocked user", "FIREWALL", setup_blocked_user, test_blocked_user)
    
    # Test 2: Bloqueo indefinido (sin fecha de expiración)
    def setup_indefinite_block():
        db.create_user(800800819, "Indefinite Block", "user")
        db.create_firewall_entry(800800819, is_blocked=True, blocked_until=None, strike_count=10)
    
    def test_indefinite_block():
        response = send_request({"user": {"telegram_id": 800800819}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "FIREWALL_BLOCKED", "reason"),
            runner.assert_equals(body.get("blocked_until"), "indefinido", "blocked_until")
        ])
    
    runner.run_test("Indefinite block (no expiry)", "FIREWALL", 
                    setup_indefinite_block, test_indefinite_block)
    
    # Test 3: Bloqueo que expira pronto (1 minuto)
    def setup_expiring_soon():
        db.create_user(800800820, "Expiring Soon", "user")
        blocked_until = datetime.now(timezone.utc) + timedelta(minutes=1)
        db.create_firewall_entry(800800820, is_blocked=True, blocked_until=blocked_until)
    
    def test_expiring_soon():
        response = send_request({"user": {"telegram_id": 800800820}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "FIREWALL_BLOCKED", "reason")
    
    runner.run_test("Block expiring soon (1 min)", "FIREWALL", 
                    setup_expiring_soon, test_expiring_soon)
    
    # Test 4: Usuario nuevo bloqueado (sin registro en users)
    def setup_new_user_blocked():
        blocked_until = datetime.now(timezone.utc) + timedelta(hours=1)
        db.create_firewall_entry(800800821, is_blocked=True, blocked_until=blocked_until, strike_count=5)
    
    def test_new_user_blocked():
        response = send_request({"user": {"telegram_id": 800800821}})
        if not response:
            return False
        
        body = response["body"]
        # Usuario nuevo pero bloqueado por firewall
        return runner.assert_equals(body.get("reason"), "FIREWALL_BLOCKED", "reason")
    
    runner.run_test("New user but firewall blocked", "FIREWALL", 
                    setup_new_user_blocked, test_new_user_blocked)


def run_strike_tests(runner: TestRunner, db: TestDataManager):
    """Tests de conteo de strikes."""
    
    subheader("⚡ STRIKE COUNT TESTS")
    
    # Test 1: Usuario con strikes altos (debería notificar BB_00)
    def setup_high_strikes():
        db.create_user(800800822, "High Strikes", "user")
        db.create_firewall_entry(800800822, is_blocked=False, strike_count=6)
    
    def test_high_strikes():
        response = send_request({"user": {"telegram_id": 800800822}})
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("reason"), "AUTHORIZED", "reason"),
            runner.assert_equals(body.get("security", {}).get("strike_count"), 6, "strike_count")
        ])
    
    runner.run_test("User with high strikes (threshold)", "STRIKES", 
                    setup_high_strikes, test_high_strikes)
    
    # Test 2: Usuario en el límite del threshold (5)
    def setup_threshold_strikes():
        db.create_user(800800823, "Threshold Strikes", "user")
        db.create_firewall_entry(800800823, is_blocked=False, strike_count=5)
    
    def test_threshold_strikes():
        response = send_request({"user": {"telegram_id": 800800823}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("security", {}).get("strike_count"), 5, "strike_count")
    
    runner.run_test("User at strike threshold (5)", "STRIKES", 
                    setup_threshold_strikes, test_threshold_strikes)
    
    # Test 3: Usuario con 0 strikes
    def setup_zero_strikes():
        db.create_user(800800824, "Zero Strikes", "user")
        db.create_firewall_entry(800800824, is_blocked=False, strike_count=0)
    
    def test_zero_strikes():
        response = send_request({"user": {"telegram_id": 800800824}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("security", {}).get("strike_count"), 0, "strike_count")
    
    runner.run_test("User with zero strikes", "STRIKES", setup_zero_strikes, test_zero_strikes)


def run_edge_case_tests(runner: TestRunner, db: TestDataManager):
    """Tests de casos edge."""
    
    subheader("🔬 EDGE CASE TESTS")
    
    # Test 1: telegram_id muy grande
    def test_large_telegram_id():
        response = send_request({"user": {"telegram_id": 9999999999}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("access"), "granted", "access")
    
    runner.run_test("Very large telegram_id", "EDGE", lambda: None, test_large_telegram_id)
    
    # Test 2: Payload con campos extra
    def test_extra_fields():
        response = send_request({
            "user": {"telegram_id": 999999993, "first_name": "Test"},
            "extra_field": "should be ignored",
            "another": {"nested": "data"}
        })
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("access"), "granted", "access")
    
    runner.run_test("Payload with extra fields", "EDGE", lambda: None, test_extra_fields)
    
    # Test 3: first_name con caracteres especiales
    def test_special_characters():
        response = send_request({
            "user": {
                "telegram_id": 999999994,
                "first_name": "José María 日本語 🎉"
            }
        })
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("access"), "granted", "access")
    
    runner.run_test("Special characters in first_name", "EDGE", lambda: None, test_special_characters)
    
    # Test 4: Múltiples requests del mismo usuario
    def setup_multi_request_user():
        db.create_user(800800825, "Multi Request", "user")
    
    def test_multiple_requests():
        results = []
        for i in range(3):
            response = send_request({"user": {"telegram_id": 800800825}})
            if response:
                results.append(response["body"].get("reason") == "AUTHORIZED")
        
        return all(results) and len(results) == 3
    
    runner.run_test("Multiple rapid requests", "EDGE", 
                    setup_multi_request_user, test_multiple_requests)
    
    # Test 5: Usuario con todos los campos
    def test_full_payload():
        response = send_request({
            "user": {
                "telegram_id": 999999995,
                "first_name": "Full",
                "username": "full_user"
            },
            "routing": {
                "source": "test",
                "ip": "127.0.0.1"
            }
        })
        if not response:
            return False
        
        body = response["body"]
        return all([
            runner.assert_equals(body.get("access"), "granted", "access"),
            runner.assert_equals(body.get("user", {}).get("first_name"), "Full", "first_name")
        ])
    
    runner.run_test("Full payload with all fields", "EDGE", lambda: None, test_full_payload)


def run_http_status_tests(runner: TestRunner, db: TestDataManager):
    """Tests de códigos HTTP."""
    
    subheader("🌐 HTTP STATUS CODE TESTS")
    
    # Test 1: 200 para autorizado
    def test_http_200():
        response = send_request({"user": {"telegram_id": 999999996}})
        if not response:
            return False
        
        return runner.assert_equals(response["status_code"], 200, "status_code")
    
    runner.run_test("HTTP 200 for authorized", "HTTP", lambda: None, test_http_200)
    
    # Test 2: 400 para validación fallida
    def test_http_400():
        response = send_request({"user": {"telegram_id": "invalid"}})
        if not response:
            return False
        
        return runner.assert_equals(response["status_code"], 400, "status_code")
    
    runner.run_test("HTTP 400 for validation error", "HTTP", lambda: None, test_http_400)
    
    # Test 3: 403 para bloqueado
    def setup_blocked_for_http():
        db.create_user(800800826, "HTTP Blocked", "user")
        blocked_until = datetime.now(timezone.utc) + timedelta(hours=1)
        db.create_firewall_entry(800800826, is_blocked=True, blocked_until=blocked_until)
    
    def test_http_403():
        response = send_request({"user": {"telegram_id": 800800826}})
        if not response:
            return False
        
        return runner.assert_equals(response["status_code"], 403, "status_code")
    
    runner.run_test("HTTP 403 for blocked/banned", "HTTP", setup_blocked_for_http, test_http_403)


def run_priority_tests(runner: TestRunner, db: TestDataManager):
    """Tests de prioridad de reglas."""
    
    subheader("🎯 PRIORITY TESTS")
    
    # Test 1: Firewall tiene prioridad sobre banned
    def setup_firewall_priority():
        db.create_user(800800827, "Firewall Priority", "user", deleted_at=True)
        blocked_until = datetime.now(timezone.utc) + timedelta(hours=1)
        db.create_firewall_entry(800800827, is_blocked=True, blocked_until=blocked_until)
    
    def test_firewall_priority():
        response = send_request({"user": {"telegram_id": 800800827}})
        if not response:
            return False
        
        body = response["body"]
        # Firewall debería evaluarse primero
        return runner.assert_equals(body.get("reason"), "FIREWALL_BLOCKED", "reason")
    
    runner.run_test("Firewall block has priority over ban", "PRIORITY", 
                    setup_firewall_priority, test_firewall_priority)
    
    # Test 2: Banned tiene prioridad sobre authorized
    def setup_banned_priority():
        db.create_user(800800828, "Banned Priority", "user", deleted_at=True)
    
    def test_banned_priority():
        response = send_request({"user": {"telegram_id": 800800828}})
        if not response:
            return False
        
        body = response["body"]
        return runner.assert_equals(body.get("reason"), "USER_BANNED", "reason")
    
    runner.run_test("Ban has priority over authorize", "PRIORITY", 
                    setup_banned_priority, test_banned_priority)

# ============================================
# MAIN
# ============================================

def main():
    header("BB_02 - Suite Completa de Tests de Seguridad")
    
    # Setup
    db = TestDataManager(DB_CONFIG)
    
    if not db.connect():
        return 1
    
    # Cleanup inicial
    info("Limpiando datos de prueba anteriores...")
    db.cleanup()
    ok("Datos limpios")
    
    # Runner
    runner = TestRunner(db)
    
    try:
        # Ejecutar todas las suites
        run_validation_tests(runner, db)
        run_new_user_tests(runner, db)
        run_authorized_user_tests(runner, db)
        run_banned_user_tests(runner, db)
        run_firewall_blocked_tests(runner, db)
        run_strike_tests(runner, db)
        run_edge_case_tests(runner, db)
        run_http_status_tests(runner, db)
        run_priority_tests(runner, db)
        
    finally:
        # Cleanup final
        info("Limpiando datos de prueba...")
        db.cleanup()
        ok("Datos de prueba eliminados")
        db.close()
        info("Conexión cerrada")
    
    # Reporte
    header("REPORTE DE RESULTADOS")
    
    summary = runner.get_summary()
    
    for category, data in summary["categories"].items():
        passed = data["passed"]
        failed = data["failed"]
        total = passed + failed
        
        if failed == 0:
            status = f"{C.GREEN}✓{C.RESET}"
        else:
            status = f"{C.RED}✗{C.RESET}"
        
        print(f"  {status} {category}: {passed}/{total}")
        
        # Mostrar tests fallidos
        for test in data["tests"]:
            if not test.passed:
                print(f"      {C.RED}└─ {test.name}{C.RESET}")
                for err in test.errors:
                    print(f"         {C.DIM}{err}{C.RESET}")
    
    print(f"\n{'─'*70}")
    print(f"  Total: {summary['passed']}/{summary['total']} tests passed")
    print(f"{'─'*70}")
    
    if summary["failed"] == 0:
        print(f"\n{C.GREEN}{C.BOLD}✅ TODOS LOS TESTS PASARON{C.RESET}")
        return 0
    else:
        print(f"\n{C.RED}{C.BOLD}❌ {summary['failed']} TEST(S) FALLARON{C.RESET}")
        return 1

if __name__ == "__main__":
    sys.exit(main())