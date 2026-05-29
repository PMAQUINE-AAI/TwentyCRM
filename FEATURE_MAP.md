# TwentyCRM — Bilan & Feature Map

> Document de pilotage perso. Objectif : voir d'un coup d'œil ce que fait le système
> aujourd'hui, et où l'améliorer pour un usage personnel.
> Dernière mise à jour : 2026-05-29.

---

## 1. Bilan du projet (snapshot)

| Élément | État |
|---|---|
| Base | Fork de **Twenty** (CRM open-source), monorepo Nx + Yarn 4 |
| Branche de travail | `claude/project-status-feature-map` (alignée sur `main`) |
| Stack front | React 18, TypeScript strict, Jotai, Linaria, Vite, Apollo, Lingui |
| Stack back | NestJS, TypeORM, PostgreSQL, Redis, GraphQL (Yoga), BullMQ |
| Analytics | ClickHouse (optionnel) |
| Packages | 20 packages (front, server, ui, shared, emails, website, docs, cli, sdk, e2e…) |
| Node | v22.x · Yarn 4.13 |
| Outillage IA | **gstack** (global `~/.claude`) + **ruflo** (projet `.claude/`), réinstallés via hook `SessionStart` |

**Constat général.** Le socle est mûr et complet : objets standards CRM, vues
multiples, workflows, dashboards, sync mail/agenda, IA, extensibilité (objets &
champs custom, API/SDK, CLI, apps). Pour un usage *perso*, l'enjeu n'est pas de
construire des features manquantes mais de **simplifier / pré-configurer** un
sous-ensemble et d'**automatiser** ce qui est répétitif.

---

## 2. Architecture par package

```
packages/
├── twenty-front/                # SPA React (UI CRM)
├── twenty-server/               # API NestJS + GraphQL + workers
├── twenty-ui/                   # Librairie de composants partagés
├── twenty-shared/               # Types & utils communs (isDefined, etc.)
├── twenty-emails/               # Templates email (React Email)
├── twenty-website/ / twenty-docs/  # Site marketing + docs
├── twenty-cli/                  # CLI (gestion apps/workspace)
├── twenty-sdk/ / twenty-client-sdk/  # SDK serveur & client
├── twenty-apps/                 # Apps/extensions
├── twenty-companion/            # App desktop Electron (POC Recall.ai, enregistrement)
├── twenty-claude-skills/        # Skills Claude pour Twenty (présentation de records)
├── twenty-zapier/               # Intégration Zapier
├── twenty-e2e-testing/          # Tests Playwright E2E
└── twenty-docker/               # Compose dev/prod
```

---

## 3. Feature Map (par domaine fonctionnel)

Légende état : 🟢 solide · 🟡 présent mais perfectible · 🔵 avancé/optionnel

### 3.1 Données CRM (objets standards) 🟢
Source : `packages/twenty-server/src/modules/*/standard-objects`
- **Company** (sociétés), **Person/Contact** (personnes)
- **Opportunity** (pipeline de vente)
- **Task** (tâches), **Note** (notes), **Attachment** (pièces jointes)
- **Workspace Member** (membres), **Blocklist** (liste de blocage)
- **Timeline** (activité chronologique), **Favorites**
- Objets & champs **personnalisés** via metadata (cœur de l'extensibilité)

### 3.2 Vues & exploration des données 🟢
Module front : `object-record`, `views`, `spreadsheet-import`
- Vues **Table**, **Kanban**, (Calendar/Timeline selon objet)
- Filtres, tris, groupes, recherche, colonnes configurables
- Import **CSV / spreadsheet**, export
- Command menu (palette de commandes ⌘K)

### 3.3 Workflows / automatisations 🟢
Modules : front `workflow`, `logic-functions` · server `workflow`, `logic-function`
- Déclencheurs (création/màj record, cron, webhook, événement DB)
- Actions (créer/màj record, envoyer email, HTTP, code, IA, formulaire)
- **Logic functions** (code serverless) + **front components** custom
- Exécution via BullMQ (workers)

### 3.4 Dashboards & analytics 🟡🔵
Modules : front `dashboards`, `analytics`, `page-layout`, `geo-map` · server `dashboard`, ClickHouse
- Dashboards configurables, layouts de page
- Graphiques / métriques (alimentés par ClickHouse quand activé)
- Carte géographique (`geo-map`)
- 🟡 À enrichir pour usage perso : modèles de dashboards prêts à l'emploi

### 3.5 Mail & Agenda 🟢🔵
Modules : `accounts`, `messaging`, `calendar`, `connected-account`, `imap-smtp-caldav-connection`
- Connexion comptes Google / Microsoft + **IMAP/SMTP/CalDAV**
- Sync **emails** (threads dans le timeline) et **événements agenda**
- Matching participants → contacts ; blocklist
- Domaines emailing, provisioning SES, replay inbound

### 3.6 Intelligence artificielle 🔵
Modules : front `ai`, server `code-interpreter`, `logic-function`
- Assistant IA, génération/IA dans workflows
- Code interpreter côté serveur
- + skills Claude (`twenty-claude-skills`, gstack, ruflo) côté dev

### 3.7 Paramètres, admin & sécurité 🟢
Modules : `settings`, `admin-panel`, `auth`, `billing`, `domain-manager`, `feature-flag`, `lab`, `impersonation`, `audit`, `api-key`
- Auth (email/password, SSO/SAML, Google/MS), 2FA, captcha
- Gestion workspace, membres, rôles & permissions
- Feature flags, labs (features expérimentales), audit logs
- Billing (Stripe), domaines, clés API, webhooks
- Admin panel (variables serveur, santé)

### 3.8 Extensibilité & intégrations 🟢🔵
- **API GraphQL** (code-first) + **REST**, **API keys**, **webhooks**
- **SDK** (`twenty-sdk`, `twenty-client-sdk`) + **CLI** (`twenty-cli`)
- **Apps / marketplace** (`applications`, `marketplace`, `twenty-apps`)
- **Zapier** (`twenty-zapier`)
- **Companion desktop** (Electron, enregistrement réunions — POC)
- MCP Postgres read-only configuré (`.mcp.json`) pour le dev

### 3.9 Plateforme / DevEx 🟢
- Monorepo Nx, lint (oxlint + règles custom), typecheck, Jest, Storybook, Playwright
- Migrations & **instance/workspace commands** (upgrade par workspace)
- i18n (Lingui) avec traductions auto
- Docker compose dev/prod

---

## 4. Surfaces de personnalisation (pour usage perso)

| Besoin | Levier dans Twenty | Effort |
|---|---|---|
| Adapter le modèle de données | Objets & champs custom (no-code, via Settings) | Faible |
| Automatiser des tâches récurrentes | Workflows + logic functions | Faible/Moyen |
| Tableaux de bord persos | Dashboards + ClickHouse | Moyen |
| Centraliser mails/agenda | Connected accounts (IMAP/CalDAV) | Faible |
| Étendre l'UI | Front components / apps | Moyen/Élevé |
| Scripts & intégrations | SDK + API + CLI + webhooks | Moyen |
| Assistance IA sur mes données | Module `ai` + `twenty-claude-skills` | Moyen |

---

## 5. Idées d'amélioration priorisées (usage perso)

> À trier ensemble. Chaque item = quick win potentiel pour *ton* usage.

### Quick wins (faible effort, fort impact)
1. **Pré-configurer un workspace perso** : objets custom (ex. Projets, Abonnements,
   Contacts perso) + vues par défaut, plutôt que le schéma B2B standard.
2. **Connecter mail + agenda** perso (IMAP/CalDAV) pour la timeline unifiée.
3. **Workflows perso** : rappels de tâches, suivi d'opportunités/projets, emails auto.
4. **Seed de données** : script de bootstrap (objets + vues + données démo) pour
   reconstruire l'environnement rapidement (utile vu l'env éphémère).

### Moyen terme
5. **Dashboards persos** prêts à l'emploi (activer ClickHouse + modèles).
6. **Skills IA sur tes records** : étendre `twenty-claude-skills` (résumés,
   préparation de RDV, extraction depuis emails).
7. **Companion desktop** : évaluer l'enregistrement/notes de réunion si pertinent.

### Exploratoire
8. **Intégrations perso** via SDK/CLI (sync vers Notion, banque, etc.).
9. **Automatisations multi-agents** via ruflo (swarm) pour des tâches de fond.

---

## 6. Points d'attention

- **Environnement web éphémère** : tout ce qui n'est pas commité disparaît. Les
  skills gstack/ruflo sont réinstallés par `.claude/hooks/session-start.sh` ;
  les données CRM doivent vivre dans une base persistée (Postgres géré).
- **`.claude/` est gitignoré** (sauf `settings.json` + `hooks/session-start.sh`,
  réexposés volontairement). Ne pas committer `.claude-flow/` (runtime).
- **Backward-compat GraphQL** : vérifier la compat schéma avant tout changement
  d'objet (voir CLAUDE.md).
- **Instance commands** : générer une migration pour tout changement d'entité.

---

## 7. Prochaines décisions à prendre ensemble

- [ ] Définir le **schéma perso** (quels objets custom ?)
- [ ] Quelles **automatisations** prioritaires ?
- [ ] Activer **ClickHouse** pour les dashboards ? (oui/non)
- [ ] Niveau d'usage de **ruflo** (swarm) vs **gstack** (workflow) au quotidien ?
