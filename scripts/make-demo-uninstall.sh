#!/usr/bin/env bash
set -euo pipefail

# make-demo-uninstall.sh: remove KV-Cache Aware Routing demo resources
# - Deletes Tekton assets (pipelines, RBAC)
# - Deletes LLM-D assets (gateway, HTTPRoute, decode/EPP, DRs, ModelService)
# - Optionally deletes the namespace if NS_DELETE=true
#
# Usage:
#   NS=llm-d ./scripts/make-demo-uninstall.sh
#   NS=llm-d NS_DELETE=true ./scripts/make-demo-uninstall.sh

NS=${NS:-llm-d}
NS_DELETE=${NS_DELETE:-false}

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[OK]\033[0m %s\n"   "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR]\033[0m %s\n"  "$*"; }

cmd() { echo "> $*"; eval "$@"; }

exists_ns() { oc get ns "$NS" >/dev/null 2>&1; }

if ! exists_ns; then
  warn "Namespace $NS does not exist; nothing to uninstall."
  exit 0
fi

info "Uninstalling demo from namespace: $NS"

# 1) Delete Tekton PipelineRuns first (best-effort)
warn "Deleting Tekton PipelineRuns (best-effort)"
cmd "oc delete pipelineruns.tekton.dev -n $NS --all --ignore-not-found=true" || true

# 2) Delete Tekton assets (pipelines, tasks, RBAC)
info "Deleting Tekton pipelines and RBAC"
for f in \
  assets/cache-aware/tekton/cache-ramp-pipelinerun.yaml \
  assets/cache-aware/tekton/cache-pod-restart-pipelinerun.yaml \
  assets/cache-aware/tekton/cache-hit-pipelinerun.yaml \
  assets/cache-aware/tekton/cache-hit-pipeline.yaml \
  assets/cache-aware/tekton/cache-pod-restart-pipeline.yaml \
  assets/cache-aware/tekton/rbac-metrics-exec.yaml
do
  [ -f "$f" ] && cmd oc delete -n "$NS" -f "$f" --ignore-not-found=true || true
done

# 3) Delete LLM-D data-plane assets (reverse order of creation)
info "Deleting LLM-D data-plane assets"
for f in \
  assets/llm-d/modelservice.yaml \
  assets/cache-aware/destination-rule-session-affinity.yaml \
  assets/llm-d/epp.yaml \
  assets/llm-d/decode-deployment.yaml \
  assets/llm-d/decode-service.yaml \
  assets/llm-d/destinationrule-decode.yaml \
  assets/llm-d/httproute.yaml \
  assets/llm-d/gateway.yaml
do
  [ -f "$f" ] && cmd oc delete -n "$NS" -f "$f" --ignore-not-found=true || true
done

# 4) Wait for pods to terminate (best-effort)
info "Waiting for pods in $NS to terminate (30s grace)"
SECS=0
while oc get pods -n "$NS" --no-headers 2>/dev/null | grep -q . && [ $SECS -lt 30 ]; do
  sleep 3; SECS=$((SECS+3));
  echo -n "."
done
echo

# 5) Optionally delete namespace
if [ "$NS_DELETE" = "true" ]; then
  warn "Deleting namespace $NS"
  cmd oc delete ns "$NS" --ignore-not-found=true
  ok "Namespace deletion requested"
else
  ok "Uninstall complete (namespace preserved: $NS)"
fi

