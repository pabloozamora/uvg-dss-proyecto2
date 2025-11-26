# Módulo de Nginx para Logs de Juice Shop

## 📋 Índice

1. [Introducción](#introducción)
2. [Arquitectura General](#arquitectura-general)
3. [Configuración de Nginx](#configuración-de-nginx)
4. [Formato de Logs JSON](#formato-de-logs-json)
5. [Flujo de Datos Completo](#flujo-de-datos-completo)
6. [Integración con ELK Stack](#integración-con-elk-stack)
7. [Ejemplos Prácticos](#ejemplos-prácticos)
8. [Troubleshooting](#troubleshooting)

---

## Introducción

El módulo de Nginx en este proyecto actúa como un **proxy reverso** entre los usuarios y la aplicación Juice Shop. Su función principal es:

1. **Recibir** todas las peticiones HTTP del exterior (puerto 8080)
2. **Reenviar** las peticiones a Juice Shop (puerto 3000)
3. **Registrar** cada petición en un formato JSON estructurado
4. **Proporcionar** logs enriquecidos para análisis de seguridad

Esta arquitectura permite interceptar y registrar todo el tráfico sin modificar la aplicación Juice Shop original.

---

## Arquitectura General

```
┌─────────────┐
│   Usuario   │
└──────┬──────┘
       │ HTTP Request
       │ (port 8080)
       ▼
┌─────────────────────────────────────┐
│         Nginx Proxy                 │
│  ┌──────────────────────────────┐   │
│  │  Custom JSON Log Format      │   │
│  │  (juice_json)                │   │
│  └──────────┬───────────────────┘   │
│             │ Logs escritos a       │
│             │ /var/log/nginx/       │
│             │ juice_access.log      │
└─────────┬───┴─────────────────────┘
          │ Proxied Request
          │ (internal network)
          ▼
    ┌──────────────┐
    │  Juice Shop  │
    │  (port 3000) │
    └──────────────┘
          │
          │ Logs de contenedor
          │ (stdout/stderr)
          ▼
    ┌──────────────┐
    │ Docker Engine│
    └──────┬───────┘
           │ Container logs en
           │ /var/lib/docker/containers/
           ▼
    ┌──────────────┐
    │   Filebeat   │ ← Lee logs de nginx desde volumen compartido
    │              │ ← Lee logs de Docker desde socket
    └──────┬───────┘
           │ Envía eventos
           ▼
    ┌──────────────┐
    │ Elasticsearch│
    └──────┬───────┘
           │ Almacena y indexa
           ▼
    ┌──────────────┐
    │    Kibana    │
    └──────────────┘
```

---

## Configuración de Nginx

### Archivo: `default.conf`

El archivo de configuración se monta en el contenedor de Nginx y define:

#### 1. **Formato de Log Personalizado (juice_json)**

```nginx
log_format juice_json escape=json '{
  "timestamp":"$time_iso8601",
  "remote_addr":"$remote_addr",
  "x_forwarded_for":"$http_x_forwarded_for",
  "request":"$request",
  "request_method":"$request_method",
  "request_uri":"$request_uri",
  "status":$status,
  "body_bytes_sent":$body_bytes_sent,
  "request_time":$request_time,
  "upstream_response_time":"$upstream_response_time",
  "http_referrer":"$http_referer",
  "http_user_agent":"$http_user_agent",
  "http_x_real_ip":"$http_x_real_ip",
  "upstream_addr":"$upstream_addr",
  "host":"$host",
  "server_name":"$server_name"
}';
```

**¿Por qué JSON?**
- **Estructurado**: Cada campo tiene un nombre y tipo definido
- **Parseable**: Filebeat puede leer y procesar JSON automáticamente
- **Queryable**: Elasticsearch indexa cada campo individualmente
- **Extensible**: Fácil agregar nuevos campos sin romper el formato

#### 2. **Bloque Server**

```nginx
server {
  listen 80;
  server_name _;

  # Bloquear acceso de IP específica
  deny 192.168.1.100;

  # Logs JSON para todo el server
  access_log /var/log/nginx/juice_access.log juice_json;
  error_log  /var/log/nginx/juice_error.log warn;

  # Headers CORS
  add_header Access-Control-Allow-Origin "*" always;
  add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
  add_header Access-Control-Allow-Headers "Content-Type, Authorization, X-Requested-With";

  location / {
    proxy_pass http://juice-shop:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }

  location /healthz {
    return 200 "ok\n";
  }
}
```

**Componentes clave:**

- **`listen 80`**: Nginx escucha en el puerto 80 interno del contenedor
- **`access_log`**: Especifica dónde escribir los logs y en qué formato (`juice_json`)
- **`proxy_pass`**: Reenvía todas las peticiones a `juice-shop:3000`
- **`proxy_set_header`**: Preserva información del cliente original (IP, headers)
- **`deny`**: Ejemplo de regla de seguridad (bloqueo de IP)

---

## Formato de Logs JSON

### Campos Capturados

Cada petición HTTP genera un log JSON con los siguientes campos:

| Campo | Variable Nginx | Descripción | Ejemplo |
|-------|---------------|-------------|---------|
| **timestamp** | `$time_iso8601` | Fecha y hora en formato ISO 8601 | `"2025-11-25T10:30:45+00:00"` |
| **remote_addr** | `$remote_addr` | IP del cliente que hizo la petición | `"192.168.1.50"` |
| **x_forwarded_for** | `$http_x_forwarded_for` | IP real si hay proxies intermedios | `"203.0.113.42"` |
| **request** | `$request` | Línea completa de la petición HTTP | `"GET /rest/products/search?q=apple HTTP/1.1"` |
| **request_method** | `$request_method` | Método HTTP usado | `"GET"`, `"POST"`, `"PUT"` |
| **request_uri** | `$request_uri` | URI solicitada (path + query string) | `"/rest/products/search?q=apple"` |
| **status** | `$status` | Código de estado HTTP | `200`, `404`, `500` |
| **body_bytes_sent** | `$body_bytes_sent` | Tamaño de la respuesta en bytes | `1234` |
| **request_time** | `$request_time` | Tiempo total de procesamiento (segundos) | `0.125` |
| **upstream_response_time** | `$upstream_response_time` | Tiempo que tardó Juice Shop en responder | `0.112` |
| **http_referrer** | `$http_referer` | URL de donde vino el usuario | `"http://localhost:8080/"` |
| **http_user_agent** | `$http_user_agent` | Navegador o herramienta usada | `"Mozilla/5.0..."`, `"curl/7.68.0"` |
| **http_x_real_ip** | `$http_x_real_ip` | Header personalizado X-Real-IP | `"10.0.0.5"` |
| **upstream_addr** | `$upstream_addr` | Dirección del backend (Juice Shop) | `"juice-shop:3000"` |
| **host** | `$host` | Header Host de la petición | `"localhost:8080"` |
| **server_name** | `$server_name` | Nombre del servidor virtual | `"_"` |

### Ejemplo de Log Real

```json
{
  "timestamp": "2025-11-25T10:30:45+00:00",
  "remote_addr": "172.18.0.1",
  "x_forwarded_for": "",
  "request": "GET /rest/products/search?q=apple HTTP/1.1",
  "request_method": "GET",
  "request_uri": "/rest/products/search?q=apple",
  "status": 200,
  "body_bytes_sent": 2456,
  "request_time": 0.125,
  "upstream_response_time": "0.112",
  "http_referrer": "http://localhost:8080/",
  "http_user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
  "http_x_real_ip": "172.18.0.1",
  "upstream_addr": "172.18.0.3:3000",
  "host": "localhost:8080",
  "server_name": "_"
}
```

---

## Flujo de Datos Completo

### Paso a Paso: ¿Cómo llegan los logs a Kibana?

#### **Paso 1: Usuario hace petición**

```bash
curl http://localhost:8080/rest/products/search?q=apple
```

#### **Paso 2: Nginx recibe y procesa**

1. Nginx recibe la petición en el puerto 80 (mapeado a 8080 en el host)
2. Verifica reglas de seguridad (deny, allow)
3. Aplica headers CORS
4. Reenvía la petición a `juice-shop:3000` vía `proxy_pass`

#### **Paso 3: Juice Shop responde**

1. Juice Shop procesa la petición
2. Devuelve respuesta HTTP a Nginx
3. Juice Shop escribe sus propios logs a stdout/stderr

#### **Paso 4: Nginx registra la transacción**

Nginx escribe un log JSON en `/var/log/nginx/juice_access.log` usando el formato `juice_json`:

```json
{"timestamp":"2025-11-25T10:30:45+00:00","remote_addr":"172.18.0.1",...}
```

Este archivo está en un **volumen compartido** llamado `proxy-logs`.

#### **Paso 5: Docker captura logs de contenedor**

Docker Engine captura stdout/stderr de todos los contenedores y los almacena en:
```
/var/lib/docker/containers/<container-id>/<container-id>-json.log
```

#### **Paso 6: Filebeat lee logs**

Filebeat tiene **dos inputs** configurados:

**Input 1: Logs de contenedores Docker**
```yaml
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  processors:
    - add_docker_metadata:
```

Lee logs de Juice Shop, Elasticsearch, Kibana, etc.

**Input 2: Logs de nginx (access logs)**
```yaml
- type: log
  paths:
    - '/var/log/nginx/juice_access.log'
  json.keys_under_root: true
  fields:
    service.name: "nginx-proxy"
```

Lee el archivo `juice_access.log` del volumen compartido.

#### **Paso 7: Filebeat procesa y enriquece**

Para cada log leído:

1. **Decodifica JSON** (si aplica)
2. **Agrega metadata**:
   - `container.name`: `"juice-shop"` o `"nginx-proxy"`
   - `container.image.name`: `"bkimminich/juice-shop"`
   - `host.hostname`: nombre del host Docker
   - `service.name`: `"nginx-proxy"` (para logs de nginx)
3. **Normaliza timestamps**
4. **Agrupa eventos** en lotes

#### **Paso 8: Filebeat envía a Elasticsearch**

Filebeat envía eventos a Elasticsearch vía HTTP:

```
POST http://elasticsearch:9200/_bulk
```

Los logs se indexan en diferentes índices según reglas:

```yaml
indices:
  # Logs de nginx access
  - index: "filebeat-nginx-access-%{+yyyy.MM.dd}"
    when.equals:
      service.name: "nginx-proxy"
  
  # Logs de Juice Shop
  - index: "filebeat-juice-shop-%{+yyyy.MM.dd}"
    when.contains:
      container.name: "juice-shop"
  
  # Otros logs
  - index: "filebeat-docker-%{+yyyy.MM.dd}"
```

**Resultado:**
- Logs de nginx → `filebeat-nginx-access-2025.11.25`
- Logs de Juice Shop → `filebeat-juice-shop-2025.11.25`

#### **Paso 9: Elasticsearch indexa y almacena**

Elasticsearch:
1. Recibe el documento JSON
2. Analiza cada campo (string, number, date)
3. Crea índices invertidos para búsqueda rápida
4. Almacena en disco

#### **Paso 10: Kibana visualiza**

1. Usuario abre Kibana (`http://localhost:5601`)
2. Crea Data View: `filebeat-nginx-access-*`
3. Usa **Discover** para buscar logs
4. Crea **visualizaciones** y **dashboards**
5. Configura **reglas de detección** de seguridad

---

## Integración con ELK Stack

### ¿Por qué usar Nginx como proxy?

#### **Ventajas:**

1. **Punto centralizado de logging**
   - Un solo lugar para capturar **todo** el tráfico HTTP
   - No depende de logs internos de Juice Shop

2. **Información de red enriquecida**
   - IP del cliente (`remote_addr`)
   - Tiempos de respuesta (`request_time`, `upstream_response_time`)
   - Códigos de estado HTTP (`status`)
   - User-Agent (útil para detectar scanners)

3. **Seguridad**
   - Permite aplicar reglas de firewall (deny/allow)
   - Headers de seguridad (CSP, CORS)
   - Rate limiting (no implementado aquí, pero posible)

4. **Separación de responsabilidades**
   - Juice Shop solo se preocupa de la lógica de negocio
   - Nginx maneja logging, proxy, seguridad

### Configuración en Docker Compose

```yaml
juice-proxy:
  image: nginx:1.25
  container_name: juice-proxy
  depends_on:
    juice-shop:
      condition: service_started
  ports:
    - "8080:80"  # Expone Nginx al host
  volumes:
    # Configuración de Nginx
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    # Volumen compartido para logs (Filebeat también lo monta)
    - proxy-logs:/var/log/nginx
  networks:
    - elk-network
```

```yaml
filebeat:
  volumes:
    # Monta el mismo volumen de logs de nginx
    - proxy-logs:/var/log/nginx:ro
    # Monta socket de Docker para metadata
    - /var/run/docker.sock:/var/run/docker.sock:ro
    # Monta logs de contenedores
    - /var/lib/docker/containers:/var/lib/docker/containers:ro
```

**Volumen compartido `proxy-logs`:**
- Nginx escribe logs en `/var/log/nginx/juice_access.log`
- Filebeat lee desde `/var/log/nginx/juice_access.log`
- Ambos acceden al **mismo archivo** gracias al volumen

---

## Ejemplos Prácticos

### Ejemplo 1: Detectar SQL Injection

**Petición maliciosa:**
```bash
curl "http://localhost:8080/rest/user/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"'\'' OR 1=1--","password":"x"}'
```

**Log generado por Nginx:**
```json
{
  "timestamp": "2025-11-25T15:30:00+00:00",
  "remote_addr": "172.18.0.1",
  "request_method": "POST",
  "request_uri": "/rest/user/login",
  "status": 200,
  "http_user_agent": "curl/7.68.0"
}
```

**En Elasticsearch:**
```json
{
  "@timestamp": "2025-11-25T15:30:00.000Z",
  "service.name": "nginx-proxy",
  "request_uri": "/rest/user/login",
  "status": 200,
  "log_type": "access",
  "container.name": "juice-proxy"
}
```

**Regla de detección en Kibana:**
```kql
request_uri: "/rest/user/login" and status: 200
```

Agrupa por `remote_addr` y dispara alerta si hay más de 5 intentos en 2 minutos.

---

### Ejemplo 2: Detectar XSS

**Petición maliciosa:**
```bash
curl "http://localhost:8080/rest/products/search?q=<script>alert('XSS')</script>"
```

**Log generado:**
```json
{
  "request_uri": "/rest/products/search?q=<script>alert('XSS')</script>",
  "status": 500,
  "request_method": "GET"
}
```

**Regla KQL:**
```kql
request_uri: (*<script>* or *alert(* or *onerror* or *javascript:*)
```

---

### Ejemplo 3: Detectar Scanner (sqlmap, nmap, Burp)

**Petición de scanner:**
```bash
curl -A "sqlmap/1.7.2" "http://localhost:8080/rest/products/search?q=test"
```

**Log generado:**
```json
{
  "http_user_agent": "sqlmap/1.7.2",
  "request_uri": "/rest/products/search?q=test"
}
```

**Regla KQL:**
```kql
http_user_agent: (*sqlmap* or *nmap* or *burp* or *nikto* or *ZAP*)
```

---

## Troubleshooting

### Problema 1: No aparecen logs de nginx en Kibana

**Diagnóstico:**

```bash
# 1. Verificar que nginx está escribiendo logs
docker exec juice-proxy ls -lh /var/log/nginx/
docker exec juice-proxy tail -f /var/log/nginx/juice_access.log

# 2. Verificar que Filebeat puede leer el volumen
docker exec filebeat ls -lh /var/log/nginx/
docker exec filebeat cat /var/log/nginx/juice_access.log

# 3. Ver logs de Filebeat
docker logs filebeat | grep -i nginx
docker logs filebeat | grep -i error
```

**Posibles causas:**
- Volumen no montado correctamente
- Permisos de lectura en el archivo
- Filebeat no está configurado para leer ese path
- Elasticsearch rechaza los logs (revisar `docker logs filebeat`)

---

### Problema 2: Logs aparecen pero sin campos estructurados

**Diagnóstico:**

```bash
# Ver un documento en Elasticsearch
curl -u elastic:changeme "http://localhost:9200/filebeat-nginx-access-*/_search?size=1&pretty"
```

**Si `request_uri` no aparece como campo separado:**

Revisar la configuración de Filebeat:

```yaml
- type: log
  paths:
    - '/var/log/nginx/juice_access.log'
  json.keys_under_root: true  # ← Debe estar en true
  json.add_error_key: true
```

---

### Problema 3: Logs duplicados

**Causa:**
Filebeat puede estar leyendo el mismo log desde dos fuentes:
1. Volumen de nginx (`/var/log/nginx/juice_access.log`)
2. Logs de contenedor Docker (`/var/lib/docker/containers/...`)

**Solución:**
Asegurarse de que los inputs estén bien separados:

```yaml
# Input para logs de nginx (solo access logs)
- type: log
  paths:
    - '/var/log/nginx/juice_access.log'
  
# Input para logs de contenedores (excluye nginx-proxy)
- type: container
  paths:
    - '/var/lib/docker/containers/*/*.log'
  exclude_files:
    - '.*nginx.*'  # Opcional: excluir nginx de container logs
```

---

### Problema 4: Nginx no está haciendo proxy correctamente

**Diagnóstico:**

```bash
# Probar acceso directo a Juice Shop (sin proxy)
curl http://localhost:3000

# Probar acceso vía proxy
curl http://localhost:8080

# Ver logs de error de nginx
docker logs juice-proxy
```

**Posibles causas:**
- Juice Shop no está corriendo (`docker ps`)
- Problema de red entre contenedores
- Configuración incorrecta en `proxy_pass`

**Verificar conectividad interna:**
```bash
docker exec juice-proxy ping juice-shop
docker exec juice-proxy curl http://juice-shop:3000
```

---

## Resumen

### ¿Qué hace el módulo de Nginx?

1. **Actúa como proxy reverso** entre usuarios y Juice Shop
2. **Registra cada petición** en formato JSON estructurado
3. **Enriquece logs** con metadata de red (IP, tiempos, user-agent)
4. **Escribe logs** en un volumen compartido con Filebeat
5. **Permite detección de amenazas** al exponer tráfico HTTP completo

### Ventajas del diseño

✅ **Centralizado**: Un solo punto de registro de tráfico  
✅ **Estructurado**: Formato JSON parseable automáticamente  
✅ **Enriquecido**: Campos de seguridad (IP, User-Agent, códigos HTTP)  
✅ **Escalable**: Fácil agregar más campos o reglas  
✅ **Integrado**: Funciona nativamente con ELK Stack  

### Casos de uso

- **Blue Team**: Detección de ataques (SQLi, XSS, brute force, scanners)
- **Observabilidad**: Análisis de rendimiento (`request_time`, `upstream_response_time`)
- **Auditoría**: Registro completo de actividad de usuarios
- **Forensics**: Reconstrucción de incidentes de seguridad

---

## Referencias

- [Documentación oficial de Nginx](https://nginx.org/en/docs/)
- [Nginx log_format module](https://nginx.org/en/docs/http/ngx_http_log_module.html#log_format)
- [Variables de Nginx](https://nginx.org/en/docs/varindex.html)
- [Filebeat documentation](https://www.elastic.co/guide/en/beats/filebeat/current/index.html)
- [Elasticsearch index lifecycle](https://www.elastic.co/guide/en/elasticsearch/reference/current/index-lifecycle-management.html)
