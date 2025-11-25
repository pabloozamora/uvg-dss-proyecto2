#!/bin/bash
# Script para activar/desactivar debug logging dinámicamente
# Uso: ./toggle-debug-logging.sh <enable|disable|status>

set -e

NGINX_CONF_DIR="/home/runner/work/uvg-dss-proyecto2/uvg-dss-proyecto2/src/nginx"
NGINX_CONF="$NGINX_CONF_DIR/default.conf"
NGINX_CONF_BACKUP="$NGINX_CONF_DIR/default.conf.backup"
DEBUG_CONF="$NGINX_CONF_DIR/debug.conf"
CONTAINER_NAME="juice-proxy"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para mostrar uso
usage() {
    echo "Uso: $0 <enable|disable|status>"
    echo ""
    echo "Comandos:"
    echo "  enable   - Activar logging detallado (debug)"
    echo "  disable  - Desactivar logging detallado (volver a normal)"
    echo "  status   - Mostrar estado actual del logging"
    echo ""
    echo "Ejemplos:"
    echo "  $0 enable"
    echo "  $0 disable"
    echo "  $0 status"
    exit 1
}

# Función para crear configuración de debug
create_debug_config() {
    cat > "$DEBUG_CONF" << 'EOF'
# Formato de log detallado para debugging y análisis forense
log_format debug_json escape=json '{'
  '"timestamp":"$time_iso8601",'
  '"remote_addr":"$remote_addr",'
  '"x_forwarded_for":"$http_x_forwarded_for",'
  '"request":"$request",'
  '"request_method":"$request_method",'
  '"request_uri":"$request_uri",'
  '"query_string":"$query_string",'
  '"request_body":"$request_body",'
  '"status":$status,'
  '"body_bytes_sent":$body_bytes_sent,'
  '"request_time":$request_time,'
  '"request_length":$request_length,'
  '"upstream_response_time":"$upstream_response_time",'
  '"upstream_connect_time":"$upstream_connect_time",'
  '"upstream_header_time":"$upstream_header_time",'
  '"http_referrer":"$http_referer",'
  '"http_user_agent":"$http_user_agent",'
  '"http_cookie":"$http_cookie",'
  '"http_authorization":"$http_authorization",'
  '"http_accept":"$http_accept",'
  '"http_accept_language":"$http_accept_language",'
  '"http_accept_encoding":"$http_accept_encoding",'
  '"http_x_real_ip":"$http_x_real_ip",'
  '"upstream_addr":"$upstream_addr",'
  '"upstream_status":"$upstream_status",'
  '"host":"$host",'
  '"server_name":"$server_name",'
  '"connection":"$connection",'
  '"connection_requests":"$connection_requests",'
  '"ssl_protocol":"$ssl_protocol",'
  '"ssl_cipher":"$ssl_cipher"'
'}';

server {
  listen 80;
  server_name _;

  # Habilitar lectura del request body para logging completo
  client_body_buffer_size 128k;
  client_max_body_size 10m;
  
  # CORS headers
  add_header Access-Control-Allow-Origin "*" always;
  add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
  add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With";

  location / {
    # Forzar buffering para poder leer el body
    proxy_request_buffering on;
    
    proxy_pass http://juice-shop:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Logging detallado con formato JSON extendido
    access_log /var/log/nginx/juice_access.log debug_json;
    access_log /var/log/nginx/juice_debug.log debug_json;
    error_log  /var/log/nginx/juice_error.log debug;
  }

  location /healthz {
    return 200 "ok\n";
  }
}
EOF
    echo -e "${GREEN}Configuración de debug creada${NC}"
}

# Función para habilitar debug logging
enable_debug() {
    echo -e "${BLUE}Activando logging detallado...${NC}"
    
    # Crear backup si no existe
    if [ ! -f "$NGINX_CONF_BACKUP" ]; then
        cp "$NGINX_CONF" "$NGINX_CONF_BACKUP"
        echo -e "${GREEN}Backup creado: $NGINX_CONF_BACKUP${NC}"
    fi
    
    # Crear configuración de debug
    create_debug_config
    
    # Reemplazar configuración actual con debug
    cp "$DEBUG_CONF" "$NGINX_CONF"
    echo -e "${GREEN}Configuración de debug activada${NC}"
    
    # Verificar sintaxis
    if docker exec "$CONTAINER_NAME" nginx -t > /dev/null 2>&1; then
        # Recargar Nginx
        docker exec "$CONTAINER_NAME" nginx -s reload
        echo -e "${GREEN}Nginx recargado con configuración de debug${NC}"
        echo ""
        echo -e "${YELLOW}ADVERTENCIA: El logging detallado puede consumir mucho espacio en disco${NC}"
        echo -e "${YELLOW}Recuerda desactivarlo cuando termines: $0 disable${NC}"
        echo ""
        echo -e "${BLUE}Logs detallados disponibles en:${NC}"
        echo "  - /var/log/nginx/juice_debug.log (dentro del contenedor)"
        echo "  - docker logs juice-proxy"
        echo ""
        echo -e "${BLUE}Para ver logs en tiempo real:${NC}"
        echo "  docker exec juice-proxy tail -f /var/log/nginx/juice_debug.log"
    else
        echo -e "${RED}Error en la configuración de Nginx${NC}"
        docker exec "$CONTAINER_NAME" nginx -t
        # Restaurar backup
        cp "$NGINX_CONF_BACKUP" "$NGINX_CONF"
        return 1
    fi
}

# Función para deshabilitar debug logging
disable_debug() {
    echo -e "${BLUE}Desactivando logging detallado...${NC}"
    
    # Verificar si existe backup
    if [ ! -f "$NGINX_CONF_BACKUP" ]; then
        echo -e "${YELLOW}No se encontró configuración de backup${NC}"
        echo -e "${YELLOW}El logging debug puede no estar activo${NC}"
        return 0
    fi
    
    # Restaurar configuración original
    cp "$NGINX_CONF_BACKUP" "$NGINX_CONF"
    echo -e "${GREEN}Configuración normal restaurada${NC}"
    
    # Recargar Nginx
    if docker exec "$CONTAINER_NAME" nginx -t > /dev/null 2>&1; then
        docker exec "$CONTAINER_NAME" nginx -s reload
        echo -e "${GREEN}Nginx recargado con configuración normal${NC}"
        
        # Limpiar archivos temporales
        rm -f "$NGINX_CONF_BACKUP" "$DEBUG_CONF"
        echo -e "${GREEN}Archivos temporales eliminados${NC}"
        
        echo ""
        echo -e "${BLUE}Limpieza de logs (opcional):${NC}"
        echo "Para limpiar logs debug antiguos:"
        echo "  docker exec juice-proxy truncate -s 0 /var/log/nginx/juice_debug.log"
    else
        echo -e "${RED}Error en la configuración de Nginx${NC}"
        docker exec "$CONTAINER_NAME" nginx -t
        return 1
    fi
}

# Función para mostrar estado
show_status() {
    echo -e "${BLUE}Estado del logging:${NC}"
    echo "=================================="
    
    if [ -f "$NGINX_CONF_BACKUP" ]; then
        echo -e "${GREEN}Debug logging: ACTIVO${NC}"
        echo ""
        echo "Configuración actual incluye:"
        echo "  - Request body completo"
        echo "  - Headers completos"
        echo "  - Tiempos de respuesta detallados"
        echo "  - Información de upstream"
        echo ""
        echo "Para desactivar: $0 disable"
    else
        echo -e "${YELLOW}Debug logging: INACTIVO${NC}"
        echo ""
        echo "Logging normal activo con:"
        echo "  - Request básico"
        echo "  - Status codes"
        echo "  - IPs y user agents"
        echo ""
        echo "Para activar debug: $0 enable"
    fi
    
    echo ""
    echo -e "${BLUE}Uso de disco en logs:${NC}"
    docker exec "$CONTAINER_NAME" du -sh /var/log/nginx/ 2>/dev/null || echo "No disponible"
    
    echo ""
    echo -e "${BLUE}Últimas 5 líneas del log actual:${NC}"
    docker exec "$CONTAINER_NAME" tail -5 /var/log/nginx/juice_access.log 2>/dev/null || echo "No disponible"
}

# Función para rotar logs
rotate_logs() {
    echo -e "${BLUE}Rotando logs...${NC}"
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Copiar logs actuales con timestamp
    docker exec "$CONTAINER_NAME" sh -c "
        if [ -f /var/log/nginx/juice_debug.log ]; then
            cp /var/log/nginx/juice_debug.log /var/log/nginx/juice_debug.log.$timestamp
            truncate -s 0 /var/log/nginx/juice_debug.log
            echo 'Log debug rotado'
        fi
        
        if [ -f /var/log/nginx/juice_access.log ]; then
            cp /var/log/nginx/juice_access.log /var/log/nginx/juice_access.log.$timestamp
            truncate -s 0 /var/log/nginx/juice_access.log
            echo 'Log access rotado'
        fi
    "
    
    echo -e "${GREEN}Logs rotados con timestamp: $timestamp${NC}"
    echo "Los logs antiguos están guardados como .log.$timestamp"
}

# Script principal
if [ $# -lt 1 ]; then
    usage
fi

COMMAND=$1

case $COMMAND in
    enable)
        enable_debug
        ;;
    disable)
        disable_debug
        ;;
    status)
        show_status
        ;;
    rotate)
        rotate_logs
        ;;
    *)
        echo -e "${RED}Error: Comando desconocido '$COMMAND'${NC}"
        usage
        ;;
esac

exit 0
