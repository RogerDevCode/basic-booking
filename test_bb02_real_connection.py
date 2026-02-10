#!/usr/bin/env python3
"""
Test Script para BB_02_Security_Firewall usando conexión real con n8n
Este script crea un workflow temporal que llama a BB_02 y ejecuta pruebas reales
"""

import json
import sys
import os
import uuid
import time
import requests
from typing import Dict, Any, Optional

# Agregar el directorio de scripts a la ruta para importar los módulos
sys.path.append(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'scripts-py'))

from n8n_crud_agent import N8NCrudAgent


class RealBB02Tester:
    def __init__(self, api_url: str = "http://localhost:5678"):
        self.api_url = api_url
        self.agent = N8NCrudAgent(api_url)
        self.caller_workflow_id = None
        self.webhook_path = None
        
    def find_bb02_workflow(self) -> Optional[str]:
        """Encuentra el workflow BB_02 en la instancia de n8n"""
        workflows = self.agent.list_workflows()
        if workflows:
            for wf in workflows:
                if 'BB_02' in wf.get('name', '') and 'Security_Firewall' in wf.get('name', ''):
                    return wf.get('id')
        return None

    def create_caller_workflow(self) -> Optional[str]:
        """Crea un workflow temporal con webhook que llama a BB_02"""
        bb02_id = self.find_bb02_workflow()
        if not bb02_id:
            print("❌ No se encontró el workflow BB_02_Security_Firewall")
            return None

        name = f"Test_BB02_Caller_{uuid.uuid4().hex[:8]}"
        self.webhook_path = f"test-bb02-{uuid.uuid4().hex[:8]}"
        
        workflow = {
            "name": name,
            "nodes": [
                {
                    "parameters": {
                        "httpMethod": "POST",
                        "path": self.webhook_path,
                        "responseMode": "lastNode",
                        "options": {}
                    },
                    "id": "webhook",
                    "name": "Webhook",
                    "type": "n8n-nodes-base.webhook",
                    "typeVersion": 1,
                    "position": [0, 0]
                },
                {
                    "parameters": {
                        "workflowId": bb02_id,
                        "options": {}
                    },
                    "id": "call_bb02",
                    "name": "Call BB_02",
                    "type": "n8n-nodes-base.executeWorkflow",
                    "typeVersion": 1.1,
                    "position": [250, 0]
                }
            ],
            "connections": {
                "Webhook": {
                    "main": [[{"node": "Call BB_02", "type": "main", "index": 0}]]
                }
            },
            "settings": {"saveManualExecutions": True}
        }

        print(f"🔧 Creando workflow temporal: {name}")
        created_workflow = self.agent.create_workflow(workflow)
        if created_workflow:
            workflow_id = created_workflow.get('id')
            print(f"✅ Workflow creado con ID: {workflow_id}")
            
            # Activar el workflow
            if self.agent.activate_workflow(workflow_id):
                print(f"✅ Workflow activado")
                self.caller_workflow_id = workflow_id
                
                # Esperar un momento para que el webhook se registre
                print("⏳ Esperando a que el webhook se registre...")
                time.sleep(3)
                
                return workflow_id
            else:
                print("❌ Fallo al activar el workflow")
                # Eliminar el workflow si no se pudo activar
                self.agent.delete_workflow(workflow_id)
                return None
        else:
            print("❌ Fallo al crear el workflow")
            return None

    def execute_test_scenario(self, scenario_name: str, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Ejecuta un escenario de prueba enviando una solicitud al webhook"""
        if not self.webhook_path:
            print("❌ No hay webhook disponible")
            return {"error": "No webhook"}

        print(f"\n🧪 Ejecutando escenario: {scenario_name}")
        print(f"   Payload: {json.dumps(payload, indent=2)}")
        
        # Enviar solicitud al webhook
        webhook_url = f"{self.api_url}/webhook/{self.webhook_path}"
        
        try:
            response = requests.post(webhook_url, json=payload, timeout=15)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Solicitud exitosa")
                print(f"   Resultado: {json.dumps(result, indent=2)}")
                return result
            else:
                print(f"❌ Solicitud fallida - Código: {response.status_code}")
                print(f"   Respuesta: {response.text}")
                return {"error": f"HTTP {response.status_code}", "details": response.text}
        except Exception as e:
            print(f"❌ Error en la solicitud: {e}")
            return {"error": str(e)}

    def run_comprehensive_tests(self):
        """Ejecuta todos los tests de BB_02 usando la conexión real a n8n"""
        print("🚀 Iniciando tests de BB_02_Security_Firewall con conexión real a n8N")
        print(f"🔗 Conectando a: {self.api_url}")
        
        # Buscar BB_02
        bb02_id = self.find_bb02_workflow()
        if not bb02_id:
            print("❌ No se encontró el workflow BB_02_Security_Firewall")
            return
        else:
            print(f"✅ BB_02 encontrado con ID: {bb02_id}")

        # Crear workflow de caller
        caller_id = self.create_caller_workflow()
        if not caller_id:
            print("❌ No se pudo crear el workflow de caller")
            return

        # Definir escenarios de prueba
        test_scenarios = [
            ("TC1: Usuario Nuevo", {
                "user": {
                    "telegram_id": 999999999,
                    "first_name": "TestUser",
                    "username": "testuser"
                }
            }),
            ("TC2: Validación - Sin telegram_id", {
                "user": {
                    "first_name": "NoID"
                }
            }),
            ("TC3: Validación - telegram_id inválido", {
                "user": {
                    "telegram_id": "abc123"
                }
            }),
            ("TC4: Validación - Sin objeto user", {
                "telegram_id": 123456789
            }),
            ("TC5: Validación - telegram_id negativo", {
                "user": {
                    "telegram_id": -123
                }
            }),
            ("TC6: Validación - Payload vacío", {}),
            ("TC7: Validación - username muy largo", {
                "user": {
                    "telegram_id": 111111111,
                    "username": "a" * 50  # 50 caracteres, max es 32
                }
            }),
            ("TC8: telegram_id como string numérico", {
                "user": {
                    "telegram_id": "888888888"  # String pero numérico
                }
            }),
            ("TC9: Request con routing", {
                "user": {
                    "telegram_id": 777777777
                },
                "routing": {
                    "action": "book",
                    "provider_id": "abc-123"
                }
            })
        ]

        # Ejecutar todos los escenarios
        results = []
        for scenario_name, payload in test_scenarios:
            result = self.execute_test_scenario(scenario_name, payload)
            results.append((scenario_name, result))
            time.sleep(1)  # Pequeña pausa entre ejecuciones

        # Mostrar resultados
        print("\n" + "="*60)
        print("📊 RESULTADOS DE LAS PRUEBAS")
        print("="*60)
        
        passed = 0
        failed = 0
        
        for scenario_name, result in results:
            if "error" not in result:
                status = "✅ PASS"
                passed += 1
            else:
                status = "❌ FAIL"
                failed += 1
            
            print(f"{status} {scenario_name}")
            if "error" not in result:
                print(f"     Result: {result.get('access', 'N/A')} | {result.get('reason', 'N/A')}")
        
        print(f"\n📈 RESUMEN: {passed} PASSED, {failed} FAILED")
        
        # Limpiar: eliminar el workflow temporal
        if self.caller_workflow_id:
            print(f"\n🧹 Limpiando workflow temporal: {self.caller_workflow_id}")
            if self.agent.deactivate_workflow(self.caller_workflow_id):
                print("✅ Workflow desactivado correctamente")
            else:
                print("⚠️  No se pudo desactivar el workflow")
                
            if self.agent.delete_workflow(self.caller_workflow_id):
                print("✅ Workflow eliminado correctamente")
            else:
                print("⚠️  No se pudo eliminar el workflow")

    def test_direct_connection(self):
        """Prueba la conexión directa con n8n"""
        print("🔍 Probando conexión directa con n8n...")
        
        try:
            workflows = self.agent.list_workflows()
            if workflows is not None:
                print(f"✅ Conexión exitosa a n8n")
                print(f"📦 Número de workflows: {len(workflows) if workflows else 0}")
                
                # Mostrar workflows BB_XX
                bb_workflows = [wf for wf in (workflows or []) if 'BB_' in wf.get('name', '')]
                print(f"📋 Workflows BB_XX encontrados: {len(bb_workflows)}")
                for wf in bb_workflows:
                    status = "🟢" if wf.get('active', False) else "🔴"
                    print(f"   {status} {wf.get('name')} (ID: {wf.get('id')})")
                
                return True
            else:
                print("❌ Fallo al listar workflows")
                return False
        except Exception as e:
            print(f"❌ Error en la conexión: {e}")
            return False


def main():
    print("🧪 Test de BB_02_Security_Firewall con Conexión Real a n8n")
    print("="*60)
    
    tester = RealBB02Tester()
    
    # Primero probar la conexión
    if not tester.test_direct_connection():
        print("\n❌ No se pudo establecer conexión con n8n. Terminando.")
        return
    
    print()
    
    # Luego ejecutar los tests reales
    tester.run_comprehensive_tests()


if __name__ == "__main__":
    main()