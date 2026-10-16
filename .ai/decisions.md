# Décisions d'architecture

> Toutes les décisions ci-dessous ont été **tranchées par l'utilisateur** lors de la
> session de grilling du 2026-10-16 (Q1–Q32). Claude a proposé une recommandation
> et une justification par question ; l'utilisateur les a acceptées et doit savoir
> les défendre avec ses mots en soutenance.
>
> Format : Choix · Alternatives écartées · Pourquoi · Compromis accepté.
> Les versions exactes (images, crates, charts) sont ajoutées dans la section
> « Versions épinglées » au début de chaque phase (D30).

---

## Plateforme

### D12 — VM cible : Debian 12 uniquement (Q1)
- Alternatives : Ubuntu, support multi-distro.
- Pourquoi : la VM de dev est une Debian 12 (VirtualBox). Une seule distro = un seul chemin `apt` à tester. `make deps` vérifie l'OS et échoue clairement sinon.
- Specs minimales documentées dans le README : 4 CPU, 8 Go RAM, 30 Go disque.
- Compromis : pas de support des autres distros.

### D13 — Tous les builds dans Docker (Q2)
- Alternatives : installer cargo/rustc/npm sur l'hôte.
- Pourquoi : la VM neuve n'a besoin que de `docker`, `k3d`, `kubectl`, `helm`, `make`, `curl`. Aucune dépendance à l'état de la machine de dev. L'image construite est exactement celle qui tourne dans le cluster (Dockerfiles multi-stage).
- Compromis : boucle de dev plus lente. `cargo` local reste permis pour itérer, jamais requis par `make`.

### D10 — K8s local : k3d + Traefik intégré (Q8)
- Alternatives : kind, minikube ; ingress-nginx.
- Pourquoi : k3d fait tourner k3s dans des conteneurs Docker (Docker est déjà requis). Le cluster vit entièrement dans la VM, se crée/détruit en secondes. Fournit un registry local (`k3d registry create`, pas de cloud), un LoadBalancer et Traefik comme ingress : rien de plus à installer pour les hostnames.
- Compromis : k3s est un Kubernetes allégé (certains composants remplacés) ; spécificités de Traefik à apprendre.

### D15 — Helm (versions épinglées) pour les tiers, YAML brut pour nos services (Q9)
- Périmètre Helm : Grafana, Loki, Tempo, Prometheus, OTel Collector, Kubo. Values dans `k8s/`.
- Périmètre manifests : `api`, `compiler`, `frontend`.
- Pourquoi : les charts officiels gèrent la complexité (stockage, config) ; épinglés = reproductibles. Manifests bruts pour notre code = chaque ligne explicable.
- Compromis : deux mécanismes de déploiement à expliquer.

### D11 — Namespaces `lgtm-app`, `observability`, `ipfs` (Q25)
- Pourquoi : NetworkPolicies et quotas par namespace ; cycles de vie séparés (redéployer l'app sans toucher l'observabilité).

### D26 — `make` = `make up`, DNS via `/etc/hosts` (Q27)
- `make up` enchaîne `deps → cluster → dns → observability → ipfs → build → deploy`.
- `make dns` ajoute avec `sudo` un bloc balisé `127.0.0.1 lgtm.local grafana.lgtm.local ipfs.lgtm.local`, idempotent. k3d mappe le port 80 de la VM vers Traefik.
- Pourquoi : une seule commande sur VM neuve, comme le demande le sujet.
- Compromis : `sudo` requis (déjà nécessaire pour installer les outils).

### D27 — HTTP uniquement (Q28)
- Alternative : TLS via mkcert.
- Pourquoi : le sujet n'impose pas HTTPS ; Monaco et `fetch` fonctionnent en HTTP ; un outil de moins à installer et à expliquer.
- Compromis : pas de TLS (polish possible plus tard).

### D30 — Toutes les versions épinglées (Q31)
- Images Rust/Node, crates `wasmtime`/`opentelemetry*`, charts Helm, Kubo.
- Choisies au début de chaque phase et consignées ici.
- Pourquoi : l'API Rust d'OTel change souvent ; l'épinglage garantit « marche sur VM neuve ».

#### Versions épinglées
_À remplir au fil des phases._

---

## Application

### D1 — Backend en Rust (axum + tokio) (Q3)
- Alternatives : Go (recommandé par la roadmap initiale).
- Pourquoi (motivation réelle) : **apprendre Rust**, que l'utilisateur ne connaît pas encore. Le projet sert de terrain d'apprentissage.
- Vérification d'adéquation au sujet, faite avant de trancher : Wasmtime est écrit en Rust, son API Rust est l'API de première classe : epoch, `StoreLimits` (mémoire), pipes WASI (capture de sortie) s'utilisent sans couche FFI. Même langage que le code utilisateur : un seul écosystème.
- Compromis : OTel Rust moins mature que Go (API qui bouge entre versions), temps de compilation, courbe d'apprentissage (langage nouveau + async/tokio) qui pèse sur le planning.

### D18 — Workspace Cargo `backend/` : crates `api`, `compiler`, `telemetry` (Q17)
- Pourquoi : la config OTel (tracer, meter, logs, propagation `traceparent`) est écrite une fois dans `telemetry` et partagée ; tests ciblés via `cargo test -p <crate>`.
- Compromis : les Dockerfiles doivent builder dans le contexte du workspace.

### D4 — Langage utilisateur : Rust → `wasm32-wasip1` (Q4)
- Alternatives : C/clang, TinyGo, AssemblyScript (gardés pour le bonus Polyglot) ; WASI preview 2 / component model.
- Pourquoi : Rust est l'exemple du sujet (« A developer writes a Rust function »). `wasm32-wasip1` est une cible officielle rustup. Preview 1 est supporté partout (TinyGo, wasi-sdk), ce qui garde le Polyglot ouvert. P2/components = complexité non demandée.
- Compromis : image rustc lourde (~1,5 Go), compilation de quelques centaines de ms à quelques secondes.

### D5 — Service compilateur dédié (Q15)
- Contrat : `POST /compile {language, source}` → `200` + octets `.wasm`, ou `422 {stderr}` si erreur de compilation.
- Implémentation : `rustc` directement sur un fichier unique, sans cargo ni crates externes : rien à télécharger.
- Isolation : NetworkPolicy deny-all en sortie, sauf vers l'OTel Collector. Pod non-root, readOnlyRootFS, limits.
- Pourquoi : rustc traite du code non fiable (macros, `include_str!`…) → on l'isole. Rend la trace distribuée sur 2 services.
- Alternatives : rustc dans le pod API.
- Compromis : transfert des octets en HTTP, un service de plus à déployer.

### D17 — Trait `Toolchain` par langage (Q16)
- Dans `compiler` : `trait Toolchain { compile(source) -> wasm }`, sélection par le champ `language`. Une image par toolchain à terme.
- Pourquoi : tous les langages ciblent wasip1, donc le runner est agnostique. Le Polyglot = ajouter une Toolchain + une image, sans toucher à l'API ni au runner.

### D3 — Wasmtime dans le process API, limites de la sandbox (Q14)
- Alternatives : Wasmer, WasmEdge ; runner dans un pod séparé.
- Limites :
  - **Mémoire** : `StoreLimits` à 10 MiB de mémoire linéaire. Au-delà, `memory.grow` échoue → panic/abort côté utilisateur.
  - **Temps** : epoch interruption. Une tâche tokio incrémente l'epoch ; deadline 5 s wall-clock. (Fuel écarté : compte des instructions, pas du temps, et ralentit l'exécution.)
  - **Sortie** : stdout/stderr dans un pipe mémoire plafonné à 10 kB ; au-delà, tronqué et `truncated=true`.
  - **Réseau / FS** : aucun preopen, pas d'env/args/stdio hérités. wasip1 n'a pas de création de socket et on n'accorde rien.
- Pourquoi : pas de hop réseau, le span `run` mesure l'exécution réelle.
- Compromis : un bug Wasmtime compromettrait le pod API → même durcissement que le compilateur (non-root, readOnlyRootFS, limits, NetworkPolicy).

### D23 — Contrat d'API synchrone (Q23)
- `POST /api/execute {language, source}` → `{status, stdout, stderr, truncated, cid, timings{compile, run, upload}, trace_id}` quand tout est fini. Spinner côté front.
- Pourquoi : suffisant pour le mandatory, simple à tracer.
- Évolution possible sans casse : progression live par SSE.

### D29 — Protection contre la surcharge (Q30)
- Source limitée à 64 kB → `413`.
- Max 4 exécutions concurrentes (sémaphore tokio) → `429` si plein, compté en `status="rejected"`.
- Pourquoi : 10 MiB par instance n'a de sens que si le nombre d'instances est borné ; sinon n'importe qui sature rustc et le pod.

### D20 — Politique d'upload IPFS (Q20)
- Upload dès que la compilation a réussi : succès, runtime error et timeout (la sortie, erreur comprise, va dans le répertoire). Jamais pour une `compile_error`.
- Pourquoi : une exécution en timeout a une sortie pertinente à partager.
- Conséquence : seules les traces `compile_error` n'ont pas de span `ipfs_upload`.

### D6 — IPFS : Kubo dans le cluster, API RPC HTTP (Q11)
- Alternatives : Helia.
- Pourquoi : nœud IPFS de référence. Un seul pod fournit l'API RPC (`/api/v0/add` avec `wrap-with-directory` → CID de répertoire), la gateway (`ipfs.lgtm.local`) et la connectivité P2P nécessaire pour que `ipfs.io` trouve le CID. Helia est une lib JS à encapsuler dans un service maison.

### D24 — Joignabilité publique d'IPFS (Q24)
- Port libp2p 4001 TCP+UDP ouvert de bout en bout : pod Kubo → port mapping k3d → VM → NAT VirtualBox → box.
- Kubo : AutoNAT + relay / hole punching en filet de sécurité.
- Procédure de test : ouvrir `ipfs.io/ipfs/<CID>` depuis un téléphone en 4G.
- Le README explique les limites NAT, comme le demande le sujet.

### D9 — Frontend : SvelteKit + `adapter-static` + nginx + Monaco (Q10)
- Alternatives : React + CodeMirror ; SvelteKit en SSR (adapter-node).
- Pourquoi : Svelte déjà maîtrisé. Monaco = l'éditeur de VS Code, donne l'effet « envie d'essayer » demandé. Build statique servi par nginx, `/api` routé par l'ingress : pas de serveur Node en prod, un service de moins à faire tourner et instrumenter.
- Compromis : Monaco est lourd (plusieurs Mo), pas de SSR (inutile ici).

### D28 — Démontrabilité des limites (Q29)
- Sélecteur d'exemples dans le front : Hello World (pré-chargé, montre Rust), boucle infinie (temps), grosse allocation (mémoire), spam de print (sortie), tentative fichier/réseau (refusée), erreur de compilation.
- Un **test Rust** par limite dans le crate `api`, sur un `.wasm` précompilé.
- `make demo` : rejoue tous les exemples en `curl` contre `lgtm.local`.
- Pourquoi : chaque limite est prouvable en un clic, par un test et en CLI.

---

## Observabilité

### D8 — OpenTelemetry Collector (contrib) (Q6)
- Alternatives : Grafana Alloy.
- Pourquoi : standard CNCF neutre. Le modèle receivers → processors → exporters est exactement ce qu'il faut expliquer, et c'est transposable chez n'importe quel vendor. Alloy emballe la même chose dans son propre langage (River).
- Compromis : config YAML plus verbeuse.

### D7 — Prometheus plutôt que Mimir (Q5)
- Alternatives : Mimir (recommandé par la roadmap initiale). Le sujet autorise la substitution.
- Pourquoi : Mimir est un système distribué conçu pour le multi-tenant à l'échelle ; sur une VM c'est plusieurs composants plus un stockage objet. Prometheus est un binaire unique et stocke les exemplars (`--enable-feature=exemplar-storage`), exigés par le sujet.
- Compromis : la stack n'est plus strictement « LGTM » ; substitution à expliquer en soutenance.
- À trancher en Phase 1 : exporter Collector → Prometheus (`otlphttp` vers le receiver OTLP de Prometheus, ou `prometheusremotewrite`), en vérifiant que les exemplars passent.

### D2 — Instrumentation du backend (Q18)
- Traces + logs : `tracing` + `tracing-opentelemetry` + `opentelemetry-appender-tracing`.
- Métriques : **OTel Metrics API directement** (`opentelemetry::metrics`), exigée nommément par le sujet.
- Alternatives : SDK `opentelemetry` brut pour tout.
- Pourquoi : `tracing` est le standard Rust ; `#[instrument]` crée les spans et tout log émis dans un span hérite de son `trace_id`.

### D14 — Logs applicatifs en OTLP vers Loki (Q7)
- Alternative : JSON sur stdout lu par le Collector (`filelog`).
- Pourquoi : `trace_id`/`span_id` attachés automatiquement par le bridge tracing↔OTel, corrélation garantie par construction. Loki 3 accepte l'OTLP nativement.
- Compromis : si un pod crashe avant flush, ses logs OTLP sont perdus. On garde aussi un stdout lisible pour `kubectl logs`.

### D19 — Taxonomie succès / échec (Q19)
- Compteur `executions_total{status, language}`, `status ∈ success | compile_error | runtime_error | timeout | memory_limit | rejected`.
- Dashboard : « failed » = `status != success`.
- Sortie tronquée = toujours `success`, avec un attribut `truncated`.
- Pourquoi : une métrique donne total, succès et échecs, avec la cause en bonus.

### D21 — Identification du code dans les traces (Q21)
- `code.sha256` sur le root span dès la réception ; `ipfs.cid` ajouté après l'upload.
- Pourquoi : le hash identifie toutes les traces, y compris les `compile_error` qui n'ont jamais de CID.

### D22 — Dashboard Traces et exemplars (Q22)
- Histogramme OTel `execution_duration_seconds` exporté vers Prometheus **avec exemplars** → durée dans le temps, moyenne, max ; clic sur un point → trace.
- Table **TraceQL** (Tempo) → exécutions les plus lentes.
- Liens de datasources : Tempo → Loki (« Logs for this span », par `trace_id`) ; Prometheus → Tempo (exemplars).
- Écarté : metrics-generator de Tempo (doublonnerait l'histogramme sans rien apporter).

### D25 — Persistance des données d'observabilité (Q26)
- PVC (`local-path` de k3d) pour Prometheus, Loki, Tempo ; rétention 7 jours. `make down` détruit tout.
- Pourquoi : un pod redémarré pendant la soutenance ne vide pas les dashboards.

---

## Démarche

### D16 — Mandatory d'abord, conçu modulaire pour les bonus (Q12)
- On termine entièrement le mandatory avant tout bonus (le sujet ne les évalue que si le mandatory est irréprochable).
- Ce qu'on construit doit rester assez modulaire pour accueillir les bonus plus tard : champ `language` partout, label `language` sur les métriques, trait `Toolchain` (D17), contrat d'API extensible (D23).
