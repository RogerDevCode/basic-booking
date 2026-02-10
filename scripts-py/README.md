# n8n Python Scripts - Refactored

This directory contains refactored Python scripts for interacting with n8n workflows. The original redundant scripts have been consolidated into a more maintainable structure.

## Structure

### Core Modules

- `n8n_crud_agent.py`: Central module containing the `N8NCrudAgent` class with all n8n workflow management functionality
- `qwen_n8n_plugin.py`: Plugin interface for Qwen to interact with n8n through the agent
- `utils.py`: Utility functions combining functionality from removed scripts

### Demo and Test Scripts

- `demo_crud.py`: Demonstrates all CRUD operations with n8n workflows
- `qwen_n8n_integration_demo.py`: Shows how Qwen can use the plugin interface
- `example_usage.py`: Basic example of using the CRUD agent
- `test_n8n_crud_agent.py`: Comprehensive unit tests for the CRUD agent
- `test_publish_unpublish.py`: Specific tests for publish/unpublish functionality

## Key Improvements

1. **Centralized Functionality**: All n8n interaction logic is now in `N8NCrudAgent`
2. **Reduced Redundancy**: Removed duplicate functions across multiple files
3. **Enhanced Capabilities**: Added execution and execution history functionality
4. **Better Organization**: Clear separation between core functionality and utilities

## Available Methods

The `N8NCrudAgent` class provides the following methods:

- `list_workflows()` - Get all workflows
- `list_active_workflows()` - Get only active workflows
- `get_workflow_by_id(id)` - Get specific workflow
- `create_workflow(data)` - Create new workflow
- `update_workflow(id, data)` - Update existing workflow
- `delete_workflow(id)` - Delete workflow
- `activate_workflow(id)` - Activate (publish) workflow
- `deactivate_workflow(id)` - Deactivate (unpublish) workflow
- `publish_workflow(id)` - Alias for activate
- `unpublish_workflow(id)` - Alias for deactivate
- `execute_workflow(id)` - Execute workflow manually
- `get_executions(workflow_id, limit)` - Get workflow executions
- `get_execution_by_id(id)` - Get specific execution

## Usage Examples

### Using the CRUD Agent Directly

```python
from n8n_crud_agent import N8NCrudAgent

agent = N8NCrudAgent("http://localhost:5678")
workflows = agent.list_workflows()
```

### Using the Qwen Plugin

```python
from qwen_n8n_plugin import qwen_n8n_plugin

result = qwen_n8n_plugin("list_workflows")
```

## API Key Configuration

Scripts look for API keys in the following order:
1. Environment variables: `N8N_API_KEY` or `N8N_ACCESS_TOKEN`
2. `.env` file in the scripts-py directory with `N8N_API_KEY` or `N8N_ACCESS_TOKEN`

## Removed Scripts

The following redundant scripts have been removed as their functionality is now available in the centralized modules:
- `activate_workflow.py`
- `create_and_activate_workflow.py`
- `execute_workflow.py`
- `list_active_workflows.py`
- `list_all_workflows.py`
- `trigger_workflow.py`
- `complete_report.py`

All functionality from these scripts is now available through the `N8NCrudAgent` class or utility functions in `utils.py`.

## Backups

Original scripts are preserved in the `backup/` directory for reference.