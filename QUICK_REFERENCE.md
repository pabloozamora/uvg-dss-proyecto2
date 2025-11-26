# Respuestas de Seguridad - Guía Rápida

Esta guía proporciona comandos y referencias rápidas para implementar las cuatro respuestas de seguridad principales.

## 📋 Resumen de Implementaciones

| Acción | Dónde | Implementado | Script | Documentación |
|--------|-------|--------------|--------|---------------|
| **Bloqueo IP** | Nginx | ✅ Sí | `block-ip-nginx.sh` | [Ver guía](#1-bloqueo-de-ip-en-nginx) |
| **Bloqueo Temporal** | iptables/pfctl | ✅ Sí | `block-ip-iptables.sh` | [Ver guía](#2-bloqueo-temporal-iptables) |
| **Aumento Logging** | Nginx/Juice Shop | ✅ Sí | `toggle-debug-logging.sh` | [Ver guía](#3-aumento-de-logging) |
| **Comunicación** | Kibana | ✅ Sí | Manual (UI) | [Ver guía](#4-alertas-en-kibana) |

---

## 🚀 Inicio Rápido

### Levantar el Sistema

```bash
cd /home/runner/work/uvg-dss-proyecto2/uvg-dss-proyecto2/src
docker-compose up -d
```

### Verificar Estado

```bash
docker-compose ps
# Todos los contenedores deben estar "healthy" o "Up"
```

---

## 1. Bloqueo de IP en Nginx

### Comando Rápido

```bash
# Bloquear IP
./src/scripts/block-ip-nginx.sh block 192.168.1.100

# Desbloquear IP
./src/scripts/block-ip-nginx.sh unblock 192.168.1.100

# Listar IPs bloqueadas
./src/scripts/block-ip-nginx.sh list
```

### Bloqueo Manual

1. Editar `src/nginx/blocked_ips.conf`:
   ```nginx
   deny 192.168.1.100;  # Comentario opcional
   ```

2. Recargar Nginx:
   ```bash
   docker exec juice-proxy nginx -s reload
   ```

### Verificar Bloqueo

```bash
# Desde la IP bloqueada (o simular):
curl -I http://localhost:8080/
# Esperado: HTTP/1.1 403 Forbidden
```

**Documentación completa:** `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md` (Sección 1)

---

## 2. Bloqueo Temporal (iptables)

### Comando Rápido (requiere sudo)

```bash
# Bloqueo permanente
sudo ./src/scripts/block-ip-iptables.sh block 192.168.1.100

# Bloqueo temporal (1 hora = 3600 segundos)
sudo ./src/scripts/block-ip-iptables.sh block 192.168.1.100 3600

# Desbloquear
sudo ./src/scripts/block-ip-iptables.sh unblock 192.168.1.100

# Listar reglas
sudo ./src/scripts/block-ip-iptables.sh list
```

### Comandos Manuales de iptables

```bash
# Bloquear IP
sudo iptables -A INPUT -s 192.168.1.100 -j DROP

# Ver reglas
sudo iptables -L INPUT -n -v --line-numbers

# Eliminar regla por número de línea
sudo iptables -D INPUT <número>

# Eliminar regla específica
sudo iptables -D INPUT -s 192.168.1.100 -j DROP
```

### Para macOS (pfctl)

```bash
# Crear archivo de reglas
echo "block drop from 192.168.1.100 to any" | sudo tee /tmp/pf_block.conf

# Aplicar
sudo pfctl -f /tmp/pf_block.conf
sudo pfctl -e

# Ver reglas
sudo pfctl -s rules

# Deshabilitar
sudo pfctl -d
```

**Documentación completa:** `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md` (Sección 2)

---

## 3. Aumento de Logging

### Comando Rápido

```bash
# Activar debug logging
./src/scripts/toggle-debug-logging.sh enable

# Ver estado
./src/scripts/toggle-debug-logging.sh status

# Desactivar debug logging
./src/scripts/toggle-debug-logging.sh disable

# Rotar logs
./src/scripts/toggle-debug-logging.sh rotate
```

### Ver Logs Detallados

```bash
# Ver logs en tiempo real
docker exec juice-proxy tail -f /var/log/nginx/juice_debug.log

# Ver últimas 50 líneas
docker exec juice-proxy tail -50 /var/log/nginx/juice_debug.log

# Buscar IP específica en logs
docker exec juice-proxy grep "192.168.1.100" /var/log/nginx/juice_access.log
```

### Nivel de Log en Juice Shop

Para aumentar el nivel de logging en Juice Shop (requiere reinicio):

```bash
# Editar docker-compose.yml
# Cambiar en servicio juice-shop:
#   environment:
#     - LOG_LEVEL=debug

# Reiniciar contenedor
docker-compose restart juice-shop
```

**Documentación completa:** `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md` (Sección 3)

---

## 4. Alertas en Kibana

### Acceso Rápido

- **URL Kibana:** http://localhost:5601
- **Usuario:** elastic
- **Contraseña:** changeme

### Configurar Conectores

1. Menu (☰) → **Stack Management**
2. **Alerts and Insights** → **Rules and Connectors**
3. Pestaña **Connectors** → **Create connector**

#### Conectores Disponibles:
- **Slack** - Requiere Webhook URL de Slack App
- **Email** - Requiere SMTP (ej: Gmail)
- **Webhook** - Para APIs personalizadas

### Crear Regla de Detección

1. Menu (☰) → **Security** → **Rules**
2. **Create new rule** → **Custom query**
3. Configurar query, acciones y guardar

### Ejemplos de Queries

```kql
# SQL Injection
message:(*"' OR 1=1"* OR *"union select"*)

# XSS
message:(*"<script"* OR *"javascript:"*)

# Brute Force (usar tipo Threshold)
status:(401 OR 403)
Threshold: count() >= 5
Group by: remote_addr

# Alto volumen de requests
Threshold: count() >= 100 per IP in 5 min
```

### Probar Alertas

```bash
# Generar SQL Injection
curl "http://localhost:8080/rest/products/search?q=' OR 1=1 --"

# Generar XSS
curl "http://localhost:8080/rest/products/search?q=<script>alert('xss')</script>"

# Esperar 1-2 minutos
# Verificar en: Security → Alerts
```

**Documentación completa:** `GUIA_ALERTAS_KIBANA.md`

---

## 🧪 Testing Completo

### Ejecutar Suite de Tests

```bash
./src/scripts/test-security-responses.sh
```

**Opciones del test:**
1. Test de bloqueo IP en Nginx
2. Test de debug logging
3. Test de alertas en Kibana
4. Test de workflow completo
5. Ejecutar todos los tests

---

## 🔄 Workflow de Respuesta a Incidente

### Escenario: Ataque SQL Injection Detectado

```bash
# 1. DETECCIÓN (automática vía Kibana)
# Alerta recibida en Slack/Email

# 2. ANÁLISIS (1-2 minutos)
# Revisar logs en Kibana para identificar IP
# Buscar: message:"OR 1=1" AND @timestamp > now-5m

# 3. RESPUESTA INMEDIATA (30 segundos)
# Bloquear IP atacante
./src/scripts/block-ip-nginx.sh block <IP_ATACANTE>

# O a nivel sistema
sudo ./src/scripts/block-ip-iptables.sh block <IP_ATACANTE>

# 4. INVESTIGACIÓN PROFUNDA (5 minutos)
# Activar debug logging para captura detallada
./src/scripts/toggle-debug-logging.sh enable

# Generar tráfico si el atacante cambia de IP
# Analizar payloads completos

# 5. DOCUMENTACIÓN
# Exportar evidencia desde Kibana
# Screenshots, logs, timeline del ataque

# 6. DESESCALADA (cuando sea seguro)
# Desbloquear si fue falso positivo
./src/scripts/block-ip-nginx.sh unblock <IP>

# Desactivar debug logging
./src/scripts/toggle-debug-logging.sh disable
```

---

## 📊 Monitoreo Continuo

### Dashboard en Kibana

1. Ir a **Dashboard** → **Create dashboard**
2. Agregar paneles:
   - Total de alertas (Metric)
   - Alertas por tipo (Pie chart)
   - Timeline de alertas (Line chart)
   - Top IPs atacantes (Table)
3. Guardar como "Security Monitoring"

### Comandos de Monitoreo

```bash
# Ver logs de todos los contenedores
docker-compose logs -f

# Ver solo logs de nginx
docker logs -f juice-proxy

# Ver logs de Filebeat (envío a Elasticsearch)
docker logs -f filebeat

# Verificar índices en Elasticsearch
curl http://elastic:changeme@localhost:9200/_cat/indices?v | grep filebeat

# Verificar salud del cluster
curl http://elastic:changeme@localhost:9200/_cluster/health?pretty
```

---

## 🛠️ Troubleshooting Rápido

### Problema: Nginx no recarga

```bash
# Verificar sintaxis
docker exec juice-proxy nginx -t

# Ver error específico
docker logs juice-proxy --tail 50

# Reiniciar si es necesario
docker-compose restart juice-proxy
```

### Problema: Alertas no se disparan

```bash
# Verificar datos en Elasticsearch
curl http://elastic:changeme@localhost:9200/filebeat-*/_count

# Verificar regla está habilitada
# Kibana → Security → Rules

# Ver logs de Kibana
docker logs kibana | grep -i alert
```

### Problema: Logs llenan disco

```bash
# Ver uso de disco
docker exec juice-proxy du -sh /var/log/nginx/

# Limpiar logs debug
docker exec juice-proxy truncate -s 0 /var/log/nginx/juice_debug.log

# Rotar logs automáticamente
./src/scripts/toggle-debug-logging.sh rotate
```

---

## 📚 Documentación Adicional

- **Guía Completa de Implementación:** `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md`
- **Guía de Alertas en Kibana:** `GUIA_ALERTAS_KIBANA.md`
- **Scripts de Automatización:** `src/scripts/`
- **Reporte del Proyecto:** `REPORTE.md`

---

## 🔐 Mejores Prácticas

### Seguridad
- ✅ Nunca exponer credenciales en logs
- ✅ Rotar logs frecuentemente cuando debug está activo
- ✅ Documentar cada bloqueo (IP, razón, timestamp)
- ✅ Revisar false positives regularmente

### Operacional
- ✅ Mantener backup de configuraciones
- ✅ Probar cambios en ambiente de staging primero
- ✅ Establecer procedimientos de escalación
- ✅ Realizar ejercicios de respuesta a incidentes

### Monitoreo
- ✅ Revisar dashboard de seguridad diariamente
- ✅ Ajustar umbrales de alertas según necesidad
- ✅ Mantener inventario de IPs bloqueadas
- ✅ Realizar auditorías de reglas mensualmente

---

## 📞 Contactos de Emergencia

En caso de incidente de seguridad crítico:

1. **Blue Team Lead:** [contacto]
2. **Security Operations:** [contacto]
3. **Sistema de Tickets:** [URL]
4. **Escalación:** [procedimiento]

---

## ✅ Checklist de Implementación

- [ ] Sistema ELK Stack funcionando correctamente
- [ ] Nginx configurado con formato de log JSON
- [ ] Scripts de bloqueo probados y funcionando
- [ ] Debug logging probado (enable/disable)
- [ ] Conector de Slack configurado y probado
- [ ] Conector de Email configurado y probado
- [ ] Al menos 3 reglas de detección creadas
- [ ] Reglas de detección probadas con ataques simulados
- [ ] Dashboard de seguridad creado
- [ ] Procedimientos de respuesta documentados
- [ ] Equipo entrenado en uso de herramientas

---

## 📝 Notas Importantes

⚠️ **Advertencias:**
- El debug logging consume mucho espacio en disco
- Bloquear IPs puede afectar usuarios legítimos
- iptables requiere privilegios de root
- Las reglas de iptables no persisten al reiniciar (sin configuración adicional)
- Slack webhooks son públicos; no enviar datos sensibles

💡 **Tips:**
- Usar bloqueo en Nginx para pruebas y situaciones no críticas
- Usar iptables para bloqueos urgentes a nivel sistema
- Activar debug logging solo durante investigaciones
- Configurar throttling en alertas para evitar spam
- Mantener logs de todas las acciones de respuesta

---

**Última actualización:** 2025-11-25  
**Versión:** 1.0  
**Autores:** Equipo Blue Team - Proyecto DSS
