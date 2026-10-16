# ---------------------------------------------------------------------------- #
#                        ft_lgtm - Looks Good To Monitor                       #
# ---------------------------------------------------------------------------- #

# ------------------------------- Configuration ------------------------------ #
CLUSTER_NAME	:= lgtm
REGISTRY_NAME	:= lgtm-registry
REGISTRY_PORT	:= 5000
HOSTS			:= lgtm.local grafana.lgtm.local ipfs.lgtm.local

# Pinned versions (see .ai/decisions.md)
K3D_VERSION		:= v5.9.0
K3S_IMAGE		:= rancher/k3s:v1.36.5-k3s1
KUBECTL_VERSION	:= v1.36.5
HELM_VERSION	:= v4.3.1

ARCH			:= $(shell dpkg --print-architecture)
BIN_DIR			:= /usr/local/bin
BASE_PACKAGES	:= ca-certificates curl
DOCKER_PACKAGES	:= docker-ce docker-ce-cli containerd.io docker-buildx-plugin
SHELL			:= /bin/bash
.SHELLFLAGS		:= -eu -o pipefail -c

.DEFAULT_GOAL	:= up
.PHONY: help up deps check-os base-packages docker k3d kubectl helm cluster dns down

# ----------------------------------- Meta ----------------------------------- #
help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ------------------------------- Orchestration ------------------------------ #
up: deps cluster namespaces dns ## Install and deploy everything (default target)

# ---------------------------------- Phase 0 --------------------------------- #
deps: check-os base-packages docker k3d kubectl helm ## Install host tools (Debian 12 only)

check-os:
	@. /etc/os-release; \
	if [ "$$ID" != "debian" ] || [ "$$VERSION_ID" != "12" ]; then \
			echo "Error: Debian 12 required (found: $$PRETTY_NAME)" >&2; \
			exit 1; \
	fi

base-packages:
	@if dpkg -s $(BASE_PACKAGES) >/dev/null 2>&1; then \
			echo "Base packages already installed"; \
	else \
			echo "Installing base packages"; \
			sudo apt-get update -qq; \
			sudo apt-get install -y -qq $(BASE_PACKAGES); \
	fi

docker: ## Install Docker Engine (official apt repository)
	@if command -v docker >/dev/null 2>&1; then \
			echo "Docker already installed"; \
	else \
			echo "Installing Docker Engine"; \
			sudo install -m 0755 -d /etc/apt/keyrings; \
			sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; \
			sudo chmod a+r /etc/apt/keyrings/docker.asc; \
			. /etc/os-release; \
			echo "deb [arch=$(ARCH) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $$VERSION_CODENAME stable" \
					| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; \
			sudo apt-get update -qq; \
			sudo apt-get install -y -qq $(DOCKER_PACKAGES); \
			sudo systemctl enable --now docker; \
	fi
	@if ! id -nG "$$USER" | grep -qw docker; then \
			sudo usermod -aG docker "$$USER"; \
			echo "Added $$USER to the docker group: log out and back in, then run make again." >&2; \
			exit 1; \
	elif ! docker info >/dev/null 2>&1; then \
			echo "Cannot reach the Docker daemon. If you were just added to the docker group, log out and back in." >&2; \
			exit 1; \
	fi

k3d: ## Install k3d $(K3D_VERSION)
	@if [ "$$(k3d version 2>/dev/null | awk 'NR==1 {print $$3}')" = "$(K3D_VERSION)" ]; then \
			echo "k3d $(K3D_VERSION) already installed"; \
	else \
			echo "Installing k3d $(K3D_VERSION)"; \
			curl -fsSL -o /tmp/k3d \
					https://github.com/k3d-io/k3d/releases/download/$(K3D_VERSION)/k3d-linux-$(ARCH); \
			sudo install -m 0755 /tmp/k3d $(BIN_DIR)/k3d; \
			rm -f /tmp/k3d; \
	fi

kubectl: ## Install kubectl $(KUBECTL_VERSION)
	@if [ "$$(kubectl version --client 2>/dev/null | awk '/Client Version/ {print $$3}')" = "$(KUBECTL_VERSION)" ]; then \
			echo "kubectl $(KUBECTL_VERSION) already installed"; \
	else \
			echo "Installing kubectl $(KUBECTL_VERSION)"; \
			curl -fsSL -o /tmp/kubectl https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/$(ARCH)/kubectl; \
			echo "$$(curl -fsSL https://dl.k8s.io/release/$(KUBECTL_VERSION)/bin/linux/$(ARCH)/kubectl.sha256)  /tmp/kubectl" \
					| sha256sum --check --quiet; \
			sudo install -m 0755 /tmp/kubectl $(BIN_DIR)/kubectl; \
			rm -f /tmp/kubectl; \
	fi

helm: ## Install Helm $(HELM_VERSION)
	@if [ "$$(helm version --template '{{.Version}}' 2>/dev/null)" = "$(HELM_VERSION)" ]; then \
			echo "Helm $(HELM_VERSION) already installed"; \
	else \
			echo "Installing Helm $(HELM_VERSION)"; \
			curl -fsSL -o /tmp/helm.tar.gz https://get.helm.sh/helm-$(HELM_VERSION)-linux-$(ARCH).tar.gz; \
			echo "$$(curl -fsSL https://get.helm.sh/helm-$(HELM_VERSION)-linux-$(ARCH).tar.gz.sha256)  /tmp/helm.tar.gz" \
					| sha256sum --check --quiet; \
			tar -xzf /tmp/helm.tar.gz -C /tmp linux-$(ARCH)/helm; \
			sudo install -m 0755 /tmp/linux-$(ARCH)/helm $(BIN_DIR)/helm; \
			rm -rf /tmp/helm.tar.gz /tmp/linux-$(ARCH); \
	fi

cluster: ## Create the k3d registry and cluster
	@if k3d registry list k3d-$(REGISTRY_NAME) >/dev/null 2>&1; then \
			echo "Registry k3d-$(REGISTRY_NAME) already exists"; \
	else \
			k3d registry create $(REGISTRY_NAME) --port $(REGISTRY_PORT); \
	fi
	@if k3d cluster list $(CLUSTER_NAME) >/dev/null 2>&1; then \
			echo "Cluster $(CLUSTER_NAME) already exists"; \
	else \
			k3d cluster create $(CLUSTER_NAME) \
					--image $(K3S_IMAGE) \
					--servers 1 --agents 0 \
					--registry-use k3d-$(REGISTRY_NAME):$(REGISTRY_PORT) \
					--port "80:80@loadbalancer" \
					--port "4001:4001/tcp@loadbalancer" \
					--port "4001:4001/udp@loadbalancer" \
					--wait; \
	fi
	@kubectl config use-context k3d-$(CLUSTER_NAME) >/dev/null
	@kubectl wait --for=condition=Ready node --all --timeout=120s

namespaces: ## Create the project namespaces
	@kubectl apply -f k8s/namespaces.yaml

dns: ## Add the *.lgtm.local entries to /etc/hosts
	@echo "dns: TODO (next-steps, step 10)"

down: ## Delete the cluster and the registry
	@echo "down: TODO (next-steps, step 11)"
