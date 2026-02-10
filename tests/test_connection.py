#!/usr/bin/env python3
"""
Test de conexión básico a n8n
Ejecutar: python3 test_connection.py
"""

import sys

# ============================================
# CONFIGURACIÓN
# ============================================
N8N_BASE_URL = "http://localhost:5678"
WEBHOOK_PATH = "/webhook/689841d2-b2a8-4329-b118-4e8675a810be"

# ============================================
# IMPORTAR REQUESTS
# ============================================
try:
    import requests
except ImportError:
    print("❌ Módulo 'requests' no instalado")
    print("   Instalar: sudo apt install python3-requests")
    print("         o: pip3 install requests --user")
    sys.exit(1)

# ============================================
# COLORES
# ============================================
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
CYAN = '\033[96m'
RESET = '\033[0m'

def test_n8n_health():
    """Test 1: Verificar que n8n está corriendo"""
    print(f"{CYAN}[1/3] Testing n8n health...{RESET}")
    
    try:
        url = f"{N8N_BASE_URL}/healthz"
        print(f"      GET {url}")
        
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            print(f"      {GREEN}✓ n8n está corriendo (HTTP 200){RESET}")
            return True
        else:
            print(f"      {YELLOW}⚠ HTTP {response.status_code}{RESET}")
            print(f"      Response: {response.text[:100]}")
            return True  # n8n responde, aunque no sea 200
            
    except requests.exceptions.ConnectionError:
        print(f"      {RED}✗ No se puede conectar a {N8N_BASE_URL}{RESET}")
        print(f"      Verificar: docker ps | grep n8n")
        return False
    except Exception as e:
        print(f"      {RED}✗ Error: {e}{RESET}")
        return False

def test_webhook_exists():
    """Test 2: Verificar que el webhook responde"""
    print(f"\n{CYAN}[2/3] Testing webhook endpoint...{RESET}")
    
    try:
        url = f"{N8N_BASE_URL}{WEBHOOK_PATH}"
        print(f"      POST {url}")
        
        # Enviar payload mínimo
        payload = {"test": "connection"}
        response = requests.post(url, json=payload, timeout=10)
        
        print(f"      Status: {response.status_code}")
        
        if response.status_code == 404:
            print(f"      {RED}✗ Webhook no encontrado (404){RESET}")
            print(f"      Verificar que BB_02 esté activo en n8n")
            return False
        elif response.status_code == 500:
            # 500 puede significar que el workflow procesó pero falló
            try:
                body = response.json()
                print(f"      Response: {body}")
                if "Unused Respond to Webhook" in str(body):
                    print(f"      {YELLOW}⚠ Webhook configurado incorrectamente{RESET}")
                    print(f"      Cambiar: Webhook → Respond → 'Using Respond to Webhook Node'")
                else:
                    print(f"      {YELLOW}⚠ Workflow error (revisar n8n logs){RESET}")
            except:
                print(f"      Response: {response.text[:200]}")
            return False
        else:
            print(f"      {GREEN}✓ Webhook responde{RESET}")
            try:
                print(f"      Response: {response.json()}")
            except:
                print(f"      Response: {response.text[:200]}")
            return True
            
    except requests.exceptions.Timeout:
        print(f"      {RED}✗ Timeout (>10s){RESET}")
        return False
    except Exception as e:
        print(f"      {RED}✗ Error: {e}{RESET}")
        return False

def test_bb02_validation():
    """Test 3: Probar validación de BB_02"""
    print(f"\n{CYAN}[3/3] Testing BB_02 validation...{RESET}")
    
    try:
        url = f"{N8N_BASE_URL}{WEBHOOK_PATH}"
        
        # Payload válido
        payload = {
            "user": {
                "telegram_id": 999999999,
                "first_name": "TestUser"
            }
        }
        
        print(f"      POST {url}")
        print(f"      Payload: {payload}")
        
        response = requests.post(url, json=payload, timeout=15)
        
        print(f"      Status: {response.status_code}")
        
        try:
            body = response.json()
            print(f"      Response: {body}")
            
            # Verificar estructura esperada
            if body.get("success") is True:
                print(f"      {GREEN}✓ BB_02 funciona correctamente{RESET}")
                return True
            elif body.get("success") is False:
                reason = body.get("reason", "unknown")
                print(f"      {YELLOW}⚠ BB_02 respondió: {reason}{RESET}")
                return True  # Funciona, aunque sea error de validación
            else:
                print(f"      {YELLOW}⚠ Respuesta inesperada{RESET}")
                return False
                
        except:
            print(f"      Response (raw): {response.text[:300]}")
            return False
            
    except Exception as e:
        print(f"      {RED}✗ Error: {e}{RESET}")
        return False

def main():
    print(f"\n{'='*50}")
    print(f"  n8n Connection Test")
    print(f"  Target: {N8N_BASE_URL}")
    print(f"{'='*50}\n")
    
    results = []
    
    # Test 1: Health check
    results.append(("n8n Health", test_n8n_health()))
    
    if not results[-1][1]:
        print(f"\n{RED}❌ n8n no está accesible. Abortando.{RESET}")
        print(f"\nVerificar:")
        print(f"  1. docker ps | grep n8n")
        print(f"  2. docker logs n8n --tail 20")
        sys.exit(1)
    
    # Test 2: Webhook exists
    results.append(("Webhook", test_webhook_exists()))
    
    # Test 3: BB_02 validation
    results.append(("BB_02", test_bb02_validation()))
    
    # Resumen
    print(f"\n{'='*50}")
    print(f"  RESUMEN")
    print(f"{'='*50}")
    
    for name, passed in results:
        status = f"{GREEN}PASS{RESET}" if passed else f"{RED}FAIL{RESET}"
        print(f"  {name}: {status}")
    
    passed = sum(1 for _, p in results if p)
    failed = len(results) - passed
    
    print(f"\n  Total: {passed}/{len(results)} passed")
    
    if failed > 0:
        print(f"\n{RED}❌ Algunos tests fallaron{RESET}")
        sys.exit(1)
    else:
        print(f"\n{GREEN}✅ Conexión OK - Listo para tests completos{RESET}")
        sys.exit(0)

if __name__ == "__main__":
    main()