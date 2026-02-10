#!/usr/bin/env bash
set -euo pipefail

# Dump de Neon DB sin exponer password
pg_dump --table='public.*' 'postgresql://neondb_owner@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require' > tablas.sql

echo "Dump guardado en tablas.sql ($(du -h schema.sql | cut -f1))"
