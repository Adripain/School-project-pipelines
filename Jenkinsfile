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
                echo 'Build: construction de l image Docker avec Docker Compose.'
                sh '''#!/usr/bin/env bash
set -euo pipefail

docker compose build
'''
            }
        }

        stage('Test') {
            steps {
                echo 'Test: controle du contenu HTML et de la configuration Compose.'
                sh '''#!/usr/bin/env bash
set -euo pipefail

grep -Fq "TP DevOps - Landing Page" index.html
docker compose config >/dev/null

echo "Les controles simples sont valides."
'''
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
: "${SSH_KEY_FILE:?Cle SSH Jenkins introuvable}"

remote="${DEPLOY_USER}@${DEPLOY_HOST}"
ssh_options="-i ${SSH_KEY_FILE} -o StrictHostKeyChecking=accept-new"

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
ssh ${ssh_options} "${remote}" "cd '${DEPLOY_PATH}' && chmod +x deploy/deploy.sh && DEPLOY_PATH='${DEPLOY_PATH}' ./deploy/deploy.sh"
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
