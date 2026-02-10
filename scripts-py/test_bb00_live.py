import sys
import json
import time
import os
import requests
from n8n_crud_agent import N8NCrudAgent

# Path to the workflow JSON file
WORKFLOW_FILE_PATH = os.path.join(os.path.dirname(__file__), '../workflows/Test_BB00_Trigger.json')
WEBHOOK_URL = "http://localhost:5678/webhook/test-bb00-crash"
# Note: For testing, n8n usually uses /webhook-test/ if not active, or /webhook/ if active.
# We will try to activate it.

def load_workflow_json():
    try:
        with open(WORKFLOW_FILE_PATH, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Failed to load workflow JSON: {e}")
        return None

def run_live_test():
    print("🚀 Starting Live Test for BB_00_Global_Error_Handler (via Webhook)...")
    
    agent = N8NCrudAgent("http://localhost:5678")
    workflow_data = load_workflow_json()
    if not workflow_data:
        return

    # 1. Upsert Test Workflow
    workflows = agent.list_workflows()
    test_workflow = next((w for w in workflows if w['name'] == 'Test_BB00_Trigger'), None)
    
    if test_workflow:
        print(f"🔄 Updating existing workflow: {test_workflow['name']}...")
        agent.update_workflow(test_workflow['id'], workflow_data)
        workflow_id = test_workflow['id']
    else:
        print("✨ Creating new test workflow...")
        created = agent.create_workflow(workflow_data)
        if not created:
            print("❌ Failed to create workflow")
            return
        workflow_id = created['id']
    
    # 2. Activate Workflow (Required for production webhook URL)
    print(f"🔌 Activating workflow {workflow_id}...")
    if agent.activate_workflow(workflow_id):
        print("✅ Workflow activated.")
    else:
        print("⚠️ Failed to activate workflow. Webhook might fail if not using /webhook-test/")
    
    # 3. Trigger Webhook
    print(f"⚡ Sending POST to {WEBHOOK_URL}...")
    try:
        # We expect a 500 error or similar because the workflow crashes on purpose!
        # Or n8n might catch it and return a standard error.
        response = requests.post(WEBHOOK_URL, json={"test": "data"}, timeout=5)
        print(f"ℹ️ Webhook Response: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"ℹ️ Webhook request finished (likely crashed/error as expected): {str(e)}")

    # 4. Wait for BB_00
    print("⏳ Waiting 3 seconds for Error Handler to catch it...")
    time.sleep(3)
    
    # 5. Check Executions of BB_00
    workflows = agent.list_workflows()
    bb00 = next((w for w in workflows if w['name'] == 'BB_00_Global_Error_Handler'), None)
    
    if bb00:
        print(f"🔍 Checking BB_00 logs (ID: {bb00['id']})...")
        # Fetch last 20 executions globally and filter in Python to avoid API issues
        executions = agent.get_executions(limit=20)
        
        bb00_executions = [
            e for e in executions 
            if e.get('workflowId') == bb00['id']
        ] if executions else []
        
        if len(bb00_executions) > 0:
            last = bb00_executions[0]
            print(f"✅ DETECTED EXECUTION in BB_00!")
            print(f"   ID: {last['id']}")
            print(f"   Status: {last['status']}")
            print(f"   Time: {last['startedAt']}")
            print("🎉 SUCCESS: The Global Error Handler was triggered by the crash.")
        else:
            print("❌ FAILURE: BB_00 did not record an execution. Check if Error Trigger is set up correctly.")
    else:
        print("❌ BB_00 Workflow not found.")

if __name__ == "__main__":
    run_live_test()
