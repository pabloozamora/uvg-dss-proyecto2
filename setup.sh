#!/bin/bash

# Script de configuración automática para el proyecto ELK Stack
# Autor: Proyecto 2 - Sistema de Logging

set -e  # Salir si hay algún error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir mensajes con colores
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

# Banner
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════╗
║   Sistema de Logging con ELK Stack               ║
║   Proyecto 2 - Desarrollo Seguro de Software     ║
╚═══════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar requisitos previos
print_header "Verificando Requisitos Previos"

# Verificar Docker
print_info "Verificando Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker instalado: $DOCKER_VERSION"
else
    print_error "Docker no está instalado. Por favor, instala Docker primero."
    echo "Visita: https://docs.docker.com/get-docker/"
    exit 1
fi

# Verificar Docker Compose
print_info "Verificando Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    print_success "Docker Compose instalado: $COMPOSE_VERSION"
else
    print_error "Docker Compose no está instalado o es una versión antigua."
    echo "Actualiza Docker o instala Docker Compose v2"
    exit 1
fi

# Verificar que Docker está corriendo
print_info "Verificando que Docker está ejecutándose..."
if docker ps &> /dev/null; then
    print_success "Docker daemon está activo"
else
    print_error "Docker daemon no está ejecutándose. Por favor, inicia Docker."
    exit 1
fi

# Verificar puertos disponibles
print_info "Verificando puertos disponibles..."
PORTS=(3000 5601 8080 9200 9300)
PORTS_IN_USE=()

for PORT in "${PORTS[@]}"; do
    # Intentar con lsof, ss, o netstat (el que esté disponible)
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            PORTS_IN_USE+=($PORT)
        fi
    elif command -v ss &> /dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":$PORT "; then
            PORTS_IN_USE+=($PORT)
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
            PORTS_IN_USE+=($PORT)
        fi
    else
        print_warning "No se pudo verificar puertos (lsof, ss o netstat no disponibles)"
        break
    fi
done

if [ ${#PORTS_IN_USE[@]} -eq 0 ]; then
    print_success "Todos los puertos necesarios están disponibles"
else
    print_warning "Los siguientes puertos están en uso: ${PORTS_IN_USE[*]}"
    echo "Puedes cambiar los puertos en docker-compose.yml o detener los servicios que los usan."
    read -p "¿Continuar de todas formas? (s/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# Navegar al directorio src
print_header "Configurando Proyecto"

if [ -d "src" ]; then
    cd src
    print_success "En el directorio src/"
else
    print_warning "No se encontró el directorio src/. Asumiendo que ya estás en él."
fi

# Verificar archivos necesarios
print_info "Verificando archivos de configuración..."
REQUIRED_FILES=("docker-compose.yml" "filebeat.yml" "kibana.yml" "Dockerfile")
MISSING_FILES=()

for FILE in "${REQUIRED_FILES[@]}"; do
    if [ -f "$FILE" ]; then
        print_success "Encontrado: $FILE"
    else
        MISSING_FILES+=($FILE)
        print_error "No se encontró: $FILE"
    fi
done

if [ ${#MISSING_FILES[@]} -ne 0 ]; then
    print_error "Faltan archivos necesarios. Verifica que estás en el directorio correcto."
    exit 1
fi

# Preguntar si quiere limpiar contenedores anteriores
print_header "Limpieza (Opcional)"
read -p "¿Quieres eliminar contenedores anteriores? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_info "Deteniendo contenedores existentes..."
    docker compose down 2>/dev/null || true
    
    read -p "¿También eliminar volúmenes (ESTO BORRARÁ TODOS LOS DATOS)? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        print_warning "Eliminando volúmenes..."
        docker compose down -v 2>/dev/null || true
        print_success "Volúmenes eliminados"
    fi
    print_success "Limpieza completada"
fi

# Levantar servicios
print_header "Iniciando Servicios"

print_info "Descargando imágenes y creando contenedores..."
print_info "Esto puede tomar varios minutos la primera vez..."
docker compose up -d

print_success "Contenedores iniciados"

# Esperar a que los servicios estén listos
print_header "Esperando a que los Servicios Estén Listos"

print_info "Esto puede tomar 2-3 minutos. Por favor espera..."

# Verificar que curl esté disponible
if ! command -v curl &> /dev/null; then
    print_warning "curl no está instalado. Se omitirá la verificación de servicios."
    print_info "Instala curl con: sudo apt-get install curl (Debian/Ubuntu) o sudo yum install curl (RHEL/CentOS)"
    SKIP_CHECKS=true
else
    SKIP_CHECKS=false
fi

# Función para verificar si un servicio está listo
check_service() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=0

    if [ "$SKIP_CHECKS" = true ]; then
        return 0
    fi

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 5
    done
    return 1
}

# Esperar por Elasticsearch
print_info "Esperando por Elasticsearch..."
if check_service "elasticsearch" "http://localhost:9200"; then
    print_success "Elasticsearch está listo"
else
    print_warning "Elasticsearch está tardando más de lo esperado. Puede que necesite más tiempo."
fi

# Esperar por Kibana
print_info "Esperando por Kibana..."
if check_service "kibana" "http://localhost:5601/api/status"; then
    print_success "Kibana está listo"
else
    print_warning "Kibana está tardando más de lo esperado. Puede que necesite más tiempo."
fi

# Esperar por Juice Shop
print_info "Esperando por Juice Shop..."
if check_service "juice-shop" "http://localhost:3000"; then
    print_success "Juice Shop está listo"
else
    print_warning "Juice Shop está tardando más de lo esperado. Puede que necesite más tiempo."
fi

# Verificar estado de contenedores
print_header "Estado de los Servicios"
docker compose ps

# Generar tráfico de prueba
print_header "Generando Tráfico de Prueba"
read -p "¿Quieres generar tráfico de prueba para crear logs? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    print_info "Generando 20 peticiones HTTP..."
    for i in {1..20}; do
        curl -s http://localhost:3000 > /dev/null
        echo -n "."
    done
    echo ""
    print_success "Tráfico generado. Los logs deberían aparecer en Kibana en unos segundos."
fi

# Resumen final
print_header "¡Instalación Completada!"

echo -e "${GREEN}El sistema está listo para usar. Accede a:${NC}"
echo ""
echo -e "  ${BLUE}Juice Shop:${NC}      http://localhost:3000"
echo -e "  ${BLUE}Juice Proxy:${NC}     http://localhost:8080"
echo -e "  ${BLUE}Kibana:${NC}          http://localhost:5601"
echo -e "  ${BLUE}Elasticsearch:${NC}   http://localhost:9200"
echo ""
echo -e "${YELLOW}Credenciales de Kibana/Elasticsearch:${NC}"
echo -e "  Usuario:   ${GREEN}elastic${NC}"
echo -e "  Password:  ${GREEN}changeme${NC}"
echo ""
echo -e "${BLUE}Próximos pasos:${NC}"
echo "  1. Abre Kibana en http://localhost:5601"
echo "  2. Inicia sesión con elastic / changeme"
echo "  3. Ve a Management → Stack Management → Data Views"
echo "  4. Crea un Data View con el patrón: filebeat-*"
echo "  5. Ve a Discover para explorar los logs"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo "  Ver logs:              docker compose logs -f"
echo "  Detener servicios:     docker compose down"
echo "  Reiniciar servicios:   docker compose restart"
echo "  Ver estado:            docker compose ps"
echo ""
echo -e "${GREEN}Para más información, consulta README.md o QUICKSTART.md${NC}"
echo ""
