# Guía de Implementación de Respuestas de Seguridad

Este documento explica cómo implementar cada una de las acciones de respuesta a incidentes de seguridad en el sistema ELK Stack con Juice Shop.

## Tabla de Contenidos

1. [Bloqueo de IP en Nginx](#1-bloqueo-de-ip-en-nginx)
2. [Bloqueo Temporal con iptables](#2-bloqueo-temporal-con-iptables)
3. [Aumento de Logging Dinámico](#3-aumento-de-logging-dinámico)
4. [Configuración de Alertas en Kibana](#4-configuración-de-alertas-en-kibana)

---

## 1. Bloqueo de IP en Nginx

### ¿Qué hace?
Bloquea direcciones IP específicas en el proxy reverso Nginx, impidiendo que lleguen solicitudes maliciosas a Juice Shop.

### ¿Cómo implementarlo?

#### Método 1: Bloqueo Manual (Recomendado para testing)

1. **Editar la configuración de Nginx:**
   ```bash
   # Editar el archivo de configuración
   nano /home/runner/work/uvg-dss-proyecto2/uvg-dss-proyecto2/src/nginx/default.conf
   ```

2. **Agregar directivas de bloqueo en el bloque `location /`:**
   ```nginx
   location / {
       # Bloquear IPs específicas
       deny 192.168.1.100;
       deny 10.0.0.50;
       deny 172.16.0.25;
       
       # Permitir todas las demás
       allow all;
       
       # Configuración existente del proxy
       proxy_pass http://juice-shop:3000;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
       
       access_log /var/log/nginx/juice_access.log juice_json;
       error_log  /var/log/nginx/juice_error.log warn;
   }
   ```

3. **Recargar la configuración de Nginx:**
   ```bash
   docker exec juice-proxy nginx -s reload
   ```

4. **Verificar que el bloqueo funciona:**
   ```bash
   # Desde la IP bloqueada, deberías recibir un 403 Forbidden
   curl -I http://localhost:8080/
   ```

#### Método 2: Bloqueo con Lista de IPs (Recomendado para producción)

1. **Crear un archivo de lista de bloqueo:**
   ```bash
   # Crear archivo con IPs bloqueadas
   cat > /home/runner/work/uvg-dss-proyecto2/uvg-dss-proyecto2/src/nginx/blocked_ips.conf << 'EOF'
   # Lista de IPs bloqueadas - actualizar según necesidad
   deny 192.168.1.100;
   deny 10.0.0.50;
   deny 172.16.0.25;
   # Agregar más IPs según sea necesario
   EOF
   ```

2. **Incluir el archivo en default.conf:**
   ```nginx
   location / {
       # Incluir lista de IPs bloqueadas
       include /etc/nginx/conf.d/blocked_ips.conf;
       allow all;
       
       # Resto de la configuración...
   }
   ```

3. **Actualizar docker-compose.yml para montar el archivo:**
   ```yaml
   juice-proxy:
     image: nginx:1.25
     container_name: juice-proxy
     volumes:
       - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
       - ./nginx/blocked_ips.conf:/etc/nginx/conf.d/blocked_ips.conf:ro
       - proxy-logs:/var/log/nginx
   ```

#### Método 3: Bloqueo Automático mediante Script

Ver script `src/scripts/block-ip-nginx.sh` para automatización.

### Ventajas
- ✅ Bloqueo rápido y efectivo
- ✅ Bajo impacto en rendimiento
- ✅ Fácil de implementar y revertir
- ✅ Se registra en logs de Nginx (403 Forbidden)

### Desventajas
- ❌ Solo funciona para tráfico que pasa por Nginx
- ❌ Fácil de eludir con cambio de IP
- ❌ Requiere reinicio/recarga de Nginx

---

## 2. Bloqueo Temporal con iptables/pfctl

### ¿Qué hace?
Bloquea tráfico sospechoso a nivel de firewall del sistema operativo, antes de que llegue a los contenedores Docker.

### ¿Cómo implementarlo?

#### En Linux (iptables)

1. **Bloquear una IP específica:**
   ```bash
   # Bloquear todo el tráfico desde una IP
   sudo iptables -A INPUT -s 192.168.1.100 -j DROP
   
   # Bloquear solo tráfico al puerto 8080 (Nginx proxy)
   sudo iptables -A INPUT -s 192.168.1.100 -p tcp --dport 8080 -j DROP
   
   # Bloquear solo tráfico al puerto 3000 (Juice Shop directo)
   sudo iptables -A INPUT -s 192.168.1.100 -p tcp --dport 3000 -j DROP
   ```

2. **Ver reglas actuales:**
   ```bash
   sudo iptables -L INPUT -n -v --line-numbers
   ```

3. **Eliminar una regla (desbloquear):**
   ```bash
   # Por número de línea
   sudo iptables -D INPUT <número_de_línea>
   
   # Por especificación exacta
   sudo iptables -D INPUT -s 192.168.1.100 -j DROP
   ```

4. **Bloqueo temporal (con expiración automática):**
   ```bash
   # Bloquear por 1 hora usando timeout
   sudo iptables -A INPUT -s 192.168.1.100 -j DROP
   sleep 3600
   sudo iptables -D INPUT -s 192.168.1.100 -j DROP
   ```

#### En macOS (pfctl)

1. **Crear archivo de reglas:**
   ```bash
   cat > /tmp/pf_block.conf << 'EOF'
   # Bloquear IPs maliciosas
   block drop from 192.168.1.100 to any
   block drop from 10.0.0.50 to any
   EOF
   ```

2. **Aplicar reglas:**
   ```bash
   # Cargar reglas
   sudo pfctl -f /tmp/pf_block.conf
   
   # Habilitar pf si no está activo
   sudo pfctl -e
   ```

3. **Ver reglas activas:**
   ```bash
   sudo pfctl -s rules
   ```

4. **Eliminar bloqueo:**
   ```bash
   # Deshabilitar pf
   sudo pfctl -d
   
   # O recargar sin las reglas de bloqueo
   sudo pfctl -f /etc/pf.conf
   ```

#### Script de Bloqueo Automático

Ver script `src/scripts/block-ip-iptables.sh` para automatización en Linux.

### Ventajas
- ✅ Bloqueo a nivel de sistema operativo (más bajo nivel)
- ✅ Funciona para todo el tráfico, no solo HTTP
- ✅ Alto rendimiento (kernel-level filtering)
- ✅ Puede configurarse con timeouts automáticos

### Desventajas
- ❌ Requiere privilegios de superusuario
- ❌ Puede afectar tráfico legítimo si se configura incorrectamente
- ❌ Reglas se pierden al reiniciar (sin persistencia)
- ❌ Diferente implementación según SO

---

## 3. Aumento de Logging Dinámico

### ¿Qué hace?
Incrementa temporalmente el nivel de logging para capturar información detallada de solicitudes de IPs atacantes, incluyendo payloads completos.

### ¿Cómo implementarlo?

#### Método 1: Variables de Entorno (Requiere reinicio)

1. **Modificar docker-compose.yml:**
   ```yaml
   juice-shop:
     build: .
     container_name: juice-shop
     environment:
       - NODE_ENV=production
       - LOG_LEVEL=debug  # Cambiar de 'info' a 'debug'
     restart: unless-stopped
   ```

2. **Reiniciar el contenedor:**
   ```bash
   docker-compose restart juice-shop
   ```

#### Método 2: Logging Condicional en Nginx (Sin reinicio)

1. **Crear formato de log detallado en nginx/default.conf:**
   ```nginx
   # Formato detallado para debugging
   log_format debug_json escape=json '{'
     '"timestamp":"$time_iso8601",'
     '"remote_addr":"$remote_addr",'
     '"x_forwarded_for":"$http_x_forwarded_for",'
     '"request":"$request",'
     '"request_method":"$request_method",'
     '"request_uri":"$request_uri",'
     '"request_body":"$request_body",'
     '"status":$status,'
     '"body_bytes_sent":$body_bytes_sent,'
     '"request_time":$request_time,'
     '"upstream_response_time":"$upstream_response_time",'
     '"http_referrer":"$http_referer",'
     '"http_user_agent":"$http_user_agent",'
     '"http_cookie":"$http_cookie",'
     '"http_authorization":"$http_authorization",'
     '"all_headers":"$http_*",'
     '"upstream_addr":"$upstream_addr",'
     '"host":"$host",'
     '"server_name":"$server_name"'
   '}';
   ```

2. **Logging condicional por IP en location /:**
   ```nginx
   location / {
       # Variable para determinar si es IP atacante
       set $is_attacker 0;
       
       # Marcar IPs atacantes conocidas
       if ($remote_addr = "192.168.1.100") {
           set $is_attacker 1;
       }
       if ($remote_addr = "10.0.0.50") {
           set $is_attacker 1;
       }
       
       # Log normal para tráfico regular
       access_log /var/log/nginx/juice_access.log juice_json;
       
       # Log detallado solo para atacantes
       access_log /var/log/nginx/juice_debug.log debug_json if=$is_attacker;
       
       # Resto de configuración...
   }
   ```

3. **Recargar Nginx:**
   ```bash
   docker exec juice-proxy nginx -s reload
   ```

#### Método 3: Filebeat con Procesamiento Condicional

1. **Modificar filebeat.yml para capturar más campos:**
   ```yaml
   filebeat.inputs:
     - type: log
       enabled: true
       paths:
         - '/var/log/nginx/juice_debug.log'
       json.keys_under_root: true
       json.add_error_key: true
       fields:
         log_level: "debug"
         source: "nginx-debug"
       fields_under_root: true
   ```

2. **Reiniciar Filebeat:**
   ```bash
   docker-compose restart filebeat
   ```

#### Método 4: Script de Activación/Desactivación Dinámica

Ver script `src/scripts/toggle-debug-logging.sh` para automatización.

### Captura de Payloads Completos

Para capturar el body completo de las solicitudes HTTP:

1. **Habilitar lectura de request body en Nginx:**
   ```nginx
   server {
       # Habilitar lectura de request body
       client_body_buffer_size 128k;
       client_max_body_size 10m;
       
       location / {
           # Forzar lectura del body
           proxy_request_buffering on;
           
           # Log con body completo
           access_log /var/log/nginx/juice_full.log debug_json;
           
           # Resto de configuración...
       }
   }
   ```

### Ventajas
- ✅ Información detallada para análisis forense
- ✅ Captura payloads de ataques completos
- ✅ Puede activarse solo para IPs específicas
- ✅ Útil para entender técnicas de ataque

### Desventajas
- ❌ Mayor consumo de disco
- ❌ Impacto en rendimiento si está muy activo
- ❌ Puede exponer información sensible en logs
- ❌ Requiere rotación de logs más frecuente

---

## 4. Configuración de Alertas en Kibana

### ¿Qué hace?
Configura conectores de comunicación (email, Slack, webhook) para enviar alertas automáticas cuando se detectan eventos de seguridad.

### ¿Cómo implementarlo?

#### Paso 1: Acceder a Stack Management

1. Abrir Kibana en `http://localhost:5601`
2. Ir a menú hamburguesa → **Stack Management**
3. En la sección **Alerts and Insights**, seleccionar **Rules and Connectors**

#### Paso 2: Configurar Conectores

##### Conector de Email

1. Ir a **Connectors** → **Create connector**
2. Seleccionar **Email**
3. Configurar:
   ```
   Connector name: Security Alerts Email
   
   From: security-alerts@empresa.com
   Host: smtp.gmail.com
   Port: 587
   Secure: true (TLS)
   
   Authentication:
   - User: tu-email@gmail.com
   - Password: tu-app-password
   ```

4. **Probar el conector:**
   - Click en **Test** → **Send test email**
   - Verificar recepción

##### Conector de Slack

1. **Crear Slack App (primero en Slack):**
   - Ir a https://api.slack.com/apps
   - **Create New App** → **From scratch**
   - Nombre: "Kibana Security Alerts"
   - Seleccionar workspace
   - **Incoming Webhooks** → **Activate**
   - **Add New Webhook to Workspace**
   - Seleccionar canal (ej: #security-alerts)
   - Copiar **Webhook URL**

2. **Configurar en Kibana:**
   - **Create connector** → **Slack**
   - Configurar:
     ```
     Connector name: Security Alerts Slack
     Webhook URL: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX
     ```

3. **Probar:**
   - Click en **Test** → **Send test message**
   - Verificar mensaje en canal de Slack

##### Conector de Webhook (Genérico)

1. **Create connector** → **Webhook**
2. Configurar:
   ```
   Connector name: Security Webhook
   Method: POST
   URL: https://tu-servidor.com/api/security-alerts
   
   Headers:
   - Content-Type: application/json
   - Authorization: Bearer tu-token-secreto
   
   Body (ejemplo):
   {
     "alert": "{{context.message}}",
     "timestamp": "{{date}}",
     "severity": "{{context.severity}}",
     "source": "Kibana ELK Stack"
   }
   ```

3. **Probar:**
   - Click en **Test**
   - Verificar recepción en tu endpoint

#### Paso 3: Crear Reglas de Detección con Alertas

1. **Ir a Security → Rules**
2. **Create new rule** → **Custom query**

##### Ejemplo: Alerta de SQL Injection

```
Rule name: SQL Injection Detection Alert
Description: Detecta intentos de SQL injection y envía alerta

Index patterns: filebeat-*

Custom query:
message:(*"' OR 1=1"* OR *"union select"* OR *"'; DROP TABLE"*)
OR url.original:(*"' OR 1=1"* OR *"union select"*)

Schedule: 
- Run every: 1 minute
- Look back: 2 minutes

Actions:
1. Email:
   - Connector: Security Alerts Email
   - To: security-team@empresa.com
   - Subject: [CRITICAL] SQL Injection Attempt Detected
   - Body:
     Alert: SQL Injection detected
     Time: {{date}}
     Details: {{context.alerts}}
     
2. Slack:
   - Connector: Security Alerts Slack
   - Message:
     🚨 *SQL Injection Detected* 🚨
     Time: {{date}}
     Severity: High
     Count: {{context.alerts.count}}
     Review in Kibana: http://localhost:5601

3. Webhook:
   - Connector: Security Webhook
   - Body:
     {
       "rule": "SQL Injection Detection",
       "severity": "critical",
       "timestamp": "{{date}}",
       "count": {{context.alerts.count}}
     }
```

##### Ejemplo: Alerta de Múltiples Fallos de Login

```
Rule name: Brute Force Login Attempts
Description: Detecta múltiples intentos fallidos de login

Index patterns: filebeat-nginx-access-*

Custom query:
status:401 OR status:403

Threshold:
- When count() >= 5
- Grouped by: remote_addr
- Over: 5 minutes

Actions:
1. Slack:
   - Message:
     ⚠️ *Possible Brute Force Attack* ⚠️
     IP: {{context.group}}
     Failed attempts: {{context.value}}
     Time window: 5 minutes
     
2. Email:
   - Subject: [WARNING] Multiple Failed Login Attempts
   - Body: See details in Kibana
```

##### Ejemplo: Alerta de XSS

```
Rule name: XSS Attack Detection
Description: Detecta intentos de Cross-Site Scripting

Index patterns: filebeat-*

Custom query:
message:(*"<script"* OR *"javascript:"* OR *"onerror="* OR *"<iframe"*)
OR url.original:(*"<script"* OR *"javascript:"*)

Schedule:
- Run every: 1 minute

Actions:
1. Slack + Email
   Similar al ejemplo anterior
```

#### Paso 4: Crear Dashboard de Alertas

1. **Ir a Dashboard** → **Create dashboard**
2. **Agregar visualizaciones:**
   - Total de alertas generadas
   - Alertas por tipo
   - Timeline de alertas
   - Top IPs generando alertas
   - Estado de conectores

3. **Guardar:** "Security Alerts Dashboard"

### Configuración Avanzada

#### Throttling de Alertas

Para evitar spam de notificaciones:

```
En Rule settings:
- Notify: Only on status change
- Throttle: 15 minutes
```

#### Múltiples Acciones Condicionales

```yaml
Action 1 (Critical - Slack + Email):
  If: context.severity == "critical"
  
Action 2 (Warning - Solo Slack):
  If: context.severity == "warning"
  
Action 3 (Info - Solo log):
  If: context.severity == "info"
```

### Ventajas
- ✅ Notificación inmediata de incidentes
- ✅ Múltiples canales de comunicación
- ✅ Automatización de respuesta
- ✅ Integración con herramientas existentes
- ✅ Historial de alertas en Kibana

### Desventajas
- ❌ Riesgo de fatiga por alertas (false positives)
- ❌ Requiere configuración cuidadosa de umbrales
- ❌ Dependencia de conectividad de red
- ❌ Posible exposición de información sensible en notificaciones

---

## Scripts de Automatización

Todos los scripts mencionados están disponibles en `src/scripts/`:

- `block-ip-nginx.sh` - Bloqueo automático de IPs en Nginx
- `block-ip-iptables.sh` - Bloqueo con iptables en Linux
- `toggle-debug-logging.sh` - Activar/desactivar logging debug
- `test-security-responses.sh` - Script de pruebas end-to-end

### Uso de Scripts

```bash
# Bloquear IP en Nginx
./src/scripts/block-ip-nginx.sh block 192.168.1.100

# Desbloquear IP
./src/scripts/block-ip-nginx.sh unblock 192.168.1.100

# Activar debug logging
./src/scripts/toggle-debug-logging.sh enable

# Desactivar debug logging
./src/scripts/toggle-debug-logging.sh disable

# Probar todas las respuestas
./src/scripts/test-security-responses.sh
```

---

## Workflow de Respuesta a Incidentes

### Escenario Ejemplo: Detección de Ataque SQL Injection

1. **Detección (Automática):**
   - Regla de Kibana detecta patrón SQL injection
   - Se envía alerta a Slack y Email
   - Blue Team recibe notificación inmediata

2. **Análisis (1-2 minutos):**
   ```bash
   # Ver logs en Kibana
   # Buscar: message:"' OR 1=1" AND @timestamp > now-5m
   
   # Identificar IP atacante
   # Ejemplo: 192.168.1.100
   ```

3. **Respuesta Inmediata (30 segundos):**
   ```bash
   # Bloquear IP en Nginx
   ./src/scripts/block-ip-nginx.sh block 192.168.1.100
   
   # O bloquear a nivel sistema
   sudo iptables -A INPUT -s 192.168.1.100 -j DROP
   ```

4. **Investigación Profunda (5 minutos):**
   ```bash
   # Activar debug logging
   ./src/scripts/toggle-debug-logging.sh enable
   
   # Esperar capturas adicionales si el atacante cambia de IP
   ```

5. **Documentación (Continuo):**
   - Logs capturados automáticamente en Elasticsearch
   - Screenshots desde Kibana
   - Exportar datos para informe:
     ```bash
     curl -X GET "localhost:9200/filebeat-*/_search" \
       -H 'Content-Type: application/json' \
       -d '{"query":{"match":{"remote_addr":"192.168.1.100"}}}' \
       > incident_report.json
     ```

6. **Desescalada (Cuando sea seguro):**
   ```bash
   # Desbloquear IP si fue falso positivo
   ./src/scripts/block-ip-nginx.sh unblock 192.168.1.100
   
   # Desactivar debug logging
   ./src/scripts/toggle-debug-logging.sh disable
   ```

---

## Pruebas y Validación

### Test 1: Verificar Bloqueo de IP en Nginx

```bash
# 1. Bloquear tu propia IP
./src/scripts/block-ip-nginx.sh block 127.0.0.1

# 2. Intentar acceder
curl -I http://localhost:8080/
# Esperado: HTTP/1.1 403 Forbidden

# 3. Desbloquear
./src/scripts/block-ip-nginx.sh unblock 127.0.0.1

# 4. Verificar acceso restaurado
curl -I http://localhost:8080/
# Esperado: HTTP/1.1 200 OK
```

### Test 2: Verificar Debug Logging

```bash
# 1. Activar debug logging
./src/scripts/toggle-debug-logging.sh enable

# 2. Generar tráfico
curl "http://localhost:8080/rest/products/search?q=test"

# 3. Verificar logs detallados
docker exec juice-proxy cat /var/log/nginx/juice_debug.log | tail -5

# 4. Desactivar
./src/scripts/toggle-debug-logging.sh disable
```

### Test 3: Verificar Alertas de Kibana

```bash
# 1. Generar ataque SQL Injection
curl "http://localhost:8080/rest/products/search?q=' OR 1=1 --"

# 2. Esperar 1-2 minutos

# 3. Verificar en Kibana:
# - Ir a Security → Alerts
# - Buscar alert reciente
# - Verificar que se envió a Slack/Email

# 4. Verificar en Slack
# Buscar mensaje en canal #security-alerts
```

---

## Mejores Prácticas

### Seguridad
- ✅ Nunca exponer credenciales en logs
- ✅ Usar tokens/secrets seguros para webhooks
- ✅ Implementar rate limiting además de bloqueos
- ✅ Rotar logs frecuentemente cuando debug está activo
- ✅ Mantener listas de IPs bloqueadas actualizadas

### Operacional
- ✅ Documentar cada bloqueo (razón, timestamp, duración)
- ✅ Establecer procedimientos de escalación
- ✅ Revisar alertas regularmente para ajustar umbrales
- ✅ Mantener runbooks actualizados
- ✅ Practicar respuesta a incidentes (tabletop exercises)

### Monitoreo
- ✅ Crear dashboard de estado de seguridad
- ✅ Monitorear efectividad de bloqueos
- ✅ Rastrear false positives/negatives
- ✅ Revisar logs de conectores (éxitos/fallos de envío)

---

## Troubleshooting

### Problema: Nginx no recarga configuración

```bash
# Verificar sintaxis
docker exec juice-proxy nginx -t

# Ver logs de error
docker logs juice-proxy

# Reiniciar contenedor si es necesario
docker-compose restart juice-proxy
```

### Problema: iptables no bloquea

```bash
# Verificar que la regla existe
sudo iptables -L INPUT -n -v | grep <IP>

# Verificar que no hay regla ACCEPT antes
sudo iptables -L INPUT --line-numbers

# Reordenar si es necesario (reglas se evalúan en orden)
sudo iptables -I INPUT 1 -s <IP> -j DROP
```

### Problema: Alertas no se envían

```bash
# Verificar estado del conector
# En Kibana: Stack Management → Connectors → Test

# Ver logs de Kibana
docker logs kibana | grep -i connector

# Verificar conectividad de red
docker exec kibana curl -I https://hooks.slack.com
```

### Problema: Logs debug llenan disco

```bash
# Ver uso de disco
docker exec juice-proxy du -sh /var/log/nginx/

# Limpiar logs antiguos
docker exec juice-proxy sh -c "truncate -s 0 /var/log/nginx/juice_debug.log"

# Configurar rotación automática (ver scripts)
```

---

## Conclusión

Las cuatro acciones de respuesta a incidentes **SÍ PUEDEN** implementarse en el stack actual:

1. ✅ **Bloqueo IP en Nginx** - Implementado mediante edición de configuración y recarga
2. ✅ **Bloqueo Temporal** - Implementado con iptables (Linux) o pfctl (macOS)
3. ✅ **Aumento de Logging** - Implementado mediante logging condicional en Nginx y variables de entorno
4. ✅ **Comunicación en Kibana** - Implementado mediante Rules and Connectors

Cada método tiene sus ventajas y casos de uso específicos. La combinación de todos proporciona una defensa en profundidad efectiva.

---

## Referencias

- [Nginx deny directive](http://nginx.org/en/docs/http/ngx_http_access_module.html#deny)
- [iptables tutorial](https://www.netfilter.org/documentation/)
- [Kibana Alerting](https://www.elastic.co/guide/en/kibana/current/alerting-getting-started.html)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Filebeat Configuration](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-reference-yml.html)
