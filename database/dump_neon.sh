#!/usr/bin/env bash
set -euo pipefail

# Dump de Neon DB sin exponer password
pg_dump 'postgresql://neondb_owner@ep-green-firefly-ahywl83k-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require' > schema.sql

echo "Dump guardado en schema.sql ($(du -h schema.sql | cut -f1))"
