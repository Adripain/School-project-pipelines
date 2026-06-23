# TP DevOps - Landing Page et API NodeJS

Projet simple pour un TP DevOps. Il contient une landing page statique ecrite en HTML, CSS et JavaScript vanilla, ainsi qu'une API NodeJS minimale. Les deux services sont dockerises, publies sur DockerHub, puis deployes sur un serveur VPN avec Jenkins et Docker Compose.

Le projet evite volontairement la sur-ingenierie : pas de framework front-end, pas de base de donnees, et une API NodeJS sans dependance externe.

Pour la consigne Azure, la VM Ubuntu Azure est remplacee par un VPS Ubuntu personnel faute de credits Azure disponibles. Les etapes techniques restent equivalentes : serveur Linux, port applicatif ouvert, Docker, Docker Compose, Jenkins, image DockerHub et deploiement automatise.

## Arborescence

```text
.
├── index.html
├── styles.css
├── script.js
├── Dockerfile
├── docker-compose.yml
├── Jenkinsfile
├── .dockerignore
├── .gitignore
├── README.md
├── api/
│   ├── Dockerfile
│   ├── package.json
│   ├── server.js
│   └── test.js
├── deploy/
│   └── deploy.sh
└── .env.example
```

## Pre-requis

- Git
- Docker
- Docker Compose v2
- Compte DockerHub
- Jenkins
- rsync sur l'agent Jenkins et sur le serveur VPN
- Acces SSH au serveur VPN
- Un repository GitHub pour le projet

Sur le serveur VPN, Docker doit etre installe et l'utilisateur utilise par Jenkins doit avoir le droit de lancer Docker.

## Lancement local

Copier le fichier d'exemple, creer le reseau Docker externe, puis lancer le conteneur :

```bash
cp .env.example .env
docker network create devops
docker compose up -d --build
```

URLs locales attendues :

```text
Landing page : http://localhost:8085
API NodeJS   : http://localhost:8086
Healthcheck  : http://localhost:8086/health
```

Si le port `8085` ou `8086` est deja utilise, modifier `APP_PORT` ou `API_PORT` dans `.env`, par exemple :

```env
APP_PORT=8090
API_PORT=8091
```

## Commandes utiles

Afficher les logs :

```bash
docker compose logs -f
```

Voir le statut :

```bash
docker compose ps
```

Reconstruire et relancer :

```bash
docker compose up -d --build
```

Arreter le conteneur du projet :

```bash
docker compose down
```

Cette commande arrete uniquement les services declares dans ce projet. Elle ne supprime pas les autres conteneurs du serveur.

## Configuration

Le fichier `.env.example` contient les valeurs d'exemple :

```env
APP_PORT=8085
API_PORT=8086
DOCKER_IMAGE=your-dockerhub-user/tp-devops-landing:latest
API_DOCKER_IMAGE=your-dockerhub-user/tp-devops-api:latest
DEPLOY_PATH=/opt/tp-devops-landing
DEPLOY_HOST=CHANGE_ME
DEPLOY_USER=CHANGE_ME
```

Pour travailler localement, creer un fichier `.env` :

```bash
cp .env.example .env
```

Le fichier `.env` ne doit pas etre versionne.

Si le port `80` est disponible sur le serveur, il est possible de modifier `APP_PORT` :

```env
APP_PORT=80
```

Si un autre service utilise deja le port `80`, conserver un port dedie comme `8085`. L'API utilise un port separe, par defaut `8086`.

## DockerHub

La pipeline construit deux tags pour chaque image :

```text
DOCKERHUB_IMAGE:BUILD_NUMBER
DOCKERHUB_IMAGE:latest
DOCKERHUB_API_IMAGE:BUILD_NUMBER
DOCKERHUB_API_IMAGE:latest
```

Exemple de valeur Jenkins pour l'image :

```text
DOCKERHUB_IMAGE=your-dockerhub-user/tp-devops-landing
DOCKERHUB_API_IMAGE=your-dockerhub-user/tp-devops-api
```

Dans Jenkins, creer aussi un credential DockerHub de type `Username with password`.

Valeurs conseillees :

```text
ID: dockerhub-credentials
Username: votre identifiant DockerHub
Password: un access token DockerHub
```

Il est preferable d'utiliser un token DockerHub plutot que le mot de passe du compte.

## Mise en place Jenkins

1. Creer un nouveau job Jenkins de type `Pipeline`.
2. Configurer le job pour recuperer le repository GitHub.
3. Utiliser le `Jenkinsfile` present dans le repository.
4. Ajouter des credentials SSH dans Jenkins, par exemple avec l'identifiant `vpn-local-ssh`.
5. Ajouter des credentials DockerHub dans Jenkins, par exemple avec l'identifiant `dockerhub-credentials`.
6. Definir les variables Jenkins suivantes :

```text
DEPLOY_HOST=localhost
DEPLOY_USER=ubuntu
DEPLOY_PATH=/opt/tp-devops-landing
SSH_CREDENTIALS_ID=vpn-local-ssh
DOCKERHUB_IMAGE=your-dockerhub-user/tp-devops-landing
DOCKERHUB_API_IMAGE=your-dockerhub-user/tp-devops-api
DOCKERHUB_CREDENTIALS_ID=dockerhub-credentials
```

7. Activer l'option Jenkins :

```text
GitHub hook trigger for GITScm polling
```

8. Dans GitHub, creer un webhook vers :

```text
https://MON_JENKINS_URL/github-webhook/
```

Le webhook permet de declencher automatiquement la pipeline Jenkins lorsqu'un push est effectue sur GitHub.

## Utiliser ngrok temporairement

Si Jenkins tourne sur une machine locale non accessible depuis GitHub, ngrok peut exposer Jenkins temporairement :

```bash
ngrok http 8080
```

Ngrok fournit une URL publique temporaire. Utiliser ensuite cette URL dans le webhook GitHub :

```text
https://URL_NGROK/github-webhook/
```

Cette solution est pratique pour un TP ou une demonstration. Pour un usage durable, il vaut mieux exposer Jenkins proprement derriere un reverse proxy securise.

## Deploiement sur serveur VPN

Le deploiement final se fait dans un dossier dedie, par exemple :

```text
/opt/tp-devops-landing
```

Commandes a executer une premiere fois sur le serveur VPN :

```bash
sudo mkdir -p /opt/tp-devops-landing
sudo chown -R "$USER:$USER" /opt/tp-devops-landing
docker network inspect devops >/dev/null 2>&1 || docker network create devops
```

Ensuite, depuis Jenkins, la pipeline :

- recupere le code depuis GitHub ;
- verifie les fichiers obligatoires ;
- construit les images Docker de la landing page et de l'API NodeJS ;
- controle que le titre HTML et les endpoints API attendus sont presents ;
- publie les deux images sur DockerHub ;
- synchronise le projet vers le serveur VPN ;
- execute `deploy/deploy.sh` sur le serveur ;
- pull les images DockerHub publiees ;
- lance `docker compose up -d`.

Le script `deploy/deploy.sh` ne supprime aucun autre conteneur, volume ou reseau Docker. Il se limite au projet courant.

Pour tester manuellement le deploiement avec une image DockerHub :

```bash
cd /opt/tp-devops-landing
DOCKER_IMAGE=your-dockerhub-user/tp-devops-landing:latest \
API_DOCKER_IMAGE=your-dockerhub-user/tp-devops-api:latest \
DEPLOY_PATH=/opt/tp-devops-landing \
./deploy/deploy.sh
```

Verification apres deploiement :

```bash
curl -I http://localhost:8085
curl -s http://localhost:8085 | grep "TP DevOps - Landing Page"
curl -s http://localhost:8086/health
docker compose ps
```

## Securite

- Ne pas versionner le fichier `.env`.
- Ne jamais stocker de mot de passe, cle privee SSH ou token dans GitHub.
- Utiliser Jenkins Credentials pour les acces SSH et DockerHub.
- Limiter les ports exposes sur le VPN.
- Choisir des ports `APP_PORT` et `API_PORT` qui ne sont pas deja utilises par un autre service.
- Garder Jenkins et Docker a jour.

## Ameliorations possibles

- Ajouter HTTPS via un reverse proxy existant.
- Ajouter des tests plus complets sur le HTML et les assets.
- Ajouter un scan de l'image Docker.
- Ajouter du monitoring ou une verification de sante HTTP.
- Publier aussi l'image dans un registre prive ou GitHub Container Registry.
