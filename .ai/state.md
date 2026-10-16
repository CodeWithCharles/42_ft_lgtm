# État du projet

_Mis à jour le 2026-10-16._

- **Phase 0 terminée** (dernier commit `2fcfec2`). `make down && make` recrée tout sans intervention : deps → registry + cluster k3d (attente de Traefik) → namespaces → `/etc/hosts` ; `curl http://lgtm.local` → 404 de Traefik (aucune route encore).
- **Phase suivante** : Phase 1, stack d'observabilité (voir `next-steps.md`). En parallèle : piste R (montée en Rust).
- **Machine de dev** : VM VirtualBox Debian 12, 8 CPU, 13 Gio RAM. Outils aux versions épinglées (k3d v5.9.0, kubectl v1.36.5, Helm v4.3.1, k3s v1.36.5-k3s1).
- **Fichiers** : `Makefile` (help, deps, cluster, namespaces, dns, down, up), `k8s/namespaces.yaml`, `README.md` (brouillon, sections Description / Instructions / Resources), `.ai/`, `CLAUDE.md`.
- **À ajouter au README** : `sudo apt install make` en prérequis (une Debian neuve n'a pas toujours `make`) ; mention que Claude peut écrire des fichiers sur demande explicite (section AI).

## Leçons de la Phase 0 (pièges rencontrés)
- **Nœud Ready ≠ cluster prêt** : k3s installe Traefik de façon asynchrone (HelmChart → helm-controller → Job). `make cluster` attend `--for=create` puis `rollout status` sur `deployment/traefik`.
- **Ordre de `make down`** : `--registry-use` branche le registry sur le réseau du cluster ; supprimer le cluster d'abord laisse le réseau `k3d-lgtm` orphelin, et k3d le traite ensuite comme externe (ne le supprime plus). Ordre retenu : registry puis cluster.
- **Deux noms pour le registry** : on pousse vers `localhost:5000/...` depuis la VM ; les pods tirent `k3d-lgtm-registry:5000/...`.
- **`.local`** est réservé à mDNS ; `/etc/hosts` (`files`) passe avant dans `nsswitch.conf`, d'où le choix de D26.

## Ouvert
- Phase 1 : chart Prometheus (simple vs kube-prometheus-stack) ; exporter Collector → Prometheus (`otlphttp` vs `prometheusremotewrite`, selon les exemplars, D7).

## Historique
- 2026-10-16 : `CLAUDE.md` et `.ai/{decisions,state,next-steps}.md` non commités ont disparu du disque ; reconstruits (grilling Q1–Q32), `roadmap.md` réécrit.
- 2026-10-16 : quiz de soutenance D1, D3, D5, D7 OK ; D10 expliqué par Claude. Points clés : WASI = 1re couche, durcissement du pod = 2e (défense en profondeur) ; « Wasmtime est un sandbox, rustc non » (`include_str!`) ; le sujet autorise Prometheus à la place de Mimir.
- 2026-10-16 : règle d'édition assouplie : Claude peut écrire dans un fichier du repo **sur demande explicite uniquement**.
