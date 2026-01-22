// ============================================================================
// LOGGING CODE PARA N8N CODE NODES
// ============================================================================
// Versión: 2.0
// Uso: Copiar este código en un Code Node al final de cada workflow
//
// INSTRUCCIONES:
// 1. Crear un Code Node llamado "Log Output"
// 2. Conectarlo DESPUÉS del nodo de respuesta (en paralelo)
// 3. Configurar ejecución: "Run Once for All Items"
// 4. Copiar el código correspondiente según el workflow
// ============================================================================

// ============================================================================
// CÓDIGO GENÉRICO (Funciona en cualquier workflow)
// ============================================================================

// CONFIGURACIÓN
const WORKFLOW_ID = 'BB_XX';  // ← CAMBIAR: BB_00, BB_01, etc.
const WORKFLOW_NAME = 'Nombre del Workflow';  // ← CAMBIAR
const ENDPOINT = 'MAIN';  // ← CAMBIAR si es un endpoint específico

// Capturar el output del workflow
const outputData = $input.all()[0]?.json || {};

// Convertir a JSON formateado (UTF-8)
const outputJson = JSON.stringify(outputData, null, 2);

// Preparar el log
const fs = require('fs');
const logDir = '/home/manager/Sync/N8N Projects/basic-booking/logs/workflow_outputs';

// Asegurar que el directorio existe
try {
    fs.mkdirSync(logDir, { recursive: true });
} catch (e) {
    // Directorio ya existe, continuar
}

// Generar nombre de archivo
const now = new Date();
const timestamp = now.toISOString().replace(/[-:]/g, '').replace('T', '_').split('.')[0];
const filename = `${logDir}/${WORKFLOW_ID}_${ENDPOINT}_${timestamp}.log`;

// Crear contenido del log
const logContent = `# ============================================================================
# WORKFLOW OUTPUT LOG
# ============================================================================
Workflow ID:      ${WORKFLOW_ID}
Workflow Name:    ${WORKFLOW_NAME}
Endpoint:         ${ENDPOINT}
Timestamp:        ${now.toISOString()}
Execution ID:     ${$execution.id}
Instance:         AutoAgenda v3.1.0
# ============================================================================

${outputJson}

# ============================================================================
# END OF LOG
# ============================================================================
`;

// Guardar el log (síncrono para asegurar que se complete)
try {
    fs.writeFileSync(filename, logContent, 'utf8');
    console.log(`✅ Log guardado: ${filename}`);
} catch (error) {
    console.error(`❌ Error al guardar log: ${error.message}`);
}

// Retornar los items sin modificar (para no afectar el flujo)
return items;


// ============================================================================
// CÓDIGO ESPECÍFICO PARA BB_06 (Admin Dashboard)
// ============================================================================
// Este código maneja múltiples endpoints del mismo workflow

// Detectar qué endpoint se ejecutó
const webhookNode = $('GET /admin')?.first()?.json || 
                    $('GET /api/calendar')?.first()?.json ||
                    $('GET /api/stats')?.first()?.json ||
                    $('POST /api/config')?.first()?.json;

// Determinar el endpoint basándose en el path
let endpoint = 'UNKNOWN';
if ($('GET /admin')?.all()?.length > 0) endpoint = 'GET_admin';
else if ($('GET /api/calendar')?.all()?.length > 0) endpoint = 'GET_api_calendar';
else if ($('GET /api/stats')?.all()?.length > 0) endpoint = 'GET_api_stats';
else if ($('POST /api/config')?.all()?.length > 0) endpoint = 'POST_api_config';

// Configuración específica para BB_06
const WORKFLOW_ID_BB06 = 'BB_06';
const WORKFLOW_NAME_BB06 = 'Admin Dashboard';

// Capturar el output
const outputData = $input.all()[0]?.json || {};
const outputJson = JSON.stringify(outputData, null, 2);

// Preparar el log
const fs = require('fs');
const logDir = '/home/manager/Sync/N8N Projects/basic-booking/logs/workflow_outputs';

try {
    fs.mkdirSync(logDir, { recursive: true });
} catch (e) {}

// Generar nombre de archivo
const now = new Date();
const timestamp = now.toISOString().replace(/[-:]/g, '').replace('T', '_').split('.')[0];
const filename = `${logDir}/${WORKFLOW_ID_BB06}_${endpoint}_${timestamp}.log`;

// Crear contenido del log
const logContent = `# ============================================================================
# WORKFLOW OUTPUT LOG
# ============================================================================
Workflow ID:      ${WORKFLOW_ID_BB06}
Workflow Name:    ${WORKFLOW_NAME_BB06}
Endpoint:         ${endpoint}
Timestamp:        ${now.toISOString()}
Execution ID:     ${$execution.id}
Instance:         AutoAgenda v3.1.0
# ============================================================================

${outputJson}

# ============================================================================
# END OF LOG
# ============================================================================
`;

// Guardar el log
try {
    fs.writeFileSync(filename, logContent, 'utf8');
    console.log(`✅ Log BB_06/${endpoint} guardado: ${filename}`);
} catch (error) {
    console.error(`❌ Error al guardar log: ${error.message}`);
}

// Retornar items sin modificar
return items;


// ============================================================================
// CÓDIGO SIMPLIFICADO (Versión mínima)
// ============================================================================
// Si solo quieres algo rápido y simple

const fs = require('fs');
const data = JSON.stringify($input.all()[0]?.json || {}, null, 2);
const timestamp = new Date().toISOString().replace(/[-:]/g, '').replace('T', '_').split('.')[0];
const logPath = '/home/manager/Sync/N8N Projects/basic-booking/logs/workflow_outputs';
const filename = `${logPath}/BB_XX_${timestamp}.log`;  // ← CAMBIAR BB_XX

fs.mkdirSync(logPath, { recursive: true });
fs.writeFileSync(filename, `# BB_XX Log - ${new Date().toISOString()}\n\n${data}`, 'utf8');

return items;
