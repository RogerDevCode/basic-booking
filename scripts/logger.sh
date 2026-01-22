#!/usr/bin/env bash
# ============================================================================
# WORKFLOW OUTPUT LOGGER - Sistema Eficiente de Logging para AutoAgenda
# ============================================================================
# Versión: 2.0
# Propósito: Capturar outputs de workflows n8n en formato UTF-8 para análisis IA
# Autor: AutoAgenda Team
# ============================================================================

set -euo pipefail

# Configuración
readonly LOG_DIR="/home/manager/Sync/N8N Projects/basic-booking/logs/workflow_outputs"
readonly MAX_LOG_SIZE_MB=100
readonly RETENTION_DAYS=30

# Asegurar que el directorio existe
mkdir -p "$LOG_DIR" || {
    echo "ERROR: No se puede crear directorio de logs" >&2
    exit 1
}

# ============================================================================
# FUNCIÓN PRINCIPAL: Guardar log de workflow
# ============================================================================
log_workflow_output() {
    local workflow_id="$1"
    local workflow_name="$2"
    local endpoint="${3:-MAIN}"
    local output_data="$4"
    
    # Validación de parámetros
    if [[ -z "$workflow_id" ]] || [[ -z "$workflow_name" ]] || [[ -z "$output_data" ]]; then
        echo "ERROR: Parámetros requeridos: <workflow_id> <workflow_name> <endpoint> '<json_data>'" >&2
        return 1
    fi
    
    # Generar nombre de archivo (formato: WFID_ENDPOINT_TIMESTAMP.log)
    local timestamp=$(date -u +"%Y%m%d_%H%M%S")
    local filename="${LOG_DIR}/${workflow_id}_${endpoint}_${timestamp}.log"
    
    # Crear log en formato UTF-8
    cat > "$filename" <<-EOF
	# ============================================================================
	# WORKFLOW OUTPUT LOG
	# ============================================================================
	Workflow ID:      $workflow_id
	Workflow Name:    $workflow_name
	Endpoint:         $endpoint
	Timestamp:        $(date -u +"%Y-%m-%d %H:%M:%S UTC")
	Instance:         AutoAgenda v3.1.0
	# ============================================================================
	
	$output_data
	
	# ============================================================================
	# END OF LOG
	# ============================================================================
	EOF
    
    # Verificar que se creó correctamente
    if [[ -f "$filename" ]]; then
        local size=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null)
        echo "✅ Log guardado: $filename (${size} bytes)"
        return 0
    else
        echo "ERROR: Falló la creación del log" >&2
        return 1
    fi
}

# ============================================================================
# FUNCIÓN: Listar logs recientes
# ============================================================================
list_recent_logs() {
    local hours="${1:-24}"
    local minutes=$((hours * 60))
    
    echo "📋 Logs de las últimas $hours horas:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    find "$LOG_DIR" -type f -name "*.log" -mmin -"$minutes" -exec ls -lh {} \; | \
        awk '{printf "%-50s %10s  %s %s %s\n", $9, $5, $6, $7, $8}' | \
        sort -r
    
    local count=$(find "$LOG_DIR" -type f -name "*.log" -mmin -"$minutes" | wc -l | tr -d ' ')
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: $count archivo(s)"
}

# ============================================================================
# FUNCIÓN: Buscar logs por workflow
# ============================================================================
search_by_workflow() {
    local workflow_id="$1"
    
    if [[ -z "$workflow_id" ]]; then
        echo "ERROR: Especifica el ID del workflow (ej: BB_00)" >&2
        return 1
    fi
    
    echo "🔍 Logs del workflow: $workflow_id"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    find "$LOG_DIR" -type f -name "${workflow_id}_*.log" -exec ls -lht {} \; | head -20
    
    local total=$(find "$LOG_DIR" -type f -name "${workflow_id}_*.log" | wc -l | tr -d ' ')
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Total: $total archivo(s) del workflow $workflow_id"
}

# ============================================================================
# FUNCIÓN: Estadísticas del sistema de logging
# ============================================================================
stats() {
    echo "📊 ESTADÍSTICAS DEL SISTEMA DE LOGGING"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Directorio: $LOG_DIR"
    
    local total_logs=$(find "$LOG_DIR" -type f -name "*.log" | wc -l | tr -d ' ')
    local total_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
    
    echo "Total de logs: $total_logs"
    echo "Tamaño total: $total_size"
    echo ""
    
    # Logs por workflow
    echo "Distribución por workflow:"
    for wf in BB_00 BB_01 BB_02 BB_03 BB_04 BB_05 BB_06; do
        local count=$(find "$LOG_DIR" -type f -name "${wf}_*.log" | wc -l | tr -d ' ')
        if [[ $count -gt 0 ]]; then
            printf "  %-6s : %5d logs\n" "$wf" "$count"
        fi
    done
    
    echo ""
    echo "Logs de las últimas 24 horas: $(find "$LOG_DIR" -type f -name "*.log" -mtime -1 | wc -l | tr -d ' ')"
    echo "Logs de la última hora: $(find "$LOG_DIR" -type f -name "*.log" -mmin -60 | wc -l | tr -d ' ')"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================================================
# FUNCIÓN: Limpieza automática de logs antiguos
# ============================================================================
cleanup() {
    local days="${1:-$RETENTION_DAYS}"
    
    echo "🗑️  Limpiando logs anteriores a $days días..."
    
    local count_before=$(find "$LOG_DIR" -type f -name "*.log" | wc -l | tr -d ' ')
    find "$LOG_DIR" -type f -name "*.log" -mtime +"$days" -delete
    local count_after=$(find "$LOG_DIR" -type f -name "*.log" | wc -l | tr -d ' ')
    
    local deleted=$((count_before - count_after))
    echo "✅ Limpieza completada: $deleted archivo(s) eliminado(s)"
}

# ============================================================================
# FUNCIÓN: Ver contenido de un log
# ============================================================================
view_log() {
    local log_file="$1"
    
    if [[ ! -f "$log_file" ]]; then
        echo "ERROR: Archivo no encontrado: $log_file" >&2
        return 1
    fi
    
    # Mostrar con colores si está disponible
    if command -v bat &>/dev/null; then
        bat --style=plain --language=json "$log_file"
    else
        cat "$log_file"
    fi
}

# ============================================================================
# INTERFAZ DE LÍNEA DE COMANDOS
# ============================================================================
main() {
    case "${1:-help}" in
        log)
            shift
            log_workflow_output "$@"
            ;;
        list)
            list_recent_logs "${2:-24}"
            ;;
        search)
            search_by_workflow "$2"
            ;;
        stats)
            stats
            ;;
        cleanup)
            cleanup "${2:-$RETENTION_DAYS}"
            ;;
        view)
            view_log "$2"
            ;;
        help|*)
            cat <<-'HELP'
			🔧 WORKFLOW OUTPUT LOGGER - AutoAgenda v2.0
			━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
			
			USO:
			  logger.sh log <workflow_id> <workflow_name> <endpoint> '<json_data>'
			      Guarda el output de un workflow en formato UTF-8
			      
			  logger.sh list [hours]
			      Lista logs recientes (default: últimas 24 horas)
			      
			  logger.sh search <workflow_id>
			      Busca logs de un workflow específico (ej: BB_06)
			      
			  logger.sh stats
			      Muestra estadísticas del sistema de logging
			      
			  logger.sh cleanup [days]
			      Elimina logs anteriores a N días (default: 30)
			      
			  logger.sh view <archivo>
			      Muestra el contenido de un log específico
			      
			  logger.sh help
			      Muestra esta ayuda
			
			EJEMPLOS:
			  # Guardar log de BB_06 endpoint /api/calendar
			  logger.sh log BB_06 "Admin Dashboard" "GET_api_calendar" '{"events": [...]}'
			  
			  # Listar logs de las últimas 6 horas
			  logger.sh list 6
			  
			  # Buscar todos los logs de BB_03
			  logger.sh search BB_03
			  
			  # Ver estadísticas
			  logger.sh stats
			
			━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
			HELP
            ;;
    esac
}

# Ejecutar
main "$@"
