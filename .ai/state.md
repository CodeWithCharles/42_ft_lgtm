# État du projet

_Mis à jour le 2026-10-16._

- **Phase en cours** : début de Phase 0. Aucun code, aucun Makefile, aucun manifest.
- **Cadrage terminé** : session de grilling (Q1–Q32). Toutes les décisions sont dans `decisions.md` (D1–D30), la roadmap a été réécrite pour la stack retenue, `next-steps.md` détaille la Phase 0.
- **Machine de dev** : VM VirtualBox Debian 12, 8 CPU, 13 Gio RAM. `docker`, `k3d`, `kubectl`, `helm`, Node 22 déjà installés ; pas de Rust (normal : les builds passent par Docker, D13).
- **Fichiers présents** : `ft_lgtm.pdf` (sujet v1.1, gitignoré), `.gitignore` (`*.pdf`), `CLAUDE.md`, `.ai/`. Rien n'est encore commité à part l'ancienne roadmap.
- **Ouvert, à trancher en Phase 1** : exporter Collector → Prometheus (`otlphttp` vs `prometheusremotewrite`), selon le passage des exemplars (D7).
- **Historique** : le 2026-10-16, `CLAUDE.md` et `.ai/{decisions,state,next-steps}.md` non commités ont disparu du disque ; `roadmap.md` restauré depuis git puis réécrit, les autres reconstruits.
