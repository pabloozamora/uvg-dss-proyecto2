# Proyecto 2 - Sistema de Logging con ELK Stack

Sistema de monitoreo y análisis de logs usando ELK Stack (Elasticsearch, Filebeat, Kibana) con OWASP Juice Shop como aplicación vulnerable de prueba.

## 📋 Tabla de Contenidos

- [Descripción](#descripción)
- [Arquitectura](#arquitectura)
- [Requisitos Previos](#requisitos-previos)
- [Instalación](#instalación)
- [Configuración](#configuración)
- [Uso](#uso)
- [Verificación](#verificación)
- [Solución de Problemas](#solución-de-problemas)
- [Comandos Útiles](#comandos-útiles)

## 🎯 Descripción

Este proyecto implementa un sistema completo de logging y monitoreo para detectar y analizar actividades de seguridad en una aplicación web vulnerable (OWASP Juice Shop).

### Componentes del Sistema

1. **Juice Shop** - Aplicación web vulnerable para pruebas de seguridad
2. **Nginx Proxy** - Proxy reverso que registra el tráfico HTTP
3. **Elasticsearch** - Motor de búsqueda y almacenamiento de logs
4. **Kibana** - Interfaz web para visualización y análisis
5. **Filebeat** - Recolector de logs de contenedores Docker

## 🏗️ Arquitectura

```
┌─────────────┐
│   Usuario   │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌──────────────┐
│ Nginx Proxy │────▶│  Juice Shop  │
│   :8080     │     │    :3000     │
└──────┬──────┘     └──────┬───────┘
       │                   │
       │ logs              │ logs
       ▼                   ▼
┌──────────────────────────────┐
│         Filebeat             │
│    (Recolector de Logs)      │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│       Elasticsearch          │
│   (Almacenamiento de Logs)   │
│          :9200               │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│          Kibana              │
│      (Visualización)         │
│          :5601               │
└──────────────────────────────┘
```

## 📦 Requisitos Previos

Antes de comenzar, asegúrate de tener instalado:

- **Docker** (versión 20.10 o superior)
- **Docker Compose** (versión 2.0 o superior)
- **Git** (para clonar el repositorio)
- Al menos **4 GB de RAM** disponible para los contenedores
- Al menos **10 GB de espacio en disco**

### Verificar Instalación

```bash
# Verificar Docker
docker --version

# Verificar Docker Compose
docker compose version

# Verificar que Docker está ejecutándose
docker ps
```

## 🚀 Instalación

### 1. Clonar el Repositorio

```bash
git clone https://github.com/pabloozamora/uvg-dss-proyecto2.git
cd uvg-dss-proyecto2
```

### 2. Navegar al Directorio de Configuración

```bash
cd src
```

### 3. Levantar los Servicios

```bash
# Iniciar todos los contenedores en segundo plano
docker compose up -d

# Ver el estado de los contenedores
docker compose ps
```

### 4. Esperar a que los Servicios Estén Listos

Los servicios pueden tardar 2-3 minutos en estar completamente operativos. Puedes monitorear los logs:

```bash
# Ver logs de todos los servicios
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f elasticsearch
docker compose logs -f kibana
docker compose logs -f filebeat
```

## ⚙️ Configuración

### Credenciales por Defecto

- **Elasticsearch**:
  - Usuario: `elastic`
  - Contraseña: `changeme`
  - URL: `http://localhost:9200`

- **Kibana**:
  - URL: `http://localhost:5601`
  - Usuario: `elastic`
  - Contraseña: `changeme`

### Configuración de Filebeat

El archivo `filebeat.yml` está preconfigurado para:
- Recolectar logs de contenedores Docker
- Recolectar logs de acceso de Nginx
- Enviar datos a Elasticsearch
- Añadir metadata de contenedores

### Configuración de Kibana

El archivo `kibana.yml` contiene:
- Conexión a Elasticsearch
- Credenciales de acceso
- Configuración de interfaz

## 🎮 Uso

### Acceder a las Aplicaciones

1. **Juice Shop** (Aplicación Vulnerable):
   - Directo: http://localhost:3000
   - A través del proxy: http://localhost:8080

2. **Kibana** (Visualización de Logs):
   - URL: http://localhost:5601
   - Usuario: `elastic`
   - Contraseña: `changeme`

3. **Elasticsearch** (API de Búsqueda):
   - URL: http://localhost:9200
   - Requiere autenticación básica

### Configurar Data Views en Kibana

1. Accede a Kibana: http://localhost:5601
2. Ve a **Management** → **Stack Management** → **Data Views**
3. Crea un nuevo Data View:
   - **Name**: `Logs de Juice Shop`
   - **Index pattern**: `filebeat-*`
   - **Timestamp field**: `@timestamp`
4. Haz clic en **Save Data View**

### Generar Tráfico de Prueba

Para generar logs y poder visualizarlos:

```bash
# Generar múltiples peticiones HTTP
for i in {1..20}; do 
  curl -s http://localhost:3000 > /dev/null
  echo "Request $i"
  sleep 1
done
```

### Explorar Logs en Kibana

1. Ve a **Discover** en Kibana
2. Selecciona el Data View `filebeat-*`
3. Ajusta el rango de tiempo en la esquina superior derecha
4. Explora los logs recolectados

### Buscar Logs con KQL (Kibana Query Language)

```kql
# Logs solo de Juice Shop
container.name: "juice-shop"

# Mensajes que contienen 'error'
message: *error*

# Códigos de estado HTTP 4xx o 5xx
http.response.status_code >= 400

# Logs de múltiples contenedores
container.name: ("juice-shop" OR "juice-proxy")
```

## ✅ Verificación

### Verificar que Elasticsearch está Funcionando

```bash
# Verificar salud del cluster
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# Verificar información del nodo
curl -u elastic:changeme http://localhost:9200

# Listar índices creados
curl -u elastic:changeme http://localhost:9200/_cat/indices?v
```

**Respuesta esperada**: Estado del cluster debe ser "yellow" o "green"

### Verificar que Kibana está Funcionando

```bash
# Verificar estado de Kibana
curl http://localhost:5601/api/status | jq .status.overall.state
```

**Respuesta esperada**: `"green"`

### Verificar que Filebeat está Enviando Logs

```bash
# Ver logs de Filebeat
docker compose logs filebeat | grep -i "connection"

# Verificar índices de Filebeat en Elasticsearch
curl -u elastic:changeme "http://localhost:9200/_cat/indices?v" | grep filebeat

# Ver un documento de ejemplo
curl -u elastic:changeme "http://localhost:9200/filebeat-*/_search?size=1&pretty"
```

**Respuesta esperada**: Deberías ver índices con el patrón `filebeat-*`

### Verificar que Juice Shop está Funcionando

```bash
# Hacer petición a Juice Shop
curl http://localhost:3000

# Verificar logs del contenedor
docker compose logs juice-shop --tail 50
```

### Verificar Todos los Contenedores

```bash
# Ver estado de todos los contenedores
docker compose ps

# Verificar que todos estén "healthy" o "running"
docker ps --format "table {{.Names}}\t{{.Status}}"
```

**Respuesta esperada**: Todos los contenedores deben estar "Up" y los que tienen healthcheck deben mostrar "(healthy)"

## 🔧 Solución de Problemas

### Problema: Elasticsearch no arranca

**Síntoma**: El contenedor se reinicia constantemente

**Solución**:
```bash
# Verificar logs de Elasticsearch
docker compose logs elasticsearch

# Puede ser falta de memoria, ajusta en docker-compose.yml:
# ES_JAVA_OPTS=-Xms512m -Xmx512m

# Reiniciar el servicio
docker compose restart elasticsearch
```

### Problema: Kibana no se conecta a Elasticsearch

**Síntoma**: Error "Kibana server is not ready yet"

**Solución**:
```bash
# Esperar a que Elasticsearch esté completamente inicializado
docker compose logs elasticsearch | grep "started"

# Reiniciar Kibana después de que Elasticsearch esté listo
docker compose restart kibana

# Verificar logs de Kibana
docker compose logs kibana
```

### Problema: No se ven logs en Kibana

**Síntoma**: Discover muestra 0 documentos

**Soluciones**:
1. Verifica que el rango de tiempo sea correcto (últimas 24 horas)
2. Genera tráfico hacia Juice Shop para crear logs
3. Verifica que Filebeat esté enviando datos:
   ```bash
   docker compose logs filebeat | grep -i "events"
   ```
4. Verifica que existan índices de Filebeat:
   ```bash
   curl -u elastic:changeme "http://localhost:9200/_cat/indices?v"
   ```

### Problema: Puerto ya en uso

**Síntoma**: Error "port is already allocated"

**Solución**:
```bash
# Identificar qué proceso usa el puerto (ejemplo: 9200)
sudo lsof -i :9200

# O con netstat
netstat -tuln | grep 9200

# Detener el proceso conflictivo o cambiar el puerto en docker-compose.yml
```

### Problema: Contenedores sin espacio en disco

**Síntoma**: Error "no space left on device"

**Solución**:
```bash
# Limpiar imágenes no usadas
docker system prune -a

# Limpiar volúmenes no usados
docker volume prune

# Ver uso de espacio
docker system df
```

### Reiniciar Todo el Sistema

Si nada funciona, reinicia completamente:

```bash
# Detener todos los contenedores
docker compose down

# Eliminar volúmenes (CUIDADO: borra todos los datos)
docker compose down -v

# Volver a levantar
docker compose up -d

# Esperar 2-3 minutos
sleep 180

# Verificar estado
docker compose ps
```

## 📚 Comandos Útiles

### Gestión de Contenedores

```bash
# Iniciar servicios
docker compose up -d

# Detener servicios
docker compose down

# Reiniciar un servicio específico
docker compose restart <servicio>

# Ver logs en tiempo real
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f elasticsearch

# Ejecutar comando dentro de un contenedor
docker compose exec elasticsearch bash
```

### Consultas a Elasticsearch

```bash
# Salud del cluster
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# Listar todos los índices
curl -u elastic:changeme http://localhost:9200/_cat/indices?v

# Contar documentos en un índice
curl -u elastic:changeme http://localhost:9200/filebeat-*/_count?pretty

# Buscar documentos
curl -u elastic:changeme -X GET "http://localhost:9200/filebeat-*/_search?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "match": {
      "container.name": "juice-shop"
    }
  },
  "size": 10
}'

# Eliminar un índice (¡CUIDADO!)
curl -u elastic:changeme -X DELETE "http://localhost:9200/filebeat-2025.11.25"
```

### Generar Tráfico de Prueba

```bash
# Generar peticiones simples
for i in {1..50}; do curl -s http://localhost:3000 > /dev/null; done

# Generar peticiones con diferentes rutas
curl http://localhost:3000/
curl http://localhost:3000/#/search?q=apple
curl http://localhost:3000/#/login
curl http://localhost:3000/#/basket

# Simular SQL Injection (para testing)
curl "http://localhost:3000/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'\'' OR 1=1--","password":"test"}'

# Simular XSS (para testing)
curl "http://localhost:3000/rest/products/search?q=<script>alert('xss')</script>"
```

### Backup y Restauración

```bash
# Hacer backup de los datos de Elasticsearch
docker run --rm -v uvg-dss-proyecto2_elasticsearch-data:/data -v $(pwd):/backup alpine tar czf /backup/elasticsearch-backup.tar.gz -C /data .

# Restaurar backup
docker run --rm -v uvg-dss-proyecto2_elasticsearch-data:/data -v $(pwd):/backup alpine tar xzf /backup/elasticsearch-backup.tar.gz -C /data
```

## 🎓 Próximos Pasos

Una vez que tengas el sistema funcionando:

1. **Explorar Kibana**: Familiarízate con Discover, Visualize y Dashboard
2. **Crear Visualizaciones**: Crea gráficos de logs por contenedor, códigos HTTP, etc.
3. **Configurar Alertas**: Define reglas de detección para SQL Injection, XSS, etc.
4. **Pruebas de Seguridad**: Usa la colección de Postman incluida para probar vulnerabilidades
5. **Documentar Hallazgos**: Usa REPORTE.md como plantilla para documentar tus pruebas

## 📖 Recursos Adicionales

- [Documentación oficial de Elasticsearch](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Documentación oficial de Kibana](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Documentación oficial de Filebeat](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
- [Kibana Query Language (KQL)](https://www.elastic.co/guide/en/kibana/current/kuery-query.html)

## 👥 Autores

- Pablo Andrés Zamora Vásquez - 21780
- Diego Andrés Morales Aquino - 21762
- Erick Stiv Junior Guerra - 21781

## 📝 Licencia

Este proyecto es para fines educativos como parte del curso de Desarrollo Seguro de Software.

---

**Nota**: Este sistema está diseñado para entornos de desarrollo y aprendizaje. No utilizar en producción sin ajustes de seguridad apropiados.
