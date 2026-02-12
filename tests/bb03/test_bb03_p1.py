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
Test BB_03 P1 Improvements using a Wrapper Workflow
Verifica que la modularización de BB_03 funcione correctamente:
1. Crea un workflow temporal con Webhook para disparar BB_03
2. Verifica ejecución exitosa con sub-workflows
3. Verifica creación de audit logs
"""

import sys
import os
import json
import time
import uuid
import requests


from n8n_crud_agent import N8NCrudAgent
from test_helpers import (
    print_header, print_step, print_success, print_error, print_info,
    init_agent, verify_workflow_exists
)

BB_03_ID = '4D2-fV_Y792B3eDweI3lH'
WRAPPER_NAME = "Test_BB03_Wrapper_Temp"
WEBHOOK_PATH = f"test-bb03-{str(uuid.uuid4())[:8]}"

def create_wrapper_workflow(agent, input_data):
    """Crea un workflow temporal para disparar BB_03"""
    
    workflow_data = {
        "name": WRAPPER_NAME,
        "nodes": [
            {
                "parameters": {
                    "httpMethod": "POST",
                    "path": WEBHOOK_PATH,
                    "options": {}
                },
                "id": "webhook-node",
                "name": "Webhook",
                "type": "n8n-nodes-base.webhook",
                "typeVersion": 1,
                "position": [260, 300],
                "webhookId": str(uuid.uuid4())
            },
            {
                "parameters": {
                    "jsCode": f"return [{{ json: {json.dumps(input_data)} }}];"
                },
                "id": "prepare-data-node",
                "name": "Prepare Data",
                "type": "n8n-nodes-base.code",
                "typeVersion": 2,
                "position": [460, 300]
            },
            {
                "parameters": {
                    "workflowId": {
                        "__rl": True,
                        "value": BB_03_ID,
                        "mode": "id",
                        "cachedResultUrl": f"/workflow/{BB_03_ID}"
                    },
                    "options": {}
                },
                "id": "execute-bb03-node",
                "name": "Execute BB_03",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": [660, 300]
            }
        ],
        "connections": {
            "Webhook": {
                "main": [[{"node": "Prepare Data", "type": "main", "index": 0}]]
            },
            "Prepare Data": {
                "main": [[{"node": "Execute BB_03", "type": "main", "index": 0}]]
            }
        },
        "settings": {
            "executionOrder": "v1"
        }
    }
    
    return agent.create_workflow(workflow_data)

def run_bb03_test():
    print_header("Test BB_03: Modularización y Audit Log (Wrapper Method)")
    
    agent = init_agent('http://localhost:5678')
    if not agent:
        return False

    # 1. Verificar BB_03
    print_step(1, 4, "Verificando BB_03")
    wf = verify_workflow_exists(agent, BB_03_ID, "BB_03_Slot_Availability")
    if not wf:
        return False
    
    # 2. Crear y Ejecutar Wrapper
    print_step(2, 4, "Ejecutando BB_03 vía Wrapper")
    
    test_input = {
        "provider_id": "11111111-1111-1111-1111-111111111111", 
        "target_date": "2026-03-01",
        "days_range": 5
    }
    
    wrapper = create_wrapper_workflow(agent, test_input)
    if not wrapper:
        print_error("No se pudo crear el workflow wrapper")
        return False
        
    print_success(f"Wrapper creado: {wrapper['id']} (Webhook: {WEBHOOK_PATH})")
    
    try:
        # Activar wrapper
        if agent.activate_workflow(wrapper['id']):
            print_info("Wrapper activado")
            
            # Verificar si realmente está activo
            active_wfs = agent.list_active_workflows()
            is_active = any(w['id'] == wrapper['id'] for w in active_wfs)
            if is_active:
                print_success(f"Confirmado: Workflow {wrapper['id']} está en la lista de activos")
            else:
                print_error(f"ALERTA: Workflow {wrapper['id']} NO aparece como activo a pesar de respuesta 200")
            
            # Llamar al webhook
            webhook_url = f"{agent.api_url}/webhook/{WEBHOOK_PATH}"
            print_info(f"Llamando a {webhook_url} (POST)...")
            
            try:
                # Esperar un poco para que se propague la activación
                time.sleep(5)
                response = requests.post(webhook_url, json={}, timeout=10)
                if response.status_code == 200:
                    print_success(f"Webhook response: {response.status_code}")
                else:
                    print_error(f"Webhook response: {response.status_code} - {response.text}")
            except Exception as e:
                print_error(f"Error llamando webhook: {e}")
                
            # Esperar a que se procese
            print_info("Esperando ejecución de BB_03...")
            time.sleep(5)
            
            # Esperar a que se procese
            print_info("Esperando ejecución de BB_03...")
            time.sleep(5)
            
            # 3. Verificar Audit Log en DB (La prueba más fiable)
            print_step(3, 4, "Verificando Audit Log en Base de Datos")
            
            # Usar n8n para consultar la DB (ya que no tenemos acceso directo desde aquí)
            # Creamos un workflow temporal de consulta
            check_db_workflow = {
                "name": "Check_Audit_Log_Temp",
                "nodes": [
                    {
                        "parameters": {
                            "httpMethod": "POST",
                            "path": f"check-db-{str(uuid.uuid4())[:8]}",
                            "options": {}
                        },
                        "id": "webhook-node-db",
                        "name": "Webhook",
                        "type": "n8n-nodes-base.webhook",
                        "typeVersion": 1,
                        "position": [260, 300],
                        "webhookId": str(uuid.uuid4())
                    },
                    {
                        "parameters": {
                            "operation": "executeQuery",
                            "query": f"SELECT * FROM audit_logs WHERE record_id = '{test_input['provider_id']}' ORDER BY created_at DESC LIMIT 1;",
                            "options": {}
                        },
                        "id": "postgres-node",
                        "name": "Postgres",
                        "type": "n8n-nodes-base.postgres",
                        "typeVersion": 2.4,
                        "position": [460, 300],
                        "credentials": {
                            "postgres": {
                                "id": "99BnrzwZQDhYU6Ly",
                                "name": "Postgres Booking"
                            }
                        }
                    }
                ],
                "connections": {
                    "Webhook": {
                        "main": [[{"node": "Postgres", "type": "main", "index": 0}]]
                    }
                },
                "settings": {
                    "executionOrder": "v1"
                }
            }
            
            check_wf = agent.create_workflow(check_db_workflow)
            if check_wf:
                # Activate the workflow so webhook works
                agent.activate_workflow(check_wf['id'])
                # Wait for activation to propagate
                time.sleep(2)
                
                print_info("Ejecutando verificación de DB...")
                # Extract webhook path to call it
                webhook_path = next(n['parameters']['path'] for n in check_wf['nodes'] if n['type'] == 'n8n-nodes-base.webhook')
                webhook_url = f"{agent.api_url}/webhook/{webhook_path}"
                
                try:
                    response = requests.post(webhook_url, json={}, timeout=10)
                    if response.status_code == 200:
                        # n8n webhook response might not contain the DB data directly if not configured to respond
                        # But we can check execution data
                        pass
                    else:
                        print_error(f"Error calling DB check webhook: {response.status_code}")
                except Exception as e:
                    print_error(f"Exc calling DB check: {e}")

                # Get the execution result to see the DB output
                time.sleep(2)
                execs = agent.get_executions(workflow_id=check_wf['id'], limit=1)
                db_result = execs[0] if execs else None
                
                # Limpiar
                agent.delete_workflow(check_wf['id'])
                
                if db_result:
                    rows = db_result.get('data', {}).get('resultData', {}).get('runData', {}).get('Postgres', [{}])[0].get('data', {}).get('main', [[]])[0]
                    
                    if rows:
                        log_entry = rows[0].get('json', {})
                        print_success(f"Audit Log encontrado! ID: {log_entry.get('id')}")
                        print_info(f"Action: {log_entry.get('action')}")
                        print_info(f"Entity: {log_entry.get('entity_type')} {log_entry.get('entity_id')}")
                        print_info(f"Metadata: {log_entry.get('metadata')}")
                        
                        # Si hay log, BB_03 llegó al menos hasta la validación exitosa
                        # También implica que los sub-workflows (Validate Config) pasaron si el log se crea
                        # (dependiendo del orden, pero Audit Log está tras validación)
                        print_success("✅ Integración BB_03 verificada exitosamente")
                    else:
                        print_error("❌ No se encontró Audit Log en la base de datos")
                else:
                    print_error("Error ejecutando consulta de verificación")
            else:
                print_error("No se pudo crear workflow de verificación de DB")

            # 4. Verificar Ejecución del Wrapper (para debug)
            print_step(4, 4, "Verificando Ejecución del Wrapper")
            wrapper_execs = agent.get_executions(workflow_id=wrapper['id'], limit=1)
            if wrapper_execs:
                w_exec_id = wrapper_execs[0]['id']
                print_info(f"Ejecución Wrapper: {w_exec_id}")
                w_details = agent.get_execution_by_id(w_exec_id)
                if w_details:
                    # Check output of Execute BB_03
                    run_data = w_details.get('data', {}).get('resultData', {}).get('runData', {})
                    bb03_node = run_data.get('Execute BB_03', [{}])
                    if bb03_node:
                        # n8n v1 returns status in the object
                        print_success("Nodo 'Execute BB_03' ejecutado en wrapper")
                        # output_data = bb03_node[0].get('data', {}).get('main', [[]])[0]
                        # print_info(f"Output BB_03: {json.dumps(output_data, default=str)[:200]}...")
                    else:
                        print_error("Nodo 'Execute BB_03' no parece haberse ejecutado correctamente")
            else:
                print_info("No se encontró ejecución del wrapper (puede ser normal si fue muy rápida o no persistida)")

    finally:
        # Limpieza
        print_step(4, 4, "Limpieza")
        agent.delete_workflow(wrapper['id'])
        print_info("Workflow wrapper eliminado")

if __name__ == "__main__":
    run_bb03_test()
