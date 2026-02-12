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
Test Script definitivo para BB_02_Security_Firewall
Usando la conexión real con n8n y el método correcto para ejecutar workflows
"""

import json
import sys
import os
import time
import uuid
from typing import Dict, Any, Optional

# Agregar el directorio de scripts a la ruta para importar los módulos
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts-py'))

from n8n_crud_agent import N8NCrudAgent
import requests


def test_bb02_definitive():
    """Prueba BB_02 usando el método correcto para interactuar con n8n"""
    api_url = "https://n8n.stax.ink"
    agent = N8NCrudAgent(api_url)
    
    print("🔍 Buscando BB_02_Security_Firewall...")
    workflows = agent.list_workflows()
    bb02_id = None
    if workflows:
        for wf in workflows:
            if 'BB_02' in wf.get('name', '') and 'Security_Firewall' in wf.get('name', ''):
                bb02_id = wf.get('id')
                print(f"✅ BB_02 encontrado con ID: {bb02_id}")
                break
    
    if not bb02_id:
        print("❌ No se encontró el workflow BB_02_Security_Firewall")
        return
    
    # Crear un workflow que llame a BB_02 y tenga un webhook para dispararlo
    print("\n🔧 Creando workflow temporal con webhook...")
    
    webhook_path = f"test-bb02-final-{uuid.uuid4().hex[:8]}"
    
    workflow_data = {
        "name": f"Test_BB02_Final_{uuid.uuid4().hex[:8]}",
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": webhook_path,
                    "responseMode": "lastNode",
                    "options": {}
                },
                "id": "webhook_trigger",
                "name": "Webhook Trigger",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [240, 300]
            },
            {
                "parameters": {
                    "workflowId": bb02_id,
                    "workflowInputs": {
                        "mappingMode": "defineBelow",
                        "value": "={{ $json }}"
                    }
                },
                "id": "execute_bb02",
                "name": "Execute BB_02 Security Firewall",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": [500, 300]
            }
        ],
        "connections": {
            "Webhook Trigger": {
                "main": [
                    [
                        {
                            "node": "Execute BB_02 Security Firewall",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            }
        },
        "settings": {
            "saveManualExecutions": True
        }
    }
    
    # Crear el workflow
    created_workflow = agent.create_workflow(workflow_data)
    if not created_workflow:
        print("❌ Fallo al crear el workflow")
        return
    
    workflow_id = created_workflow.get('id')
    print(f"✅ Workflow temporal creado con ID: {workflow_id}")
    
    # Activar el workflow
    print("🔌 Activando workflow...")
    if not agent.activate_workflow(workflow_id):
        print("❌ Fallo al activar el workflow")
        agent.delete_workflow(workflow_id)
        return
    
    print("✅ Workflow activado")
    
    # Esperar a que el webhook se registre
    print("⏳ Esperando a que el webhook se registre...")
    time.sleep(5)  # Esperar más tiempo para asegurar registro del webhook
    
    # Definir los casos de prueba
    test_cases = [
        ("Usuario Nuevo", {
            "user": {
                "telegram_id": 999999999,
                "first_name": "TestUser",
                "username": "testuser"
            }
        }),
        ("Validación - Sin telegram_id", {
            "user": {
                "first_name": "NoID"
            }
        }),
        ("Validación - telegram_id inválido", {
            "user": {
                "telegram_id": "abc123"
            }
        }),
        ("Validación - telegram_id negativo", {
            "user": {
                "telegram_id": -123
            }
        }),
        ("Payload vacío", {}),
        ("Request con routing", {
            "user": {
                "telegram_id": 777777777
            },
            "routing": {
                "action": "book",
                "provider_id": "abc-123"
            }
        })
    ]
    
    # URL del webhook
    webhook_url = f"{api_url}/webhook/{webhook_path}"
    print(f"🌐 Webhook URL: {webhook_url}")
    
    # Ejecutar cada caso de prueba
    results = []
    for test_name, test_input in test_cases:
        print(f"\n🧪 Ejecutando: {test_name}")
        print(f"   Input: {json.dumps(test_input, indent=2)}")
        
        # Hacer la solicitud POST al webhook
        try:
            response = requests.post(webhook_url, json=test_input, timeout=15)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Solicitud exitosa")
                print(f"   Resultado: {json.dumps(result, indent=2)}")
                
                # Verificar si es el resultado esperado de BB_02
                expected_fields = ['success', 'access', 'reason']
                has_expected_fields = all(field in result for field in expected_fields)
                
                if has_expected_fields:
                    print(f"   ✅ Resultado válido: {result.get('access', 'N/A')} | {result.get('reason', 'N/A')}")
                    results.append((test_name, True, result))
                else:
                    print(f"   ⚠️  Resultado inesperado")
                    results.append((test_name, False, result))
            else:
                print(f"❌ Solicitud fallida - Código: {response.status_code}")
                print(f"   Respuesta: {response.text}")
                results.append((test_name, False, {"error": f"HTTP {response.status_code}", "details": response.text}))
        except Exception as e:
            print(f"❌ Error en la solicitud: {e}")
            results.append((test_name, False, {"error": str(e)}))
        
        # Pequeña pausa entre ejecuciones
        time.sleep(2)
    
    # Mostrar resumen
    print("\n" + "="*60)
    print("📊 RESULTADOS FINALES")
    print("="*60)
    
    passed = sum(1 for _, success, _ in results if success)
    failed = len(results) - passed
    
    for test_name, success, result in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}")
        if result and 'error' not in result:
            print(f"     Result: {result.get('access', 'N/A')} | {result.get('reason', 'N/A')}")
        elif result:
            print(f"     Error: {result.get('error', 'Unknown error')}")
    
    print(f"\n📈 RESUMEN: {passed}/{len(results)} PASSED")
    
    # Limpiar: desactivar y eliminar el workflow temporal
    print(f"\n🧹 Limpiando recursos...")
    if agent.deactivate_workflow(workflow_id):
        print("✅ Workflow desactivado correctamente")
    else:
        print("⚠️  No se pudo desactivar el workflow")
        
    if agent.delete_workflow(workflow_id):
        print("✅ Workflow eliminado correctamente")
    else:
        print("⚠️  No se pudo eliminar el workflow")


def main():
    print("🧪 Test Definitivo de BB_02_Security_Firewall con Conexión Real a n8n")
    print("   Usando workflow con webhook que llama a BB_02")
    print("="*60)
    
    test_bb02_definitive()


if __name__ == "__main__":
    main()