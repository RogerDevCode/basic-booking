#!/bin/bash
# SCRIPT PARA CONFIGURAR ORIGEN REMOTO Y HACER PUSH A GITHUB

# Cambiar al directorio del proyecto
cd "/home/manager/Sync/N8N Projects/basic-booking"

echo "🔧 Configurando origen remoto para GitHub..."

# Configurar el origen remoto (reemplaza con la URL correcta de tu repositorio GitHub)
# IMPORTANTE: Debes reemplazar la URL abajo con la URL correcta de tu repositorio GitHub
read -p "Por favor ingresa la URL de tu repositorio GitHub: " GITHUB_REPO_URL

git remote add origin "$GITHUB_REPO_URL"

echo "🔗 Origen remoto configurado."

echo "🔄 Haciendo push inicial al repositorio remoto..."
git push -u origin master

echo "✅ Push completado exitosamente"