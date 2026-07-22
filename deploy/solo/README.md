# Déploiement solopreneur — TwentyCRM

Stack auto-hébergé mono-utilisateur en **4 conteneurs** (server, worker, PostgreSQL, Redis).
RAM minimale ~2 Go. Aucun service cloud requis (stockage local, emails en logger).

## Démarrage rapide

```bash
cd deploy/solo
cp .env.example .env

# Générer les secrets et les coller dans .env :
openssl rand -base64 32   # -> ENCRYPTION_KEY
openssl rand -base64 24   # -> PG_DATABASE_PASSWORD (sans caractères spéciaux)

docker compose up -d
docker compose logs -f server   # attendre "Nest application successfully started"
```

Puis ouvrez **http://localhost:3000**, cliquez **Sign up**, créez votre compte :
le **premier compte devient admin** et son **workspace est créé automatiquement**.
En mode `IS_MULTIWORKSPACE_ENABLED=false`, aucun second workspace ne pourra être créé.

## Mise en production (domaine + HTTPS)

Un service Caddy (HTTPS automatique via Let's Encrypt) est intégré au compose,
désactivé par défaut :

1. Pointez un domaine (`crm.mondomaine.com`) vers le serveur (ports 80/443 ouverts).
2. Dans `.env` : `SERVER_URL=https://crm.mondomaine.com` et `CADDY_DOMAIN=crm.mondomaine.com`.
3. `docker compose --profile proxy up -d`

Le port 3000 reste lié à `127.0.0.1` : rien ne transite en HTTP clair sur internet.
Pour un accès direct par IP sans TLS (test uniquement) : `BIND_IP=0.0.0.0` dans `.env`.

## Opérations courantes

```bash
docker compose ps                 # état des conteneurs
docker compose logs -f worker     # logs des jobs (emails, syncs, webhooks)
# mise à jour : sauvegarder, puis incrémenter TAG dans .env, puis :
docker compose pull && docker compose up -d   # (voir note ci-dessous)
docker compose down               # arrêt (les volumes persistent)
```

### Sauvegarde (à automatiser via cron)

```bash
# Base de données
docker compose exec -T db pg_dumpall -U postgres > backup-$(date +%F).sql
# Fichiers (pièces jointes)
docker run --rm -v twenty-solo_server-local-data:/data -v "$PWD":/out \
  alpine tar czf /out/files-$(date +%F).tgz -C /data .
```

> **À garder hors du serveur** : `ENCRYPTION_KEY` + un dump récent. Sans la clé,
> les secrets chiffrés (tokens) sont irrécupérables après restauration.

## Notes

- **Mises à jour** : Twenty applique les migrations au démarrage du `server`.
  Lisez `packages/twenty-docs/.../upgrade-guide.mdx` avant un saut de version majeure,
  et sauvegardez d'abord.
- **Worker obligatoire** : sans lui, pas d'emails, de webhooks ni de sync mail/agenda.
- **Pourquoi `deploy/solo/` et pas `packages/twenty-docker/`** : pour rester isolé de
  l'upstream et éviter les conflits lors des synchronisations.
- Détails et plan complet : voir `SOLOPRENEUR_SETUP.md` à la racine.
