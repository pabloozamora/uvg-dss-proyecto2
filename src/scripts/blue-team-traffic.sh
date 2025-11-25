#!/bin/bash
# Script de tráfico legítimo para Blue Team
# Genera requests normales para establecer baseline

echo "=== Iniciando tráfico legítimo Blue Team ==="
echo "Timestamp: $(date -u)"

ENDPOINTS=(
  "http://localhost:3000"
  "http://localhost:3000/#/login"
  "http://localhost:3000/rest/products/search?q=apple"
  "http://localhost:3000/rest/products/search?q=juice"
  "http://localhost:3000/api/Products"
)

for url in "${ENDPOINTS[@]}"; do
  curl -s "$url" > /dev/null
  echo "$(date -u) OK $url"
  sleep 5
done

echo "=== Tráfico legítimo completado ==="
echo "Timestamp: $(date -u)"
