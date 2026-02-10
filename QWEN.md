# Integración de Qwen con n8n: Plataforma Completa de Automatización

## Descripción
La integración de Qwen con n8n permite a Qwen interactuar con instancias locales de n8n para realizar operaciones CRUD sobre workflows, ejecutar análisis de datos con Python y gestionar tareas de automatización complejas.

## Arquitectura del Sistema

### Contenedores Docker
- **Servicio Principal (n8n)**: Contenedor que aloja la interfaz de n8n y gestiona la orquestación de workflows
- **Servicio Task Runners**: Contenedor dedicado que ejecuta tareas de Python y JavaScript de forma aislada para evitar bloqueos del servidor principal
- **Comunicación**: Los servicios se comunican a través de una red Docker interna

### Configuración del Docker Compose
El archivo `docker-compose.yml` define dos servicios principales:

#### Servicio n8n
- Imagen: `n8nio/n8n:2.6.3`
- Puerto: 5678 (UI y API)
- Puerto adicional: 5679 (broker para runners)
- Variables críticas:
  - `N8N_RUNNERS_ENABLED=true`
  - `N8N_RUNNERS_MODE=external`
  - `N8N_FEATURE_FLAG_MCP=true`
  - `N8N_MCP_ENABLED=true`
  - `N8N_SKIP_RESPONSE_COMPRESSION=true`

#### Servicio Task Runners
- Imagen personalizada basada en `n8n-task-runners-python312`
- Configuración para Python 3.12 con soporte para librerías científicas (pandas, numpy, scipy, sklearn)
- Variables de entorno para control de threads (OMP_NUM_THREADS, MKL_NUM_THREADS, etc.)

## Opciones de Integración

### 1. Plugin Python Directo
- Archivo principal: `/home/manager/Sync/docker-compose/n8n/scripts-py/qwen_n8n_plugin.py`
- Otros archivos relacionados: `/home/manager/Sync/docker-compose/n8n/scripts-py/`

#### Funcionalidades
- Crear workflows
- Leer (listar y obtener por ID) workflows
- Actualizar workflows (con limitaciones en algunas versiones de n8n)
- Eliminar workflows
- Activar/Desactivar workflows (Publicar/Despublicar)
- Ejecutar workflows programáticamente
- Monitorear ejecuciones de workflows

#### Función Principal
```python
qwen_n8n_plugin(action: str, **kwargs) -> str
```

##### Acciones Disponibles
- `list_workflows`: Lista todos los workflows
- `list_active_workflows`: Lista solo workflows activos
- `get_workflow_by_id`: Obtiene un workflow específico por ID
- `create_workflow`: Crea un nuevo workflow
- `update_workflow`: Actualiza un workflow existente
- `delete_workflow`: Elimina un workflow
- `activate_workflow`: Activa un workflow
- `deactivate_workflow`: Desactiva un workflow
- `publish_workflow`: Publica un workflow (alias para activar)
- `unpublish_workflow`: Despublica un workflow (alias para desactivar)
- `execute_workflow`: Ejecuta un workflow manualmente

#### Uso
```python
from scripts-py.qwen_n8n_plugin import qwen_n8n_plugin

# Ejemplo: Listar workflows
result = qwen_n8n_plugin("list_workflows")
print(result)

# Ejemplo: Activar un workflow
result = qwen_n8n_plugin("activate_workflow", workflow_id="some_id")
print(result)

# Ejemplo: Crear un workflow con nodos específicos
workflow_data = {
    "name": "Workflow de ejemplo",
    "nodes": [
        {
            "parameters": {},
            "id": "trigger-node-id",
            "name": "Manual Trigger",
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
result = qwen_n8n_plugin("create_workflow", workflow_data=workflow_data)
print(result)
```

#### Configuración
- URL predeterminada: `http://localhost:5678`
- API key: Se obtiene de las variables de ambiente `N8N_API_KEY` o `N8N_ACCESS_TOKEN` (en ese orden de prioridad), o del archivo `.env` en la carpeta `scripts-py/`
- Si no se define ninguna de las variables `N8N_API_KEY` o `N8N_ACCESS_TOKEN`, los scripts mostrarán un mensaje de error y se detendrán

#### Entorno
- El plugin requiere el entorno virtual con `requests` instalado
- Instalar dependencias: `pip install requests`

### 2. Servidor MCP (Model Context Protocol)
Qwen puede usar el protocolo MCP para integrar n8n con capacidades avanzadas:

#### Configuración del MCP
- n8n tiene MCP habilitado con la variable `N8N_MCP_ENABLED=true`
- Soporta comunicación bidireccional para capacidades de contexto extendido

#### Funcionalidades MCP
- Listar workflows
- Crear nuevos workflows
- Activar/desactivar workflows
- Obtener detalles de ejecuciones
- Administrar credenciales
- Ver historial de ejecuciones
- Integración con agentes de IA para toma de decisiones automatizada

## Capacidad de Ejecución de Python
El sistema está configurado para ejecutar código Python de forma segura y eficiente:

### Librerías Disponibles
- pandas
- numpy
- requests
- openpyxl
- scipy
- sklearn
- beautifulsoup4
- lxml
- Y otras librerías científicas y de análisis de datos

### Configuración de Task Runners
- Modo externo para evitar bloqueos del servidor principal
- Aislamiento completo del proceso de ejecución
- Control de recursos y límites de tiempo de ejecución
- Soporte para librerías científicas pesadas

## Scripts Disponibles en scripts-py/

### Gestión de API Key
Todos los scripts en esta carpeta ahora utilizan las variables de ambiente `N8N_API_KEY` o `N8N_ACCESS_TOKEN` como API key (en ese orden de prioridad). Estas variables se pueden definir de las siguientes maneras:

1. Como variable de ambiente del sistema:
   ```bash
   export N8N_API_KEY=your_token_here
   # o
   export N8N_ACCESS_TOKEN=your_token_here
   ```

2. En un archivo `.env` dentro de la carpeta `scripts-py/`:
   ```
   N8N_API_KEY=your_token_here
   # o
   N8N_ACCESS_TOKEN=your_token_here
   ```

Si no se define ninguna de las variables `N8N_API_KEY` o `N8N_ACCESS_TOKEN` en ninguno de estos lugares, los scripts mostrarán un mensaje de error y se detendrán.

### Agentes Principales
- `n8n_crud_agent.py`: Clase que encapsula todas las operaciones CRUD para workflows
- `qwen_n8n_plugin.py`: Plugin principal que Qwen puede usar para interactuar con n8n
- `qwen_n8n_integration_demo.py`: Ejemplo de cómo Qwen puede procesar solicitudes de usuarios y usar el plugin

### Scripts de Ejemplo
- `activate_workflow.py`: Activa un workflow específico
- `create_and_activate_workflow.py`: Crea y activa un nuevo workflow con un trigger
- `demo_crud.py`: Demostración completa de operaciones CRUD
- `execute_workflow.py`: Ejecuta un workflow desde un archivo JSON
- `list_active_workflows.py`: Lista workflows activos
- `list_all_workflows.py`: Lista todos los workflows
- `trigger_workflow.py`: Ejecuta manualmente un workflow específico

### Scripts de Prueba
- `test_n8n_crud_agent.py`: Suite de pruebas para el agente CRUD
- `test_publish_unpublish.py`: Prueba las funcionalidades de publicación/despublicación

## Casos de Uso Avanzados

### Análisis de Datos con Python
- Ejecución de scripts de pandas y numpy en contenedores aislados
- Procesamiento de grandes volúmenes de datos sin afectar el rendimiento de n8n
- Integración con bases de datos y APIs externas

### Automatización Compleja
- Workflows con múltiples triggers y condiciones
- Integración con sistemas externos
- Ejecución programada de tareas

### Gestión de Workflows
- Creación dinámica de workflows basados en parámetros
- Activación/desactivación programada
- Monitorización de estado y rendimiento

## Limitaciones Conocidas
- La actualización de workflows puede fallar en algunas versiones de n8n debido a restricciones de la API (método PATCH no permitido)
- Los workflows creados a través de la API pueden aparecer como "bloqueados" en el editor web de n8n
- Para activar un workflow, debe contener al menos un nodo de trigger válido
- El sistema requiere configuración adecuada de variables de entorno para el correcto funcionamiento de los task runners

## Qwen Added Memories
- La arquitectura actual utiliza un patrón de microservicios con n8n como orquestador principal y task runners externos para la ejecución de código Python/JavaScript, lo que permite procesar tareas pesadas sin bloquear el servidor principal.
- El sistema está configurado para usar Python 3.12 con soporte para librerías científicas como pandas y numpy, lo que permite a Qwen realizar análisis de datos complejos a través de workflows de n8n.
- La integración MCP está habilitada en n8n, lo que permite a Qwen acceder a capacidades avanzadas de contexto y comunicación bidireccional con la plataforma de automatización.
- Se ha implementado un sistema de booking/automatización llamado AutoAgenda que opera a través de un bot de Telegram, con una arquitectura modular de workflows (BB_XX), manejo centralizado de errores (BB_00), firewall de seguridad (BB_02), y redirección de deep links (BB_09), conectado a una base de datos PostgreSQL.
- El sistema sigue convenciones técnicas específicas como el uso de ciertas versiones de nodos n8n, patrones de código estructurados, y manejo estricto de errores y auditoría.
