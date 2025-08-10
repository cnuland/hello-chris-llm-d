#!/usr/bin/env bash
set -euo pipefail

# Minimal POC deployer (dry-run by default)
# Usage:
#   scripts/deploy.sh               # print the kubectl commands (no changes applied)
#   scripts/deploy.sh --monitoring  # include monitoring commands in the printout
#   scripts/deploy.sh --apply       # actually apply core manifests
#   scripts/deploy.sh --apply --monitoring  # also apply monitoring

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }

DRY_RUN=true
WITH_MONITORING=false

for arg in "$@"; do
  case "$arg" in
    --apply) DRY_RUN=false ;;
    --monitoring) WITH_MONITORING=true ;;
    -h|--help)
      cat <<'EOF'
Minimal LLM-D POC deployer

Default behavior is DRY-RUN (prints the kubectl commands without applying).

Flags:
  --apply        Apply the manifests to the cluster
  --monitoring   Include Prometheus and Grafana manifests
  -h, --help     Show this help

Core manifests:
  - kustomize: assets/llm-d
  - EnvoyFilter: assets/envoyfilter-epp.yaml
  - Inference CRs: assets/inference-crs.yaml
Optional monitoring (applied in order):
  - monitoring/prometheus-config.yaml
  - monitoring/prometheus.yaml
  - monitoring/grafana-config.yaml
  - monitoring/grafana-datasources.yaml
  - monitoring/grafana-dashboards-config.yaml
  - monitoring/grafana-dashboard-llm-performance.json
  - monitoring/grafana.yaml
  - monitoring/grafana-service.yaml
EOF
      exit 0
      ;;
  esac
done

# Build command lists
CORE_CMDS=(
  "kubectl apply -k assets/llm-d"
  "kubectl apply -f assets/envoyfilter-epp.yaml"
  "kubectl apply -f assets/inference-crs.yaml"
)
MON_CMDS=(
  "kubectl apply -f monitoring/prometheus-config.yaml"
  "kubectl apply -f monitoring/prometheus.yaml"
  "kubectl apply -f monitoring/grafana-config.yaml"
  "kubectl apply -f monitoring/grafana-datasources.yaml"
  "kubectl apply -f monitoring/grafana-dashboards-config.yaml"
  "kubectl apply -f monitoring/grafana-dashboard-llm-performance.json"
  "kubectl apply -f monitoring/grafana.yaml"
  "kubectl apply -f monitoring/grafana-service.yaml"
)

info "LLM-D POC deployer"
if "$DRY_RUN"; then warn "DRY-RUN: No changes will be applied"; fi

# Execute or print core commands
for cmd in "${CORE_CMDS[@]}"; do
  if "$DRY_RUN"; then
    echo "$cmd"
  else
    eval "$cmd"
  fi
done

# Execute or print monitoring commands
if "$WITH_MONITORING"; then
  for cmd in "${MON_CMDS[@]}"; do
    if "$DRY_RUN"; then
      echo "$cmd"
    else
      eval "$cmd"
    fi
  done
fi

if "$DRY_RUN"; then
  warn "This was a dry run. Re-run with --apply to execute these commands."
else
  ok "Deployment complete."
fi
