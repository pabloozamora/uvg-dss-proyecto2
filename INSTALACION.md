# Guía de Instalación y Configuración

Instrucciones detalladas paso a paso para configurar el Sistema de Logging con ELK Stack.

## 📑 Índice

1. [Instalación Automática (Recomendado)](#instalación-automática)
2. [Instalación Manual](#instalación-manual)
3. [Configuración Inicial de Kibana](#configuración-inicial-de-kibana)
4. [Verificación del Sistema](#verificación-del-sistema)
5. [Configuración Avanzada](#configuración-avanzada)

---

## 🤖 Instalación Automática (Recomendado)

La forma más rápida de configurar el sistema es usando el script de instalación automática.

### Paso 1: Ejecutar el Script de Configuración

```bash
# Desde el directorio raíz del proyecto
./setup.sh
```

El script automáticamente:
- ✓ Verifica que Docker esté instalado
- ✓ Verifica que los puertos necesarios estén disponibles
- ✓ Levanta todos los servicios
- ✓ Espera a que estén listos
- ✓ Genera tráfico de prueba (opcional)
- ✓ Muestra las URLs de acceso

### Paso 2: Acceder a Kibana

Una vez completado el script, accede a:
- **URL**: http://localhost:5601
- **Usuario**: `elastic`
- **Contraseña**: `changeme`

⚠️ **NOTA DE SEGURIDAD**: La contraseña por defecto es débil y solo apropiada para entornos de desarrollo/aprendizaje. Si planeas exponer el sistema a la red, cambia las credenciales siguiendo las instrucciones en la sección de [Configuración Avanzada](#configuración-avanzada).

---

## 🔧 Instalación Manual

Si prefieres instalar manualmente o el script automático falla, sigue estos pasos:

### Paso 1: Verificar Requisitos

```bash
# Verificar Docker
docker --version
# Debe mostrar: Docker version 20.10.x o superior

# Verificar Docker Compose
docker compose version
# Debe mostrar: Docker Compose version v2.x.x o superior

# Verificar que Docker está ejecutándose
docker ps
# Debe mostrar la lista de contenedores (puede estar vacía)
```

### Paso 2: Clonar el Repositorio

```bash
# Clonar el proyecto
git clone https://github.com/pabloozamora/uvg-dss-proyecto2.git

# Entrar al directorio
cd uvg-dss-proyecto2
```

### Paso 3: Navegar al Directorio de Configuración

```bash
cd src
```

### Paso 4: Revisar Archivos de Configuración

Verifica que existan los siguientes archivos:

```bash
ls -la
```

Deberías ver:
- `docker-compose.yml` - Configuración de los servicios
- `filebeat.yml` - Configuración de Filebeat
- `kibana.yml` - Configuración de Kibana
- `Dockerfile` - Imagen de Juice Shop
- `nginx/` - Configuración del proxy

### Paso 5: Levantar los Servicios

```bash
# Iniciar todos los contenedores en segundo plano
docker compose up -d
```

**Salida esperada:**
```
[+] Running 6/6
 ✔ Network src_elk-network       Created
 ✔ Volume "src_elasticsearch-data" Created
 ✔ Container elasticsearch       Started
 ✔ Container juice-shop          Started
 ✔ Container kibana              Started
 ✔ Container filebeat            Started
 ✔ Container juice-proxy         Started
```

### Paso 6: Verificar Estado de los Contenedores

```bash
docker compose ps
```

**Estado esperado después de 2-3 minutos:**
```
NAME            STATUS                    PORTS
elasticsearch   Up (healthy)              0.0.0.0:9200->9200/tcp
filebeat        Up                        
juice-proxy     Up                        0.0.0.0:8080->80/tcp
juice-shop      Up                        0.0.0.0:3000->3000/tcp
kibana          Up (healthy)              0.0.0.0:5601->5601/tcp
```

### Paso 7: Ver Logs (Opcional)

Para verificar que todo está funcionando correctamente:

```bash
# Ver logs de todos los servicios
docker compose logs -f

# Ver logs de un servicio específico
docker compose logs -f elasticsearch
docker compose logs -f kibana
docker compose logs -f filebeat
```

Presiona `Ctrl+C` para salir de los logs.

---

## 🎨 Configuración Inicial de Kibana

Una vez que los servicios estén levantados, configura Kibana para visualizar los logs.

### Paso 1: Acceder a Kibana

1. Abre tu navegador web
2. Ve a: http://localhost:5601
3. Espera a que cargue (puede tomar 30-60 segundos)

### Paso 2: Iniciar Sesión

- **Usuario**: `elastic`
- **Contraseña**: `changeme`

### Paso 3: Crear Data View

1. En la página principal de Kibana, busca el menú lateral izquierdo
2. Haz clic en el icono de hamburguesa (☰) si está colapsado
3. Ve a **Management** (Gestión)
4. Haz clic en **Stack Management**
5. En la sección "Kibana", haz clic en **Data Views**
6. Haz clic en el botón **Create data view**

**Configuración del Data View:**
- **Name** (Nombre): `Logs de Juice Shop`
- **Index pattern** (Patrón de índice): `filebeat-*`
- **Timestamp field** (Campo de tiempo): `@timestamp`

7. Haz clic en **Save data view to Kibana**

### Paso 4: Explorar Logs en Discover

1. Ve al menú lateral
2. Haz clic en **Discover**
3. Selecciona el Data View que acabas de crear: `Logs de Juice Shop`
4. Ajusta el rango de tiempo en la esquina superior derecha a **Last 24 hours**

Si no ves logs, genera tráfico (ver siguiente sección).

---

## ✅ Verificación del Sistema

### Generar Tráfico de Prueba

Para que aparezcan logs en Kibana, necesitas generar tráfico HTTP:

```bash
# Generar 20 peticiones HTTP
for i in {1..20}; do 
  curl -s http://localhost:3000 > /dev/null
  echo "Petición $i completada"
  sleep 1
done
```

### Verificar Elasticsearch

```bash
# Verificar que Elasticsearch está funcionando
curl -u elastic:changeme http://localhost:9200

# Verificar salud del cluster
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# Listar índices (deberías ver índices filebeat-*)
curl -u elastic:changeme http://localhost:9200/_cat/indices?v
```

**Salida esperada del cluster health:**
```json
{
  "cluster_name" : "docker-cluster",
  "status" : "yellow",
  "number_of_nodes" : 1,
  ...
}
```

El estado "yellow" es normal en un cluster de un solo nodo.

### Verificar Kibana

```bash
# Verificar estado de Kibana
curl http://localhost:5601/api/status
```

### Verificar Filebeat

```bash
# Ver logs de Filebeat
docker compose logs filebeat | grep -i "connection"

# Verificar que está enviando eventos
docker compose logs filebeat | grep -i "events"
```

**Deberías ver líneas como:**
```
Connection to backoff(elasticsearch(http://elasticsearch:9200)) established
```

### Verificar Juice Shop

```bash
# Hacer petición a Juice Shop
curl http://localhost:3000

# Deberías recibir HTML con el contenido de la página
```

---

## ⚙️ Configuración Avanzada

### Personalizar Credenciales de Elasticsearch

Para cambiar la contraseña por defecto:

1. Edita `src/docker-compose.yml`
2. Busca la línea: `ELASTIC_PASSWORD=changeme`
3. Cámbiala por: `ELASTIC_PASSWORD=tu_nueva_contraseña`
4. Edita `src/kibana.yml`
5. Actualiza la contraseña en: `elasticsearch.password: "tu_nueva_contraseña"`
6. Edita `src/filebeat.yml`
7. Actualiza la contraseña en la sección de output de Elasticsearch
8. Reinicia los servicios:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Ajustar Memoria de Elasticsearch

Si tienes problemas de memoria, ajusta los límites:

1. Edita `src/docker-compose.yml`
2. Busca: `ES_JAVA_OPTS=-Xms1g -Xmx1g`
3. Para sistemas con menos RAM, usa: `ES_JAVA_OPTS=-Xms512m -Xmx512m`
4. Reinicia Elasticsearch:
   ```bash
   docker compose restart elasticsearch
   ```

### Cambiar Puertos

Si los puertos por defecto están en uso:

1. Edita `src/docker-compose.yml`
2. En cada servicio, cambia el mapeo de puertos:
   ```yaml
   ports:
     - "PUERTO_HOST:PUERTO_CONTENEDOR"
   ```
3. Ejemplo para cambiar Kibana del puerto 5601 al 5602:
   ```yaml
   kibana:
     ports:
       - "5602:5601"
   ```
4. Reinicia los servicios:
   ```bash
   docker compose down
   docker compose up -d
   ```

### Habilitar Persistencia de Datos

Los datos ya persisten por defecto usando volúmenes Docker. Para hacer backup:

```bash
# Listar volúmenes
docker volume ls | grep src_

# Ver ubicación del volumen de Elasticsearch
docker volume inspect src_elasticsearch-data

# Hacer backup (ejemplo con tar)
docker run --rm -v src_elasticsearch-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/es-backup-$(date +%Y%m%d).tar.gz -C /data .
```

### Configurar Índices Personalizados en Filebeat

Para cambiar el nombre de los índices:

1. Edita `src/filebeat.yml`
2. Busca la sección `output.elasticsearch`
3. Modifica el campo `index`:
   ```yaml
   output.elasticsearch:
     index: "mi-indice-personalizado-%{+yyyy.MM.dd}"
   ```
4. Reinicia Filebeat:
   ```bash
   docker compose restart filebeat
   ```

### Logs de Nginx (Códigos de Estado HTTP)

Los logs del proxy Nginx incluyen códigos de estado HTTP, útiles para detección:

```bash
# Ver logs de acceso del proxy
docker compose exec juice-proxy cat /var/log/nginx/access.log

# Filtrar solo errores 4xx y 5xx
docker compose exec juice-proxy grep -E "HTTP/[0-9.]\" [45][0-9]{2}" /var/log/nginx/access.log
```

---

## 🐛 Solución de Problemas Comunes

### Error: "port is already allocated"

**Causa**: Otro servicio está usando el puerto.

**Solución**:
```bash
# Ver qué proceso usa el puerto
sudo lsof -i :9200
# O con netstat
sudo netstat -tuln | grep 9200

# Opción 1: Detener el proceso conflictivo
# Opción 2: Cambiar el puerto en docker-compose.yml
```

### Error: "no space left on device"

**Causa**: Docker se quedó sin espacio en disco.

**Solución**:
```bash
# Ver uso de espacio
docker system df

# Limpiar imágenes no usadas
docker system prune -a

# Limpiar volúmenes no usados (¡CUIDADO!)
docker volume prune
```

### Elasticsearch no arranca (CrashLoopBackOff)

**Causa**: Falta de memoria o configuración incorrecta.

**Solución**:
```bash
# Ver logs de error
docker compose logs elasticsearch

# Reducir uso de memoria en docker-compose.yml:
# ES_JAVA_OPTS=-Xms512m -Xmx512m

# Reiniciar
docker compose restart elasticsearch
```

### No se ven logs en Kibana

**Causas y soluciones**:

1. **Rango de tiempo incorrecto**:
   - En Kibana, cambia el rango a "Last 24 hours" o "Last 7 days"

2. **No hay tráfico generado**:
   ```bash
   # Generar tráfico
   for i in {1..50}; do curl -s http://localhost:3000 > /dev/null; done
   ```

3. **Filebeat no está enviando datos**:
   ```bash
   # Verificar logs de Filebeat
   docker compose logs filebeat
   
   # Reiniciar Filebeat
   docker compose restart filebeat
   ```

4. **Índices no creados**:
   ```bash
   # Verificar índices en Elasticsearch
   curl -u elastic:changeme http://localhost:9200/_cat/indices?v
   ```

### Kibana muestra "Kibana server is not ready yet"

**Causa**: Kibana aún está iniciando o no puede conectarse a Elasticsearch.

**Solución**:
```bash
# Esperar 2-3 minutos

# Verificar que Elasticsearch esté listo
curl -u elastic:changeme http://localhost:9200/_cluster/health

# Ver logs de Kibana
docker compose logs kibana

# Si persiste, reiniciar
docker compose restart kibana
```

---

## 📞 Soporte

Si encuentras problemas no cubiertos en esta guía:

1. Revisa los logs: `docker compose logs -f`
2. Consulta [README.md](README.md) para más información
3. Verifica el archivo [REPORTE.md](REPORTE.md) para ejemplos de uso

---

## ✨ Resumen de Comandos

```bash
# Iniciar sistema
cd src
docker compose up -d

# Ver estado
docker compose ps

# Ver logs
docker compose logs -f

# Detener sistema
docker compose down

# Detener y eliminar datos
docker compose down -v

# Reiniciar un servicio
docker compose restart <servicio>

# Generar tráfico
for i in {1..20}; do curl -s http://localhost:3000 > /dev/null; done
```

---

**¡Listo!** Ahora tienes el sistema completamente configurado y funcionando. 🎉
