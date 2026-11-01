#!/usr/bin/env bash
# =========================================================================
# run-all.sh : reconstruye las 3 imágenes (arm64 local), limpia contenedores
# previos y levanta app-php (8081), app-ruby (8082) y app-dart (8083).
# Al final verifica salud con curl y resume con docker ps / docker images.
# =========================================================================
set -euo pipefail

DOCKERHUB_USER="${DOCKERHUB_USER:-coste123}"
PROJECT_PREFIX="madeo07"
VERSION="1.0.0"
PLATFORM_LOCAL="${PLATFORM_LOCAL:-linux/arm64}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPS=(
  "php|8081|${ROOT_DIR}/app-php"
  "ruby|8082|${ROOT_DIR}/app-ruby"
  "dart|8083|${ROOT_DIR}/app-dart"
)

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

say "Paso 1/4 - Parando y eliminando contenedores previos (si existen)"
for entry in "${APPS[@]}"; do
  IFS='|' read -r lang port _ <<< "$entry"
  name="app-${lang}"
  if docker ps -a --format '{{.Names}}' | grep -qx "$name"; then
    echo "  - removiendo $name"
    docker rm -f "$name" >/dev/null
  else
    echo "  - $name no existía, nada que remover"
  fi
done

say "Paso 2/4 - Build local (${PLATFORM_LOCAL}) de las 3 imágenes"
for entry in "${APPS[@]}"; do
  IFS='|' read -r lang port ctx <<< "$entry"
  tag_versioned="${DOCKERHUB_USER}/${PROJECT_PREFIX}-${lang}:${VERSION}"
  tag_latest="${DOCKERHUB_USER}/${PROJECT_PREFIX}-${lang}:latest"
  echo "  - construyendo ${tag_versioned} y ${tag_latest} desde ${ctx}"
  docker buildx build \
    --platform "${PLATFORM_LOCAL}" \
    --load \
    -t "${tag_versioned}" \
    -t "${tag_latest}" \
    "${ctx}"
done

say "Paso 3/4 - Levantando los 3 contenedores en background"
for entry in "${APPS[@]}"; do
  IFS='|' read -r lang port _ <<< "$entry"
  tag_versioned="${DOCKERHUB_USER}/${PROJECT_PREFIX}-${lang}:${VERSION}"
  name="app-${lang}"
  echo "  - docker run -d --name ${name} -p ${port}:${port} ${tag_versioned}"
  docker run -d --name "${name}" -p "${port}:${port}" "${tag_versioned}" >/dev/null
done

say "Paso 4/4 - Verificaciones (esperando 3 s a que los procesos respondan)"
sleep 3

for entry in "${APPS[@]}"; do
  IFS='|' read -r lang port _ <<< "$entry"
  echo "  - curl http://localhost:${port}/health"
  code=$(curl -s -o /tmp/health-"${lang}".json -w "%{http_code}" "http://localhost:${port}/health" || true)
  body=$(cat /tmp/health-"${lang}".json 2>/dev/null || echo '')
  printf "      HTTP %s  body=%s\n" "$code" "$body"
done

echo
echo "docker ps:"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
echo
echo "docker images (solo las de la actividad):"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}" | grep -E "REPOSITORY|${DOCKERHUB_USER}/${PROJECT_PREFIX}-"
echo
say "Listo. Abre http://localhost:8081, http://localhost:8082 y http://localhost:8083 en el navegador."
