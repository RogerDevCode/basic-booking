#!/usr/bin/env bash
# Corregir todos los archivos de test

cd "/home/manager/Sync/N8N Projects/basic-booking/scripts-py"

# 1. Agregar import os donde falta
for f in test_bb03_workflows.py test_e2e.py test_integration.py test_edge_cases.py; do
    if ! grep -q "^import os" "$f" 2>/dev/null; then
        sed -i '1a import os' "$f"
    fi
done

# 2. Agregar from.id a todos los mensajes de Telegram en test_e2e.py
sed -i 's/"from": {"first_name": "TestUser"/"from": {"id": 123456789, "first_name": "TestUser"/g' test_e2e.py

# 3. Agregar from.id en test_edge_cases.py
sed -i 's/"from": {"first_name": "Test"}/"from": {"id": 123, "first_name": "Test"}/g' test_edge_cases.py

echo "Correcciones aplicadas"
