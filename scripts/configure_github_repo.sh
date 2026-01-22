#!/bin/bash
# INSTRUCCIONES PARA CONFIGURAR EL REPOSITORIO GITHUB

echo "==============================================="
echo "CONFIGURACIÓN DE REPOSITORIO GITHUB - AUTOAGENDA"
echo "==============================================="

echo ""
echo "Para completar la configuración del repositorio GitHub, necesitas:"
echo ""
echo "1. Crear un repositorio en GitHub.com llamado 'autoagenda' o similar"
echo "2. Copiar la URL HTTPS del repositorio (termina en .git)"
echo "3. Opcionalmente, configurar un token de acceso personal para autenticación"
echo ""
echo "Ejemplo de URL: https://github.com/TU_USUARIO/autoagenda.git"
echo ""
echo "Además, si aún no lo has hecho, necesitarás:"
echo "- Crear un Personal Access Token (PAT) en GitHub"
echo "- Configurarlo como credencial en Git"
echo ""
echo "¿Ya tienes un repositorio GitHub creado y la URL disponible?"
echo "Ingresa la URL del repositorio (o presiona Enter para salir y crearlo primero):"
read -r REPO_URL

if [ -z "$REPO_URL" ]; then
    echo ""
    echo "Saliendo. Por favor:"
    echo "1. Ve a https://github.com/new para crear un nuevo repositorio"
    echo "2. Nómbralo como 'autoagenda' o similar"
    echo "3. No inicialices con README, .gitignore o licencia"
    echo "4. Copia la URL HTTPS que aparece en la página siguiente"
    echo "5. Vuelve a ejecutar este script"
    exit 0
fi

echo ""
echo "Configurando el origen remoto..."

# Cambiar al directorio del proyecto
cd "/home/manager/Sync/N8N Projects/basic-booking"

# Agregar el origen remoto
git remote add origin "$REPO_URL"

# Verificar que se haya agregado correctamente
if git remote -v | grep -q "$REPO_URL"; then
    echo "✅ Origen remoto configurado correctamente"
else
    echo "❌ Error al configurar el origen remoto"
    exit 1
fi

echo ""
echo "¿Deseas configurar credenciales para autenticación automática?"
echo "Esto es recomendado para evitar tener que ingresar usuario/contraseña cada vez"
echo "Opciones:"
echo "1) Configurar Personal Access Token (recomendado)"
echo "2) Solo continuar sin configurar credenciales ahora"
read -p "Selecciona una opción (1 o 2): " CRED_OPTION

if [ "$CRED_OPTION" = "1" ]; then
    echo ""
    echo "Para configurar un Personal Access Token:"
    echo "1. Ve a https://github.com/settings/tokens"
    echo "2. Haz clic en 'Generate new token'"
    echo "3. Selecciona 'repo' en los scopes"
    echo "4. Copia el token generado"
    echo ""
    read -p "Ingresa tu Personal Access Token: " TOKEN
    
    # Extraer el nombre de usuario del repo URL
    USERNAME=$(echo "$REPO_URL" | sed -n 's|https://github.com/\([^/]*\)/.*|\1|p')
    
    # Configurar credenciales
    git config credential.helper store
    echo "https://$USERNAME:$TOKEN@github.com" > ~/.git-credentials
    
    echo "✅ Credenciales configuradas"
fi

echo ""
echo "Haciendo push inicial al repositorio remoto..."
git push -u origin master

if [ $? -eq 0 ]; then
    echo ""
    echo "🎉 ¡Éxito! Repositorio GitHub configurado correctamente"
    echo "Tu código de AutoAgenda ha sido subido a GitHub"
    echo ""
    echo "URL del repositorio: $REPO_URL"
    echo ""
    echo "El repositorio está listo para futuros commits y pushes"
else
    echo ""
    echo "❌ Hubo un error al hacer push al repositorio"
    echo "Verifica que la URL sea correcta y que tengas permisos de escritura"
fi