# Explicación: Módulo de Nginx para Logs de Juice Shop

## Resumen Ejecutivo

El módulo de Nginx en este proyecto funciona como un **proxy reverso** que intercepta y registra todo el tráfico HTTP hacia Juice Shop. Su función es capturar información detallada de cada petición en formato JSON estructurado, facilitando el análisis de seguridad y la detección de amenazas.

---

## ¿Cómo Funciona?

### Arquitectura de 3 Capas

```
┌─────────────────────────────────────────────────────────────┐
│                         CAPA 1: ENTRADA                     │
│                                                             │
│  Usuario → http://localhost:8080 → Nginx Proxy (puerto 80) │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    CAPA 2: PROCESAMIENTO                    │
│                                                             │
│  1. Nginx recibe petición HTTP                              │
│  2. Aplica reglas de seguridad (deny, CORS)                 │
│  3. Registra en formato JSON → /var/log/nginx/              │
│  4. Reenvía a Juice Shop → http://juice-shop:3000          │
│  5. Recibe respuesta de Juice Shop                          │
│  6. Completa el log con código de estado y tiempos         │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      CAPA 3: RECOLECCIÓN                    │
│                                                             │
│  Filebeat → Lee logs desde volumen compartido               │
│          → Enriquece con metadata                           │
│          → Envía a Elasticsearch                            │
│          → Kibana visualiza y alerta                        │
└─────────────────────────────────────────────────────────────┘
```

---

## Componentes Clave

### 1. Formato de Log JSON Personalizado

Nginx está configurado con un formato de log llamado `juice_json` que captura:

```nginx
log_format juice_json escape=json '{
  "timestamp":"$time_iso8601",           # Cuándo ocurrió
  "remote_addr":"$remote_addr",          # Quién hizo la petición (IP)
  "request_method":"$request_method",     # GET, POST, PUT, DELETE
  "request_uri":"$request_uri",          # Qué se solicitó (/rest/user/login)
  "status":$status,                      # Código de respuesta (200, 404, 500)
  "request_time":$request_time,          # Cuánto tardó (segundos)
  "http_user_agent":"$http_user_agent"   # Navegador o herramienta (curl, sqlmap)
  # ... más campos
}';
```

**Ejemplo de log generado:**
```json
{
  "timestamp": "2025-11-25T10:30:45+00:00",
  "remote_addr": "172.18.0.1",
  "request_method": "POST",
  "request_uri": "/rest/user/login",
  "status": 401,
  "request_time": 0.125,
  "http_user_agent": "Mozilla/5.0..."
}
```

### 2. Configuración del Proxy

```nginx
server {
  listen 80;
  
  # Usa el formato JSON para logs de acceso
  access_log /var/log/nginx/juice_access.log juice_json;
  
  # Reenvía todo el tráfico a Juice Shop
  location / {
    proxy_pass http://juice-shop:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }
}
```

### 3. Volumen Compartido

Docker Compose monta un volumen compartido entre Nginx y Filebeat:

```yaml
# En docker-compose.yml
juice-proxy:
  volumes:
    - proxy-logs:/var/log/nginx  # Nginx escribe aquí

filebeat:
  volumes:
    - proxy-logs:/var/log/nginx:ro  # Filebeat lee desde aquí (read-only)
```

Esto permite que Filebeat acceda a los logs en tiempo real sin necesidad de APIs o configuraciones complejas.

---

## Flujo Completo de un Request

### Ejemplo: Usuario busca productos

```bash
curl "http://localhost:8080/rest/products/search?q=apple"
```

#### **Paso 1: Nginx recibe** (Entrada)
- Puerto 8080 del host → puerto 80 del contenedor nginx
- IP del cliente: `172.18.0.1`

#### **Paso 2: Nginx registra** (Pre-procesamiento)
- Crea un objeto JSON con timestamp, IP, método, URI
- Aún no tiene código de estado (falta respuesta)

#### **Paso 3: Nginx reenvía** (Proxy)
- Envía `GET /rest/products/search?q=apple` a `juice-shop:3000`
- Preserva headers originales (User-Agent, IP real)

#### **Paso 4: Juice Shop responde** (Backend)
- Procesa búsqueda
- Devuelve JSON con productos
- Código HTTP 200

#### **Paso 5: Nginx completa el log** (Post-procesamiento)
- Agrega `"status": 200`
- Calcula `request_time` (ej: 0.125 segundos)
- Escribe log completo a `/var/log/nginx/juice_access.log`

#### **Paso 6: Filebeat recolecta** (Shipping)
- Lee la nueva línea del archivo
- Parsea el JSON
- Agrega metadata: `service.name: "nginx-proxy"`
- Envía a Elasticsearch en índice `filebeat-nginx-access-2025.11.25`

#### **Paso 7: Elasticsearch indexa** (Storage)
- Almacena el documento
- Crea índices invertidos para búsqueda rápida
- Cada campo es consultable independientemente

#### **Paso 8: Kibana visualiza** (Análisis)
- Analista abre Discover
- Busca: `request_uri: *search* and status: 200`
- Ve el evento en tiempo real

---

## ¿Por Qué es Útil para Seguridad?

### Detección de Ataques

El formato JSON con campos estructurados permite crear reglas de detección:

#### **1. SQL Injection**
```kql
request_uri: (*OR* or *UNION* or *SELECT* or *--* or *1=1*)
```

**Ejemplo de ataque detectado:**
```json
{
  "request_uri": "/rest/user/login?email=' OR 1=1--",
  "status": 200  # ← Exitoso = probable vulnerabilidad
}
```

#### **2. XSS (Cross-Site Scripting)**
```kql
request_uri: (*<script>* or *alert(* or *onerror*)
```

**Ejemplo:**
```json
{
  "request_uri": "/rest/products/search?q=<script>alert('XSS')</script>",
  "status": 500
}
```

#### **3. Brute Force**
```kql
request_uri: "/rest/user/login" and status: 401
```

Agrupa por `remote_addr` y cuenta:
- Si una IP tiene >10 intentos fallidos en 5 minutos → alerta

**Ejemplo:**
```json
{"remote_addr": "192.168.1.50", "request_uri": "/rest/user/login", "status": 401}
{"remote_addr": "192.168.1.50", "request_uri": "/rest/user/login", "status": 401}
{"remote_addr": "192.168.1.50", "request_uri": "/rest/user/login", "status": 401}
...
```

#### **4. Security Scanners**
```kql
http_user_agent: (*sqlmap* or *nmap* or *burp* or *nikto* or *ZAP*)
```

**Ejemplo:**
```json
{
  "http_user_agent": "sqlmap/1.7.2",
  "request_uri": "/rest/products/search?q=test"
}
```

---

## Ventajas del Diseño

### 🎯 **Centralización**
- Un solo punto captura **todo** el tráfico HTTP
- No depende de logs internos de Juice Shop
- Funciona aunque la aplicación falle

### 📊 **Datos Estructurados**
- JSON → fácil de parsear automáticamente
- Cada campo indexado independientemente en Elasticsearch
- Búsquedas rápidas y eficientes

### 🔍 **Visibilidad Completa**
- IP del atacante (`remote_addr`)
- Herramienta usada (`http_user_agent`)
- Payload exacto (`request_uri`)
- Resultado del ataque (`status`)
- Tiempo de respuesta (`request_time`)

### 🛡️ **Seguridad por Capas**
- Nginx puede bloquear IPs (`deny 192.168.1.100`)
- Rate limiting (no implementado, pero posible)
- Headers de seguridad (CORS)
- Todo sin tocar código de Juice Shop

### ⚡ **Tiempo Real**
- Logs escritos inmediatamente
- Filebeat lee cambios en segundos
- Alertas disparan en <1 minuto

---

## Comparación: Con vs Sin Nginx

### ❌ **Sin Nginx (acceso directo a Juice Shop)**

```
Usuario → Juice Shop (puerto 3000)
```

**Desventajas:**
- Solo tienes logs internos de Juice Shop (limitados)
- No capturas IP del cliente directamente
- No tienes códigos de estado HTTP estructurados
- Difícil agregar seguridad sin modificar código
- User-Agent puede no registrarse

### ✅ **Con Nginx como proxy**

```
Usuario → Nginx → Juice Shop
```

**Ventajas:**
- Logs completos en formato JSON
- Información de red enriquecida
- Punto centralizado para seguridad
- Fácil integración con ELK
- No modificas la aplicación original

---

## Configuración Técnica

### Archivo: `nginx/default.conf`

```nginx
# 1. Definir formato JSON
log_format juice_json escape=json '{...}';

# 2. Configurar server
server {
  listen 80;
  
  # 3. Aplicar formato a access log
  access_log /var/log/nginx/juice_access.log juice_json;
  
  # 4. Configurar proxy
  location / {
    proxy_pass http://juice-shop:3000;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

### Docker Compose

```yaml
services:
  juice-proxy:
    image: nginx:1.25
    ports:
      - "8080:80"  # Expone Nginx al exterior
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
      - proxy-logs:/var/log/nginx  # Volumen compartido
    depends_on:
      - juice-shop
  
  filebeat:
    volumes:
      - proxy-logs:/var/log/nginx:ro  # Lee del mismo volumen
```

### Filebeat Config

```yaml
filebeat.inputs:
  # Leer logs de nginx desde volumen
  - type: log
    paths:
      - '/var/log/nginx/juice_access.log'
    json.keys_under_root: true  # Parsea JSON automáticamente
    fields:
      service.name: "nginx-proxy"

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  indices:
    # Envía logs de nginx a índice específico
    - index: "filebeat-nginx-access-%{+yyyy.MM.dd}"
      when.equals:
        service.name: "nginx-proxy"
```

---

## Verificación del Funcionamiento

### 1. Comprobar que Nginx está escribiendo logs

```bash
# Ver logs en tiempo real
docker exec juice-proxy tail -f /var/log/nginx/juice_access.log

# Hacer una petición de prueba
curl http://localhost:8080/

# Deberías ver aparecer un log JSON
```

### 2. Verificar que Filebeat está leyendo

```bash
# Ver logs de Filebeat
docker logs filebeat | grep -i nginx

# Deberías ver algo como:
# "Harvester started for file: /var/log/nginx/juice_access.log"
```

### 3. Verificar que llegan a Elasticsearch

```bash
# Listar índices
curl -u elastic:changeme "http://localhost:9200/_cat/indices?v" | grep nginx

# Buscar un documento
curl -u elastic:changeme "http://localhost:9200/filebeat-nginx-access-*/_search?size=1&pretty"
```

### 4. Visualizar en Kibana

1. Abrir `http://localhost:5601`
2. Ir a **Discover**
3. Crear Data View: `filebeat-nginx-access-*`
4. Seleccionar campo de tiempo: `@timestamp`
5. Buscar: `service.name: "nginx-proxy"`

---

## Conclusión

El módulo de Nginx es la **pieza clave** que permite:

1. ✅ **Capturar** todo el tráfico HTTP en un formato estructurado
2. ✅ **Enriquecer** logs con metadata de seguridad
3. ✅ **Integrar** seamlessly con ELK Stack
4. ✅ **Detectar** ataques mediante reglas de Kibana
5. ✅ **Auditar** actividad de usuarios para forensics

Sin Nginx, estaríamos limitados a logs internos de Juice Shop, que no proporcionan suficiente contexto para análisis de seguridad efectivo.

---

## Documentación Adicional

Para información más detallada, consulta:

- **[src/nginx/README.md](src/nginx/README.md)** - Documentación técnica completa
- **Variables de Nginx**: https://nginx.org/en/docs/varindex.html
- **Log Format Module**: https://nginx.org/en/docs/http/ngx_http_log_module.html
- **Filebeat Inputs**: https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-log.html

---

**Fecha de creación**: 26 de noviembre de 2025
**Proyecto**: DSS Proyecto 2 - ELK Stack + OWASP Juice Shop
