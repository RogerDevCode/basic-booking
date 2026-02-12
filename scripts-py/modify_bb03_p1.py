#!/usr/bin/env python3

# --- Watchdog Injection ---
import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '.')))
try:
    import watchdog
    watchdog.setup(300)
except ImportError:
    print('Warning: watchdog module not found', file=sys.stderr)
# --------------------------

"""
Script para modificar BB_03 con mejoras P1:
- Reemplazar Calculate Slots con sub-workflow
- Agregar Validate Config helper
- Agregar Audit Logging
"""

import sys
import os
import json
import uuid

current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.append(current_dir)

from n8n_crud_agent import N8NCrudAgent

# IDs de los helpers
VALIDATE_CONFIG_ID = 'nuQRvaWJAUCYjVSk'
CALCULATE_SLOTS_ID = 'sI5VqGo9yr67UmeW'
BB_03_ID = '4D2-fV_Y792B3eDweI3lH'
BB_00_ID = '_Za9GzqB2cS9HVwBglt43'

def modify_bb03():
    """Modifica BB_03 para usar sub-workflows"""
    
    agent = N8NCrudAgent('http://localhost:5678')
    
    # Cargar BB_03 actual
    print("📋 Cargando BB_03 actual...")
    bb03 = agent.get_workflow_by_id(BB_03_ID)
    if not bb03:
        print("❌ Error cargando BB_03")
        return False
    
    nodes = bb03['nodes']
    connections = bb03['connections']
    
    print(f"✅ BB_03 cargado ({len(nodes)} nodos)")
    print("   Nodos encontrados:", [n['name'] for n in nodes])
    
    # ============================================
    # 1. Agregar nodo de Audit Log
    # ============================================
    print("\n📝 Agregando nodo de Audit Log...")
    
    if any(n['name'] == "Audit Log: Availability Check" for n in nodes):
         print("⚠️  Audit Log ya existe, saltando...")
    else:
        audit_log_node = {
            "parameters": {
                "operation": "executeQuery",
                "query": """INSERT INTO audit_logs (
      action, entity_type, entity_id, metadata, created_at
    ) VALUES (
      'ACCESS_CHECK',
      'provider',
      '{{ $json.provider_id }}',
      '{{ JSON.stringify({
        target_date: $json.target_date,
        days_range: $json.days_range,
        workflow: "BB_03"
      }) }}',
      NOW()
    )""",
                "options": {}
            },
            "id": str(uuid.uuid4()),
            "name": "Audit Log: Availability Check",
            "type": "n8n-nodes-base.postgres",
            "typeVersion": 2.4,
            "position": [336, 560],
            "alwaysOutputData": True,
            "credentials": {
                "postgres": {
                    "id": "99BnrzwZQDhYU6Ly",
                    "name": "Postgres Booking"
                }
            },
            "continueOnFail": True
        }
        
        nodes.append(audit_log_node)
        
        # Conectar: Switch: Valid? (extra output) -> Audit Log -> DB: Provider + Config
        # Encontrar nodos por nombre
        switch_valid_node = next((n for n in nodes if n['name'] == 'Switch: Valid?'), None)
        # db_provider_node = next((n for n in nodes if n['name'] == 'DB: Provider + Config'), None) # Not strictly needed for connection update
        
        if switch_valid_node:
            # Modificar conexión: Switch: Valid? -> Audit Log
            if 'Switch: Valid?' not in connections:
                connections['Switch: Valid?'] = {"main": [[], []]}
            
            # Extra output (índice 1) va a Audit Log
            connections['Switch: Valid?']['main'][1] = [{
                "node": "Audit Log: Availability Check",
                "type": "main",
                "index": 0
            }]
            
            # Audit Log -> DB: Provider + Config
            connections['Audit Log: Availability Check'] = {
                "main": [[{
                    "node": "DB: Provider + Config",
                    "type": "main",
                    "index": 0
                }]]
            }
            
            print("✅ Audit Log agregado y conectado")
        else:
            print("⚠️  No se encontraron nodos para conectar Audit Log")
    
    # ============================================
    # 2. Agregar nodo Execute: Validate Config
    # ============================================
    print("\n🔧 Agregando nodo Execute: Validate Config...")
    
    if any(n['name'] == "Execute: Validate Config" for n in nodes):
        print("⚠️  Validate Config ya existe, saltando...")
    else:
        validate_config_exec_node = {
            "parameters": {
                "workflowId": {
                    "__rl": True,
                    "value": VALIDATE_CONFIG_ID,
                    "mode": "id",
                    "cachedResultUrl": f"/workflow/{VALIDATE_CONFIG_ID}"
                },
                "options": {}
            },
            "id": str(uuid.uuid4()),
            "name": "Execute: Validate Config",
            "type": "n8n-nodes-base.executeWorkflow",
            "typeVersion": 1.1,
            "position": [1216, 720],
            "continueOnFail": False
        }
        
        nodes.append(validate_config_exec_node)
        
        # Conectar: Prepare Schedule Data -> Execute: Validate Config
        prepare_schedule_node = next((n for n in nodes if n['name'] == 'Prepare Schedule Data'), None)
        # switch_has_schedule_node = next((n for n in nodes if n['name'] == 'Switch: Has Schedule?'), None) # Not strictly needed
        
        if prepare_schedule_node:
            # Modificar conexión: Prepare Schedule Data -> Execute: Validate Config
            connections['Prepare Schedule Data'] = {
                "main": [[{
                    "node": "Execute: Validate Config",
                    "type": "main",
                    "index": 0
                }]]
            }
            
            # Execute: Validate Config -> Switch: Has Schedule?
            connections['Execute: Validate Config'] = {
                "main": [[{
                    "node": "Switch: Has Schedule?",
                    "type": "main",
                    "index": 0
                }]]
            }
            
            print("✅ Validate Config agregado y conectado")
        else:
            print("⚠️  No se encontraron nodos para conectar Validate Config")
    
    # ============================================
    # 3. Reemplazar Calculate Slots con Execute Workflow
    # ============================================
    print("\n🔄 Reemplazando Calculate Slots con sub-workflow...")
    
    # Check if already replaced
    if any(n['name'] == "Execute: Calculate Slots" for n in nodes):
        print("⚠️  Calculate Slots ya fue reemplazado, saltando...")
    else:
        # Encontrar y eliminar nodo Calculate Slots original
        calculate_slots_node = next((n for n in nodes if n['name'] == 'Calculate Slots'), None)
        
        if calculate_slots_node:
            # Guardar posición
            position = calculate_slots_node['position']
            
            # Eliminar nodo original
            nodes.remove(calculate_slots_node)
            
            # Crear nodo Execute Workflow
            execute_calculate_node = {
                "parameters": {
                    "workflowId": {
                        "__rl": True,
                        "value": CALCULATE_SLOTS_ID,
                        "mode": "id",
                        "cachedResultUrl": f"/workflow/{CALCULATE_SLOTS_ID}"
                    },
                    "options": {}
                },
                "id": str(uuid.uuid4()),
                "name": "Execute: Calculate Slots",
                "type": "n8n-nodes-base.executeWorkflow",
                "typeVersion": 1.1,
                "position": position,
                "continueOnFail": False
            }
            
            nodes.append(execute_calculate_node)
            
            # Actualizar conexiones
            # Switch: Bookings Error? -> Execute: Calculate Slots
            if 'Switch: Bookings Error?' in connections:
                connections['Switch: Bookings Error?']['main'][1] = [{
                    "node": "Execute: Calculate Slots",
                    "type": "main",
                    "index": 0
                }]
            
            # Execute: Calculate Slots -> Format Response
            connections['Execute: Calculate Slots'] = {
                "main": [[{
                    "node": "Format Response",
                    "type": "main",
                    "index": 0
                }]]
            }
            
            print("✅ Calculate Slots reemplazado con sub-workflow")
        else:
            print("⚠️  Nodo Calculate Slots no encontrado (y no existe su reemplazo)")
    
    # ============================================
    # 4. Preparar datos para actualización
    # ============================================
    print("\n📦 Preparando workflow para actualización...")
    
    # Filtrar settings para incluir solo propiedades permitidas
    settings = bb03.get('settings', {})
    allowed_settings = {'executionOrder', 'errorWorkflow', 'callerPolicy'}
    filtered_settings = {k: v for k, v in settings.items() if k in allowed_settings}
    
    # Crear payload para actualización
    update_payload = {
        "name": bb03['name'],
        "nodes": nodes,
        "connections": connections,
        "settings": filtered_settings
    }
    
    # Guardar versión modificada
    with open('/tmp/bb03_modified.json', 'w') as f:
        json.dump(update_payload, f, indent=2)
    
    print("✅ Workflow modificado guardado en /tmp/bb03_modified.json")
    
    # ============================================
    # 5. Actualizar workflow en n8n
    # ============================================
    print("\n🚀 Actualizando BB_03 en n8n...")
    
    result = agent.update_workflow(BB_03_ID, update_payload)
    
    if result:
        print("✅ BB_03 actualizado exitosamente!")
        print(f"   Total nodos: {len(nodes)}")
        print(f"   Nodos agregados: 3 (Audit Log, Validate Config, Calculate Slots)")
        print(f"   Nodos eliminados: 1 (Calculate Slots original)")
        return True
    else:
        print("❌ Error actualizando BB_03")
        print("   Puedes restaurar desde: /tmp/bb03_backup.json")
        return False


if __name__ == "__main__":
    try:
        success = modify_bb03()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
