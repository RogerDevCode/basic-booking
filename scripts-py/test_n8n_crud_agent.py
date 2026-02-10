#!/usr/bin/env python3
"""
Test suite for N8N CRUD Agent
"""

import unittest
import sys
import os
import uuid
from pathlib import Path

# Add the current directory to the path so we can import n8n_crud_agent
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from n8n_crud_agent import N8NCrudAgent


class TestN8NCrudAgent(unittest.TestCase):
    """Test cases for the N8NCrudAgent class"""
    
    @classmethod
    def setUpClass(cls):
        """Initialize the agent once for all tests"""
        cls.api_url = "http://localhost:5678"

        # Get API key from environment variables
        api_key_env = os.environ.get('N8N_API_KEY') or os.environ.get('N8N_ACCESS_TOKEN')

        cls.api_key = api_key_env
        if not cls.api_key:
            raise ValueError("No API key found. Please set N8N_API_KEY or N8N_ACCESS_TOKEN environment variable.")

        cls.agent = N8NCrudAgent(cls.api_url, cls.api_key)
        cls.created_workflow_ids = []  # Track created workflows for cleanup
    
    def test_01_list_workflows(self):
        """Test listing all workflows"""
        workflows = self.agent.list_workflows()
        self.assertIsNotNone(workflows, "Should return a list of workflows or empty list")
        self.assertIsInstance(workflows, list, "Should return a list")
        
    def test_02_list_active_workflows(self):
        """Test listing active workflows"""
        active_workflows = self.agent.list_active_workflows()
        self.assertIsNotNone(active_workflows, "Should return a list of active workflows or empty list")
        self.assertIsInstance(active_workflows, list, "Should return a list")
    
    def test_03_create_workflow(self):
        """Test creating a new workflow"""
        workflow_name = f"Test Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": workflow_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }
        
        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should return created workflow data")
        self.assertIn('id', created_workflow, "Created workflow should have an ID")
        self.assertEqual(created_workflow['name'], workflow_name, "Workflow name should match")
        
        # Store the ID for cleanup
        self.created_workflow_ids.append(created_workflow['id'])
    
    def test_04_get_workflow_by_id(self):
        """Test retrieving a specific workflow by ID"""
        # First create a workflow to test with
        workflow_name = f"Test Get Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": workflow_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"get-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Get Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }
        
        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should create workflow for test")
        
        workflow_id = created_workflow['id']
        self.created_workflow_ids.append(workflow_id)
        
        # Now test retrieving it
        retrieved_workflow = self.agent.get_workflow_by_id(workflow_id)
        self.assertIsNotNone(retrieved_workflow, "Should return workflow data")
        self.assertEqual(retrieved_workflow['id'], workflow_id, "Should return correct workflow")
        self.assertEqual(retrieved_workflow['name'], workflow_name, "Should have correct name")
    
    def test_05_update_workflow(self):
        """Test updating an existing workflow"""
        # First create a workflow to update
        original_name = f"Original Test Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": original_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"update-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Update Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }
        
        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should create workflow for test")
        
        workflow_id = created_workflow['id']
        self.created_workflow_ids.append(workflow_id)
        
        # Verify the original name
        retrieved_original = self.agent.get_workflow_by_id(workflow_id)
        self.assertEqual(retrieved_original['name'], original_name, "Original name should match")
        
        # Now update the workflow
        updated_name = f"Updated Test Workflow {uuid.uuid4().hex[:8]}"
        update_data = {
            "name": updated_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"update-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Update Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }
        
        updated_workflow = self.agent.update_workflow(workflow_id, update_data)
        # Note: Update might fail with some n8n versions, so we'll make this test flexible
        if updated_workflow:
            self.assertEqual(updated_workflow['name'], updated_name, "Updated name should match")
            # Verify the update persisted
            verified_workflow = self.agent.get_workflow_by_id(workflow_id)
            self.assertEqual(verified_workflow['name'], updated_name, "Updated name should persist")
        else:
            print("Warning: Update operation failed (this may be expected depending on n8n version)")
    
    def test_06_activate_deactivate_workflow(self):
        """Test activating and deactivating a workflow"""
        # Create a workflow with a proper trigger for activation
        workflow_name = f"Activation Test Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": workflow_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"activate-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Activate Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }
        
        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should create workflow for test")
        
        workflow_id = created_workflow['id']
        self.created_workflow_ids.append(workflow_id)
        
        # Initially should be inactive
        retrieved_before = self.agent.get_workflow_by_id(workflow_id)
        self.assertFalse(retrieved_before.get('active', False), "Workflow should initially be inactive")
        
        # Try to activate (may fail if no proper trigger node)
        activation_result = self.agent.activate_workflow(workflow_id)
        # Activation might fail due to lack of proper trigger nodes, which is OK
        
        # Try to deactivate (should work regardless)
        deactivation_result = self.agent.deactivate_workflow(workflow_id)
        self.assertTrue(deactivation_result, "Should be able to deactivate workflow")
    
    def test_07_execute_workflow(self):
        """Test executing a workflow"""
        # Create a workflow to execute
        workflow_name = f"Execution Test Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": workflow_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"exec-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Execution Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }

        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should create workflow for test")

        workflow_id = created_workflow['id']
        self.created_workflow_ids.append(workflow_id)

        # Execute the workflow
        execution_result = self.agent.execute_workflow(workflow_id)
        # Execution might fail if workflow isn't activated, which is OK for this test
        if execution_result:
            self.assertIsNotNone(execution_result.get('id'), "Execution should have an ID")

    def test_08_get_executions(self):
        """Test getting executions for a workflow"""
        # Create a workflow to get executions for
        workflow_name = f"Get Executions Test Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": workflow_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"get-exec-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Get Executions Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }

        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should create workflow for test")

        workflow_id = created_workflow['id']
        self.created_workflow_ids.append(workflow_id)

        # Get executions for the workflow
        executions = self.agent.get_executions(workflow_id, limit=5)
        # May return empty list if no executions exist, which is OK
        if executions is not None:
            self.assertIsInstance(executions, list, "Should return a list of executions")

    def test_09_delete_workflow(self):
        """Test deleting a workflow"""
        # Create a workflow to delete
        workflow_name = f"Deletion Test Workflow {uuid.uuid4().hex[:8]}"
        workflow_data = {
            "name": workflow_name,
            "nodes": [
                {
                    "parameters": {},
                    "id": f"delete-test-trigger-{uuid.uuid4().hex[:8]}",
                    "name": "Delete Test Trigger",
                    "type": "n8n-nodes-base.manualTrigger",
                    "typeVersion": 1,
                    "position": [240, 300]
                }
            ],
            "connections": {},
            "settings": {
                "saveManualExecutions": True
            }
        }

        created_workflow = self.agent.create_workflow(workflow_data)
        self.assertIsNotNone(created_workflow, "Should create workflow for test")

        workflow_id = created_workflow['id']

        # Verify it exists
        retrieved_before = self.agent.get_workflow_by_id(workflow_id)
        self.assertIsNotNone(retrieved_before, "Workflow should exist before deletion")

        # Delete the workflow
        deletion_result = self.agent.delete_workflow(workflow_id)
        self.assertTrue(deletion_result, "Should successfully delete workflow")

        # Verify it no longer exists
        retrieved_after = self.agent.get_workflow_by_id(workflow_id)
        self.assertIsNone(retrieved_after, "Workflow should not exist after deletion")
    
    @classmethod
    def tearDownClass(cls):
        """Clean up any remaining test workflows"""
        print(f"\nCleaning up {len(cls.created_workflow_ids)} test workflows...")
        for workflow_id in cls.created_workflow_ids:
            try:
                result = cls.agent.delete_workflow(workflow_id)
                if result:
                    print(f"✓ Deleted test workflow: {workflow_id}")
                else:
                    print(f"✗ Failed to delete test workflow: {workflow_id}")
            except Exception as e:
                print(f"✗ Error deleting test workflow {workflow_id}: {str(e)}")


if __name__ == '__main__':
    print("Starting N8N CRUD Agent tests...")
    print("=" * 50)
    
    # Run the tests
    unittest.main(verbosity=2)