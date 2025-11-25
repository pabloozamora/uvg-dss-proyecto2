#!/bin/bash
# Script para bloquear/desbloquear IPs en Nginx
# Uso: ./block-ip-nginx.sh <block|unblock|list> <IP>

set -e

# Use relative path from script location or environment variable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_CONF="${NGINX_BLOCKED_IPS_CONF:-${SCRIPT_DIR}/../nginx/blocked_ips.conf}"
CONTAINER_NAME="${NGINX_CONTAINER_NAME:-juice-proxy}"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para mostrar uso
usage() {
    echo "Uso: $0 <block|unblock|list> [IP]"
    echo ""
    echo "Comandos:"
    echo "  block <IP>    - Bloquear una dirección IP"
    echo "  unblock <IP>  - Desbloquear una dirección IP"
    echo "  list          - Listar todas las IPs bloqueadas"
    echo ""
    echo "Ejemplos:"
    echo "  $0 block 192.168.1.100"
    echo "  $0 unblock 192.168.1.100"
    echo "  $0 list"
    exit 1
}

# Función para validar IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    else
        echo -e "${RED}Error: '$ip' no es una dirección IP válida${NC}"
        return 1
    fi
}

# Función para crear archivo de IPs bloqueadas si no existe
init_blocked_file() {
    if [ ! -f "$NGINX_CONF" ]; then
        echo "# Lista de IPs bloqueadas - Generado automáticamente" > "$NGINX_CONF"
        echo "# Formato: deny <IP>;" >> "$NGINX_CONF"
        echo "# No eliminar este archivo" >> "$NGINX_CONF"
        echo "" >> "$NGINX_CONF"
        echo -e "${GREEN}Archivo de configuración creado: $NGINX_CONF${NC}"
    fi
}

# Función para bloquear IP
block_ip() {
    local ip=$1
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    init_blocked_file
    
    # Verificar si la IP ya está bloqueada
    if grep -q "deny $ip;" "$NGINX_CONF"; then
        echo -e "${YELLOW}La IP $ip ya está bloqueada${NC}"
        return 0
    fi
    
    # Agregar IP al archivo
    echo "deny $ip;  # Bloqueada el $(date '+%Y-%m-%d %H:%M:%S')" >> "$NGINX_CONF"
    echo -e "${GREEN}IP $ip agregada a la lista de bloqueo${NC}"
    
    # Recargar Nginx
    reload_nginx
}

# Función para desbloquear IP
unblock_ip() {
    local ip=$1
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    if [ ! -f "$NGINX_CONF" ]; then
        echo -e "${YELLOW}No hay archivo de IPs bloqueadas${NC}"
        return 0
    fi
    
    # Verificar si la IP está bloqueada
    if ! grep -q "deny $ip;" "$NGINX_CONF"; then
        echo -e "${YELLOW}La IP $ip no está en la lista de bloqueo${NC}"
        return 0
    fi
    
    # Eliminar la línea con la IP
    sed -i "/deny $ip;/d" "$NGINX_CONF"
    echo -e "${GREEN}IP $ip eliminada de la lista de bloqueo${NC}"
    
    # Recargar Nginx
    reload_nginx
}

# Función para listar IPs bloqueadas
list_blocked() {
    if [ ! -f "$NGINX_CONF" ]; then
        echo -e "${YELLOW}No hay archivo de IPs bloqueadas${NC}"
        return 0
    fi
    
    echo -e "${GREEN}IPs actualmente bloqueadas:${NC}"
    echo "=================================="
    grep "^deny" "$NGINX_CONF" || echo "No hay IPs bloqueadas"
    echo "=================================="
}

# Función para recargar Nginx
reload_nginx() {
    echo "Recargando configuración de Nginx..."
    
    # Verificar sintaxis primero
    if docker exec "$CONTAINER_NAME" nginx -t > /dev/null 2>&1; then
        # Recargar configuración
        docker exec "$CONTAINER_NAME" nginx -s reload
        echo -e "${GREEN}Nginx recargado exitosamente${NC}"
    else
        echo -e "${RED}Error en la configuración de Nginx${NC}"
        docker exec "$CONTAINER_NAME" nginx -t
        return 1
    fi
}

# Script principal
if [ $# -lt 1 ]; then
    usage
fi

COMMAND=$1

case $COMMAND in
    block)
        if [ $# -ne 2 ]; then
            echo -e "${RED}Error: Falta especificar la IP${NC}"
            usage
        fi
        block_ip "$2"
        ;;
    unblock)
        if [ $# -ne 2 ]; then
            echo -e "${RED}Error: Falta especificar la IP${NC}"
            usage
        fi
        unblock_ip "$2"
        ;;
    list)
        list_blocked
        ;;
    *)
        echo -e "${RED}Error: Comando desconocido '$COMMAND'${NC}"
        usage
        ;;
esac

exit 0
