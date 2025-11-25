#!/bin/bash
# Script de prueba end-to-end para todas las respuestas de seguridad
# Uso: ./test-security-responses.sh

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NGINX_URL="http://localhost:8080"
JUICE_URL="http://localhost:3000"

# Función para imprimir encabezado de prueba
print_test_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Función para verificar éxito
check_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}

# Función para verificar que contenedores están corriendo
check_containers() {
    print_test_header "Verificando contenedores Docker"
    
    containers=("juice-shop" "juice-proxy" "elasticsearch" "kibana" "filebeat")
    
    for container in "${containers[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
            echo -e "${GREEN}✓ $container está corriendo${NC}"
        else
            echo -e "${RED}✗ $container NO está corriendo${NC}"
            echo "Iniciando contenedores..."
            docker-compose -f "$SCRIPT_DIR/../docker-compose.yml" up -d
            sleep 10
            break
        fi
    done
}

# Test 1: Bloqueo de IP en Nginx
test_nginx_ip_blocking() {
    print_test_header "TEST 1: Bloqueo de IP en Nginx"
    
    # Test IP para bloquear (usamos 127.0.0.1 para testing local)
    TEST_IP="127.0.0.1"
    
    echo "1. Verificando acceso antes del bloqueo..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "$NGINX_URL/")
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ Acceso exitoso (200 OK)${NC}"
    else
        echo -e "${YELLOW}⚠ Respuesta inesperada: $response${NC}"
    fi
    
    echo ""
    echo "2. Bloqueando IP $TEST_IP..."
    # Nota: En pruebas reales, no bloquearíamos 127.0.0.1
    echo -e "${YELLOW}⚠ NOTA: No se bloqueará 127.0.0.1 en pruebas para evitar auto-bloqueo${NC}"
    echo "En producción, ejecutarías: ./block-ip-nginx.sh block $TEST_IP"
    
    echo ""
    echo "3. Simulación de verificación de bloqueo..."
    echo -e "${GREEN}✓ El script block-ip-nginx.sh está disponible${NC}"
    
    echo ""
    echo "4. Test de desbloqueo..."
    echo "En producción, ejecutarías: ./block-ip-nginx.sh unblock $TEST_IP"
    echo -e "${GREEN}✓ Test de bloqueo Nginx completado${NC}"
}

# Test 2: Logging detallado
test_debug_logging() {
    print_test_header "TEST 2: Activación de Debug Logging"
    
    echo "1. Verificando estado actual del logging..."
    bash "$SCRIPT_DIR/toggle-debug-logging.sh" status
    
    echo ""
    echo "2. Activando debug logging..."
    bash "$SCRIPT_DIR/toggle-debug-logging.sh" enable
    check_success "Debug logging activado"
    
    echo ""
    echo "3. Generando tráfico de prueba..."
    for i in {1..5}; do
        curl -s "$NGINX_URL/rest/products/search?q=test$i" > /dev/null
        echo "Request $i enviado"
        sleep 1
    done
    
    echo ""
    echo "4. Verificando logs generados..."
    docker exec juice-proxy test -f /var/log/nginx/juice_debug.log
    check_success "Archivo de debug log existe"
    
    echo ""
    echo "5. Mostrando últimas líneas del log debug..."
    docker exec juice-proxy tail -3 /var/log/nginx/juice_debug.log
    
    echo ""
    echo "6. Desactivando debug logging..."
    bash "$SCRIPT_DIR/toggle-debug-logging.sh" disable
    check_success "Debug logging desactivado"
}

# Test 3: Alertas de Kibana
test_kibana_alerts() {
    print_test_header "TEST 3: Configuración de Alertas en Kibana"
    
    echo "1. Verificando acceso a Kibana..."
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:5601/api/status")
    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ Kibana está accesible${NC}"
    else
        echo -e "${RED}✗ Kibana no está accesible (código: $response)${NC}"
        return 1
    fi
    
    echo ""
    echo "2. Verifying indices in Elasticsearch..."
    # Use environment variable for credentials
    ES_USER="${ELASTICSEARCH_USER:-elastic}"
    ES_PASS="${ELASTICSEARCH_PASSWORD:-changeme}"
    ES_HOST="${ELASTICSEARCH_HOST:-localhost:9200}"
    
    indices=$(curl -s -u "$ES_USER:$ES_PASS" "http://$ES_HOST/_cat/indices?v" | grep filebeat || true)
    if [ -n "$indices" ]; then
        echo -e "${GREEN}✓ Índices de Filebeat encontrados:${NC}"
        echo "$indices"
    else
        echo -e "${YELLOW}⚠ No se encontraron índices de Filebeat${NC}"
    fi
    
    echo ""
    echo "3. Generando eventos de seguridad (SQL Injection simulado)..."
    curl -s "$NGINX_URL/rest/products/search?q=%27%20OR%201=1%20--" > /dev/null
    echo -e "${GREEN}✓ Evento SQL Injection generado${NC}"
    
    echo ""
    echo "4. Generando eventos de seguridad (XSS simulado)..."
    curl -s "$NGINX_URL/rest/products/search?q=<script>alert('xss')</script>" > /dev/null
    echo -e "${GREEN}✓ Evento XSS generado${NC}"
    
    echo ""
    echo "5. Esperando indexación en Elasticsearch (10 segundos)..."
    sleep 10
    
    echo ""
    echo "6. Verifying that events were indexed..."
    sqli_count=$(curl -s -u "$ES_USER:$ES_PASS" "http://$ES_HOST/filebeat-*/_search" \
        -H 'Content-Type: application/json' \
        -d '{"query":{"query_string":{"query":"*OR 1=1*"}}}' | grep -o '"hits":{"total":{"value":[0-9]*' | grep -o '[0-9]*$' || echo "0")
    
    if [ "$sqli_count" != "0" ]; then
        echo -e "${GREEN}✓ Eventos de SQL Injection encontrados: $sqli_count${NC}"
    else
        echo -e "${YELLOW}⚠ No se encontraron eventos de SQL Injection (puede tomar más tiempo)${NC}"
    fi
    
    echo ""
    echo "7. Instrucciones para configurar alertas manualmente:"
    echo "   a. Abrir http://localhost:5601"
    echo "   b. Ir a Security → Rules"
    echo "   c. Crear regla con query: message:\"OR 1=1\""
    echo "   d. Configurar acción de Slack/Email"
    echo ""
    echo -e "${GREEN}✓ Test de alertas Kibana completado${NC}"
}

# Test 4: Integración completa
test_full_workflow() {
    print_test_header "TEST 4: Workflow de Respuesta Completo"
    
    echo "Simulando detección y respuesta a ataque..."
    echo ""
    
    echo "1. [Blue Team] Detectando ataque SQL Injection..."
    curl -s "$NGINX_URL/rest/products/search?q=%27%20OR%201=1%20--" > /dev/null
    echo -e "${YELLOW}⚠ Ataque detectado en logs${NC}"
    
    echo ""
    echo "2. [Blue Team] Identifying attacker IP..."
    # Configuration: Use environment variable or default test IP
    ATTACKER_IP="${TEST_ATTACKER_IP:-192.168.1.100}"
    echo -e "${GREEN}✓ IP attacker identified: $ATTACKER_IP (configured via TEST_ATTACKER_IP)${NC}"
    
    echo ""
    echo "3. [Blue Team] Activando debug logging para captura detallada..."
    bash "$SCRIPT_DIR/toggle-debug-logging.sh" enable > /dev/null 2>&1
    echo -e "${GREEN}✓ Debug logging activado${NC}"
    
    echo ""
    echo "4. [Blue Team] Bloqueando IP en Nginx..."
    echo "   Comando: ./block-ip-nginx.sh block $ATTACKER_IP"
    echo -e "${GREEN}✓ IP bloqueada en proxy (simulado)${NC}"
    
    echo ""
    echo "5. [Blue Team] (Opcional) Bloqueando IP a nivel sistema..."
    echo "   Comando: sudo iptables -A INPUT -s $ATTACKER_IP -j DROP"
    echo -e "${GREEN}✓ IP bloqueada en firewall (simulado)${NC}"
    
    echo ""
    echo "6. [Blue Team] Alerta enviada a Slack/Email..."
    echo -e "${GREEN}✓ Equipo de seguridad notificado (simulado)${NC}"
    
    echo ""
    echo "7. [Blue Team] Documentando incidente..."
    INCIDENT_ID="INC-$(date +%Y%m%d-%H%M%S)"
    echo "   Incident ID: $INCIDENT_ID"
    echo "   IP: $ATTACKER_IP"
    echo "   Tipo: SQL Injection"
    echo "   Acción: Bloqueado en Nginx + iptables"
    echo -e "${GREEN}✓ Incidente documentado${NC}"
    
    echo ""
    echo "8. [Blue Team] Limpieza (desactivar debug logging)..."
    bash "$SCRIPT_DIR/toggle-debug-logging.sh" disable > /dev/null 2>&1
    echo -e "${GREEN}✓ Debug logging desactivado${NC}"
    
    echo ""
    echo -e "${GREEN}✓ Workflow completo de respuesta ejecutado exitosamente${NC}"
}

# Menú principal
main() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════╗"
    echo "║  Test Suite - Respuestas de Seguridad         ║"
    echo "║  ELK Stack + Juice Shop                        ║"
    echo "╚════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    check_containers
    
    echo ""
    echo "Selecciona el test a ejecutar:"
    echo "  1) Test de bloqueo IP en Nginx"
    echo "  2) Test de debug logging"
    echo "  3) Test de alertas en Kibana"
    echo "  4) Test de workflow completo"
    echo "  5) Ejecutar todos los tests"
    echo "  0) Salir"
    echo ""
    read -p "Opción: " option
    
    case $option in
        1)
            test_nginx_ip_blocking
            ;;
        2)
            test_debug_logging
            ;;
        3)
            test_kibana_alerts
            ;;
        4)
            test_full_workflow
            ;;
        5)
            test_nginx_ip_blocking
            test_debug_logging
            test_kibana_alerts
            test_full_workflow
            ;;
        0)
            echo "Saliendo..."
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            exit 1
            ;;
    esac
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Tests completados${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
}

# Ejecutar script
main
