pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checkout: recuperation du code depuis GitHub.'
                checkout scm
            }
        }

        stage('Validate') {
            steps {
                echo 'Validate: verification des fichiers obligatoires.'
                sh '''#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "index.html"
  "Dockerfile"
  "docker-compose.yml"
  "deploy/deploy.sh"
  "api/package.json"
  "api/server.js"
  "api/Dockerfile"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Fichier manquant: $file"
    exit 1
  fi
done

echo "Tous les fichiers obligatoires sont presents."
'''
            }
        }

        stage('Build') {
            steps {
                echo 'Build: construction des images Docker landing page et API.'
                script {
                    if (env.DOCKERHUB_IMAGE == null || env.DOCKERHUB_IMAGE.trim() == '') {
                        error 'Variable Jenkins DOCKERHUB_IMAGE manquante'
                    }
                    if (env.DOCKERHUB_API_IMAGE == null || env.DOCKERHUB_API_IMAGE.trim() == '') {
                        error 'Variable Jenkins DOCKERHUB_API_IMAGE manquante'
                    }
                }
                sh '''#!/usr/bin/env bash
set -euo pipefail

: "${DOCKERHUB_IMAGE:?Variable Jenkins DOCKERHUB_IMAGE manquante}"
: "${DOCKERHUB_API_IMAGE:?Variable Jenkins DOCKERHUB_API_IMAGE manquante}"
: "${BUILD_NUMBER:?Variable Jenkins BUILD_NUMBER manquante}"

if [[ "${DOCKERHUB_IMAGE}" == *:* ]]; then
  echo "DOCKERHUB_IMAGE ne doit pas contenir de tag. Exemple: your-dockerhub-user/tp-devops-landing"
  exit 1
fi

if [[ "${DOCKERHUB_API_IMAGE}" == *:* ]]; then
  echo "DOCKERHUB_API_IMAGE ne doit pas contenir de tag. Exemple: your-dockerhub-user/tp-devops-api"
  exit 1
fi

docker build \
  -t "${DOCKERHUB_IMAGE}:${BUILD_NUMBER}" \
  -t "${DOCKERHUB_IMAGE}:latest" \
  .

docker build \
  -t "${DOCKERHUB_API_IMAGE}:${BUILD_NUMBER}" \
  -t "${DOCKERHUB_API_IMAGE}:latest" \
  ./api
'''
            }
        }

        stage('Test') {
            steps {
                echo 'Test: controle du contenu landing page, API NodeJS et configuration Compose.'
                sh '''#!/usr/bin/env bash
set -euo pipefail

grep -Fq "TP DevOps - Landing Page" index.html
grep -Fq "TP DevOps API NodeJS" api/server.js
grep -Fq "/health" api/server.js
docker compose config >/dev/null
docker image inspect "${DOCKERHUB_IMAGE}:${BUILD_NUMBER}" >/dev/null
docker image inspect "${DOCKERHUB_API_IMAGE}:${BUILD_NUMBER}" >/dev/null

echo "Les controles simples sont valides."
'''
            }
        }

        stage('Push DockerHub') {
            when {
                anyOf {
                    branch 'main'
                    expression { env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main' }
                }
            }
            steps {
                echo 'Push DockerHub: publication des images Docker landing page et API.'
                script {
                    if (env.DOCKERHUB_CREDENTIALS_ID == null || env.DOCKERHUB_CREDENTIALS_ID.trim() == '') {
                        error 'Variable Jenkins DOCKERHUB_CREDENTIALS_ID manquante'
                    }
                }
                withCredentials([
                    usernamePassword(
                        credentialsId: env.DOCKERHUB_CREDENTIALS_ID,
                        usernameVariable: 'DOCKERHUB_USERNAME',
                        passwordVariable: 'DOCKERHUB_TOKEN'
                    )
                ]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail

: "${DOCKERHUB_IMAGE:?Variable Jenkins DOCKERHUB_IMAGE manquante}"
: "${DOCKERHUB_API_IMAGE:?Variable Jenkins DOCKERHUB_API_IMAGE manquante}"
: "${BUILD_NUMBER:?Variable Jenkins BUILD_NUMBER manquante}"
: "${DOCKERHUB_USERNAME:?Identifiant DockerHub Jenkins introuvable}"
: "${DOCKERHUB_TOKEN:?Token DockerHub Jenkins introuvable}"

echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin
docker push "${DOCKERHUB_IMAGE}:${BUILD_NUMBER}"
docker push "${DOCKERHUB_IMAGE}:latest"
docker push "${DOCKERHUB_API_IMAGE}:${BUILD_NUMBER}"
docker push "${DOCKERHUB_API_IMAGE}:latest"
docker logout
'''
                }
            }
        }

        stage('Deploy') {
            when {
                anyOf {
                    branch 'main'
                    expression { env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main' }
                }
            }
            steps {
                echo 'Deploy: synchronisation et lancement sur le serveur VPN.'
                script {
                    if (env.DEPLOY_HOST == null || env.DEPLOY_HOST.trim() == '') {
                        error 'Variable Jenkins DEPLOY_HOST manquante'
                    }
                    if (env.DEPLOY_USER == null || env.DEPLOY_USER.trim() == '') {
                        error 'Variable Jenkins DEPLOY_USER manquante'
                    }
                    if (env.DEPLOY_PATH == null || env.DEPLOY_PATH.trim() == '') {
                        error 'Variable Jenkins DEPLOY_PATH manquante'
                    }
                    if (env.SSH_CREDENTIALS_ID == null || env.SSH_CREDENTIALS_ID.trim() == '') {
                        error 'Variable Jenkins SSH_CREDENTIALS_ID manquante'
                    }
                    if (env.DOCKERHUB_IMAGE == null || env.DOCKERHUB_IMAGE.trim() == '') {
                        error 'Variable Jenkins DOCKERHUB_IMAGE manquante'
                    }
                    if (env.DOCKERHUB_API_IMAGE == null || env.DOCKERHUB_API_IMAGE.trim() == '') {
                        error 'Variable Jenkins DOCKERHUB_API_IMAGE manquante'
                    }
                }
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: env.SSH_CREDENTIALS_ID,
                        keyFileVariable: 'SSH_KEY_FILE',
                        usernameVariable: 'SSH_CREDENTIAL_USER'
                    )
                ]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail

: "${DEPLOY_HOST:?Variable Jenkins DEPLOY_HOST manquante}"
: "${DEPLOY_USER:?Variable Jenkins DEPLOY_USER manquante}"
: "${DEPLOY_PATH:?Variable Jenkins DEPLOY_PATH manquante}"
: "${SSH_CREDENTIALS_ID:?Variable Jenkins SSH_CREDENTIALS_ID manquante}"
: "${DOCKERHUB_IMAGE:?Variable Jenkins DOCKERHUB_IMAGE manquante}"
: "${DOCKERHUB_API_IMAGE:?Variable Jenkins DOCKERHUB_API_IMAGE manquante}"
: "${BUILD_NUMBER:?Variable Jenkins BUILD_NUMBER manquante}"
: "${SSH_KEY_FILE:?Cle SSH Jenkins introuvable}"

remote="${DEPLOY_USER}@${DEPLOY_HOST}"
ssh_options="-i ${SSH_KEY_FILE} -o StrictHostKeyChecking=accept-new"
docker_image="${DOCKERHUB_IMAGE}:${BUILD_NUMBER}"
api_docker_image="${DOCKERHUB_API_IMAGE}:${BUILD_NUMBER}"

echo "Creation du dossier distant si necessaire: ${DEPLOY_PATH}"
ssh ${ssh_options} "${remote}" "mkdir -p '${DEPLOY_PATH}'"

echo "Synchronisation des fichiers vers le serveur VPN."
rsync -az --delete \
  -e "ssh ${ssh_options}" \
  --exclude '.git/' \
  --exclude '.env' \
  --exclude 'node_modules/' \
  ./ "${remote}:${DEPLOY_PATH}/"

echo "Execution du script de deploiement distant."
ssh ${ssh_options} "${remote}" "cd '${DEPLOY_PATH}' && chmod +x deploy/deploy.sh && DEPLOY_PATH='${DEPLOY_PATH}' DOCKER_IMAGE='${docker_image}' API_DOCKER_IMAGE='${api_docker_image}' ./deploy/deploy.sh"
'''
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline terminee avec succes.'
        }
        failure {
            echo 'Pipeline en echec. Consulte les logs Jenkins pour identifier l etape concernee.'
        }
    }
}
