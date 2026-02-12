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
Test Script para BB_02_Security_Firewall usando conexión real con n8n
Alternativa: Usar el executeWorkflowTrigger directamente
"""

import json
import sys
import os
import time
from typing import Dict, Any, Optional

# Agregar el directorio de scripts a la ruta para importar los módulos
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts-py'))

from n8n_crud_agent import N8NCrudAgent


def test_bb02_with_execute_workflow():
    """Prueba BB_02 creando un workflow que lo llama usando executeWorkflow"""
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
    
    # Crear un workflow temporal que llame a BB_02
    print("\n🔧 Creando workflow temporal que llama a BB_02...")
    
    # Definir el workflow que llama a BB_02
    workflow_data = {
        "name": "Test_Call_BB02_Manual",
        "nodes": [
            {
                "parameters": {},
                "id": "trigger",
                "name": "Manual Trigger",
                "type": "n8n-nodes-base.manualTrigger",
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
                "name": "Execute BB_02",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": [500, 300]
            },
            {
                "parameters": {
                    "values": {
                        "string": {
                            "response": "={{ $json }}"
                        }
                    },
                    "options": {}
                },
                "id": "set_response",
                "name": "Set Response",
                "type": "n8n-nodes-base.set",
                "typeVersion": 3.2,
                "position": [760, 300]
            }
        ],
        "connections": {
            "Manual Trigger": {
                "main": [
                    [
                        {
                            "node": "Execute BB_02",
                            "type": "main",
                            "index": 0
                        }
                    ]
                ]
            },
            "Execute BB_02": {
                "main": [
                    [
                        {
                            "node": "Set Response",
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
    
    # Ejecutar cada caso de prueba
    results = []
    for test_name, test_input in test_cases:
        print(f"\n🧪 Ejecutando: {test_name}")
        print(f"   Input: {json.dumps(test_input, indent=2)}")
        
        # Ejecutar el workflow con el input
        execution_result = agent.execute_workflow(workflow_id, {
            "inputs": [test_input]
        })
        
        if execution_result:
            print(f"✅ Ejecución completada")
            
            # Extraer el resultado
            if 'data' in execution_result and 'resultData' in execution_result['data']:
                run_data = execution_result['data']['resultData']['runData']
                
                # Buscar el resultado del nodo Execute BB_02
                for node_name, node_results in run_data.items():
                    if node_name == "Execute BB_02" and len(node_results) > 0:
                        last_execution = node_results[-1]  # Última ejecución
                        if 'data' in last_execution and 'main' in last_execution['data']:
                            output_data = last_execution['data']['main'][0][0]['json']  # Resultado del primer output
                            print(f"   Resultado de BB_02: {json.dumps(output_data, indent=2)}")
                            
                            # Verificar si es el resultado esperado
                            expected_fields = ['success', 'access', 'reason']
                            has_expected_fields = all(field in output_data for field in expected_fields)
                            
                            if has_expected_fields:
                                print(f"   ✅ Resultado válido: {output_data.get('access', 'N/A')} | {output_data.get('reason', 'N/A')}")
                                results.append((test_name, True, output_data))
                            else:
                                print(f"   ⚠️  Resultado inesperado")
                                results.append((test_name, False, output_data))
                            break
                else:
                    print("   ⚠️  No se encontró el resultado de BB_02")
                    results.append((test_name, False, None))
            else:
                print("   ⚠️  No se encontraron datos de resultado")
                results.append((test_name, False, None))
        else:
            print("   ❌ Fallo al ejecutar el workflow")
            results.append((test_name, False, None))
        
        # Pequeña pausa entre ejecuciones
        time.sleep(1)
    
    # Mostrar resumen
    print("\n" + "="*60)
    print("📊 RESULTADOS FINALES")
    print("="*60)
    
    passed = sum(1 for _, success, _ in results if success)
    failed = len(results) - passed
    
    for test_name, success, result in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"{status} {test_name}")
        if result:
            print(f"     Result: {result.get('access', 'N/A')} | {result.get('reason', 'N/A')}")
    
    print(f"\n📈 RESUMEN: {passed}/{len(results)} PASSED")
    
    # Limpiar: eliminar el workflow temporal
    print(f"\n🧹 Eliminando workflow temporal: {workflow_id}")
    if agent.delete_workflow(workflow_id):
        print("✅ Workflow eliminado correctamente")
    else:
        print("⚠️  No se pudo eliminar el workflow")


def main():
    print("🧪 Test de BB_02_Security_Firewall con Conexión Real a n8n")
    print("   Usando executeWorkflow en lugar de webhooks")
    print("="*60)
    
    test_bb02_with_execute_workflow()


if __name__ == "__main__":
    main()