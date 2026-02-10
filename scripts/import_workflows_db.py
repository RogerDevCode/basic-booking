#!/usr/bin/env python3
"""
Script para importar workflows directamente a la base de datos de n8n
"""
import os
import json
import sqlite3
from datetime import datetime
from pathlib import Path

def import_workflows_to_db():
    # Conectar a la base de datos
    db_path = "/home/manager/Sync/N8N Projects/basic-booking/temp_n8n_db.sqlite"
    
    # Copiar la base de datos actual del contenedor
    os.system("docker cp n8n:/home/node/.n8n/database.sqlite ./temp_n8n_db.sqlite")
    
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # Directorio de workflows
    workflows_dir = Path("/home/manager/Sync/N8N Projects/basic-booking/workflows/")
    
    # Importar cada archivo JSON
    for workflow_file in workflows_dir.glob("*.json"):
        print(f"Importando {workflow_file.name}...")
        
        with open(workflow_file, 'r', encoding='utf-8') as f:
            workflow_data = json.load(f)
        
        # Preparar los datos para la inserción
        name = workflow_data.get("name", workflow_file.stem)
        active = 0  # Por defecto, mantener los workflows inactivos
        nodes = json.dumps(workflow_data.get("nodes", []))
        connections = json.dumps(workflow_data.get("connections", {}))
        settings = json.dumps(workflow_data.get("settings", {}))
        static_data = json.dumps(workflow_data.get("staticData", {}))
        updated_at = datetime.now().isoformat()
        created_at = datetime.now().isoformat()
        
        # Insertar el workflow en la base de datos
        try:
            cursor.execute("""
                INSERT INTO workflow_entity (
                    name, active, nodes, connections, settings, staticData, createdAt, updatedAt
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (name, active, nodes, connections, settings, static_data, created_at, updated_at))
            
            print(f"✓ {workflow_file.name} importado exitosamente")
        except Exception as e:
            print(f"✗ Error al importar {workflow_file.name}: {str(e)}")
    
    # Guardar los cambios y cerrar la conexión
    conn.commit()
    conn.close()
    
    # Copiar la base de datos modificada de vuelta al contenedor
    os.system("docker cp ./temp_n8n_db.sqlite n8n:/home/node/.n8n/database.sqlite_new")
    
    # Renombrar el archivo para reemplazarlo
    os.system("docker exec n8n mv /home/node/.n8n/database.sqlite /home/node/.n8n/database.sqlite_backup && docker exec n8n mv /home/node/.n8n/database.sqlite_new /home/node/.n8n/database.sqlite")
    
    print("\nWorkflows importados a la base de datos. Reinicia n8n para aplicar los cambios.")

if __name__ == "__main__":
    import_workflows_to_db()