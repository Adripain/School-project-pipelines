# TP DevOps - Landing Page

Landing page statique simple pour un TP DevOps. Le site est ecrit en HTML, CSS et JavaScript vanilla, servi par Nginx dans Docker, puis deploye sur un serveur VPN avec Jenkins et Docker Compose.

Le projet evite volontairement la sur-ingenierie : pas de framework, pas de base de donnees, pas de dependance front-end.

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
├── deploy/
│   └── deploy.sh
└── .env.example
```

## Pre-requis

- Git
- Docker
- Docker Compose v2
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

URL locale attendue :

```text
http://localhost:8085
```

Si le port `8085` est deja utilise, modifier `APP_PORT` dans `.env`, par exemple :

```env
APP_PORT=8090
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
DEPLOY_PATH=/opt/tp-devops-landing
DEPLOY_HOST=CHANGE_ME
DEPLOY_USER=CHANGE_ME
```

Pour travailler localement, creer un fichier `.env` :

```bash
cp .env.example .env
```

Le fichier `.env` ne doit pas etre versionne.

## Mise en place Jenkins

1. Creer un nouveau job Jenkins de type `Pipeline`.
2. Configurer le job pour recuperer le repository GitHub.
3. Utiliser le `Jenkinsfile` present dans le repository.
4. Ajouter des credentials SSH dans Jenkins, par exemple avec l'identifiant `vpn-ssh-key`.
5. Definir les variables Jenkins suivantes :

```text
DEPLOY_HOST=CHANGE_ME
DEPLOY_USER=CHANGE_ME
DEPLOY_PATH=/opt/tp-devops-landing
SSH_CREDENTIALS_ID=vpn-ssh-key
```

6. Activer l'option Jenkins :

```text
GitHub hook trigger for GITScm polling
```

7. Dans GitHub, creer un webhook vers :

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
- construit l'image Docker ;
- controle que le titre HTML attendu est present ;
- synchronise le projet vers le serveur VPN ;
- execute `deploy/deploy.sh` sur le serveur ;
- lance `docker compose up -d --build`.

Le script `deploy/deploy.sh` ne supprime aucun autre conteneur, volume ou reseau Docker. Il se limite au projet courant.

## Securite

- Ne pas versionner le fichier `.env`.
- Ne jamais stocker de mot de passe, cle privee SSH ou token dans GitHub.
- Utiliser Jenkins Credentials pour les acces SSH.
- Limiter les ports exposes sur le VPN.
- Choisir un port `APP_PORT` qui n'est pas deja utilise par un autre service.
- Garder Jenkins et Docker a jour.

## Ameliorations possibles

- Ajouter HTTPS via un reverse proxy existant.
- Ajouter des tests plus complets sur le HTML et les assets.
- Ajouter un scan de l'image Docker.
- Ajouter du monitoring ou une verification de sante HTTP.
- Publier l'image dans un registre Docker prive ou GitHub Container Registry.
