#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[deploy] $*"
}

require_var() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "[deploy] Variable manquante: ${name}" >&2
    exit 1
  fi
}

require_var "DEPLOY_PATH"

APP_PORT="${APP_PORT:-8085}"
CONTAINER_NAME="${CONTAINER_NAME:-tp-devops-landing}"
DOCKER_IMAGE="${DOCKER_IMAGE:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_SOURCE="$(cd "${SCRIPT_DIR}/.." && pwd)"

set_env_var() {
  local key="$1"
  local value="$2"
  local tmp_file

  if grep -q "^${key}=" ".env"; then
    tmp_file="$(mktemp)"
    awk -v key="${key}" -v value="${value}" '
      BEGIN { prefix = key "=" }
      index($0, prefix) == 1 { $0 = key "=" value }
      { print }
    ' ".env" > "${tmp_file}"
    mv "${tmp_file}" ".env"
  else
    printf '\n%s=%s\n' "${key}" "${value}" >> ".env"
  fi
}

required_files=(
  "index.html"
  "styles.css"
  "script.js"
  "Dockerfile"
  "docker-compose.yml"
  ".env.example"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "${PROJECT_SOURCE}/${file}" ]]; then
    echo "[deploy] Fichier requis introuvable: ${PROJECT_SOURCE}/${file}" >&2
    exit 1
  fi
done

log "Preparation du dossier de deploiement: ${DEPLOY_PATH}"
mkdir -p "${DEPLOY_PATH}"

SOURCE_REALPATH="$(cd "${PROJECT_SOURCE}" && pwd)"
TARGET_REALPATH="$(cd "${DEPLOY_PATH}" && pwd)"

if [[ "${SOURCE_REALPATH}" != "${TARGET_REALPATH}" ]]; then
  log "Synchronisation des fichiers du projet vers ${DEPLOY_PATH}"

  if command -v rsync >/dev/null 2>&1; then
    rsync -az --delete \
      --exclude '.git/' \
      --exclude '.env' \
      --exclude 'node_modules/' \
      "${PROJECT_SOURCE}/" "${DEPLOY_PATH}/"
  else
    log "rsync indisponible, copie simple des fichiers essentiels."
    cp "${PROJECT_SOURCE}/index.html" "${DEPLOY_PATH}/"
    cp "${PROJECT_SOURCE}/styles.css" "${DEPLOY_PATH}/"
    cp "${PROJECT_SOURCE}/script.js" "${DEPLOY_PATH}/"
    cp "${PROJECT_SOURCE}/Dockerfile" "${DEPLOY_PATH}/"
    cp "${PROJECT_SOURCE}/docker-compose.yml" "${DEPLOY_PATH}/"
    cp "${PROJECT_SOURCE}/.env.example" "${DEPLOY_PATH}/"
    mkdir -p "${DEPLOY_PATH}/deploy"
    cp "${PROJECT_SOURCE}/deploy/deploy.sh" "${DEPLOY_PATH}/deploy/deploy.sh"
  fi
fi

cd "${DEPLOY_PATH}"

if [[ ! -f ".env" ]]; then
  log "Creation du fichier .env depuis .env.example"
  cp ".env.example" ".env"
fi

if ! grep -q '^APP_PORT=' ".env"; then
  log "Ajout de APP_PORT=${APP_PORT} dans .env"
  printf '\nAPP_PORT=%s\n' "${APP_PORT}" >> ".env"
fi

if [[ -n "${DOCKER_IMAGE}" ]]; then
  log "Configuration de l'image Docker: ${DOCKER_IMAGE}"
  set_env_var "DOCKER_IMAGE" "${DOCKER_IMAGE}"
fi

chmod +x "deploy/deploy.sh"

log "Verification du reseau Docker externe devops"
docker network inspect devops >/dev/null 2>&1 || docker network create devops

existing_container_id="$(docker ps -aq --filter "name=^/${CONTAINER_NAME}$" | head -n 1)"
compose_container_id="$(docker compose ps -q tp-devops-landing 2>/dev/null | head -n 1 || true)"

if [[ -n "${existing_container_id}" && "${existing_container_id}" != "${compose_container_id}" ]]; then
  log "Suppression du conteneur en conflit: ${CONTAINER_NAME}"
  docker rm -f "${CONTAINER_NAME}"
fi

if [[ -n "${DOCKER_IMAGE}" ]]; then
  log "Pull de l'image publiee: ${DOCKER_IMAGE}"
  docker compose pull

  log "Demarrage du conteneur depuis l'image publiee"
  docker compose up -d
else
  log "Construction locale et demarrage du conteneur"
  docker compose up -d --build
fi

log "Statut final"
docker compose ps
