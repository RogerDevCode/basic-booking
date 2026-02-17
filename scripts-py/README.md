# N8N Python Scripts

Scripts CRUD para gestión de workflows en n8n v2.8.0+

## Configuración

1. Copia `.env.example` a `.env`:
```bash
cp .env.example .env
```

2. Configura tus credenciales:
```env
N8N_API_URL=http://localhost:5678
N8N_API_KEY=your-api-key-here
```

## Scripts Disponibles

### CREATE

| Script | Descripción | Ejemplo |
|--------|-------------|---------|
| `n8n_create_from_file.py` | Crear workflow desde archivo JSON | `python n8n_create_from_file.py --file workflow.json --activate` |

### READ

| Script | Descripción | Ejemplo |
|--------|-------------|---------|
| `n8n_read_list.py` | Listar workflows | `python n8n_read_list.py --active` |
| `n8n_read_get.py` | Obtener workflow por ID/nombre | `python n8n_read_get.py --name "BB_00"` |
| `n8n_read_executions.py` | Ver historial de ejecuciones | `python n8n_read_executions.py --workflow ID` |
| `n8n_read_export.py` | Exportar workflows a JSON | `python n8n_read_export.py --all --output-dir ./exports/` |

### UPDATE

| Script | Descripción | Ejemplo |
|--------|-------------|---------|
| `n8n_update_from_file.py` | Actualizar workflow desde JSON | `python n8n_update_from_file.py --id ID --file workflow.json` |
| `n8n_update_activate.py` | Activar workflow | `python n8n_update_activate.py --id ID` |
| `n8n_update_deactivate.py` | Desactivar workflow | `python n8n_update_deactivate.py --id ID` |

### DELETE

| Script | Descripción | Ejemplo |
|--------|-------------|---------|
| `n8n_delete.py` | Eliminar workflow | `python n8n_delete.py --id ID` |

## Ejemplos de Uso

### Listar todos los workflows activos
```bash
python n8n_read_list.py --active --format table
```

### Filtrar workflows por nombre
```bash
python n8n_read_list.py --filter "BB_" --format json
```

### Exportar todos los workflows del proyecto
```bash
python n8n_read_export.py --filter "BB_" --output-dir ../workflows/
```

### Importar workflow desde archivo
```bash
python n8n_create_from_file.py --file ../workflows/BB_00_Global_Error_Handler.json --activate
```

### Activar múltiples workflows
```bash
python n8n_update_activate.py --filter "BB_" --all
```

### Ver ejecuciones recientes de un workflow
```bash
python n8n_read_executions.py --workflow ID --limit 20 --format table
```

### Ver detalles de ejecución fallida
```bash
python n8n_read_executions.py --execution EXEC_ID --format summary
```

## Opciones Comunes

Todos los scripts aceptan:
- `--url`: URL del servidor n8n (sobrescribe N8N_API_URL)
- `--api-key`: API key (sobrescribe N8N_API_KEY)
- `--format`: Formato de salida (json, table, summary, etc.)

## Archivos

```
scripts-py/
├── config.py                    # Configuración centralizada
├── .env.example                 # Template de variables de entorno
├── README.md                    # Este archivo
│
├── n8n_create_from_file.py      # CREATE: Crear workflow
│
├── n8n_read_list.py             # READ: Listar workflows
├── n8n_read_get.py              # READ: Obtener workflow
├── n8n_read_executions.py       # READ: Ver ejecuciones
├── n8n_read_export.py           # READ: Exportar workflows
│
├── n8n_update_from_file.py      # UPDATE: Actualizar workflow
├── n8n_update_activate.py       # UPDATE: Activar workflow
├── n8n_update_deactivate.py     # UPDATE: Desactivar workflow
│
├── n8n_delete.py                # DELETE: Eliminar workflow
│
└── _old_backup/                 # Scripts antiguos (backup)
```

## Requisitos

```bash
pip install requests
```

Python 3.8+
