# Prochaines étapes — Phase 0 (Fondations)

Détail de la Phase 0 de `roadmap.md`. Une étape = un petit pas vérifiable.
Mode mentor : tu écris le code, Claude guide et review.

1. ~~**Commiter le travail de cadrage**~~ ✅ (07ccde9) (`CLAUDE.md`, `.gitignore`, `.ai/`).
   - Fini quand : `git status` est propre.
2. ~~**Relire `decisions.md`** et vérifier que tu sais dire chaque « Pourquoi » avec tes mots.~~ ✅ quiz du 2026-10-16 : D3, D5, D7, D1 répondus ; D10 (chemin d'une requête `lgtm.local` → pod) expliqué par Claude, à réécrire avec tes mots.
   - Fini quand : tu peux expliquer D1, D3, D5, D7, D10 sans relire.
3. ~~**Exigences de la VM**~~ ✅ dans le README (Instructions → Requirements) : noter Debian 12, 4 CPU / 8 Go / 30 Go (servira au README).
   - Fini quand : c'est écrit (brouillon de README ou notes).
4. ~~**Arborescence imposée**~~ ✅ (8524d5f, Makefile squelette ; reste : compléter `.gitignore`) : `Makefile`, `README.md` (première ligne en italique), `backend/`, `frontend/`, `k8s/`, `dashboards/`.
   - Fini quand : `ls -la` correspond à celui du sujet.
5. **Choisir les versions** de k3d, k3s, kubectl, helm et les consigner dans « Versions épinglées » de `decisions.md`.
   - Fini quand : la section est remplie, avec la date.
6. **`make help`** : liste les cibles avec une description.
   - Fini quand : `make help` affiche toutes les cibles.
7. **`make deps`** : vérifie Debian 12 (échec clair sinon), installe `docker`, `k3d`, `kubectl`, `helm`, `curl` aux versions épinglées ; idempotent.
   - Fini quand : le lancer deux fois de suite ne réinstalle rien et ne casse rien.
8. **`make cluster`** : registry k3d + cluster, port 80 → Traefik, port 4001 TCP/UDP mappé ; idempotent.
   - Fini quand : `kubectl get nodes` est Ready et le registry répond.
9. **Namespaces** : manifest dans `k8s/` pour `lgtm-app`, `observability`, `ipfs`, appliqué par une cible.
   - Fini quand : `kubectl get ns` les liste.
10. **`make dns`** : bloc balisé dans `/etc/hosts` via `sudo`, idempotent.
    - Fini quand : `getent hosts grafana.lgtm.local` → `127.0.0.1`, et relancer n'ajoute pas de doublon.
11. **`make down`** et **`make up`** (cible par défaut) qui enchaîne ce qui existe.
    - Fini quand : `make down && make` remonte tout sans intervention.
12. **Mettre à jour** la section Commandes de `CLAUDE.md` et `state.md`.

**En parallèle** : piste R (montée en Rust) de `roadmap.md`, hors du repo, à finir avant la Phase 2.

Ensuite : Phase 1 (stack d'observabilité).
