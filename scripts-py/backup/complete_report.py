#!/usr/bin/env python3
"""
Complete Report: Execution of n8n Workflow "Ejemplo: Análisis de Datos con Pandas y Numpy"
"""

import requests
import json
import time

def get_execution_details(execution_id, api_key):
    """Get details of a specific execution"""
    headers = {
        'X-N8N-API-Key': api_key,
        'Content-Type': 'application/json'
    }
    
    url = f"http://localhost:5678/api/v1/executions/{execution_id}"
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        return response.json()
    else:
        print(f"Error getting execution details: {response.status_code} - {response.text}")
        return None

def main():
    print("="*80)
    print("COMPLETE REPORT: EXECUTION OF N8N WORKFLOW")
    print("Workflow: Ejemplo: Análisis de Datos con Pandas y Numpy")
    print("="*80)
    
    # Configuration
    API_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI3ZmI3ZWFhMC0zMjU3LTQ0OTAtYWY3Ny05NTc5MjRiZGU4MmQiLCJpc3MiOiJuOG4iLCJhdWQiOiJwdWJsaWMtYXBpIiwianRpIjoiOGE1OGMyYWQtOGVkYy00MDg0LWE2NDUtYjNhNjk1ZTlmODNhIiwiaWF0IjoxNzcwMjUyMTIyLCJleHAiOjE3NzI3NjYwMDB9.frrjCOqxnlJN-NFJV7WVbloFLxuUXArS8-86OJYCJbU"
    WORKFLOW_ID = "xh1UqwxCpoZ_QnG2MFHx2"
    
    # Get recent executions
    headers = {
        'X-N8N-API-Key': API_KEY,
        'Content-Type': 'application/json'
    }
    
    url = f"http://localhost:5678/api/v1/executions?workflowId={WORKFLOW_ID}&limit=5"
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        executions_data = response.json()
        executions = executions_data.get('data', [])
        
        print(f"\nFound {len(executions)} recent executions:")
        
        for i, execution in enumerate(executions):
            exec_id = execution.get('id')
            status = execution.get('status')
            started_at = execution.get('startedAt')
            stopped_at = execution.get('stoppedAt')
            exec_mode = execution.get('mode')
            
            print(f"\nExecution #{i+1}:")
            print(f"  ID: {exec_id}")
            print(f"  Status: {status}")
            print(f"  Mode: {exec_mode}")
            print(f"  Started: {started_at}")
            print(f"  Ended: {stopped_at}")
            
            # Calculate duration if both timestamps exist
            if started_at and stopped_at:
                start_time = time.mktime(time.strptime(started_at.split('.')[0], "%Y-%m-%dT%H:%M:%S"))
                end_time = time.mktime(time.strptime(stopped_at.split('.')[0], "%Y-%m-%dT%H:%M:%S"))
                duration = end_time - start_time
                print(f"  Duration: {duration} seconds")
        
        # Get the most recent execution details
        if executions:
            latest_exec = executions[0]
            latest_exec_id = latest_exec.get('id')
            print(f"\nDetailed information for most recent execution (ID: {latest_exec_id}):")
            
            exec_details = get_execution_details(latest_exec_id, API_KEY)
            if exec_details:
                print(json.dumps(exec_details, indent=2))
    
    else:
        print(f"Error getting executions: {response.status_code} - {response.text}")
    
    print("\n" + "="*80)
    print("REPORT SUMMARY:")
    print("- Workflow 'Ejemplo: Análisis de Datos con Pandas y Numpy' is deployed in n8n")
    print("- Workflow ID: xh1UqwxCpoZ_QnG2MFHx2")
    print("- Status: ACTIVE")
    print("- Trigger: Webhook and Manual Trigger")
    print("- Nodes: Generar Datos (JavaScript), Análisis con Pandas (Python), Estadísticas con Numpy (Python)")
    print("- Issue: Recent executions are failing with 'error' status")
    print("- Potential Cause: Python environment configuration in n8n")
    print("- Note: Python packages (pandas, numpy) are installed in the container")
    print("="*80)

if __name__ == "__main__":
    main()