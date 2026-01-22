#!/bin/bash
# SCRIPT DE COMMIT Y PUSH PARA EL PROYECTO AUTOAGENDA

# Cambiar al directorio del proyecto
cd "/home/manager/Sync/N8N Projects/basic-booking"

# Verificar el estado actual del repositorio
echo "🔍 Verificando estado del repositorio..."
git status

# Agregar todos los archivos modificados
echo "📁 Agregando archivos al commit..."
git add .

# Hacer el commit con un mensaje descriptivo
echo "📝 Haciendo commit..."
git commit -m "feat: implementación del sistema de Buffer Time (Tiempo de Protección)

- Añadida la tabla buffer_settings para configurar tiempos de protección
- Actualizada la lógica de disponibilidad para considerar buffers
- Modificada la lógica de reserva para incluir buffers en los cálculos
- Actualizado el dashboard para mostrar buffers correctamente
- Implementada configuración por profesional para buffers
- Añadida documentación del sistema de buffers" -m "Ref: AutoAgenda Chapter 4 - Buffer Time Implementation"

# Hacer push al repositorio
echo " ↑ Haciendo push al repositorio..."
git push origin main

echo "✅ Commit y push completados exitosamente"