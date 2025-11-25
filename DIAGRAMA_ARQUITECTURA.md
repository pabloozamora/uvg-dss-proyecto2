# Diagrama de Arquitectura - Respuestas de Seguridad

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         USUARIO / ATACANTE                                   │
└─────────────────────┬───────────────────────────────────────────────────────┘
                      │
                      │ HTTP Requests
                      ▼
         ┌────────────────────────────────┐
         │      FIREWALL (iptables)       │◄──── 🛡️ BLOQUEO NIVEL 2 (Sistema)
         │  • block-ip-iptables.sh        │      • Bloqueo a nivel kernel
         │  • DROP packets desde IPs      │      • Requiere sudo
         │  • Temporal o permanente       │      • Más bajo nivel
         └────────────┬───────────────────┘
                      │
                      │ Tráfico permitido
                      ▼
         ┌────────────────────────────────┐
         │      NGINX PROXY (juice-proxy) │◄──── 🛡️ BLOQUEO NIVEL 1 (Aplicación)
         │  • Puerto 8080                 │      • block-ip-nginx.sh
         │  • blocked_ips.conf            │      • deny <IP>;
         │  • Logging JSON                │      • Recarga sin downtime
         │  • Access/Error logs           │
         └────────────┬───────────────────┘
                      │                    
                      │ Proxy Pass         ┌──────────────────────────────┐
                      ▼                    │   LOGGING DINÁMICO           │
         ┌────────────────────────────────┐│  • toggle-debug-logging.sh   │
         │    JUICE SHOP (juice-shop)     ││  • Normal: juice_access.log  │
         │  • Puerto 3000                 ││  • Debug: juice_debug.log    │
         │  • Aplicación vulnerable       ││  • Captura request body      │
         │  • LOG_LEVEL configurable      ││  • Headers completos         │
         └────────────────────────────────┘└──────────────────────────────┘
                      │
                      │ Docker logs
                      ▼
         ┌────────────────────────────────┐
         │      FILEBEAT (filebeat)       │
         │  • Recolecta logs Docker       │
         │  • Lee nginx access logs       │
         │  • Procesa JSON                │
         │  • Add metadata                │
         └────────────┬───────────────────┘
                      │
                      │ Envía a ES
                      ▼
         ┌────────────────────────────────┐
         │   ELASTICSEARCH (elasticsearch)│
         │  • Puerto 9200                 │
         │  • Índices: filebeat-*         │
         │  • Búsqueda de logs            │
         │  • Agregaciones                │
         └────────────┬───────────────────┘
                      │
                      │ Consulta
                      ▼
         ┌────────────────────────────────┐
         │        KIBANA (kibana)         │◄──── 🔔 ALERTAS Y NOTIFICACIONES
         │  • Puerto 5601                 │      • Rules and Connectors
         │  • Visualizaciones             │      • Email
         │  • Dashboards                  │      • Slack
         │  • Detection Rules             │      • Webhook
         └────────────┬───────────────────┘
                      │
                      │ Alertas
                      ▼
    ┌──────────────────┬──────────────────┬──────────────────┐
    │                  │                  │                  │
    ▼                  ▼                  ▼                  ▼
┌─────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  EMAIL  │      │  SLACK   │      │ WEBHOOK  │      │  SIEM    │
│ Gmail   │      │ #security│      │ Custom   │      │ External │
│ SMTP    │      │ Alerts   │      │ API      │      │ System   │
└─────────┘      └──────────┘      └──────────┘      └──────────┘


════════════════════════════════════════════════════════════════════════════

                    FLUJO DE RESPUESTA A INCIDENTE

1. 🔍 DETECCIÓN
   └─► Kibana detecta patrón sospechoso (SQLi, XSS, brute force)
       Query: message:*"OR 1=1"* OR url.original:*"<script"*
   
2. 🔔 ALERTA
   └─► Notificación enviada a Slack/Email
       Mensaje: "🚨 SQL Injection detectado - IP: 192.168.1.100"
   
3. 📊 ANÁLISIS
   └─► Blue Team revisa logs en Kibana
       Identifica IP, payloads, frecuencia
   
4. 🛡️ BLOQUEO INMEDIATO
   └─► Nivel 1 (Nginx):
       ./src/scripts/block-ip-nginx.sh block 192.168.1.100
   └─► Nivel 2 (Sistema):
       sudo ./src/scripts/block-ip-iptables.sh block 192.168.1.100
   
5. 🔬 INVESTIGACIÓN
   └─► Activar logging detallado:
       ./src/scripts/toggle-debug-logging.sh enable
   └─► Capturar payloads completos
       Ver en: /var/log/nginx/juice_debug.log
   
6. 📝 DOCUMENTACIÓN
   └─► Exportar evidencia desde Kibana
       Screenshots, logs, timeline
   
7. ✅ LIMPIEZA
   └─► Desactivar debug logging:
       ./src/scripts/toggle-debug-logging.sh disable
   └─► (Opcional) Desbloquear si falso positivo:
       ./src/scripts/block-ip-nginx.sh unblock <IP>


════════════════════════════════════════════════════════════════════════════

                        SCRIPTS DISPONIBLES

┌──────────────────────────────────────────────────────────────────────────┐
│ SCRIPT                      │ FUNCIÓN                  │ NIVEL           │
├─────────────────────────────┼──────────────────────────┼─────────────────┤
│ block-ip-nginx.sh           │ Bloquear/desbloquear IP  │ Aplicación      │
│ block-ip-iptables.sh        │ Bloquear con firewall    │ Sistema (sudo)  │
│ toggle-debug-logging.sh     │ Activar/desactivar debug │ Aplicación      │
│ test-security-responses.sh  │ Probar todo el sistema   │ Testing         │
│ blue-team-traffic.sh        │ Generar tráfico legítimo │ Testing         │
└──────────────────────────────────────────────────────────────────────────┘


════════════════════════════════════════════════════════════════════════════

                    REGLAS DE DETECCIÓN EN KIBANA

┌──────────────────────────────────────────────────────────────────────────┐
│ REGLA               │ SEVERIDAD │ QUERY                                  │
├─────────────────────┼───────────┼────────────────────────────────────────┤
│ SQL Injection       │ CRITICAL  │ message:*"OR 1=1"* OR *"union select"* │
│ XSS                 │ HIGH      │ message:*"<script"* OR *"javascript:"* │
│ Brute Force         │ MEDIUM    │ status:(401 OR 403) count >= 5         │
│ High Traffic (DDoS) │ MEDIUM    │ count() >= 100 per IP in 5min          │
│ Sensitive Path      │ LOW       │ request_uri:"/admin*" OR "/ftp*"       │
└──────────────────────────────────────────────────────────────────────────┘


════════════════════════════════════════════════════════════════════════════

                        DOCUMENTACIÓN

📄 README_SEGURIDAD.md                    - Resumen y guía de inicio
📄 IMPLEMENTACION_RESPUESTAS_SEGURIDAD.md - Guía técnica completa (21KB)
📄 GUIA_ALERTAS_KIBANA.md                 - Configuración de alertas (17KB)
📄 QUICK_REFERENCE.md                     - Referencia rápida (10KB)


════════════════════════════════════════════════════════════════════════════

                    RESPUESTA A LA PREGUNTA

┌──────────────────────────────────────────────────────────────────────────┐
│ ¿SE PUEDE IMPLEMENTAR CADA COSA? ¿CÓMO?                                  │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                           │
│  ✅ 1. Bloqueo IP en Nginx                                               │
│     SÍ - deny <IP>; + nginx -s reload                                    │
│     Implementado: src/scripts/block-ip-nginx.sh                          │
│                                                                           │
│  ✅ 2. Bloqueo Temporal (iptables/pfctl)                                 │
│     SÍ - iptables -A INPUT -s <IP> -j DROP                               │
│     Implementado: src/scripts/block-ip-iptables.sh                       │
│                                                                           │
│  ✅ 3. Aumento de Logging                                                │
│     SÍ - LOG_LEVEL=debug + logging condicional                           │
│     Implementado: src/scripts/toggle-debug-logging.sh                    │
│                                                                           │
│  ✅ 4. Comunicación (Kibana)                                             │
│     SÍ - Stack Management → Rules and Connectors                         │
│     Implementado: Guía completa en GUIA_ALERTAS_KIBANA.md                │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘

TODAS las acciones solicitadas PUEDEN y HAN SIDO implementadas ✅


════════════════════════════════════════════════════════════════════════════
                    Pablo Zamora - Diego Morales - Erick Guerra
                              UVG - DSS - 2025
════════════════════════════════════════════════════════════════════════════
```
