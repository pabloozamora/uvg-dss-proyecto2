# Proyecto 2 - Sistema de Logging con ELK Stack

Pablo Andrés Zamora Vásquez - 21780
Diego Andrés Morales Aquino - 21762
Erick Stiv Junior Guerra - 21781
**Fecha**: 25/11/2025  

---

## 📋 Índice

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Paso 1: Juice Shop Básico](#paso-1-juice-shop-básico)
3. [Paso 2: Elasticsearch](#paso-2-elasticsearch)
4. [Paso 3: Kibana](#paso-3-kibana)
5. [Paso 4: Filebeat](#paso-4-filebeat)
6. [Paso 5: Visualización en Kibana](#paso-5-visualización-en-kibana)
7. [Paso 6: Blue Team & Red Team](#paso-6-blue-team--red-team)
8. [Análisis Técnico](#análisis-técnico)
9. [Problemas y Soluciones](#problemas-y-soluciones)
10. [Conclusiones](#conclusiones)

---

## Resumen Ejecutivo

### Descripción del Proyecto
[Describe en 2-3 párrafos qué es el proyecto, qué tecnologías usaste y qué lograste]

### Objetivos Cumplidos
- [x] Sistema ELK Stack completamente funcional
- [x] Logs recolectándose en tiempo real
- [x] Visualizaciones y dashboards creados
- [x] 3 reglas de detección configuradas
- [x] 4 vulnerabilidades explotadas y documentadas

### Tecnologías Utilizadas
- Docker y Docker Compose
- OWASP Juice Shop
- Elasticsearch 8.11.0
- Kibana 8.11.0
- Filebeat 8.11.0

### Tiempo Invertido
| Paso | Tiempo Real |
|------|-------------|
| Paso 1: Juice Shop | 15 min |
| Paso 2: Elasticsearch | 10 min |
| Paso 3: Kibana | 15 min |
| Paso 4: Filebeat | 10 min |
| Paso 5: Visualización | 5 min |
| Paso 6: Blue/Red Team | 180 min |
| Documentación | 45 min |
| **TOTAL** | **___ horas** |

---

## Paso 1: Juice Shop Básico

### Objetivo
Levantar el código Javascript del proyecto Juice Shop de OWASP mediante un contenedor de Docker.

### Comandos Ejecutados

```bash
# Comando 1
docker compose up -d

# Output:
[Pega el output aquí]
```

```bash
# Comando 2
docker compose ps

# Output:
[Pega el output aquí]
```

[Continúa con todos los comandos...]

### Screenshots

#### Screenshot 1.1: Docker Compose PS
![Docker PS](paso1/compose-up.PNG)

**Descripción**: Estado del contenedor "juice-shop" en Docker

**Verificación**:
- [x] Contenedor en estado "Up"
- [x] Sin errores

#### Screenshot 1.2: Navegador en http://localhost:3000
![Interfaz Juice Shop](paso1/juice-shop-interfaz.PNG)

**Descripción**: Interaz de usuario de Juice Shop al acceder a localhost:3000

**Verificación**:
- [x] Interfaz renderiza correctamente

#### Screenshot 1.3: Terminal con curl http://localhost:3000
![CURL Juice Shop](paso1/juice-shop-curl.PNG)

**Descripción**: CURL realizado a localhost en el puerto sobre el que se está ejecutando Juice Shop

**Verificación**:
- [x] CURL devuelve el HTML esperado

#### Screenshot 1.4: Terminal con logs
![alt text](paso1/juice-shop-logs.PNG)

**Descripción**: Logs del contenedor de Docker

**Verificación**:
- [x] Log de servidor ejecutándose correctamente en el puerto 3000
- [x] Sin errores

### Verificación de Éxito
- [x] Contenedor corriendo sin errores
- [x] Puerto 3000 accesible
- [x] Interfaz web funcional
- [x] Logs generándose
- [x] 4 screenshots capturados

### Conceptos Aprendidos
1. **Docker Compose**: [Explica qué aprendiste]
2. **Port Mapping**: [Explica qué aprendiste]
3. **Container Logs**: [Explica qué aprendiste]

---

## Paso 2: Elasticsearch

### Objetivo
Agregar Elasticsearch como motor de almacenamiento de logs.

### Comandos Ejecutados

```bash
# Comando 1
docker compose up -d

# Output:
[Pega el output aquí]
```

```bash
# Comando 2
docker compose ps

# Output:
[Pega el output aquí]
```

```bash
# Comando 3
curl http://localhost:9200/_cluster/health?pretty

# Output:
[Pega el output aquí]
```

```bash
# Comando 4
curl http://localhost:9200

# Output:
[Pega el output aquí]
```

```bash
# Comando 5
curl -X POST "http://localhost:9200/test-index/_doc" \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Test log entry",
    "timestamp": "2025-11-04T10:00:00Z"
  }'

# Output:
[Pega el output aquí]
```

```bash
# Comando 6
curl "http://localhost:9200/test-index/_search?pretty"

# Output:
[Pega el output aquí]
```

```bash
# Comando 7
curl "http://localhost:9200/_cat/indices?v"

# Output:
[Pega el output aquí]
```

### Screenshots

#### Screenshot 2.1: Docker Compose PS
![Docker PS](paso2/docker-ps.PNG)

**Descripción**: Estado del contenedor "elasticsearch" en Docker

**Verificación**:
- [x] Estado del contenedor de ElasticSearch "healthy"

#### Screenshot 2.2: Salud del cluster
![Cluster Health](paso2/health.PNG)

**Descripción**: Salud del Cluster

**Verificación**:
- [x] Estado "Yellow"

#### Screenshot 2.3: Información del nodo
![Node info](paso2/node-info.PNG)

**Descripción**: Información del nodo de ElasticSearch

**Verificación**:
- [x] Puerto 9200 respondiendo

#### Screenshot 2.4: Creación de documento
![Doc created](paso2/document-created.PNG)
![Doc result](paso2/search-document.PNG)

**Descripción**: Creación de un documento en un índice de prueba

**Verificación**:
- [x] Creación exitosa del documento
- [x] Respuesta del documento creado al buscarlo

#### Screenshot 2.5: Lista de índices
![Indices List](paso2/indices-list.PNG)

**Descripción**: Lista de índices en ElasticSearch

**Verificación**:
- [x] Índice de prueba "test-index" listado

### Verificación de Éxito
- [x] Elasticsearch corriendo y healthy
- [x] Cluster en estado GREEN/YELLOW
- [x] Puerto 9200 respondiendo
- [x] Puede crear documentos
- [x] 5 screenshots capturados

### Conceptos Aprendidos
1. **Elasticsearch**: [Explica]
2. **Índices y Documentos**: [Explica]
3. **RESTful API**: [Explica]

---

## Paso 3: Kibana

### Objetivo
Agregar Kibana como interfaz visual para Elasticsearch.

### Comandos Ejecutados

```bash
# Comando 1
docker compose up -d

# Output:
[Pega el output aquí]
```

```bash
# Comando 2
docker compose ps

# Output:
[Pega el output aquí]
```

```bash
# Comando 3
curl http://localhost:5601/api/status | jq .

# Output:
[Pega el output aquí]
```

### Screenshots

#### Screenshot 3.1: docker compose ps con los 3 servicios
![Docker PS](paso3/docker-ps.PNG)

**Descripción**: Estado del contenedor "kibana" en Docker

**Verificación**:
- [x] Estado del contenedor de Kibana "healthy"

#### Screenshot 3.2: Pantalla de bienvenida de Kibana
![Docker PS](paso3/home.PNG)

**Descripción**: Pantalla de bienvenida de la interfaz de Kibana en localhost:5601

**Verificación**:
- [x] Puerto 5601 accesible
- [x] Interfaz web funcional

#### Screenshot 3.3: Dev Tools con query GET / y respuesta
![Docker PS](paso3/devtools.PNG)

**Descripción**: Funcionamiento de las Dev Tools en la interfaz

**Verificación**:
- [x] DevTools funcionando correctamente
- [x] Respuesta correcta de GET /

#### Screenshot 3.4: Estado de Kibana
![Docker PS](paso3/status.PNG)

**Descripción**: Respuesta del endpoint /api/status de Kibana

**Verificación**:
- [x] Estado "available"

### Verificación de Éxito
- [x] Kibana corriendo y healthy
- [x] Puerto 5601 accesible
- [x] Conectado a Elasticsearch
- [x] Dev Tools funcional
- [x] 4 screenshots capturados

### Conceptos Aprendidos
1. **Kibana**: [Explica]
2. **Dev Tools**: [Explica]
3. **Redes Docker**: [Explica]

---

## Paso 4: Filebeat

### Objetivo
Agregar Filebeat para conectar todo el flujo de datos.

### Comandos Ejecutados


```bash
# Comando 1
docker compose up -d

# Output:
[Pega el output aquí]
```

```bash
# Comando 2
docker compose ps

# Output:
[Pega el output aquí]
```

```bash
# Comando 3
docker compose logs filebeat | grep -i "connection"

# Output:
[Pega el output aquí]
```

```bash
# Comando 4
for i in {1..20}; do 
  curl -s http://localhost:3000 > /dev/null
  echo "Request $i"
  sleep 1
done

```bash
# Comando 5
curl "http://localhost:9200/_cat/indices?v" | grep filebeat

# Output:
[Pega el output aquí]
```
```bash
# Comando 6
curl -X GET "http://localhost:9200/filebeat-juice-shop-*/_search?size=1&pretty"

# Output:
[Pega el output aquí]
```

### Screenshots

#### Screenshot 4.1: docker compose ps con los 4 servicios
![Docker PS](paso4/docker-ps.PNG)

**Descripción**: Estado del conetendor "filebeat" en docker

**Verificación**:
- [x] Contenedor ejecutándose

#### Screenshot 4.2: Logs de Filebeat mostrando conexión
![Docker PS](paso4/logs.PNG)

**Descripción**: Logs de Filebeat

**Verificación**:
- [x] Conexión con ElasticSearch establecida

#### Screenshot 4.3: Generación de tráfico (loop de curl)
![Docker PS](paso4/curl-loop.PNG)

**Descripción**: Loop de solicitudes a localhost:3000 (Juice Shop) para generar tráfico

**Verificación**:
- [x] Solicitudes enviadas exitosamente

#### Screenshot 4.4: Índices filebeat-* creados
![Docker PS](paso4/indices-list.PNG)

**Descripción**: Lista de índices tras el tráfico generado hacia Juice Shop

**Verificación**:
- [x] Índices filebeat-*

#### Screenshot 4.5: Documento de log completo (JSON)
![Docker PS](paso4/single-log.PNG)

**Descripción**: Respuesta de la búsqueda de un log individual de filebeat

**Verificación**:
- [x] Log perteneciente al índice "filebeat-juice-shop-2025.11.21"

### Verificación de Éxito
- [x] Filebeat corriendo sin errores
- [x] Conectado a Elasticsearch
- [x] Índices filebeat-* creados
- [x] Logs con metadata completa
- [x] 5 screenshots capturados

### Conceptos Aprendidos
1. **Filebeat**: [Explica]
2. **Log Shipping**: [Explica]
3. **Processors**: [Explica]

---

## Paso 5: Visualización en Kibana

### Objetivo
[Describe el objetivo]

### Configuraciones Realizadas

#### Data Views Creados

**Data View 1: Todos los Logs**
- Name: Todos los Logs
- Index pattern: filebeat-*
- Timestamp field: @timestamp

[Describe cómo lo creaste]

#### Visualizaciones Creadas

**Visualización 1: Distribución por Contenedor**
- Tipo: Pie Chart
- Campo: container.name.keyword
- [Describe configuración]

**Visualización 2: Volumen en el Tiempo**
- Tipo: Line Chart
- [Describe configuración]

**Visualización 3: Total de Logs**
- Tipo: Metric
- [Describe configuración]

#### Dashboard Creado

**Nombre**: Overview de Logs del Sistema

**Visualizaciones incluidas**:
1. [Lista de visualizaciones]

[Describe el layout]

### Screenshots

[Mínimo 12 screenshots]

#### Screenshot 5.1: Creación de Data View
![Data View](./screenshots/paso-5/01-data-view.png)

[Continúa con todos...]

### Búsquedas KQL Utilizadas

```kql
# Búsqueda 1: Solo logs de Juice Shop
container.name: "juice-shop"
```

[Documenta todas las búsquedas que hiciste]

### Verificación de Éxito
- [ ] Data View creado
- [ ] Discover funcional
- [ ] 3 visualizaciones creadas
- [ ] Dashboard creado
- [ ] 12 screenshots capturados

### Conceptos Aprendidos
1. **Data Views**: [Explica]
2. **KQL**: [Explica]
3. **Visualizaciones**: [Explica]
4. **Dashboards**: [Explica]

---

## Paso 6: Blue Team & Red Team

### Blue Team: Reglas de Detección

#### Regla 1: Detección de SQL Injection

**Configuración**:
- Name: Detección SQL Injection
- Type: Custom query
- Query: `url.original:("*' or 1=1*" or "*union select*")`
- Severity: High
- Risk score: 75

**Prueba**:
```bash
curl "http://localhost:3000/rest/products/search?q=' OR 1=1 --"
```

**Resultado**: [Describe si se detectó]

#### Regla 2: Detección de XSS

[Sigue el mismo formato]

#### Regla 3: Detección de Scanning

[Sigue el mismo formato]

### Red Team: Vulnerabilidades Explotadas

#### Vulnerabilidad 1: SQL Injection en Login

**Descripción Técnica**:
[Explica qué es SQL Injection y cómo funciona]

**Endpoint Vulnerable**: `/rest/user/login`

**Pasos para Reproducir**:
1. [Paso 1]
2. [Paso 2]
3. [Paso 3]

**Payload Utilizado**:
```bash
curl -X POST http://localhost:3000/rest/user/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "'\'' OR 1=1--",
    "password": "anything"
  }'
```

**Response Obtenida**:
```json
[Pega la respuesta]
```

**Impacto**:
- **Confidencialidad**: 🔴 CRÍTICO - [Explica por qué]
- **Integridad**: 🔴 CRÍTICO - [Explica por qué]
- **Disponibilidad**: 🟡 MEDIO - [Explica por qué]

**Clasificación**:
- **OWASP Top 10**: A03:2021 - Injection
- **CVSS v3.1**: 9.8 (Critical)
- **Vector**: CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H

**Cálculo CVSS**:
- **AV:N** (Attack Vector: Network) - [Explica por qué]
- **AC:L** (Attack Complexity: Low) - [Explica por qué]
- **PR:N** (Privileges Required: None) - [Explica por qué]
- **UI:N** (User Interaction: None) - [Explica por qué]
- **C:H** (Confidentiality: High) - [Explica por qué]
- **I:H** (Integrity: High) - [Explica por qué]
- **A:H** (Availability: High) - [Explica por qué]

**Screenshots**:
![SQLi Request](./screenshots/paso-6/sqli-01-request.png)
![SQLi Response](./screenshots/paso-6/sqli-02-response.png)

#### Vulnerabilidad 2: Cross-Site Scripting (XSS)

[Sigue el mismo formato detallado]

#### Vulnerabilidad 3: Broken Authentication

[Sigue el mismo formato detallado]

#### Vulnerabilidad 4: Broken Access Control

[Sigue el mismo formato detallado]

### Coordinación Red Team - Blue Team

**Resultados de Detección**:
| Ataque | Detectado | Tiempo de Detección |
|--------|-----------|---------------------|
| SQL Injection | [Sí/No] | [Tiempo] |
| XSS | [Sí/No] | [Tiempo] |
| Auth Bypass | [Sí/No] | [Tiempo] |
| Access Control | [Sí/No] | [Tiempo] |

### Screenshots

[Mínimo 12 screenshots]

### Verificación de Éxito
- [ ] 3 reglas de detección configuradas
- [ ] 4 vulnerabilidades explotadas
- [ ] Alertas generadas
- [ ] Dashboard de detecciones creado
- [ ] 12 screenshots capturados
- [ ] Vulnerabilidades con CVSS calculado

### Conceptos Aprendidos
1. **Reglas de Detección**: [Explica]
2. **SQL Injection**: [Explica]
3. **XSS**: [Explica]
4. **CVSS Scoring**: [Explica]
5. **OWASP Top 10**: [Explica]

---

## Análisis Técnico

### Arquitectura Completa del Sistema

```
[Dibuja o pega el diagrama de arquitectura]
```

**Componentes**:
1. **Juice Shop**: [Explica su rol]
2. **Docker Engine**: [Explica su rol]
3. **Filebeat**: [Explica su rol]
4. **Elasticsearch**: [Explica su rol]
5. **Kibana**: [Explica su rol]

### Flujo de Datos Detallado

```
Usuario → Juice Shop → Docker Logs → Filebeat → Elasticsearch → Kibana
```

**Explicación paso a paso**:
1. [Explica paso 1]
2. [Explica paso 2]
3. [Explica paso 3]
[...]

### Decisiones de Diseño

#### Decisión 1: [Título]
**Contexto**: [Por qué se necesitaba tomar una decisión]
**Decisión Tomada**: [Cuál se eligió]
**Justificación**: [Por qué se eligió]

[Repite para otras decisiones importantes]

---

## Problemas y Soluciones

### Resumen de Problemas

| Paso | Problema | Solución | Tiempo Perdido |
|------|----------|----------|----------------|
| [#] | [Descripción corta] | [Solución corta] | [minutos] |

### Detalle de Problemas Principales

#### Problema 1: [Título]

**Paso**: [En qué paso ocurrió]

**Descripción**: [Descripción detallada]

**Error Exacto**:
```
[Mensaje de error]
```

**Causa Raíz**: [Por qué ocurrió]

**Intentos de Solución**:
1. [Intento 1] - Resultado: [Funcionó/No funcionó]
2. [Intento 2] - Resultado: [Funcionó/No funcionó]

**Solución Final**:
```bash
[Comandos que resolvieron]
```

**Lección Aprendida**: [Qué aprendiste]

[Repite para otros problemas importantes]

---

## Conclusiones

### Logros Principales

1. [Logro 1]
2. [Logro 2]
3. [Logro 3]

### Reflexión Personal

[Escribe 2-3 párrafos sobre:
- ¿Qué fue lo más desafiante?
- ¿Qué fue lo más interesante?
- ¿Cómo te ayudará esto en tu carrera?
- ¿Qué harías diferente la próxima vez?]

### Aplicaciones Prácticas

**En el mundo real, este sistema se podría usar para**:
1. [Aplicación 1]
2. [Aplicación 2]
3. [Aplicación 3]

### Habilidades Desarrolladas

- [ ] Administración de contenedores Docker
- [ ] Configuración de sistemas de logging
- [ ] Análisis de logs de seguridad
- [ ] Creación de visualizaciones de datos
- [ ] Detección de amenazas
- [ ] Explotación de vulnerabilidades (ético)
- [ ] Documentación técnica
- [ ] Troubleshooting

---

## Anexos

### Anexo A: Comandos Completos

```bash
# Paso 1: Juice Shop
git checkout paso-1-juice-shop
docker compose up -d
[... todos los comandos ...]

# Paso 2: Elasticsearch
[... todos los comandos ...]

# [Continuar para todos los pasos]
```

### Anexo B: Reglas de Detección (JSON)

```json
[Pega el export de reglas de Kibana]
```

### Anexo C: Dashboard Export

```json
[Pega el export del dashboard]
```

---

## Estadísticas del Proyecto

- **Total de Screenshots**: ___ (mínimo 42)
- **Total de Comandos Ejecutados**: ___
- **Total de Vulnerabilidades Explotadas**: 4
- **Total de Reglas de Detección**: 3
- **Total de Visualizaciones Creadas**: 3
- **Total de Dashboards Creados**: 2
- **Tiempo Total Invertido**: ___ horas

---

## Checklist de Entrega

### Documentación
- [ ] Reporte completo
- [ ] Todos los pasos documentados
- [ ] Screenshots de calidad
- [ ] Comandos con outputs
- [ ] Problemas explicados

### Red Team
- [ ] 4 vulnerabilidades explotadas
- [ ] Cada una con PoC completo
- [ ] CVSS calculado
- [ ] OWASP Top 10 clasificación

### Blue Team
- [ ] 3 reglas configuradas
- [ ] Alertas funcionando
- [ ] Dashboard de detecciones
- [ ] Informe de respuesta

### Archivos
- [ ] reporte-final.pdf o .md
- [ ] screenshots/ organizado
- [ ] comandos.txt
- [ ] reglas-deteccion.json
- [ ] dashboard-export.ndjson

---

**Fin del Reporte**

**Fecha de Entrega**: ___________________________  
**Firma**: ___________________________
