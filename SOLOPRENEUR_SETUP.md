# TwentyCRM en usage solopreneur — Analyse de code & plan de mise en place

> Analyse du fork + recette concrète pour faire tourner Twenty en mono-utilisateur,
> auto-hébergé, à coût et complexité minimes. Voir aussi `deploy/solo/`.
> Dernière mise à jour : 2026-05-29.

---

## 0. TL;DR

- **Ce fork = Twenty vanilla à jour (mai 2026)**, zéro modification du code métier.
  Tout passe donc par la **configuration** et les **objets/champs personnalisés**, pas par du code.
- **Faisable en solo sans friction** : billing désactivé par défaut et sans aucune
  limite, mode mono-workspace, auth email/mot de passe intégrée, stockage local.
- **Stack minimale** : 4 conteneurs (`server`, `worker`, `postgres`, `redis`), ~2 Go RAM,
  déployable en ~30 min. Fichiers prêts dans `deploy/solo/`.
- **Le travail de "mise en place" est surtout de la config** : définir le modèle de
  données solopreneur (Clients, Projets, Devis/Factures…) en objets personnalisés,
  puis quelques workflows.

---

## 1. Analyse du code forké

### 1.1 Nature du fork
| Aspect | Constat |
|---|---|
| Code métier (`twenty-front`, `twenty-server`, `twenty-shared`, `twenty-ui`) | **Identique à l'upstream Twenty #21064** — aucune modification |
| `twenty-companion`, `twenty-claude-skills` | Packages **upstream** (PR #20976), pas spécifiques au fork |
| Branding / README / logos | Vanilla |
| Seul ajout du fork | Notre commit config/docs (gstack+ruflo, CLAUDE.md, FEATURE_MAP.md) + `.mcp.json` |

> **Implication** : on peut suivre l'upstream sans conflit, et toute personnalisation
> doit vivre en **données/config** (objets custom, workflows, env) ou dans des dossiers
> isolés (`deploy/solo/`, `.claude/`), pas en patchant le code métier.

### 1.2 Architecture d'exécution
```
        ┌───────────── server (NestJS) ─────────────┐
Navigateur ─▶│  GraphQL + REST + front statique           │
        │  migrations au démarrage + cron jobs       │
        └───────┬───────────────────────┬───────────┘
            │                       │
         PostgreSQL 16            Redis  ◀── worker (BullMQ : emails, webhooks,
         (1 schéma core +              sync mail/agenda, workflows)
          1 schéma par workspace)
```
- **Isolation multi-tenant par schéma Postgres** (`workspace_<base36(id)>`), transparente.
  En solo, un seul schéma workspace est créé. *(server : `workspace-datasource`, `workspace-manager`)*
- **Worker indispensable** : tout l'asynchrone (emails, webhooks, syncs, workflows) en dépend.

### 1.3 Dépendances : requis vs optionnel
| Composant | Requis ? | Défaut solo |
|---|---|---|
| PostgreSQL 16 | ✅ obligatoire | conteneur `db` |
| Redis | ✅ obligatoire (pas de fallback) | conteneur `redis` |
| `ENCRYPTION_KEY` | ✅ obligatoire (chiffrement des secrets) | `openssl rand -base64 32` |
| Stockage fichiers | local **ou** S3 | **local** (`STORAGE_TYPE=local`) |
| SMTP | optionnel | **logger** (emails en console) |
| ClickHouse (analytics) | optionnel | désactivé (`ANALYTICS_ENABLED=false`) |
| OAuth Google/Microsoft | optionnel | désactivé |
| Sentry / OpenTelemetry | optionnel | désactivé |

*(Validations d'env : `twenty-server/src/engine/core-modules/twenty-config/config-variables.ts`.)*

### 1.4 Friction multi-tenant / billing : levée
| Friction | Neutralisée par |
|---|---|
| Billing Stripe obligatoire | `IS_BILLING_ENABLED=false` (défaut) — **aucune limite** records/seats/workflows |
| Multi-workspace | `IS_MULTIWORKSPACE_ENABLED=false` |
| Vérification email | `IS_EMAIL_VERIFICATION_REQUIRED=false` |
| OAuth obligatoire | `AUTH_PASSWORD_ENABLED=true` (email/mot de passe) |
| Création de workspaces ouverte | `IS_WORKSPACE_CREATION_LIMITED_TO_SERVER_ADMINS=true` (1er workspace toujours permis) |

**Premier démarrage** : `Sign up` → crée user **admin** + workspace + son schéma Postgres automatiquement → onboarding (profil) → app. Aucun plan/paiement requis.

---

## 2. Modèle de données solopreneur

Twenty est orienté **CRM commercial** (objets standards : *Company, Person, Opportunity,
Task, Note, Attachment*). Un solopreneur a souvent besoin d'un modèle un peu différent.
Tout se fait **sans code**, via *Settings → Data model* (objets & champs personnalisés).

### 2.1 Mapping conseillé
| Besoin solopreneur | Objet Twenty | Action |
|---|---|---|
| Clients (entreprises) | **Company** (standard) | renommer en « Clients » au besoin |
| Contacts | **Person** (standard) | tel quel |
| Affaires / deals | **Opportunity** (standard) | pipeline (prospect → gagné) |
| Tâches & rappels | **Task** (standard) | tel quel |
| Notes / comptes-rendus | **Note** (standard) | tel quel |
| **Projets / Missions** | objet **custom** `Project` | champs : statut, client (relation Company), dates, budget |
| **Devis / Factures** | objet **custom** `Invoice` | champs : numéro, client, montant, statut (brouillon/envoyé/payé), échéance |
| **Abonnements / récurrents** | objet **custom** `Subscription` | champs : client, MRR, renouvellement |
| **Dépenses** | objet **custom** `Expense` | champs : montant, catégorie, date, justificatif (attachment) |
| **Time tracking** | objet **custom** `TimeEntry` | champs : projet (relation), durée, date, facturable (bool) |

### 2.2 Relations clés à créer
- `Project` ↔ `Company` (un client a N projets)
- `Invoice` ↔ `Company` / `Invoice` ↔ `Project`
- `TimeEntry` ↔ `Project`
- `Subscription` ↔ `Company`

> Les relations many-to-many passent par des tables de jonction
> (feature flag `IS_JUNCTION_RELATIONS_ENABLED`).

---

## 3. Automatisations utiles (Workflows, sans code)

Via le module **Workflow** (déclencheur → actions), exécuté par le worker :
1. **Relance facture** : à J+7 d'une `Invoice` au statut « envoyé » non « payé » → email/tâche de relance.
2. **Nouveau projet** : à la création d'un `Project` → créer les tâches de démarrage standard.
3. **Renouvellement abonnement** : cron mensuel → tâche de suivi sur chaque `Subscription` arrivant à échéance.
4. **Pipeline** : passage d'une `Opportunity` en « gagné » → créer un `Project` lié.
5. **Récap hebdo** : cron → email récapitulatif des tâches/échéances de la semaine.

Pour des cas avancés : **logic functions** (code serverless) + composants front custom.

---

## 4. Plan de mise en place (étape par étape)

### Étape 1 — Déployer (≈30 min)
```bash
cd deploy/solo
cp .env.example .env          # remplir ENCRYPTION_KEY + PG_DATABASE_PASSWORD
docker compose up -d
```
→ ouvrir http://localhost:3000, **Sign up** (devient admin), créer le workspace.

### Étape 2 — Production (domaine + HTTPS)
- `SERVER_URL=https://crm.mondomaine.com` + reverse-proxy TLS (Caddy/Traefik).
- VPS 2 Go (~5-15 €/mois) ou NAS/home-server.

### Étape 3 — Modèle de données
- Settings → Data model → créer `Project`, `Invoice`, `Subscription`, `Expense`, `TimeEntry` + relations (§2).
- Créer des **vues** par défaut (Table/Kanban) par objet (ex. Kanban factures par statut).

### Étape 4 — Mail & agenda (optionnel)
- Connecter un compte **IMAP/SMTP/CalDAV** (pas besoin d'OAuth Google) → timeline unifiée.

### Étape 5 — Automatisations
- Créer les workflows du §3 selon vos priorités.

### Étape 6 — Sauvegardes
- Cron quotidien `pg_dumpall` + archive des fichiers (voir `deploy/solo/README.md`).
- Stocker `ENCRYPTION_KEY` + dump **hors serveur**.

### Étape 7 — Données de démarrage (optionnel)
- Importer vos clients/contacts via **CSV** (module spreadsheet-import) ou l'API/SDK.

---

## 5. Coûts & exploitation

| Poste | Estimation |
|---|---|
| Hébergement | VPS 2 Go : 5-15 €/mois — ou NAS/home-server : 0 € |
| Stockage | local (inclus) |
| Emails | logger (0 €) ou SMTP existant (Gmail/OVH/…) |
| Maintenance | ~1-2 h/mois (sauvegardes, mises à jour) |
| Licence | Twenty open-source, billing désactivé = aucun coût logiciel |

---

## 6. Points d'attention & limites

- ⚠️ **`ENCRYPTION_KEY`** : la perdre rend les secrets chiffrés irrécupérables. Sauvegarde impérative.
- ⚠️ **Redis & worker** : tous deux obligatoires pour l'asynchrone ; surveiller leur santé.
- ⚠️ **Migrations au démarrage** : sauvegarder avant chaque mise à jour majeure (cf. `upgrade-guide.mdx`).
- ⚠️ **Pas d'objets « Facture/Compta » natifs** : à modéliser en custom (Twenty n'est pas un logiciel de facturation/compta légal).
- ⚠️ **Mono-workspace** : si un jour vous voulez plusieurs espaces, repasser `IS_MULTIWORKSPACE_ENABLED=true` (jusqu'à 5 sans enterprise key).
- ℹ️ **Suivi upstream** : garder le code métier vanilla ; ne personnaliser que data/config/`deploy/`.

---

## 7. Décisions à trancher ensemble

- [ ] Hébergement : **VPS** (domaine public) ou **home-server/NAS** (LAN/VPN) ?
- [ ] Emails réels nécessaires (SMTP) ou logger suffit au départ ?
- [ ] Modèle de données : valider la liste d'objets custom du §2.1.
- [ ] Workflows prioritaires (§3) ?
- [ ] Faut-il que je génère un **script de seed** (création des objets custom + vues via l'API/SDK) pour reproduire l'environnement automatiquement ?
