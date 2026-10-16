# ---------------------------------------------------------------------------- #
#                        ft_lgtm - Looks Good To Monitor                       #
# ---------------------------------------------------------------------------- #

# ------------------------------- Configuration ------------------------------ #
CLUSTER_NAME	:= lgtm
REGISTRY_NAME	:= lgtm-registry
REGISTRY_PORT	:= 5000
HOSTS			:= lgtm.local grafana.lgtm.local ipfs.lgtm.local

.DEFAULT_GOAL	:= up
.PHONY: help up deps cluster dns down

# ----------------------------------- Meta ----------------------------------- #
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*## "} {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ------------------------------- Orchestration ------------------------------ #
up: deps cluster dns ## Install and deploy everything (default target)

# ---------------------------------- Phase 0 --------------------------------- #
deps: ## Install host tools (Debian 12 only)
	@echo "deps: TODO (next-steps, step 7)"

cluster: ## Create the k3d registry and cluster
	@echo "cluster: TODO (next-steps, step 8)"

dns: ## Add the *.lgtm.local entries to /etc/hosts
	@echo "dns: TODO (next-steps, step 10)"

down: ## Delete the cluster and the registry
	@echo "down: TODO (next-steps, step 11)"