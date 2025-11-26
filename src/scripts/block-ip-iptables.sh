#!/bin/bash
# Script para bloquear/desbloquear IPs usando iptables (Linux)
# Uso: ./block-ip-iptables.sh <block|unblock|list> <IP> [duration_seconds]

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Puertos a proteger
NGINX_PORT=8080
JUICE_PORT=3000

# Función para mostrar uso
usage() {
    echo "Uso: $0 <block|unblock|list|flush> [IP] [duración_segundos]"
    echo ""
    echo "Comandos:"
    echo "  block <IP> [duración]   - Bloquear IP (opcional: por tiempo limitado)"
    echo "  unblock <IP>            - Desbloquear IP"
    echo "  list                    - Listar todas las reglas de bloqueo"
    echo "  flush                   - Eliminar todas las reglas de bloqueo"
    echo ""
    echo "Ejemplos:"
    echo "  $0 block 192.168.1.100           # Bloqueo permanente"
    echo "  $0 block 192.168.1.100 3600      # Bloqueo por 1 hora"
    echo "  $0 unblock 192.168.1.100"
    echo "  $0 list"
    echo "  $0 flush"
    exit 1
}

# Verificar que se ejecuta como root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}Error: Este script debe ejecutarse como root (usa sudo)${NC}"
        exit 1
    fi
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

# Función para bloquear IP
block_ip() {
    local ip=$1
    local duration=${2:-0}
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    # Verificar si ya está bloqueada
    if iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
        echo -e "${YELLOW}La IP $ip ya está bloqueada${NC}"
        return 0
    fi
    
    # Bloquear todo el tráfico desde la IP
    iptables -A INPUT -s "$ip" -j DROP
    echo -e "${GREEN}IP $ip bloqueada en iptables${NC}"
    
    # Bloquear también en OUTPUT (tráfico saliente hacia esa IP)
    iptables -A OUTPUT -d "$ip" -j DROP
    echo -e "${GREEN}Tráfico saliente hacia $ip también bloqueado${NC}"
    
    # Log del evento
    logger -t block-ip "Bloqueada IP $ip mediante iptables"
    
    # If duration specified, create timer with error handling
    if [ "$duration" -gt 0 ]; then
        echo -e "${YELLOW}Temporary block: $duration seconds${NC}"
        (
            sleep "$duration"
            if unblock_ip "$ip" 2>/dev/null; then
                logger -t block-ip "Temporary block of $ip expired and removed successfully"
                echo -e "${GREEN}Temporary block of $ip expired${NC}"
            else
                logger -t block-ip "ERROR: Failed to remove temporary block of $ip"
                echo -e "${RED}ERROR: Failed to remove temporary block of $ip${NC}" >&2
            fi
        ) &
        TIMER_PID=$!
        echo "Timer PID: $TIMER_PID"
        logger -t block-ip "Temporary block timer started (PID: $TIMER_PID) for $ip"
    fi
}

# Función para bloquear solo puertos específicos
block_ip_ports() {
    local ip=$1
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    # Bloquear solo acceso a puertos de la aplicación
    iptables -A INPUT -s "$ip" -p tcp --dport "$NGINX_PORT" -j DROP
    iptables -A INPUT -s "$ip" -p tcp --dport "$JUICE_PORT" -j DROP
    
    echo -e "${GREEN}IP $ip bloqueada en puertos $NGINX_PORT y $JUICE_PORT${NC}"
    logger -t block-ip "Bloqueada IP $ip en puertos específicos"
}

# Función para desbloquear IP
unblock_ip() {
    local ip=$1
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    # Verificar si está bloqueada
    if ! iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
        echo -e "${YELLOW}La IP $ip no está bloqueada${NC}"
        return 0
    fi
    
    # Eliminar reglas
    iptables -D INPUT -s "$ip" -j DROP
    echo -e "${GREEN}IP $ip desbloqueada en INPUT${NC}"
    
    # Eliminar también de OUTPUT si existe
    if iptables -C OUTPUT -d "$ip" -j DROP 2>/dev/null; then
        iptables -D OUTPUT -d "$ip" -j DROP
        echo -e "${GREEN}IP $ip desbloqueada en OUTPUT${NC}"
    fi
    
    logger -t block-ip "Desbloqueada IP $ip"
}

# Función para listar reglas
list_rules() {
    echo -e "${GREEN}Reglas de iptables INPUT (bloqueadas entrantes):${NC}"
    echo "=================================================="
    iptables -L INPUT -n -v --line-numbers | grep -E "(Chain INPUT|DROP)"
    echo ""
    
    echo -e "${GREEN}Reglas de iptables OUTPUT (bloqueadas salientes):${NC}"
    echo "=================================================="
    iptables -L OUTPUT -n -v --line-numbers | grep -E "(Chain OUTPUT|DROP)"
}

# Function to flush all blocking rules
flush_rules() {
    echo -e "${YELLOW}Delete all blocking rules? (y/N)${NC}"
    read -r confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Count rules before deletion
        drop_count=$(iptables -S INPUT | grep -c "DROP" || echo "0")
        
        if [ "$drop_count" -eq 0 ]; then
            echo -e "${YELLOW}No DROP rules found in INPUT chain${NC}"
        else
            # Delete DROP rules in INPUT with error handling
            if iptables -S INPUT | grep "DROP" | cut -d " " -f 2- | xargs -I {} iptables -D {} 2>/dev/null; then
                echo -e "${GREEN}Removed $drop_count rule(s) from INPUT chain${NC}"
            else
                echo -e "${RED}Error removing some rules from INPUT chain${NC}" >&2
            fi
        fi
        
        # Count rules in OUTPUT
        drop_count=$(iptables -S OUTPUT | grep -c "DROP" || echo "0")
        
        if [ "$drop_count" -eq 0 ]; then
            echo -e "${YELLOW}No DROP rules found in OUTPUT chain${NC}"
        else
            # Delete DROP rules in OUTPUT with error handling
            if iptables -S OUTPUT | grep "DROP" | cut -d " " -f 2- | xargs -I {} iptables -D {} 2>/dev/null; then
                echo -e "${GREEN}Removed $drop_count rule(s) from OUTPUT chain${NC}"
            else
                echo -e "${RED}Error removing some rules from OUTPUT chain${NC}" >&2
            fi
        fi
        
        logger -t block-ip "All blocking rules were flushed"
    else
        echo "Operation cancelled"
    fi
}

# Función para guardar reglas (persistencia)
save_rules() {
    if command -v iptables-save &> /dev/null; then
        iptables-save > /etc/iptables/rules.v4
        echo -e "${GREEN}Reglas guardadas en /etc/iptables/rules.v4${NC}"
    else
        echo -e "${YELLOW}iptables-save no disponible. Las reglas se perderán al reiniciar.${NC}"
    fi
}

# Script principal
check_root

if [ $# -lt 1 ]; then
    usage
fi

COMMAND=$1

case $COMMAND in
    block)
        if [ $# -lt 2 ]; then
            echo -e "${RED}Error: Falta especificar la IP${NC}"
            usage
        fi
        block_ip "$2" "${3:-0}"
        ;;
    block-ports)
        if [ $# -ne 2 ]; then
            echo -e "${RED}Error: Falta especificar la IP${NC}"
            usage
        fi
        block_ip_ports "$2"
        ;;
    unblock)
        if [ $# -ne 2 ]; then
            echo -e "${RED}Error: Falta especificar la IP${NC}"
            usage
        fi
        unblock_ip "$2"
        ;;
    list)
        list_rules
        ;;
    flush)
        flush_rules
        ;;
    save)
        save_rules
        ;;
    *)
        echo -e "${RED}Error: Comando desconocido '$COMMAND'${NC}"
        usage
        ;;
esac

exit 0
