# LGTM — Looks Good To Monitor · Roadmap

> Plateforme d'exécution de code Rust (WASM/WASI) partagée via IPFS, entièrement
> observée par Grafana + Prometheus + Tempo + Loki, sur un cluster k3d local dans
> une VM Debian 12.
>
> Les choix et leurs raisons sont dans `decisions.md` (référencés `Dn` ici).
> Ordre : l'observabilité est déployée **avant** l'app, pour voir les données
> arriver dès les premières lignes instrumentées.
> Mandatory d'abord ; tout est conçu modulaire pour les bonus (D16).

Chaque phase a un **critère de fin** (vérifiable) et une **check-list de soutenance**
(ce que tu dois savoir expliquer sans aide).

---

## Vue d'ensemble

| # | Phase | Livrable clé |
|---|---|---|
| R | Montée en Rust (en parallèle de 0–1) | Bases Rust + axum + Wasmtime maîtrisées avant la Phase 2 |
| 0 | Fondations | VM documentée, arborescence, `make deps/cluster/dns` |
| 1 | Observabilité | Grafana + Prometheus + Tempo + Loki + Collector provisionnés as-code |
| 2 | Backend | `compiler` + `api` : compile et exécute dans la sandbox, limites testées |
| 3 | IPFS | Kubo, CID de répertoire, visible sur `ipfs.io` |
| 4 | Instrumentation | Traces distribuées, métriques, logs corrélés |
| 5 | Frontend | Playground sur `lgtm.local` |
| 6 | Dashboards | 2 dashboards + exemplars + « Logs for this span » |
| 7 | Bonus | Seulement si le mandatory est irréprochable |
| 8 | Finitions | README, `make` sur VM neuve, `make demo`, prépa soutenance |

---

## Piste R — Montée en Rust (en parallèle des Phases 0 et 1)

**But :** arriver à la Phase 2 en sachant écrire et défendre du Rust. Rust a été choisi
pour l'apprendre (D1) ; les Phases 0 et 1 sont de l'infra pure (Makefile, Helm, YAML),
c'est le moment de monter en compétence.

Tout se fait **hors du repo** (ex. `~/rust-sandbox/`). `rustup` local est permis (D13 :
jamais requis par `make`).

1. **Le Rust Book** : ch. 1–10 (ownership, borrowing, structs/enums, `match`, gestion d'erreurs avec `Result` et `?`, traits et génériques), puis ch. 13 (closures, itérateurs) et ch. 16 (concurrence).
2. **Async** : tutoriel tokio (tâches, `async`/`await`, `Arc`, sémaphore).
3. **Mini-exercices** :
   - axum : un endpoint `POST` qui reçoit et renvoie du JSON (serde), avec erreurs typées → codes HTTP ;
   - un trait avec deux implémentations choisies à l'exécution (prépare `Toolchain`, D17) ;
   - Wasmtime : compiler un hello world en `wasm32-wasip1`, l'exécuter depuis un programme Rust en capturant stdout, puis ajouter `StoreLimits` et une epoch deadline et les voir se déclencher (prototype jetable du runner, D3).

**Critère de fin (avant la Phase 2) :** tu écris sans aide un handler axum qui renvoie du JSON et propage les erreurs avec `?` ; tu expliques ownership/borrowing, traits, `async`/`await` ; ton prototype Wasmtime coupe une boucle infinie et une allocation trop grosse.

**Soutenance :** ownership et borrow checker (pourquoi pas de GC) ; `Result` vs exceptions ; traits vs interfaces ; ce que fait le runtime tokio.

---

## Phase 0 — Fondations ✅ (terminée le 2026-10-16)

**But :** un socle reproductible sur une Debian 12 neuve (D12).

1. Documenter la VM : Debian 12, 4 CPU / 8 Go RAM / 30 Go disque minimum.
2. Arborescence imposée : `.gitignore`, `Makefile`, `README.md`, `backend/`, `frontend/`, `k8s/`, `dashboards/`.
3. Makefile, première vague :
   - `help` : liste les cibles.
   - `deps` : vérifie Debian 12 puis installe `docker`, `k3d`, `kubectl`, `helm`, `curl` (D13). Idempotent.
   - `cluster` : registry local k3d + cluster ; port 80 → Traefik, port 4001 TCP/UDP réservé pour Kubo (D10, D24).
   - `dns` : bloc balisé dans `/etc/hosts` via `sudo`, idempotent (D26).
   - `down` : détruit cluster et registry.
   - `up` (cible par défaut) : enchaîne les cibles existantes ; on l'allonge à chaque phase.
4. Namespaces `lgtm-app`, `observability`, `ipfs` (D11) en manifests dans `k8s/`.
5. Section « Versions épinglées » de `decisions.md` : k3d, k3s, kubectl, helm (D30).

**Critère de fin :** sur une VM neuve, `make` → `kubectl get nodes` Ready, les 3 namespaces existent, `getent hosts lgtm.local` → `127.0.0.1`, et relancer `make` ne casse rien.

**Soutenance :** VM vs conteneur vs cluster ; ce qu'est k3s/k3d et pourquoi pas kind/minikube ; rôle d'un ingress et de Traefik ; comment un hostname `.local` arrive jusqu'à un pod ; idempotence d'un Makefile.

---

## Phase 1 — Stack d'observabilité

**But :** pipeline de télémétrie complet, avant toute ligne d'app.

1. Charts Helm épinglés, values dans `k8s/` (D15) : Prometheus (exemplar storage activé), Tempo, Loki, OTel Collector contrib, Grafana.
2. PVC `local-path` + rétention 7 jours pour Prometheus, Loki, Tempo (D25).
3. Collector : receiver OTLP (gRPC + HTTP) → traces vers Tempo, logs vers Loki (OTLP natif), métriques vers Prometheus.
   - **À trancher ici** : `otlphttp` vers le receiver OTLP de Prometheus ou `prometheusremotewrite` ; critère = les exemplars arrivent (D7).
4. Grafana provisionné as-code depuis `dashboards/` : 3 datasources + liens Tempo → Loki (par `trace_id`) et Prometheus → Tempo (exemplars) (D22).
5. Ingress `grafana.lgtm.local`.
6. Cible `make observability`, ajoutée à `up`.

**Critère de fin :** `grafana.lgtm.local` répond, 3 datasources vertes ; un émetteur de test (ex. `telemetrygen`) produit une trace visible dans Tempo, un log dans Loki, une métrique **avec exemplar** dans Prometheus, et le lien exemplar → trace fonctionne.

**Soutenance :** les 3 piliers (logs, métriques, traces) et ce que chacun répond ; OTLP ; receivers / processors / exporters ; pourquoi Prometheus et pas Mimir ; ce qu'est un exemplar ; push vs pull ; provisioning as-code.

---

## Phase 2 — Backend : compilation et sandbox

**But :** recevoir du code, le compiler en WASM, l'exécuter sous contraintes.

1. Workspace Cargo `backend/` : crates `api`, `compiler`, `telemetry` (D18). `telemetry` exporte déjà les traces, pour voir les spans arriver dès maintenant.
2. **compiler** (D5, D17) :
   - `POST /compile {language, source}` → `200` + `.wasm` ou `422 {stderr}`.
   - Trait `Toolchain` ; une seule impl : Rust via `rustc --target wasm32-wasip1`, fichier unique, sans crates.
   - Dockerfile multi-stage avec la toolchain épinglée.
3. **api** (D3, D23, D29) :
   - `POST /api/execute`, `GET /health`.
   - Limite source 64 kB (`413`), sémaphore 4 exécutions (`429`).
   - Appel HTTP au compilateur.
   - Runner Wasmtime : `StoreLimits` 10 MiB, epoch 5 s, pipe 10 kB, aucun preopen/env/args.
   - Réponse `{status, stdout, stderr, truncated, cid, timings, trace_id}` (`cid` vide jusqu'à la Phase 3).
4. Tests Rust des limites dans `api`, sur des `.wasm` précompilés : timeout, mémoire, sortie tronquée, accès FS refusé (D28).
5. Manifests `k8s/` : Deployments, Services, ingress `/api`. Durcissement des deux pods : non-root, readOnlyRootFS, limits, NetworkPolicy (compilateur : sortie deny-all sauf Collector).
6. Cibles `make build` (images → registry k3d) et `make deploy`.

**Critère de fin :** `curl -X POST lgtm.local/api/execute` avec un Hello World renvoie le stdout ; les 4 tests de limites passent ; une boucle infinie est coupée à 5 s ; une erreur de compilation renvoie un stderr lisible.

**Soutenance :** WASM vs WASI ; modèle de sécurité par capabilities ; comment chaque limite est appliquée (StoreLimits, epoch vs fuel, pipe plafonné, aucun preopen) et ce qui se passe quand on la dépasse ; pourquoi isoler rustc ; défense en profondeur côté K8s ; async/tokio et le sémaphore.

---

## Phase 3 — IPFS

**But :** partager code + sortie dans un répertoire IPFS public.

1. Kubo via Helm dans `ipfs` : API RPC (5001, interne), gateway (8080) derrière `ipfs.lgtm.local` (D6).
2. Port 4001 TCP/UDP de bout en bout (pod → k3d → VM → NAT VirtualBox → box) ; AutoNAT + relay / hole punching (D24).
3. Dans `api` : construire le répertoire (`source.rs`, `output.txt`, `meta.json` avec langage, statut, timings) et l'envoyer via `/api/v0/add?wrap-with-directory=true` → CID du répertoire.
4. Upload dès que la compilation a réussi (succès, runtime error, timeout) ; jamais sur `compile_error` (D20).
5. Cible `make ipfs`, ajoutée à `up`.

**Critère de fin :** une exécution renvoie un CID ; `ipfs.lgtm.local/ipfs/<CID>/` liste les fichiers ; le même CID s'ouvre sur `ipfs.io` depuis un téléphone en 4G.

**Soutenance :** adressage par contenu, CID, pourquoi un répertoire a son propre CID ; DHT et annonce de contenu ; gateway ; NAT, hole punching, relays ; pourquoi Kubo et pas Helia.

---

## Phase 4 — Instrumentation OpenTelemetry

**But :** chaque exécution est entièrement observable. C'est le cœur évalué.

1. `telemetry` complet (D2) : tracer, meter, logger OTLP ; propagation W3C `traceparent`.
2. Spans :
   - root HTTP avec `code.sha256` dès la réception, `ipfs.cid` après upload (D21) ;
   - `compile` côté API, et span serveur côté compilateur (trace distribuée sur 2 services) ;
   - `run` ;
   - `ipfs_upload`.
   - Toute erreur : status `Error` + event sur le span concerné.
3. Métriques via l'OTel Metrics API (D19, D22) :
   - `executions_total{status, language}` ;
   - histogramme `execution_duration_seconds` avec exemplars.
4. Logs (D14) : OTLP vers Loki avec `trace_id`/`span_id` ; stdout lisible conservé.

**Critère de fin :** une exécution = 1 trace dans Tempo avec les 4 spans sur 2 services ; le compteur bouge dans Prometheus avec le bon `status` ; les logs de la trace sont trouvables dans Loki par `trace_id` ; une `compile_error` donne une trace en erreur sans span `ipfs_upload`.

**Soutenance :** span, trace, contexte, propagation ; API vs SDK OTel ; `tracing` et son bridge ; counter vs histogram ; cardinalité des labels ; comment un exemplar est attaché à un point d'histogramme.

---

## Phase 5 — Frontend : le Playground

**But :** une interface qui donne envie d'essayer.

1. SvelteKit + `adapter-static`, servi par nginx ; Monaco (D9).
2. Exigences du sujet : exemple pré-chargé (Hello World qui montre Rust), bouton Run proéminent, spinner pendant l'exécution, erreurs compile/run claires, sortie soignée, lien IPFS.
3. Sélecteur d'exemples (D28) : Hello World, boucle infinie, grosse allocation, spam de print, accès fichier/réseau, erreur de compilation.
4. Affichage des timings (compile · run · upload) et du `trace_id`.
5. Ingress : `/` → frontend, `/api` → api.

**Critère de fin :** sur `lgtm.local`, chaque exemple donne le résultat attendu, avec le lien IPFS quand il y a eu upload.

**Soutenance :** SPA statique vs SSR ; comment l'ingress route `/` et `/api` ; pourquoi Monaco.

---

## Phase 6 — Dashboards Grafana

**But :** les deux dashboards imposés, provisionnés depuis `dashboards/` (D22).

1. **Dashboard 1 — Metrics** : exécutions réussies, échouées (`status != success`), totales ; ventilation par `status`.
2. **Dashboard 2 — Traces** : durée dans le temps, moyenne, max (histogramme + exemplars) ; table TraceQL des plus lentes.
3. Vérifier « Logs for this span » et le clic exemplar → trace.

**Critère de fin :** depuis un point lent sur le graphe → clic → trace dans Tempo → « Logs for this span » → logs dans Loki. Boucle complète.

**Soutenance :** PromQL des panels (`rate`, `histogram_quantile`, moyenne via `_sum / _count`) ; TraceQL ; corrélations entre datasources.

---

## Phase 7 — Bonus

> Seulement une fois le mandatory irréprochable. Chacun doit être production-quality
> et visible dans Grafana.

1. **Polyglot** : nouvelles impls de `Toolchain` + images (C/wasi-sdk, TinyGo, AssemblyScript) ; sélecteur côté front ; label `language` déjà en place.
2. **Infra observability** : kube-state-metrics + node-exporter → Prometheus → dashboard K8s.
3. **Deep IPFS** : traces Kubo reliées aux traces app ; temps de propagation.
4. **Social sharing** : short URLs `lgtm.local/s/<id>` → CID.
5. **Profiling** : CPU / mémoire / hot paths attachés aux traces.

---

## Phase 8 — Finitions et soutenance

1. **README** :
   - première ligne, en italique, exactement : `*This project has been created as part of the 42 curriculum by cpoulain.*`
   - sections Description, Instructions, Resources (dont usage de l'IA : quelles tâches, quelles parties) ;
   - choix techniques (renvoi aux décisions), limites NAT d'IPFS, specs minimales de la VM.
2. **Makefile** : `make` complet testé sur une Debian 12 neuve ; `down` et `clean` propres ; `make demo` rejoue tous les exemples en `curl` (D28).
3. **Check-list de démo** :
   - [ ] Hello World → sortie + CID + trace complète.
   - [ ] Erreur de compilation → affichage clair + span en erreur.
   - [ ] Boucle infinie → coupée à 5 s, statut `timeout`.
   - [ ] Grosse allocation → statut `memory_limit`.
   - [ ] Spam de print → tronqué à 10 kB.
   - [ ] Accès fichier/réseau → refusé.
   - [ ] Plus de 4 exécutions simultanées → `429`.
   - [ ] CID ouvert sur `ipfs.io` depuis un autre réseau.
   - [ ] Exemplar → trace → logs.
4. Relire `decisions.md` : chaque « Pourquoi » doit pouvoir être dit sans notes.

---

## Pièges à éviter

- Instrumenter en dernier : l'observabilité est le sujet, on la câble tôt.
- Configurer Grafana à la main : non reproductible.
- CID de fichier au lieu de répertoire.
- Croire la sandbox sûre « par défaut » sans prouver chaque limite.
- Makefile qui ne marche que sur la machine de dev.
- Oublier `trace_id` dans les logs : toute la corrélation casse.
- Commencer un bonus avant que le mandatory soit parfait.
