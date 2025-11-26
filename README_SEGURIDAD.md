# README - Respuestas de Seguridad Implementadas

Este proyecto implementa un sistema completo de respuestas de seguridad para el stack ELK + Juice Shop, permitiendo detectar y responder a amenazas de seguridad de manera automática y manual.

## 📖 Respuesta a la Pregunta: "¿SE puede implementar cada cosa? ¿Cómo?"

**SÍ**, todas las cuatro acciones de respuesta mencionadas en el problema **PUEDEN** implementarse y **HAN SIDO** implementadas en este proyecto:

### ✅ 1. Bloqueo IP en Nginx
**¿Se puede?** SÍ  
**¿Cómo?** Mediante directivas `deny <IP>;` en la configuración de Nginx y recarga con `nginx -s reload`

**Implementación:**
- Script automatizado: `src/scripts/block-ip-nginx.sh`
- Archivo de configuración: `src/nginx/blocked_ips.conf`
- Documentación: Sección 1 de `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md`

**Uso:**
```bash
./src/scripts/block-ip-nginx.sh block 192.168.1.100
./src/scripts/block-ip-nginx.sh unblock 192.168.1.100
./src/scripts/block-ip-nginx.sh list
```

---

### ✅ 2. Bloqueo Temporal con iptables/pfctl
**¿Se puede?** SÍ  
**¿Cómo?** Usando `iptables` en Linux o `pfctl` en macOS para bloquear tráfico a nivel de firewall del sistema operativo

**Implementación:**
- Script automatizado: `src/scripts/block-ip-iptables.sh` (Linux)
- Documentación incluye comandos para macOS (pfctl)
- Documentación: Sección 2 de `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md`

**Uso:**
```bash
# Bloqueo permanente
sudo ./src/scripts/block-ip-iptables.sh block 192.168.1.100

# Bloqueo temporal (1 hora)
sudo ./src/scripts/block-ip-iptables.sh block 192.168.1.100 3600

# Desbloquear
sudo ./src/scripts/block-ip-iptables.sh unblock 192.168.1.100
```

---

### ✅ 3. Aumento de Logging
**¿Se puede?** SÍ  
**¿Cómo?** Mediante configuración dinámica de Nginx y variables de entorno en Juice Shop

**Implementación:**
- Script automatizado: `src/scripts/toggle-debug-logging.sh`
- Logging condicional por IP en Nginx
- Captura de request body completo
- Documentación: Sección 3 de `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md`

**Uso:**
```bash
# Activar debug logging
./src/scripts/toggle-debug-logging.sh enable

# Ver estado
./src/scripts/toggle-debug-logging.sh status

# Desactivar
./src/scripts/toggle-debug-logging.sh disable
```

**Características:**
- Captura headers completos
- Captura request body
- Captura tiempos de respuesta detallados
- Logging condicional por IP atacante

---

### ✅ 4. Comunicación - Alertas en Kibana
**¿Se puede?** SÍ  
**¿Cómo?** Configurando conectores (Email/Slack/Webhook) en Kibana → Stack Management → Rules and Connectors

**Implementación:**
- Guía completa paso a paso: `GUIA_ALERTAS_KIBANA.md`
- Ejemplos de reglas de detección pre-configuradas
- Plantillas de mensajes para Slack y Email
- Documentación: Sección 4 de `IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md`

**Conectores Soportados:**
- **Slack** - Notificaciones a canales de Slack
- **Email** - Alertas por correo electrónico (Gmail, SMTP)
- **Webhook** - Integración con APIs personalizadas

**Reglas Incluidas:**
- Detección de SQL Injection
- Detección de XSS
- Detección de Brute Force
- Detección de alto volumen de requests (DDoS)
- Acceso a rutas sensibles

---

## 📁 Estructura del Proyecto

```
uvg-dss-proyecto2/
├── IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md  # Guía completa (21KB)
├── GUIA_ALERTAS_KIBANA.md                   # Guía de alertas (17KB)
├── QUICK_REFERENCE.md                       # Referencia rápida (10KB)
├── README_SEGURIDAD.md                      # Este archivo
├── REPORTE.md                               # Reporte del proyecto
│
├── src/
│   ├── docker-compose.yml                   # Configuración de contenedores
│   ├── filebeat.yml                         # Configuración de Filebeat
│   ├── kibana.yml                           # Configuración de Kibana
│   │
│   ├── nginx/
│   │   ├── default.conf                     # Configuración base de Nginx
│   │   └── blocked_ips.conf                 # Lista de IPs bloqueadas
│   │
│   └── scripts/
│       ├── block-ip-nginx.sh               # Bloqueo en Nginx (4KB)
│       ├── block-ip-iptables.sh            # Bloqueo con iptables (6KB)
│       ├── toggle-debug-logging.sh         # Control de logging (8KB)
│       ├── test-security-responses.sh      # Suite de tests (10KB)
│       └── blue-team-traffic.sh            # Tráfico legítimo
```

---

## 🚀 Inicio Rápido

### 1. Levantar el Sistema

```bash
cd /home/runner/work/uvg-dss-proyecto2/uvg-dss-proyecto2/src
docker-compose up -d
```

### 2. Verificar que Todo Está Funcionando

```bash
docker-compose ps
# Todos los servicios deben estar "healthy" o "Up"
```

**Servicios esperados:**
- `juice-shop` - Aplicación vulnerable (puerto 3000)
- `juice-proxy` - Nginx proxy (puerto 8080)
- `elasticsearch` - Motor de búsqueda (puerto 9200)
- `kibana` - Interfaz de visualización (puerto 5601)
- `filebeat` - Recolector de logs

### 3. Acceder a las Interfaces

- **Juice Shop:** http://localhost:3000
- **Nginx Proxy:** http://localhost:8080
- **Kibana:** http://localhost:5601
  - Usuario: `elastic`
  - Contraseña: `changeme`
- **Elasticsearch:** http://localhost:9200

---

## 🎯 Casos de Uso Prácticos

### Caso 1: Detectar y Bloquear Ataque SQL Injection

```bash
# 1. Configurar alerta en Kibana (ver GUIA_ALERTAS_KIBANA.md)
#    - Regla: SQL Injection Detection
#    - Acción: Notificar a Slack

# 2. Simular ataque
curl "http://localhost:8080/rest/products/search?q=' OR 1=1 --"

# 3. Esperar alerta (1-2 minutos)
#    - Revisar Slack o Email
#    - Verificar en Kibana → Security → Alerts

# 4. Identificar IP atacante en logs
#    - Buscar en Kibana: message:"OR 1=1" AND @timestamp > now-5m

# 5. Bloquear IP
./src/scripts/block-ip-nginx.sh block 192.168.1.100

# 6. Activar logging detallado
./src/scripts/toggle-debug-logging.sh enable

# 7. Documentar incidente y limpiar
./src/scripts/toggle-debug-logging.sh disable
```

### Caso 2: Responder a Brute Force

```bash
# 1. La regla de Kibana detecta 5+ intentos fallidos de login

# 2. Recibir alerta con IP del atacante

# 3. Bloqueo inmediato a nivel sistema
sudo ./src/scripts/block-ip-iptables.sh block <IP_ATACANTE>

# 4. Verificar que el bloqueo funciona
curl -I http://localhost:8080/
# Debería timeout o rechazarse
```

### Caso 3: Investigación Forense

```bash
# 1. Activar logging detallado
./src/scripts/toggle-debug-logging.sh enable

# 2. Reproducir el ataque o esperar actividad sospechosa

# 3. Analizar logs detallados
docker exec juice-proxy tail -100 /var/log/nginx/juice_debug.log

# 4. Exportar evidencia
docker exec juice-proxy cat /var/log/nginx/juice_debug.log > evidencia.log

# 5. Limpiar
./src/scripts/toggle-debug-logging.sh disable
```

---

## 🧪 Testing

### Ejecutar Suite Completa de Tests

```bash
cd /home/runner/work/uvg-dss-proyecto2/uvg-dss-proyecto2
./src/scripts/test-security-responses.sh
```

**Opciones:**
1. Test de bloqueo IP en Nginx
2. Test de debug logging
3. Test de alertas en Kibana
4. Test de workflow completo
5. Ejecutar todos los tests

### Tests Manuales Rápidos

```bash
# Test 1: Bloqueo en Nginx
./src/scripts/block-ip-nginx.sh block 127.0.0.1
curl -I http://localhost:8080/
# Esperado: 403 Forbidden
./src/scripts/block-ip-nginx.sh unblock 127.0.0.1

# Test 2: Debug Logging
./src/scripts/toggle-debug-logging.sh enable
curl http://localhost:8080/test
docker exec juice-proxy tail -1 /var/log/nginx/juice_debug.log
./src/scripts/toggle-debug-logging.sh disable

# Test 3: Generar Alertas
curl "http://localhost:8080/rest/products/search?q=<script>alert('xss')</script>"
# Verificar en Kibana después de 1-2 minutos
```

---

## 📚 Documentación Completa

### Guías Principales

1. **[IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md](IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md)** (21 KB)
   - Guía completa de implementación
   - Explicación técnica detallada
   - Ventajas y desventajas de cada método
   - Ejemplos prácticos
   - Troubleshooting

2. **[GUIA_ALERTAS_KIBANA.md](GUIA_ALERTAS_KIBANA.md)** (17 KB)
   - Configuración paso a paso de conectores
   - Ejemplos de reglas de detección
   - Plantillas de mensajes
   - Testing y validación
   - Mejores prácticas

3. **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** (10 KB)
   - Comandos rápidos
   - Workflows de respuesta
   - Troubleshooting rápido
   - Checklist de implementación

### Scripts Automatizados

1. **[block-ip-nginx.sh](src/scripts/block-ip-nginx.sh)** - Bloqueo de IPs en Nginx
   - Bloquear/desbloquear IPs
   - Listar IPs bloqueadas
   - Validación automática

2. **[block-ip-iptables.sh](src/scripts/block-ip-iptables.sh)** - Bloqueo con iptables
   - Bloqueo permanente o temporal
   - Flush de todas las reglas
   - Persistencia de reglas

3. **[toggle-debug-logging.sh](src/scripts/toggle-debug-logging.sh)** - Control de logging
   - Activar/desactivar debug
   - Ver estado actual
   - Rotar logs

4. **[test-security-responses.sh](src/scripts/test-security-responses.sh)** - Suite de tests
   - Tests individuales
   - Test de workflow completo
   - Validación automática

---

## 🔐 Seguridad y Mejores Prácticas

### Seguridad

- ✅ Scripts validan entrada (IPs, parámetros)
- ✅ Backups automáticos antes de cambios
- ✅ Logging de todas las acciones
- ✅ Verificación de sintaxis antes de aplicar cambios
- ✅ No exponer credenciales en logs

### Operacional

- ✅ Scripts con códigos de salida apropiados
- ✅ Mensajes de error descriptivos
- ✅ Colores para mejor legibilidad
- ✅ Confirmación para acciones destructivas
- ✅ Documentación inline en scripts

### Monitoreo

- ✅ Logs centralizados en Elasticsearch
- ✅ Alertas automáticas configurables
- ✅ Dashboard de seguridad
- ✅ Métricas de uso de disco
- ✅ Historial de cambios

---

## ⚠️ Limitaciones y Consideraciones

### Bloqueo de IPs

- **Limitación:** Fácil de eludir con cambio de IP o VPN
- **Mitigación:** Combinar con otras defensas (rate limiting, WAF)

### iptables

- **Limitación:** Requiere privilegios de root
- **Limitación:** Reglas no persisten al reiniciar sin configuración adicional
- **Mitigación:** Usar iptables-persistent o agregar a scripts de inicio

### Debug Logging

- **Limitación:** Alto consumo de disco
- **Limitación:** Impacto en rendimiento
- **Mitigación:** Activar solo temporalmente, rotar logs frecuentemente

### Alertas de Kibana

- **Limitación:** Requiere conectividad de red
- **Limitación:** Posibles false positives
- **Mitigación:** Ajustar umbrales, configurar throttling

---

## 🆘 Troubleshooting

### Problema: Scripts no ejecutan

```bash
# Dar permisos de ejecución
chmod +x src/scripts/*.sh
```

### Problema: Nginx no recarga

```bash
# Verificar sintaxis
docker exec juice-proxy nginx -t

# Ver logs de error
docker logs juice-proxy --tail 50

# Reiniciar contenedor
docker-compose restart juice-proxy
```

### Problema: iptables requiere sudo

```bash
# Ejecutar con sudo
sudo ./src/scripts/block-ip-iptables.sh block <IP>

# O agregar capacidades al usuario (no recomendado en producción)
```

### Problema: Logs llenan disco

```bash
# Ver uso actual
docker exec juice-proxy du -sh /var/log/nginx/

# Limpiar logs debug
docker exec juice-proxy truncate -s 0 /var/log/nginx/juice_debug.log

# Rotar logs
./src/scripts/toggle-debug-logging.sh rotate
```

### Problema: Kibana no envía alertas

```bash
# Verificar conectividad
docker exec kibana curl -I https://hooks.slack.com

# Ver logs de Kibana
docker logs kibana | grep -i connector

# Test del conector
# UI: Stack Management → Connectors → Test
```

---

## 🎓 Aprendizajes y Conclusiones

### Tecnologías Implementadas

- **Docker & Docker Compose** - Orquestación de contenedores
- **Nginx** - Proxy reverso y web server
- **iptables** - Firewall de Linux
- **Elasticsearch** - Motor de búsqueda y almacenamiento
- **Kibana** - Visualización y alertas
- **Filebeat** - Recolección de logs
- **Bash Scripting** - Automatización

### Habilidades Desarrolladas

- ✅ Configuración de sistemas de detección
- ✅ Respuesta a incidentes de seguridad
- ✅ Automatización de tareas de seguridad
- ✅ Análisis de logs y eventos
- ✅ Configuración de alertas y notificaciones
- ✅ Scripting avanzado en Bash
- ✅ Troubleshooting de sistemas distribuidos

### Aplicaciones en el Mundo Real

Este sistema puede utilizarse para:

1. **SOC (Security Operations Center)** - Detección y respuesta 24/7
2. **Incident Response** - Investigación forense de ataques
3. **Compliance** - Logging y auditoría requeridos por regulaciones
4. **DevSecOps** - Integración de seguridad en CI/CD
5. **Threat Hunting** - Búsqueda proactiva de amenazas

---

## 📊 Resumen Final

| Característica | Estado | Documentación | Scripts |
|---------------|--------|---------------|---------|
| Bloqueo IP (Nginx) | ✅ Implementado | ✅ Completa | ✅ Automatizado |
| Bloqueo Temporal (iptables) | ✅ Implementado | ✅ Completa | ✅ Automatizado |
| Aumento de Logging | ✅ Implementado | ✅ Completa | ✅ Automatizado |
| Alertas en Kibana | ✅ Implementado | ✅ Completa | ⚠️ Manual (UI) |
| Suite de Tests | ✅ Implementado | ✅ Incluida | ✅ Automatizado |

**Total de Código:** ~59 KB de documentación + scripts  
**Total de Archivos:** 13 archivos nuevos  
**Cobertura:** 100% de las acciones solicitadas

---

## 👥 Autores

- Pablo Andrés Zamora Vásquez - 21780
- Diego Andrés Morales Aquino - 21762
- Erick Stiv Junior Guerra - 21781

**Fecha:** 25/11/2025  
**Proyecto:** DSS - Sistema de Logging con ELK Stack

---

## 📝 Licencia y Uso

Este proyecto es con fines educativos para el curso de Seguridad en Sistemas Distribuidos (DSS).

**Advertencia:** Las herramientas y técnicas presentadas deben usarse únicamente en ambientes controlados y con autorización. El uso no autorizado de estas técnicas puede ser ilegal.

---

## 🔗 Enlaces Útiles

- [Nginx Documentation](http://nginx.org/en/docs/)
- [iptables Tutorial](https://www.netfilter.org/documentation/)
- [Elasticsearch Guide](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Kibana Alerting](https://www.elastic.co/guide/en/kibana/current/alerting-getting-started.html)
- [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)

---

**¡El sistema está completo y listo para usar!** 🎉

Para comenzar, consulta [QUICK_REFERENCE.md](QUICK_REFERENCE.md) para comandos rápidos o [IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md](IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md) para la guía completa.
