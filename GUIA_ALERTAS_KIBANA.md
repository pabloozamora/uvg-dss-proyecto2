# Guía de Configuración de Alertas en Kibana

Esta guía detalla cómo configurar conectores y reglas de alerta en Kibana para notificación de eventos de seguridad.

## Tabla de Contenidos

1. [Prerequisitos](#prerequisitos)
2. [Configuración de Conectores](#configuración-de-conectores)
3. [Creación de Reglas de Detección](#creación-de-reglas-de-detección)
4. [Ejemplos de Reglas](#ejemplos-de-reglas)
5. [Testing y Validación](#testing-y-validación)

---

## Prerequisitos

1. **Kibana funcionando correctamente:**
   ```bash
   curl http://localhost:5601/api/status
   # Debería retornar: {"status":{"overall":{"level":"available"}}}
   ```

2. **Elasticsearch con datos indexados:**
   ```bash
   curl http://elastic:changeme@localhost:9200/_cat/indices?v | grep filebeat
   # Debería mostrar índices como: filebeat-nginx-access-2024.11.25
   ```

3. **Acceso a Kibana UI:**
   - URL: http://localhost:5601
   - Usuario: elastic
   - Contraseña: changeme

---

## Configuración de Conectores

Los conectores permiten enviar notificaciones a sistemas externos cuando se dispara una alerta.

### Paso 1: Acceder a Stack Management

1. Abrir Kibana en navegador: http://localhost:5601
2. Click en el menú hamburguesa (☰) en la esquina superior izquierda
3. Scroll hasta **Management** → **Stack Management**
4. En el panel izquierdo, bajo **Alerts and Insights**, click en **Rules and Connectors**

### Paso 2: Configurar Conector de Slack

#### 2.1. Crear Slack App (en Slack primero)

1. Ir a https://api.slack.com/apps
2. Click **Create New App** → **From scratch**
3. Configurar:
   - App Name: `Kibana Security Alerts`
   - Workspace: Seleccionar tu workspace
   - Click **Create App**

4. En el panel izquierdo, click **Incoming Webhooks**
5. Toggle **Activate Incoming Webhooks** a ON
6. Scroll down y click **Add New Webhook to Workspace**
7. Seleccionar canal de destino (ej: `#security-alerts`)
8. Click **Allow**
9. **Copiar la Webhook URL** (parecida a: `https://hooks.slack.com/services/T00000000/B00000000/XXXXXX`)

#### 2.2. Configurar Conector en Kibana

1. En Kibana → Stack Management → Rules and Connectors
2. Click en la pestaña **Connectors**
3. Click **Create connector**
4. Seleccionar **Slack**
5. Configurar:
   ```
   Name: Security Alerts Slack
   Webhook URL: [pegar URL copiada de Slack]
   ```
6. Click **Save**
7. Click **Test** para enviar mensaje de prueba
8. Verificar que el mensaje llegó al canal de Slack

**Mensaje de prueba esperado en Slack:**
```
Test message
```

### Paso 3: Configurar Conector de Email

#### 3.1. Configurar Gmail para Kibana (ejemplo con Gmail)

1. Crear una contraseña de aplicación:
   - Ir a https://myaccount.google.com/security
   - Activar verificación en dos pasos si no está activa
   - Buscar "App passwords" (Contraseñas de aplicaciones)
   - Generar nueva contraseña para "Mail" en "Other (Custom name)"
   - Nombre: `Kibana Alerts`
   - Copiar la contraseña de 16 dígitos

#### 3.2. Crear Conector en Kibana

1. Stack Management → Rules and Connectors → Connectors
2. Click **Create connector**
3. Seleccionar **Email**
4. Configurar:
   ```
   Name: Security Alerts Email
   Sender: security-alerts@tuempresa.com
   
   Service: Other
   
   Host: smtp.gmail.com
   Port: 587
   Secure: true (TLS)
   
   Authentication:
   ✓ Require authentication
   User: tu-email@gmail.com
   Password: [pegar contraseña de aplicación de 16 dígitos]
   ```
5. Click **Save**
6. Click **Test** → Ingresar email de destino → **Send test email**
7. Verificar recepción del email

### Paso 4: Configurar Conector de Webhook Genérico

Para integrar con sistemas custom (APIs, ticketing systems, etc.):

1. Stack Management → Rules and Connectors → Connectors
2. Click **Create connector**
3. Seleccionar **Webhook**
4. Configurar:
   ```
   Name: Custom Security Webhook
   
   Method: POST
   URL: https://tu-servidor.com/api/security-alerts
   
   Headers:
   Add header:
     Key: Content-Type
     Value: application/json
   Add header:
     Key: Authorization
     Value: Bearer tu-token-secreto
   
   Body (JSON):
   {
     "alert_name": "{{context.rule.name}}",
     "timestamp": "{{date}}",
     "severity": "{{context.rule.severity}}",
     "count": "{{context.alerts.count}}",
     "source": "Kibana ELK Stack"
   }
   ```
5. Click **Save**
6. Click **Test** para verificar

---

## Creación de Reglas de Detección

### Paso 1: Acceder a Security Rules

1. En Kibana, click en menú (☰)
2. Ir a **Security** → **Rules**
3. Click **Create new rule**

### Paso 2: Seleccionar Tipo de Regla

Opciones disponibles:
- **Custom query**: Query KQL o Lucene personalizada
- **Threshold**: Detecta cuando un campo supera un umbral
- **Event correlation**: Correlaciona múltiples eventos
- **Indicator match**: Coincidencia con threat intelligence
- **Machine Learning**: Detecta anomalías con ML

Para seguridad básica, usaremos **Custom query** y **Threshold**.

---

## Ejemplos de Reglas

### Regla 1: Detección de SQL Injection

#### Configuración Básica

1. **Define rule**:
   ```
   Rule type: Custom query
   
   Index patterns: 
     filebeat-nginx-access-*
     filebeat-juice-shop-*
   
   Custom query (KQL):
   message:(*"' OR 1=1"* OR *"' or 1=1"* OR *"union select"* OR *"'; DROP TABLE"* OR *"1=1--"*)
   OR url.original:(*"' OR 1=1"* OR *"union select"*)
   OR request_uri:(*"' OR 1=1"* OR *"union select"*)
   ```

2. **About rule**:
   ```
   Name: SQL Injection Attack Detection
   Description: Detecta intentos de SQL injection en parámetros de URL y request body
   Severity: Critical
   Risk score: 99
   
   Tags:
     - attack
     - sql-injection
     - injection
     - owasp-top-10
   
   MITRE ATT&CK:
     - T1190 (Exploit Public-Facing Application)
   ```

3. **Schedule rule**:
   ```
   Run every: 1 minute
   Additional look-back time: 2 minutes
   ```

4. **Rule actions**:

   **Action 1: Slack Alert**
   ```
   Connector: Security Alerts Slack
   
   Message:
   🚨 *CRITICAL: SQL Injection Detected* 🚨
   
   📊 *Details:*
   • Time: {{date}}
   • Rule: {{context.rule.name}}
   • Severity: CRITICAL
   • Count: {{context.alerts.count}}
   
   🔍 *Investigation:*
   • View in Kibana: http://localhost:5601/app/security/alerts
   • Check logs for IP and payloads
   
   ⚡ *Recommended Actions:*
   1. Identify attacker IP from logs
   2. Block IP in Nginx: `./block-ip-nginx.sh block <IP>`
   3. Review attack payloads in debug logs
   4. Document incident
   ```

   **Action 2: Email Alert**
   ```
   Connector: Security Alerts Email
   
   To: security-team@empresa.com
   
   Subject: [CRITICAL] SQL Injection Attack Detected - {{date}}
   
   Body:
   CRITICAL SECURITY ALERT
   =======================
   
   SQL Injection attack detected at {{date}}
   
   Rule: {{context.rule.name}}
   Severity: Critical
   Count: {{context.alerts.count}}
   
   IMMEDIATE ACTIONS REQUIRED:
   1. Review alerts in Kibana: http://localhost:5601/app/security/alerts
   2. Identify attacker IP from nginx access logs
   3. Block IP using: ./block-ip-nginx.sh block <IP>
   4. Enable debug logging: ./toggle-debug-logging.sh enable
   5. Document incident
   
   This is an automated alert from ELK Stack Security.
   ```

5. Click **Create & enable rule**

### Regla 2: Detección de XSS

#### Configuración

1. **Define rule**:
   ```
   Rule type: Custom query
   
   Index patterns: filebeat-*
   
   Custom query (KQL):
   message:(*"<script"* OR *"javascript:"* OR *"onerror="* OR *"onload="* OR *"<iframe"* OR *"eval("*)
   OR url.original:(*"<script"* OR *"javascript:"* OR *"<iframe"*)
   OR request_uri:(*"<script"* OR *"javascript:"*)
   ```

2. **About rule**:
   ```
   Name: Cross-Site Scripting (XSS) Detection
   Description: Detecta intentos de inyección de scripts maliciosos (XSS)
   Severity: High
   Risk score: 73
   
   Tags:
     - attack
     - xss
     - cross-site-scripting
     - injection
     - owasp-top-10
   ```

3. **Schedule**: Run every 1 minute

4. **Actions**:
   ```
   Slack Message:
   ⚠️ *High: XSS Attack Detected* ⚠️
   
   Time: {{date}}
   Count: {{context.alerts.count}}
   
   Action: Review payloads in Kibana
   ```

### Regla 3: Brute Force Login Detection

#### Configuración con Threshold

1. **Define rule**:
   ```
   Rule type: Threshold
   
   Index patterns: filebeat-nginx-access-*
   
   Custom query:
   status:(401 OR 403)
   
   Threshold:
   Field: remote_addr
   Threshold: count() >= 5
   Group by: remote_addr
   ```

2. **About rule**:
   ```
   Name: Brute Force Login Attempts
   Description: Detecta múltiples intentos fallidos de autenticación desde la misma IP
   Severity: Medium
   Risk score: 47
   
   Tags:
     - attack
     - brute-force
     - authentication
   ```

3. **Schedule**:
   ```
   Run every: 5 minutes
   Look-back time: 10 minutes
   ```

4. **Actions**:
   ```
   Slack Message:
   🔐 *Possible Brute Force Attack*
   
   IP: {{context.group}}
   Failed attempts: {{context.value}}
   Time window: 10 minutes
   
   Action: Consider blocking IP
   Command: ./block-ip-nginx.sh block {{context.group}}
   ```

### Regla 4: Alto Volumen de Requests (DDoS Detection)

#### Configuración

1. **Define rule**:
   ```
   Rule type: Threshold
   
   Index patterns: filebeat-nginx-access-*
   
   Custom query: *
   
   Threshold:
   Field: remote_addr
   Threshold: count() >= 100
   Group by: remote_addr
   ```

2. **About rule**:
   ```
   Name: High Request Volume (Possible DDoS)
   Description: Detecta alto volumen de requests desde una sola IP
   Severity: Medium
   Risk score: 50
   ```

3. **Schedule**:
   ```
   Run every: 1 minute
   Look-back time: 5 minutes
   ```

4. **Actions**:
   ```
   Slack Message:
   📈 *High Traffic Volume Detected*
   
   IP: {{context.group}}
   Request count: {{context.value}} in 5 minutes
   
   Consider rate limiting or temporary block.
   ```

### Regla 5: Acceso a Rutas Sensibles

#### Configuración

1. **Define rule**:
   ```
   Rule type: Custom query
   
   Index patterns: filebeat-nginx-access-*
   
   Custom query:
   request_uri:("/admin*" OR "/api/admin*" OR "/rest/admin*" OR "/ftp*" OR "/backup*")
   ```

2. **About rule**:
   ```
   Name: Sensitive Path Access Attempt
   Description: Detecta intentos de acceso a rutas administrativas o sensibles
   Severity: Low
   Risk score: 21
   ```

3. **Schedule**: Run every 5 minutes

4. **Actions**:
   ```
   Slack Message:
   📁 *Sensitive Path Access*
   
   Path: {{context.alerts.path}}
   IP: {{context.alerts.ip}}
   
   Review if access is legitimate.
   ```

---

## Testing y Validación

### Test 1: Disparar Alerta de SQL Injection

```bash
# Generar ataque simulado
curl "http://localhost:8080/rest/products/search?q=' OR 1=1 --"

# Esperar 1-2 minutos para que se procese la alerta

# Verificar en Kibana:
# Security → Alerts → Buscar alertas recientes

# Verificar en Slack:
# Revisar canal #security-alerts
```

### Test 2: Disparar Alerta de XSS

```bash
# Generar ataque simulado
curl "http://localhost:8080/rest/products/search?q=<script>alert('xss')</script>"

# Verificar alertas en Kibana y Slack
```

### Test 3: Disparar Alerta de Brute Force

```bash
# Generar múltiples requests fallidos
for i in {1..10}; do
  curl -X POST http://localhost:8080/rest/user/login \
    -H "Content-Type: application/json" \
    -d '{"email":"fake@test.com","password":"wrong"}' \
    -w "\nStatus: %{http_code}\n"
  sleep 1
done

# Esperar 5 minutos
# Verificar alerta
```

### Test 4: Verificar Conectores

```bash
# En Kibana UI:
# 1. Stack Management → Rules and Connectors → Connectors
# 2. Para cada conector, click en el nombre
# 3. Click en "Test" 
# 4. Verificar que el mensaje llega al destino
```

---

## Configuración Avanzada

### Throttling de Alertas

Para evitar spam de notificaciones:

1. En configuración de regla, sección **Actions**
2. Click **Advanced options**
3. Configurar:
   ```
   Action frequency:
   - Summary of alerts: On each rule run
   - For each alert: On custom action interval
   - Custom interval: 15 minutes
   
   Notify:
   - Only on status change
   ```

### Acciones Condicionales

Para enviar diferentes notificaciones según severidad:

```javascript
// En campo "Run when" de la acción:

// Para severidad crítica (Slack + Email):
context.rule.severity === 'critical'

// Para severidad media (solo Slack):
context.rule.severity === 'medium'

// Para severidad baja (solo log):
context.rule.severity === 'low'
```

### Enriquecimiento de Alertas

Agregar contexto adicional a las alertas:

```javascript
// En mensaje de Slack, usar variables:

🚨 *Alert: {{context.rule.name}}* 🚨

📊 *Attack Details:*
• IP: {{context.alerts.remote_addr}}
• Method: {{context.alerts.request_method}}
• URI: {{context.alerts.request_uri}}
• User-Agent: {{context.alerts.http_user_agent}}
• Status: {{context.alerts.status}}

🕐 *Timestamp:* {{date}}
🔢 *Alert Count:* {{context.alerts.count}}

🔗 *Links:*
• Kibana: http://localhost:5601/app/security/alerts
• Logs: http://localhost:5601/app/discover
```

---

## Dashboard de Alertas

### Crear Dashboard de Monitoreo

1. En Kibana → Dashboard → Create dashboard
2. Agregar visualizaciones:

   **Panel 1: Total de Alertas (Metric)**
   - Tipo: Metric
   - Campo: Count
   - Filtro: kibana.alert.rule.name exists

   **Panel 2: Alertas por Severidad (Pie Chart)**
   - Tipo: Pie
   - Buckets: Terms en kibana.alert.rule.severity

   **Panel 3: Timeline de Alertas (Line Chart)**
   - Tipo: Line
   - X-axis: @timestamp
   - Y-axis: Count
   - Break down by: kibana.alert.rule.name

   **Panel 4: Top IPs Generando Alertas (Table)**
   - Tipo: Table
   - Rows: Terms en remote_addr
   - Metrics: Count

3. Guardar como "Security Alerts Dashboard"

---

## Troubleshooting

### Problema: Alertas no se disparan

**Diagnóstico:**
```bash
# 1. Verificar que los datos están en Elasticsearch
curl -X GET "http://elastic:changeme@localhost:9200/filebeat-*/_search?size=5&pretty"

# 2. Verificar que la regla está habilitada
# Kibana → Security → Rules → Verificar estado

# 3. Ver logs de Kibana
docker logs kibana | grep -i "alert"

# 4. Verificar query manualmente en Dev Tools
GET filebeat-*/_search
{
  "query": {
    "query_string": {
      "query": "message:*OR 1=1*"
    }
  }
}
```

### Problema: Conector de Slack no envía mensajes

**Diagnóstico:**
```bash
# 1. Test de conectividad
docker exec kibana curl -I https://hooks.slack.com

# 2. Verificar webhook URL
# En Slack API console, verificar que el webhook está activo

# 3. Ver logs de Kibana
docker logs kibana | grep -i slack

# 4. Test del conector en Kibana UI
# Stack Management → Connectors → [tu conector] → Test
```

### Problema: Email no llega

**Diagnóstico:**
```bash
# 1. Verificar credenciales SMTP
# Verificar que la contraseña de aplicación es correcta

# 2. Verificar puerto y host
# Gmail: smtp.gmail.com:587 con TLS

# 3. Revisar logs
docker logs kibana | grep -i email

# 4. Verificar bandeja de spam
# Los emails de alertas pueden ir a spam
```

---

## Mejores Prácticas

### 1. Configuración de Reglas
- ✅ Empezar con umbrales conservadores
- ✅ Probar reglas antes de activarlas en producción
- ✅ Usar tags consistentes para organización
- ✅ Documentar cada regla (descripción clara)

### 2. Gestión de Alertas
- ✅ Configurar throttling para evitar spam
- ✅ Usar diferentes canales según severidad
- ✅ Revisar y ajustar reglas regularmente
- ✅ Mantener dashboard de alertas actualizado

### 3. Respuesta a Incidentes
- ✅ Establecer procedimientos claros
- ✅ Documentar cada acción tomada
- ✅ Realizar post-mortems de incidentes
- ✅ Actualizar reglas basado en lecciones aprendidas

### 4. Mantenimiento
- ✅ Revisar false positives semanalmente
- ✅ Actualizar conectores si cambian credenciales
- ✅ Backup de configuración de reglas
- ✅ Monitorear performance de reglas

---

## Exportar/Importar Reglas

### Exportar Reglas

```bash
# Desde Kibana UI:
# Security → Rules → Manage rules → Select all → Export

# O usando API:
curl -X POST "http://localhost:5601/api/detection_engine/rules/_export" \
  -H "kbn-xsrf: true" \
  -H "Content-Type: application/json" \
  -u elastic:changeme \
  > security_rules_backup.ndjson
```

### Importar Reglas

```bash
# Desde Kibana UI:
# Security → Rules → Manage rules → Import

# O usando API:
curl -X POST "http://localhost:5601/api/detection_engine/rules/_import" \
  -H "kbn-xsrf: true" \
  -u elastic:changeme \
  -F file=@security_rules_backup.ndjson
```

---

## Conclusión

Con esta configuración completa:

✅ **Conectores configurados** para Slack, Email y Webhooks
✅ **Reglas de detección** para ataques comunes (SQLi, XSS, brute force)
✅ **Alertas automáticas** que notifican al equipo en tiempo real
✅ **Dashboard de monitoreo** para visibilidad continua
✅ **Procedimientos de testing** para validar funcionamiento

El sistema está listo para detectar y alertar sobre amenazas de seguridad de manera automática.

---

## Referencias

- [Kibana Alerting Documentation](https://www.elastic.co/guide/en/kibana/current/alerting-getting-started.html)
- [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks)
- [Detection Rules](https://www.elastic.co/guide/en/security/current/rules-ui-management.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
