# Prochaines étapes — Phase 1 (Stack d'observabilité)

Détail de la Phase 1 de `roadmap.md`. Une étape = un petit pas vérifiable.
Mode mentor : pour chaque notion, Claude l'explique simplement d'abord ; code en markdown, l'utilisateur l'écrit (ou demande explicitement à Claude de l'écrire), puis review.

## Phase 1
1. **Concepts** : les 3 piliers (logs, métriques, traces) et la question à laquelle chacun répond ; OTLP ; le Collector (receivers → processors → exporters) ; push vs pull ; exemplars.
   - Fini quand : tu sais dessiner le chemin app → Collector → Prometheus/Tempo/Loki → Grafana et dire ce qui circule sur chaque flèche.
2. **Helm** : chart, release, values, dépôt ; `helm upgrade --install` (idempotent) ; épingler `--version`.
   - Fini quand : tu sais expliquer ce que fait `helm upgrade --install <release> <chart> -n <ns> -f values.yaml --version X`.
3. **Décision à trancher** : chart Prometheus « simple » (`prometheus-community/prometheus`) ou `kube-prometheus-stack` (opérateur, inclut node-exporter/kube-state-metrics, utile pour le bonus infra, mais bien plus lourd). Consigner dans `decisions.md`. Choisir et épingler les versions de tous les charts de la phase (D30).
4. **Prometheus** : exemplar storage activé, réception des métriques poussées (OTLP ou remote write, cf. D7), PVC + rétention 7 j.
   - Fini quand : le pod tourne et l'UI Prometheus répond (port-forward).
5. **Tempo** : mode monolithique, stockage local sur PVC, receiver OTLP.
6. **Loki** : mode single binary, stockage filesystem sur PVC, ingestion OTLP native.
7. **OTel Collector** (image contrib) : receiver OTLP gRPC + HTTP ; exporters vers Tempo, Loki, Prometheus. Trancher `otlphttp` vs `prometheusremotewrite` (exemplars).
8. **Grafana** : datasources provisionnées depuis `dashboards/` (Prometheus, Tempo, Loki) avec les liens Tempo → Loki et Prometheus → Tempo ; Ingress `grafana.lgtm.local`.
9. **`make observability`** : enchaîne les `helm upgrade --install`, ajouté à `up` après `namespaces`.
10. **Test de bout en bout** avec un émetteur factice (ex. `telemetrygen`) : une trace dans Tempo, un log dans Loki, une métrique avec exemplar dans Prometheus, et le clic exemplar → trace fonctionne.
11. **Mettre à jour** `.ai/`, la section Commandes de `CLAUDE.md`, et le README (Instructions).

**En parallèle** : piste R (montée en Rust) de `roadmap.md`, hors du repo, à finir avant la Phase 2.
