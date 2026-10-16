# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Projet

**ft_lgtm** (*Looks Good To Monitor*), projet 42 solo. Playground web : l'utilisateur écrit du Rust, clique **Run** → compilé en WASM, exécuté dans une sandbox WASI, code + sortie uploadés sur IPFS. Chaque étape est observée (traces, métriques, logs) dans Grafana.

- Sujet : `ft_lgtm.pdf` à la racine (gitignoré via `*.pdf`), v1.1. Source de vérité.
- Plan par phases : `.ai/roadmap.md`. Décisions + justification : `.ai/decisions.md` (`D1`–`D30`, tranchées par l'utilisateur). Avancement : `.ai/state.md`, `.ai/next-steps.md`.
- Mandatory d'abord, mais tout est conçu modulaire pour accueillir les bonus (D16).

## Mode de travail : MENTOR (important)

L'utilisateur doit pouvoir expliquer et défendre chaque choix sans IA (exigé par le sujet, soutenance sur sa machine, « explain all concepts »).

- **Par défaut, ne pas créer ni modifier de fichier du repo** (backend, frontend, k8s, Makefile, dashboards, README…). Code donné **en markdown**, l'utilisateur l'implémente, puis review.
- **Exception sur demande explicite** : si l'utilisateur demande explicitement à Claude d'écrire un changement précis dans un fichier (« écris-le dans le fichier », « write it yourself »), Claude l'écrit, puis fait un walkthrough du code. L'accord vaut pour ce changement-là, pas pour la suite : sans nouvelle demande, on revient au markdown.
- Toujours autorisés sans demande : `.ai/` et ce `CLAUDE.md`, mis à jour en fin de session.
- Petits pas : structure/signatures → implémentation → review. Expliquer le *pourquoi* et les compromis.
- En début de session, lire `.ai/` avant de proposer quoi que ce soit.
- Le README décrit honnêtement l'usage de l'IA. Les décisions tranchées par l'utilisateur sont tracées dans `.ai/decisions.md`.

## Contraintes dures du sujet

- Tout tourne **dans une VM**, sur un **cluster K8s local**, **aucun service cloud**.
- `make` installe les dépendances **et** déploie toute l'infra sur une **VM neuve**.
- Hostnames : app `lgtm.local`, Grafana `grafana.lgtm.local`, gateway IPFS `ipfs.lgtm.local`.
- Frontend : éditeur (Monaco), exemple pré-chargé, bouton Run, feedback pendant l'exécution, erreurs compile/run claires, affichage de la sortie, lien IPFS.
- Sandbox : pas de réseau, pas de FS (ou whitelist), mémoire (~10 Mo), temps (~5 s), sortie (~10 ko). Chaque limite doit être **démontrable** (snippets de démo).
- IPFS : le lien pointe vers un **répertoire** (source + output) ; le même CID doit marcher sur `ipfs.io`. Derrière un NAT sans UPnP/IPv6, la VM n'est pas joignable : prévoir l'explication / un réseau mobile pour la soutenance.
- Traces : root span HTTP, `compile`, `run`, `ipfs_upload` ; erreurs marquées sur les spans ; code identifié (CID, hash ou snippet).
- Dashboards imposés : (1) métriques — exécutions réussies / échouées / totales via l'**OTel Metrics API** ; (2) traces — durée dans le temps, plus lentes, moyenne, max. Plus « Logs for this span » (corrélation Loki) et **exemplars** (clic sur un point de durée → trace).
- README : **première ligne** en italique `*This project has been created as part of the 42 curriculum by cpoulain.*`, puis sections Description, Instructions, Resources (avec usage de l'IA).
- Arborescence imposée à la racine : `.gitignore`, `Makefile`, `README.md`, `backend/`, `frontend/`, `k8s/`, `dashboards/`.
- Bonus (évalués seulement si le mandatory est parfait) : Deep IPFS tracing, Infra observability (dashboard K8s), Polyglot, Short URLs, Profiling.

## Stack retenue (raisons dans `.ai/decisions.md`)

| Couche | Choix |
|---|---|
| Backend | Rust, axum + tokio, `tracing` + `tracing-opentelemetry` |
| Runtime WASI | Wasmtime (`wasmtime` + `wasmtime-wasi`), dans le process API |
| Langage utilisateur | Rust → `wasm32-wasip1` (polyglot en bonus) |
| Compilation | service compilateur dédié (pod séparé), appelé en HTTP par l'API |
| IPFS | Kubo dans le cluster, API RPC HTTP (`/api/v0/add`) |
| Observabilité | OTel Collector → Prometheus (métriques + exemplars) / Tempo / Loki → Grafana |
| Frontend | SvelteKit + Monaco Editor |
| K8s | k3d (registry local, ingress Traefik) |

## Architecture cible

```
navigateur ─▶ lgtm.local (Traefik) ─▶ frontend (SvelteKit)
                                  └─▶ /api ─▶ api (axum)
                                                ├─ HTTP ─▶ compiler (rustc → .wasm)      [span compile]
                                                ├─ wasmtime sandbox (run .wasm)          [span run]
                                                └─ HTTP ─▶ kubo /api/v0/add (répertoire)  [span ipfs_upload]
api, compiler ──OTLP──▶ otel-collector ──▶ prometheus / tempo / loki ──▶ grafana (grafana.lgtm.local)
```

- `backend/` est un workspace Cargo : `api` (axum + runner Wasmtime), `compiler` (trait `Toolchain` par langage, Rust via `rustc` fichier unique sans crates), `telemetry` (init OTel partagée).
- Contrats : `POST /compile {language, source}` → `.wasm` ou `422 {stderr}` ; `POST /api/execute` synchrone → `{status, stdout, stderr, truncated, cid, timings, trace_id}`. Source ≤ 64 kB (`413`), 4 exécutions max en parallèle (`429`).
- Sandbox : `StoreLimits` 10 MiB, epoch interruption 5 s, pipe de sortie 10 kB, aucun preopen/env/args.
- Upload IPFS (répertoire `wrap-with-directory`) dès que la compilation réussit, jamais sur `compile_error`.
- `traceparent` (W3C) propagé API → compilateur : trace distribuée sur 2 services. Root span : `code.sha256` puis `ipfs.cid`.
- Métriques (OTel Metrics API) : `executions_total{status, language}` (`success | compile_error | runtime_error | timeout | memory_limit | rejected`), histogramme `execution_duration_seconds` avec exemplars.
- Logs en OTLP → Loki, `trace_id` dans chaque log : clé de la corrélation Tempo↔Loki.
- Le code utilisateur ne s'exécute **jamais** hors de Wasmtime. Les pods `api` et `compiler` sont durcis (non-root, readOnlyRootFS, limits, NetworkPolicy ; compilateur sans sortie réseau sauf Collector).
- Tiers déployés en Helm épinglé, nos services en manifests YAML bruts, sous `k8s/`. Namespaces : `lgtm-app`, `observability`, `ipfs`.
- Datasources et dashboards Grafana provisionnés **as-code** depuis `dashboards/`.

## Commandes

Tous les builds passent par Docker : l'hôte n'a besoin que de `docker`, `k3d`, `kubectl`, `helm`, `make`, `curl` (VM Debian 12). HTTP uniquement.

Cibles existantes (`make help`) :

| Commande | Effet |
|---|---|
| `make` / `make up` | Tout installer et déployer (enchaîne les cibles ci-dessous) |
| `make deps` | Vérifie Debian 12 ; installe docker, k3d, kubectl, helm aux versions épinglées (compare la version installée) |
| `make cluster` | Registry `k3d-lgtm-registry:5000` + cluster k3d `lgtm` (1 nœud, ports 80 et 4001 tcp/udp), attend Traefik |
| `make namespaces` | `kubectl apply -f k8s/namespaces.yaml` |
| `make dns` | Ligne balisée `# ft_lgtm` dans `/etc/hosts` (`sudo`) |
| `make down` | Supprime le registry **puis** le cluster (cet ordre évite un réseau `k3d-lgtm` orphelin) |

Toutes les cibles sont idempotentes. Images : pousser vers `localhost:5000/<img>` depuis la VM, référencer `k3d-lgtm-registry:5000/<img>` dans les manifests.

Cibles prévues : `observability`, `ipfs`, `build`, `deploy`, `demo`, `clean`. **Mettre à jour cette section** au fil des phases (build, `cargo test -p <crate> <nom_test>`, front…).
