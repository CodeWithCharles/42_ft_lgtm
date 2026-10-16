*This project has been created as part of the 42 curriculum by cpoulain.*

# ft_lgtm — Looks Good To Monitor

> 🚧 Work in progress: the infrastructure and the application are being built phase by phase. Sections marked *(planned)* describe the target, not what exists today.

## Description

ft_lgtm is a code playground with observability built in. A user writes Rust in the browser and clicks **Run**:

1. the code is compiled to WebAssembly (`wasm32-wasip1`) by a dedicated compiler service;
2. the module runs in a Wasmtime/WASI sandbox with no network, no filesystem, a 10 MiB memory limit, a 5 s time limit and a 10 kB output limit;
3. the source and its output are packaged into a directory and uploaded to IPFS, which gives a CID that also works on public gateways such as `ipfs.io`;
4. every step is traced, measured and logged with OpenTelemetry, and visualized in Grafana (Prometheus for metrics, Tempo for traces, Loki for logs), with exemplars linking metrics to traces and traces to logs.

Everything runs locally in a single VM, on a k3d Kubernetes cluster, with no cloud services:

| Hostname | Service |
|---|---|
| `lgtm.local` | The playground (SvelteKit + Monaco) and its API |
| `grafana.lgtm.local` | Grafana dashboards |
| `ipfs.lgtm.local` | IPFS gateway (Kubo) |

Stack: Rust (axum, tokio, Wasmtime, `tracing` + OpenTelemetry), SvelteKit, Kubo, OpenTelemetry Collector, Prometheus, Tempo, Loki, Grafana, k3d with Traefik.

## Instructions

### Requirements

- **Debian 12** VM (the only supported OS), with at least 4 CPUs, 8 GB of RAM and 30 GB of free disk.
- `sudo` rights: `make` installs packages and adds the hostnames to `/etc/hosts`.
- Internet access, to download container images and Helm charts.
- Port 80 free on the VM.
- For the IPFS link to work on public gateways: TCP/UDP port 4001 reachable from the outside. Behind a NAT without UPnP/IPv6, see the IPFS limitations section *(planned)*.

Docker, k3d, kubectl and Helm don't need to be installed beforehand: `make` installs them. All builds (Rust, frontend) happen inside Docker images.

### Usage *(planned)*

```sh
make          # install dependencies and deploy everything (same as `make up`)
make help     # list all targets
make demo     # replay the sandbox limit examples against lgtm.local
make down     # destroy the cluster
```

Then open `http://lgtm.local` and `http://grafana.lgtm.local`.

## Resources

### References

- [Wasmtime documentation](https://docs.wasmtime.dev/) and [WASI](https://wasi.dev/)
- [The Rust Programming Language](https://doc.rust-lang.org/book/)
- [OpenTelemetry documentation](https://opentelemetry.io/docs/) and [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [IPFS documentation](https://docs.ipfs.tech/)
- [Prometheus documentation](https://prometheus.io/docs/)
- [Grafana](https://grafana.com/docs/grafana/latest/), [Tempo](https://grafana.com/docs/tempo/latest/) and [Loki](https://grafana.com/docs/loki/latest/) documentation
- [k3d documentation](https://k3d.io/)

### Use of AI

Claude Code (Anthropic) is used as a **mentor**, not as an author of the application:

- **Planning and architecture**: Claude asked structured questions and proposed options with trade-offs; every decision was made by the student and is recorded with its reasoning in `.ai/decisions.md`. The phased roadmap (`.ai/roadmap.md`) and progress notes (`.ai/state.md`, `.ai/next-steps.md`) were written by Claude from those decisions.
- **Defense preparation**: Claude quizzes the student on the design choices.
- **Code**: application code, Kubernetes manifests, the Makefile and dashboards are written by the student. Claude explains concepts, gives guidance and reviews the code.
- **This README** was drafted by Claude at the student's request and reviewed by the student.

This section will be kept up to date as the project progresses.
