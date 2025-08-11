#!/usr/bin/env bash
set -euo pipefail

# make-demo.sh: One-shot installer/run script for the KV-Cache Aware Routing demo
# - Applies LLM-D assets (gateway, route, decode, EPP, DR)
# - Applies Tekton assets (RBAC, pipelines)
# - Restarts decode pods for clean metrics
# - Launches the ramp PipelineRun
#
# Requirements:
# - oc (or kubectl) pointed at your cluster with sufficient perms
# - Tekton Pipelines installed on the cluster
# - Namespace defaults to llm-d (override with: NS=your-ns ./scripts/make-demo.sh)

NS=${NS:-llm-d}

info()  { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok()    { printf "\033[1;32m[OK]\033[0m %s\n"   "$*"; }
warn()  { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()   { printf "\033[1;31m[ERR]\033[0m %s\n"  "$*"; }

cmd() {
  echo "> $*"
  eval "$@"
}

ensure_ns() {
  if ! oc get ns "$NS" >/dev/null 2>&1; then
    info "Creating namespace $NS"
    cmd oc create ns "$NS"
  else
    info "Using existing namespace $NS"
  fi
}

apply_llmd_assets() {
  info "Applying LLM-D core assets"
  # Apply in a stable order
  for f in \
    assets/llm-d/gateway.yaml \
    assets/llm-d/httproute.yaml \
    assets/llm-d/destinationrule-decode.yaml \
    assets/llm-d/decode-service.yaml \
    assets/llm-d/decode-deployment.yaml \
    assets/llm-d/epp.yaml \
    assets/llm-d/modelservice.yaml
  do
    if [ -f "$f" ]; then cmd oc apply -n "$NS" -f "$f"; fi
  done

  # Optional: mesh-level consistent-hash DR safety net
  if [ -f assets/cache-aware/destination-rule-session-affinity.yaml ]; then
    info "Applying optional session-affinity DestinationRule"
    cmd oc apply -n "$NS" -f assets/cache-aware/destination-rule-session-affinity.yaml || warn "DestinationRule apply returned non-zero"
  fi
}

apply_tekton_assets() {
  info "Applying Tekton assets"
  for f in \
    assets/cache-aware/tekton/rbac-metrics-exec.yaml \
    assets/cache-aware/tekton/cache-pod-restart-pipeline.yaml \
    assets/cache-aware/tekton/cache-hit-pipeline.yaml
  do
    if [ -f "$f" ]; then cmd oc apply -n "$NS" -f "$f"; fi
  done
}

run_restart_pipeline() {
  info "Starting decode pod restart PipelineRun"
  if [ -f assets/cache-aware/tekton/cache-pod-restart-pipelinerun.yaml ]; then
    PR=$(oc create -n "$NS" -f assets/cache-aware/tekton/cache-pod-restart-pipelinerun.yaml -o jsonpath='{.metadata.name}') || true
    if [ -n "${PR:-}" ]; then
      info "Restart PipelineRun: $PR"
      # Wait for completion (best-effort)
      until STATUS=$(oc get pr "$PR" -n "$NS" -o jsonpath='{.status.conditions[?(@.type=="Succeeded")].status}' 2>/dev/null || true); \
            [ "$STATUS" = "True" ] || [ "$STATUS" = "False" ]; do
        sleep 5
      done
      info "Restart pipeline status: ${STATUS:-unknown}"
    else
      warn "Failed to create restart PipelineRun (continuing)"
    fi
  else
    warn "Restart PipelineRun manifest not found; skipping"
  fi
}

run_ramp_pipeline() {
  info "Starting ramp PipelineRun"
  if [ -f assets/cache-aware/tekton/cache-ramp-pipelinerun.yaml ]; then
    PR=$(oc create -n "$NS" -f assets/cache-aware/tekton/cache-ramp-pipelinerun.yaml -o jsonpath='{.metadata.name}')
    ok  "Ramp PipelineRun created: $PR"
    echo
    echo "Next: stream logs (requires tkn)"
    echo "  tkn pipelinerun logs -n $NS $PR -f --all"
    echo "Or stream the latest run:"
    echo "  tkn pipelinerun logs -n $NS --last -f --all"
  else
    err "Ramp PipelineRun manifest not found"
    return 1
  fi
}

main() {
  ensure_ns
  apply_llmd_assets
  apply_tekton_assets
  run_restart_pipeline
  run_ramp_pipeline
}

main "$@"

