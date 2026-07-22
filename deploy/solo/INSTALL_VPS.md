# Installer TwentyCRM sur un VPS — guide pas à pas pour débutant

> Objectif : avoir ton CRM en ligne sur un serveur (VPS) sous **Ubuntu**, accessible
> via `http://TON_IP:3000`. On explique chaque notion au passage.
> Profil visé : tu n'as jamais (ou presque) touché à Docker ni à un serveur Linux.
>
> ⏱️ Compte ~45 min la première fois. Garde ce fichier ouvert à côté.

---

## 🧠 Les 6 notions à connaître (lis ça une fois, ça éclaire tout le reste)

| Mot | En une phrase |
|---|---|
| **VPS** | Un ordinateur loué chez un hébergeur, allumé 24/7, accessible par Internet. Le tien aura une **adresse IP** publique (ex. `203.0.113.45`). |
| **SSH** | La façon de « se connecter à distance » au VPS en ligne de commande, depuis ton ordi. C'est comme ouvrir le terminal **du serveur**, à distance. |
| **Terminal / ligne de commande** | Une fenêtre où tu tapes des commandes texte au lieu de cliquer. On va surtout copier-coller. |
| **root / sudo** | `root` = le super-administrateur (peut tout casser). `sudo` = « exécute cette commande en tant qu'admin ». On évite de vivre en root tout le temps. |
| **Docker** | Un outil qui fait tourner des applis dans des **conteneurs** : des boîtes isolées, préemballées, qui contiennent l'appli + tout ce qu'il lui faut. Tu n'installes pas Twenty « à la main », tu lances des conteneurs. |
| **Docker Compose** | Un fichier (`docker-compose.yml`) qui décrit **plusieurs** conteneurs et comment ils se parlent. Une seule commande (`docker compose up`) démarre tout. |

> 💡 **Image vs conteneur vs volume** (le trio Docker) :
> - **Image** = le « modèle » figé d'une appli (ex. `postgres:16`). On la télécharge.
> - **Conteneur** = une image qu'on a démarrée (l'appli qui tourne).
> - **Volume** = un disque de stockage qui **survit** même si on supprime le conteneur.
>   👉 Tes données CRM vivent dans des volumes : tu peux mettre à jour/recréer les
>   conteneurs sans rien perdre.

Notre CRM = **4 conteneurs** qui tournent ensemble :
`server` (l'appli + le site web) · `worker` (tâches de fond : emails, rappels) ·
`db` (PostgreSQL = la base de données) · `redis` (mémoire rapide pour les files de tâches).

---

## Étape 0 — Choisir / préparer le VPS

- **Specs minimales** : **2 Go de RAM** (vise 4 Go pour être confortable), 2 vCPU, 20-40 Go de disque.
- **OS** : **Ubuntu 24.04 LTS** (ou 22.04 LTS). « LTS » = version maintenue longtemps = stable.
- **Hébergeurs courants** : Hetzner (~4-6 €/mois, excellent rapport qualité/prix), OVH, DigitalOcean, Scaleway.
- À la commande, l'hébergeur t'envoie : l'**adresse IP** du VPS et un **mot de passe root**
  (ou te demande une clé SSH). Note l'IP, on s'en sert partout. Dans ce guide je l'appelle `TON_IP`.

---

## Étape 1 — Se connecter au VPS en SSH

### Depuis Windows
Ouvre **PowerShell** (menu Démarrer → tape « PowerShell »). SSH est inclus d'office.

### Depuis Mac ou Linux
Ouvre l'app **Terminal**.

### La commande (identique partout)
```bash
ssh root@TON_IP
```
- Remplace `TON_IP` par l'adresse de ton VPS.
- La 1ʳᵉ fois, il demande `Are you sure you want to continue connecting?` → tape `yes`.
  > 💡 C'est juste ton ordi qui mémorise l'« empreinte » du serveur pour les fois suivantes.
- Entre le mot de passe root (⚠️ il ne s'affiche pas quand tu tapes, c'est normal).

✅ Si tu vois un truc comme `root@ubuntu:~#`, tu es **dans** le serveur. Bravo, tu fais du SSH.

> 💡 `~` = ton dossier personnel. `#` à la fin = tu es root. Un `$` voudrait dire utilisateur normal.

---

## Étape 2 — Mettre le système à jour

```bash
apt update && apt upgrade -y
```
- `apt` = le « magasin d'applis » d'Ubuntu (gestionnaire de paquets).
- `update` rafraîchit la liste des mises à jour, `upgrade -y` les installe (`-y` = « oui à tout »).
- `&&` = « fais la 2ᵉ commande seulement si la 1ʳᵉ a réussi ».

Si à la fin il dit de redémarrer : `reboot` (ça te déconnecte ; attends 30 s et refais `ssh root@TON_IP`).

---

## Étape 3 — Créer un utilisateur non-root (bonne pratique de sécurité)

Vivre en `root` est risqué. On crée un utilisateur normal qui pourra « passer admin » avec `sudo`.

```bash
adduser philippe            # remplace "philippe" par le nom que tu veux
```
→ il demande un mot de passe (choisis-en un solide) et des infos (tu peux faire Entrée pour passer).

```bash
usermod -aG sudo philippe   # donne à "philippe" le droit d'utiliser sudo
```
> 💡 `-aG sudo` = « ajoute (`a`) cet utilisateur au groupe (`G`) `sudo` ». Le groupe `sudo` a le droit admin.

Reconnecte-toi avec ce nouvel utilisateur :
```bash
exit                        # quitte la session root
ssh philippe@TON_IP         # reconnecte-toi en "philippe"
```
Maintenant ton invite finit par `$`. Quand une commande a besoin des droits admin, on préfixe par `sudo`.

---

## Étape 4 — Le pare-feu (firewall)

Un pare-feu décide quels « ports » sont ouverts depuis Internet.
> 💡 Un **port** = une porte numérotée sur le serveur. Le SSH passe par le port **22**.
> Notre CRM sera servi sur le port **3000**.

```bash
sudo ufw allow OpenSSH      # garde la porte SSH ouverte (SINON tu te coupes l'accès !)
sudo ufw allow 3000         # ouvre le port du CRM
sudo ufw enable             # active le pare-feu (tape "y" pour confirmer)
sudo ufw status             # vérifie : tu dois voir 22/OpenSSH et 3000 "ALLOW"
```
> ⚠️ **À ne jamais oublier** : `allow OpenSSH` **avant** `enable`, sinon tu te bloques dehors.

> 💡 Détail utile : Docker ouvre lui-même le port 3000 vers Internet (il « contourne » un peu UFW).
> Donc le CRM sera bien accessible. Si ton hébergeur a **aussi** un pare-feu dans son interface web
> (Hetzner, OVH…), pense à y autoriser le port **3000** également.

---

## Étape 5 — Installer Docker

On utilise le script d'installation officiel de Docker (le plus simple) :
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```
> 💡 `curl ... -o get-docker.sh` télécharge le script ; `sudo sh get-docker.sh` l'exécute en admin.
> Ça installe Docker **et** le plugin Docker Compose.

Autorise ton utilisateur à lancer Docker sans `sudo` :
```bash
sudo usermod -aG docker $USER
```
Puis **déconnecte/reconnecte-toi** pour que ça prenne effet :
```bash
exit
ssh philippe@TON_IP
```

Vérifie que tout marche :
```bash
docker --version            # ex. Docker version 27.x
docker compose version      # ex. Docker Compose version v2.x
docker run hello-world      # télécharge et lance un mini-conteneur de test
```
✅ Si `hello-world` affiche « Hello from Docker! », ton moteur Docker fonctionne.

---

## Étape 6 — Récupérer les fichiers du CRM

On crée un dossier dédié et on y met **2 fichiers** : `docker-compose.yml` (la recette) et `.env` (tes réglages/secrets).

```bash
mkdir ~/twenty && cd ~/twenty
```
> 💡 `mkdir` crée un dossier, `cd` entre dedans. `~/twenty` = un dossier "twenty" dans ton home.

### 6a. Créer `docker-compose.yml`
Colle **tout le bloc ci-dessous d'un coup** dans le terminal (il crée le fichier automatiquement) :

```bash
cat > docker-compose.yml <<'EOF'
name: twenty-solo

services:
  server:
    image: twentycrm/twenty:${TAG:-latest}
    volumes:
      - server-local-data:/app/packages/twenty-server/.local-storage
    ports:
      - "3000:3000"
    environment:
      NODE_PORT: 3000
      PG_DATABASE_URL: postgres://${PG_DATABASE_USER:-postgres}:${PG_DATABASE_PASSWORD:-postgres}@${PG_DATABASE_HOST:-db}:${PG_DATABASE_PORT:-5432}/default
      SERVER_URL: ${SERVER_URL}
      REDIS_URL: ${REDIS_URL:-redis://redis:6379}
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      STORAGE_TYPE: ${STORAGE_TYPE:-local}
      IS_MULTIWORKSPACE_ENABLED: ${IS_MULTIWORKSPACE_ENABLED:-false}
      IS_BILLING_ENABLED: ${IS_BILLING_ENABLED:-false}
      AUTH_PASSWORD_ENABLED: ${AUTH_PASSWORD_ENABLED:-true}
      IS_EMAIL_VERIFICATION_REQUIRED: ${IS_EMAIL_VERIFICATION_REQUIRED:-false}
      IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS: ${IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS:-true}
      EMAIL_DRIVER: ${EMAIL_DRIVER:-logger}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: curl --fail http://localhost:3000/healthz
      interval: 5s
      timeout: 5s
      retries: 20
    restart: always

  worker:
    image: twentycrm/twenty:${TAG:-latest}
    volumes:
      - server-local-data:/app/packages/twenty-server/.local-storage
    command: ["yarn", "worker:prod"]
    environment:
      PG_DATABASE_URL: postgres://${PG_DATABASE_USER:-postgres}:${PG_DATABASE_PASSWORD:-postgres}@${PG_DATABASE_HOST:-db}:${PG_DATABASE_PORT:-5432}/default
      SERVER_URL: ${SERVER_URL}
      REDIS_URL: ${REDIS_URL:-redis://redis:6379}
      DISABLE_DB_MIGRATIONS: "true"
      DISABLE_CRON_JOBS_REGISTRATION: "true"
      ENCRYPTION_KEY: ${ENCRYPTION_KEY}
      STORAGE_TYPE: ${STORAGE_TYPE:-local}
      IS_BILLING_ENABLED: ${IS_BILLING_ENABLED:-false}
      EMAIL_DRIVER: ${EMAIL_DRIVER:-logger}
    depends_on:
      db:
        condition: service_healthy
      server:
        condition: service_healthy
    restart: always

  db:
    image: postgres:16
    volumes:
      - db-data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${PG_DATABASE_NAME:-default}
      POSTGRES_PASSWORD: ${PG_DATABASE_PASSWORD:-postgres}
      POSTGRES_USER: ${PG_DATABASE_USER:-postgres}
    healthcheck:
      test: pg_isready -U ${PG_DATABASE_USER:-postgres} -h localhost -d postgres
      interval: 5s
      timeout: 5s
      retries: 10
    restart: always

  redis:
    image: redis
    restart: always
    command: ["--maxmemory-policy", "noeviction"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  db-data:
  server-local-data:
EOF
```
> 💡 `cat > fichier <<'EOF' ... EOF` = « écris dans `fichier` tout ce qui suit, jusqu'à la ligne `EOF` ». Pratique pour créer un fichier en une fois.

### 6b. Générer tes secrets
```bash
openssl rand -base64 32     # => copie le résultat : ce sera ENCRYPTION_KEY
openssl rand -base64 24     # => copie le résultat : ce sera le mot de passe PostgreSQL
```
> 💡 `openssl rand` génère une chaîne aléatoire. **Note l'ENCRYPTION_KEY ailleurs** (gestionnaire de mots de passe) : la perdre = perdre l'accès aux données chiffrées.

### 6c. Créer le fichier `.env`
```bash
nano .env
```
> 💡 `nano` est un éditeur de texte dans le terminal. Pour **enregistrer** : `Ctrl+O` puis `Entrée`. Pour **quitter** : `Ctrl+X`.

Colle ceci, puis remplace les `CHANGE_ME` et **`TON_IP`** :
```
# Version pinnée (jamais "latest" : une mise à jour surprise peut migrer la
# base de données sans retour arrière possible). Liste des versions :
# https://github.com/twentyhq/twenty/releases
TAG=v2.22.1
SERVER_URL=http://TON_IP:3000

PG_DATABASE_USER=postgres
PG_DATABASE_PASSWORD=CHANGE_ME_le_2e_openssl
PG_DATABASE_HOST=db
PG_DATABASE_PORT=5432
REDIS_URL=redis://redis:6379

ENCRYPTION_KEY=CHANGE_ME_le_1er_openssl

STORAGE_TYPE=local
IS_MULTIWORKSPACE_ENABLED=false
IS_BILLING_ENABLED=false
AUTH_PASSWORD_ENABLED=true
IS_EMAIL_VERIFICATION_REQUIRED=false
IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS=true
EMAIL_DRIVER=logger
```
Enregistre (`Ctrl+O`, `Entrée`) et quitte (`Ctrl+X`).
> ⚠️ `PG_DATABASE_PASSWORD` : évite les caractères spéciaux exotiques (`@ : / #`) qui peuvent casser l'URL de connexion. Lettres + chiffres = parfait.

---

## Étape 7 — Démarrer le CRM 🚀

```bash
docker compose up -d
```
> 💡 `up` démarre tout ce qui est décrit dans `docker-compose.yml`. `-d` = « detached » = ça tourne
> en arrière-plan (tu récupères la main). La 1ʳᵉ fois, Docker télécharge les images (quelques minutes).

Surveille le démarrage du serveur :
```bash
docker compose logs -f server
```
> 💡 `logs -f server` affiche les journaux du conteneur `server` en direct (`-f` = « follow »).
> Attends de voir un message du genre **« Nest application successfully started »**.
> Quitte l'affichage des logs avec `Ctrl+C` (ça n'arrête PAS le serveur, juste l'affichage).

Vérifie l'état des 4 conteneurs :
```bash
docker compose ps
```
Tu dois voir `server`, `worker`, `db`, `redis`. Le `server` doit être `healthy` (il fait ses migrations
de base de données au 1ᵉʳ lancement, ça peut prendre 1-2 min).

---

## Étape 8 — Première connexion

Sur **ton ordinateur**, ouvre le navigateur :
```
http://TON_IP:3000
```
- Clique **Sign up** (créer un compte).
- Le **tout premier compte créé devient administrateur**, et ton espace de travail est créé tout seul.
- Comme `EMAIL_DRIVER=logger`, aucun email réel n'est envoyé : pas besoin de vérifier ton adresse.

🎉 Ton CRM est en ligne !

> ⚠️ **Rappel sécurité (accès par IP, sans HTTPS)** : la connexion est en `http://` non chiffré.
> Pour un test, OK. Pour de **vraies données**, ajoute le HTTPS gratuit ci-dessous.

---

## 🔒 Bonus — HTTPS gratuit SANS acheter de domaine (recommandé)

Astuce : le service **`nip.io`** transforme automatiquement une IP en nom de domaine.
Si ton IP est `203.0.113.45`, alors `203.0.113.45.nip.io` pointe vers elle. Et comme c'est un
« vrai » nom, on peut obtenir un certificat HTTPS gratuit (Let's Encrypt) via **Caddy**, un
serveur web qui gère le HTTPS tout seul.

> 💡 **Reverse proxy** : Caddy se met « devant » le CRM. Le navigateur parle à Caddy en HTTPS (port 443),
> Caddy parle au CRM en interne. C'est le schéma standard et propre.

1. Ouvre les ports web et **ferme** l'accès direct au 3000 :
```bash
sudo ufw allow 80
sudo ufw allow 443
sudo ufw delete allow 3000
```
2. Dans `~/twenty`, retire la publication du port 3000 du CRM pour qu'il ne soit plus exposé en direct.
   Édite `docker-compose.yml` (`nano docker-compose.yml`) et **supprime** ces 2 lignes sous `server:` :
```
    ports:
      - "3000:3000"
```
3. Ajoute un conteneur Caddy. Crée le fichier de config :
```bash
cat > Caddyfile <<'EOF'
TON_IP.nip.io {
    reverse_proxy server:3000
}
EOF
```
(remplace `TON_IP` par ton IP, ex. `203.0.113.45.nip.io`)

4. Ajoute le service Caddy à `docker-compose.yml`, juste après la ligne `services:` :
```bash
nano docker-compose.yml
```
Insère ce bloc (bien indenté, 2 espaces, comme les autres services) :
```yaml
  caddy:
    image: caddy:2
    restart: always
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy-data:/data
    depends_on:
      - server
```
Et dans la section `volumes:` tout en bas, ajoute `caddy-data:` :
```yaml
volumes:
  db-data:
  server-local-data:
  caddy-data:
```
5. Mets à jour `SERVER_URL` dans `.env` :
```
SERVER_URL=https://TON_IP.nip.io
```
6. Relance :
```bash
docker compose up -d
```
Accède maintenant à **`https://TON_IP.nip.io`** (cadenas 🔒, chiffré). Caddy obtient le certificat
automatiquement en quelques secondes.

---

## 🛠️ Vie quotidienne (à garder sous le coude)

### Démarrer / arrêter / état
```bash
cd ~/twenty
docker compose ps            # qui tourne ?
docker compose stop          # mettre en pause (données conservées)
docker compose start         # redémarrer
docker compose down          # arrêter ET supprimer les conteneurs (volumes/données CONSERVÉS)
docker compose up -d         # tout (re)démarrer
```
> 💡 `down` ne supprime PAS les volumes par défaut → tes données restent. (`down -v` supprimerait
> les volumes : **à ne jamais faire** sauf si tu veux tout effacer.)

### Voir les logs (pour comprendre un souci)
```bash
docker compose logs -f server    # l'appli
docker compose logs -f worker    # les tâches de fond (emails, syncs)
```

### Mettre à jour TwentyCRM
```bash
cd ~/twenty
# 1) Sauvegarde d'abord (voir plus bas) !
docker compose pull              # télécharge les dernières images
docker compose up -d             # recrée les conteneurs avec les nouvelles versions
```
> ⚠️ Le `server` applique les migrations de base au démarrage. **Toujours sauvegarder avant.**
> Pour un gros saut de version, lis le guide d'upgrade officiel de Twenty.

### Sauvegardes (IMPORTANT)
La base de données :
```bash
cd ~/twenty
docker compose exec -T db pg_dumpall -U postgres > ~/backup-$(date +%F).sql
```
Les fichiers (pièces jointes) :
```bash
docker run --rm -v twenty-solo_server-local-data:/data -v ~:/out \
  alpine tar czf /out/files-$(date +%F).tgz -C /data .
```
> 💡 `$(date +%F)` insère la date du jour → fichiers `backup-2026-05-29.sql`, etc.
> **Copie ces sauvegardes + ton `ENCRYPTION_KEY` ailleurs** (ton ordi, un cloud). Une sauvegarde
> qui reste sur le serveur ne protège pas si le serveur meurt.

#### Sauvegarde automatique tous les jours (cron)
```bash
crontab -e        # choisis "nano" si demandé
```
Ajoute cette ligne (sauvegarde la base chaque jour à 3 h du matin) :
```
0 3 * * * cd /home/philippe/twenty && docker compose exec -T db pg_dumpall -U postgres > /home/philippe/backup-$(date +\%F).sql
```
> 💡 `cron` = le planificateur de tâches de Linux. Les 5 champs = minute heure jour mois jour-semaine.
> `0 3 * * *` = « à 3h00, tous les jours ». (Adapte `/home/philippe` à ton utilisateur.)

---

## 🆘 Dépannage rapide

| Symptôme | Quoi vérifier |
|---|---|
| La page ne charge pas | `docker compose ps` (le `server` est-il `healthy` ?) · port 3000 ouvert dans UFW **et** chez l'hébergeur ? |
| `server` redémarre en boucle | `docker compose logs server` → souvent un souci dans `.env` (mot de passe DB, ENCRYPTION_KEY manquante) |
| « unhealthy » longtemps au 1ᵉʳ lancement | Normal 1-2 min (migrations). Au-delà : regarde les logs. |
| Plus de RAM / lenteurs | VPS < 2 Go → passe à 4 Go. Vérifie avec `free -h`. |
| J'ai oublié si Docker tourne | `docker ps` liste les conteneurs actifs. |

---

## 🧾 Antisèche (les commandes que tu réutiliseras)

```bash
ssh philippe@TON_IP                  # se connecter au VPS
cd ~/twenty                          # aller dans le dossier du CRM
docker compose up -d                 # tout démarrer
docker compose ps                    # état
docker compose logs -f server        # logs en direct (Ctrl+C pour sortir)
docker compose pull && docker compose up -d   # mettre à jour
docker compose exec -T db pg_dumpall -U postgres > ~/backup.sql   # sauvegarde DB
free -h                              # RAM dispo
df -h                                # espace disque
```

> Les fichiers de référence de ce déploiement vivent dans `deploy/solo/` du repo
> (`docker-compose.yml`, `.env.example`, `README.md`). Ce guide en est la version « VPS pas à pas ».
