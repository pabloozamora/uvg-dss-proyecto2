# Guía Rápida de Inicio

Guía express para levantar el sistema en 5 minutos.

## ⚡ Inicio Rápido

### Prerrequisitos
- Docker y Docker Compose instalados
- 4 GB de RAM disponible
- Puertos libres: 3000, 5601, 8080, 9200

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/pabloozamora/uvg-dss-proyecto2.git
cd uvg-dss-proyecto2/src

# 2. Levantar todos los servicios
docker compose up -d

# 3. Esperar 2-3 minutos y verificar el estado
docker compose ps

# 4. Acceder a las aplicaciones
# Juice Shop: http://localhost:3000
# Kibana: http://localhost:5601 (usuario: elastic, password: changeme)
```

### Verificación Rápida

```bash
# Verificar Elasticsearch
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# Verificar Juice Shop
curl http://localhost:3000

# Ver logs
docker compose logs -f
```

### Generar Logs de Prueba

```bash
# Generar tráfico HTTP
for i in {1..20}; do curl -s http://localhost:3000 > /dev/null; sleep 1; done
```

### Configurar Kibana

1. Abre http://localhost:5601
2. Login: `elastic` / `changeme`
3. Ve a **Management** → **Stack Management** → **Data Views**
4. Crear Data View:
   - Name: `Logs de Juice Shop`
   - Index pattern: `filebeat-*`
   - Timestamp: `@timestamp`
5. Ve a **Discover** para ver los logs

## 🆘 Problemas Comunes

**No se ven logs en Kibana:**
- Espera 2-3 minutos después de levantar los servicios
- Genera tráfico con `curl http://localhost:3000`
- Ajusta el rango de tiempo en Kibana a "Last 24 hours"

**Puerto ya en uso:**
```bash
# Ver qué usa el puerto
sudo lsof -i :9200
# Detener el proceso conflictivo o cambiar el puerto en docker-compose.yml
```

**Contenedor no arranca:**
```bash
# Ver logs del contenedor problemático
docker compose logs elasticsearch
# Reiniciar
docker compose restart elasticsearch
```

**Reiniciar todo:**
```bash
docker compose down
docker compose up -d
```

## 📚 Más Información

Para instrucciones detalladas, consulta [README.md](README.md)

## 🎯 URLs Útiles

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| Juice Shop | http://localhost:3000 | - |
| Juice Shop (Proxy) | http://localhost:8080 | - |
| Kibana | http://localhost:5601 | elastic / changeme |
| Elasticsearch | http://localhost:9200 | elastic / changeme |

## 🚀 Siguiente Paso

Una vez que todo esté funcionando, revisa [REPORTE.md](REPORTE.md) para seguir los pasos del proyecto completo.
