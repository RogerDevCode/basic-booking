#!/usr/bin/env python3
"""
N8N Sync & Test Runner v2
1. Sincroniza workflows locales con servidor N8N
2. Ejecuta todos los tests
3. Genera reporte de errores
"""

import os
import sys
import json
import requests
from pathlib import Path
from datetime import datetime

# Configuración desde variables de entorno
N8N_API_URL = os.getenv("N8N_EDITOR_BASE_URL", "https://n8n.stax.ink").rstrip("/")
N8N_API_KEY = os.getenv("N8N_API_KEY") or os.getenv("N8N_ACCESS_TOKEN")

HEADERS = {"X-N8N-API-Key": N8N_API_KEY, "Content-Type": "application/json"}

WORKFLOWS_DIR = Path(__file__).parent / "workflows"
SCRIPTS_DIR = Path(__file__).parent / "scripts-py"


class Colors:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    BLUE = "\033[94m"
    RESET = "\033[0m"
    BOLD = "\033[1m"


def log(msg, color=None):
    timestamp = datetime.now().strftime("%H:%M:%S")
    text = f"[{timestamp}] {msg}"
    if color:
        print(f"{color}{text}{Colors.RESET}")
    else:
        print(text)


def api_get(endpoint):
    """GET request to N8N API"""
    url = f"{N8N_API_URL}/api/v1{endpoint}"
    try:
        resp = requests.get(url, headers=HEADERS, timeout=30, verify=True)
        if resp.status_code == 200:
            return resp.json().get("data", [])
        return None
    except Exception as e:
        return None


def api_post(endpoint, data):
    """POST request to N8N API"""
    url = f"{N8N_API_URL}/api/v1{endpoint}"
    try:
        resp = requests.post(url, headers=HEADERS, json=data, timeout=30, verify=True)
        return resp.status_code in [200, 201], resp.json() if resp.text else {}
    except Exception as e:
        return False, {"error": str(e)}


def api_put(endpoint, data):
    """PUT request to N8N API"""
    url = f"{N8N_API_URL}/api/v1{endpoint}"
    try:
        resp = requests.put(url, headers=HEADERS, json=data, timeout=30, verify=True)
        return resp.status_code == 200, resp.json() if resp.text else {}
    except Exception as e:
        return False, {"error": str(e)}


def clean_workflow_data(wf_data):
    """Clean workflow data for upload - only keep allowed fields"""
    return {
        "name": wf_data.get("name", ""),
        "nodes": wf_data.get("nodes", []),
        "connections": wf_data.get("connections", {}),
        "settings": wf_data.get("settings", {}),
        "staticData": wf_data.get("staticData", {}) or {},
    }


def get_local_workflows():
    """Get all local workflow files"""
    return list(WORKFLOWS_DIR.glob("BB_*.json"))


def get_server_workflows():
    """Get all workflows from N8N server"""
    return api_get("/workflows") or []


def sync_workflow(local_path, server_workflows):
    """Sync a single workflow to server"""
    with open(local_path, "r") as f:
        wf_data = json.load(f)

    wf_name = wf_data.get("name", local_path.stem)

    # Find existing workflow by name
    existing = next((w for w in server_workflows if w.get("name") == wf_name), None)

    # Clean workflow data for upload
    upload_data = clean_workflow_data(wf_data)

    if existing:
        # Update existing
        wf_id = existing.get("id")
        success, result = api_put(f"/workflows/{wf_id}", upload_data)
        action = "UPDATED" if success else "FAILED"
        return action, wf_name, result
    else:
        # Create new
        success, result = api_post("/workflows", upload_data)
        action = "CREATED" if success else "FAILED"
        return action, wf_name, result


def run_test_script(script_name):
    """Run a test script and capture results"""
    import subprocess

    script_path = SCRIPTS_DIR / script_name
    if not script_path.exists():
        return {"status": "SKIP", "output": "Script not found"}

    # Set environment for tests
    env = os.environ.copy()
    env["N8N_API_URL"] = N8N_API_URL
    env["N8N_API_KEY"] = N8N_API_KEY or ""

    try:
        result = subprocess.run(
            [sys.executable, str(script_path)],
            capture_output=True,
            text=True,
            timeout=120,
            env=env,
            cwd=str(SCRIPTS_DIR),
        )
        return {
            "status": "PASS" if result.returncode == 0 else "FAIL",
            "output": result.stdout + result.stderr,
            "returncode": result.returncode,
        }
    except subprocess.TimeoutExpired:
        return {"status": "TIMEOUT", "output": "Test timed out"}
    except Exception as e:
        return {"status": "ERROR", "output": str(e)}


def main():
    errors = []

    print("=" * 70)
    print(f"{Colors.BOLD}N8N SYNC & TEST RUNNER v2{Colors.RESET}")
    print(f"Server: {N8N_API_URL}")
    print(f"Time: {datetime.now().isoformat()}")
    print("=" * 70)

    # ========================================
    # FASE 1: SINCRONIZAR WORKFLOWS
    # ========================================
    print(f"\n{Colors.BLUE}FASE 1: SINCRONIZANDO WORKFLOWS{Colors.RESET}")
    print("-" * 70)

    if not N8N_API_KEY:
        print(f"{Colors.RED}ERROR: N8N_API_KEY no configurada{Colors.RESET}")
        sys.exit(1)

    local_workflows = get_local_workflows()
    log(f"Workflows locales encontrados: {len(local_workflows)}")

    server_workflows = get_server_workflows()
    log(f"Workflows en servidor: {len(server_workflows)}")

    sync_results = {"created": 0, "updated": 0, "failed": 0, "skipped": 0}

    for local_wf in sorted(local_workflows):
        # Skip non-main workflows (subflows and special files)
        name = local_wf.stem
        if "_0" in name or "CONNECTIONS_ONLY" in name:
            sync_results["skipped"] += 1
            continue

        action, wf_name, result = sync_workflow(local_wf, server_workflows)

        if action == "CREATED":
            sync_results["created"] += 1
            log(f"  [CREATED] {wf_name}", Colors.GREEN)
        elif action == "UPDATED":
            sync_results["updated"] += 1
            log(f"  [UPDATED] {wf_name}", Colors.GREEN)
        else:
            sync_results["failed"] += 1
            log(f"  [FAILED] {wf_name}", Colors.RED)
            errors.append({"type": "sync", "workflow": wf_name, "error": str(result)})

    print(
        f"\nSync: {sync_results['created']} creados, {sync_results['updated']} actualizados, {sync_results['failed']} fallidos, {sync_results['skipped']} omitidos"
    )

    # ========================================
    # FASE 2: EJECUTAR TESTS
    # ========================================
    print(f"\n{Colors.BLUE}FASE 2: EJECUTANDO TESTS{Colors.RESET}")
    print("-" * 70)

    test_scripts = [
        "test_all_leaf_workflows.py",
        "test_bb03_workflows.py",
        "test_integration.py",
        "test_e2e.py",
        "test_security.py",
        "test_edge_cases.py",
    ]

    test_results = {}

    for script in test_scripts:
        log(f"  Ejecutando: {script}...")
        result = run_test_script(script)
        test_results[script] = result

        status_color = Colors.GREEN if result["status"] == "PASS" else Colors.RED
        log(f"    [{result['status']}] {script}", status_color)

        if result["status"] != "PASS":
            errors.append(
                {
                    "type": "test",
                    "script": script,
                    "status": result["status"],
                    "output": result.get("output", "")[:500],
                }
            )

    # ========================================
    # REPORTE FINAL
    # ========================================
    print(f"\n{'=' * 70}")
    print(f"{Colors.BOLD}REPORTE FINAL{Colors.RESET}")
    print("=" * 70)

    print(f"\n{Colors.BOLD}Sincronización:{Colors.RESET}")
    print(f"  Creados:   {sync_results['created']}")
    print(f"  Actualizados: {sync_results['updated']}")
    print(f"  Fallidos:  {sync_results['failed']}")
    print(f"  Omitidos:  {sync_results['skipped']}")

    print(f"\n{Colors.BOLD}Tests:{Colors.RESET}")
    passed = sum(1 for r in test_results.values() if r["status"] == "PASS")
    total = len(test_results)
    print(f"  Pasados:   {passed}/{total}")

    # ========================================
    # ERRORES DETALLADOS
    # ========================================
    if errors:
        print(
            f"\n{Colors.RED}{Colors.BOLD}ERRORES ENCONTRADOS ({len(errors)}):{Colors.RESET}"
        )
        print("=" * 70)

        for i, err in enumerate(errors, 1):
            print(
                f"\n{Colors.RED}[{i}] {err['type'].upper()}: {err.get('workflow', err.get('script', 'Unknown'))}{Colors.RESET}"
            )

            if err["type"] == "test":
                print(f"    Status: {err['status']}")
                output_lines = err.get("output", "").split("\n")[:8]
                for line in output_lines:
                    if line.strip():
                        print(f"    {line[:100]}")
            else:
                err_str = str(err.get("error", "Unknown"))[:200]
                print(f"    Error: {err_str}")
    else:
        print(f"\n{Colors.GREEN}{Colors.BOLD}✓ TODOS LOS TESTS PASARON{Colors.RESET}")

    print("\n" + "=" * 70)

    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
