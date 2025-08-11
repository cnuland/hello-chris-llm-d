#!/usr/bin/env bash
set -euo pipefail

# Canonical deploy script for Istio-only EPP KV-cache-aware demo
# - Installs/updates core assets in namespace llm-d
# - Ensures HF token secret
# - Applies decode Service/Deployment, EPP stack, EnvoyFilter, HTTPRoute, Tekton pipeline
# - Waits for readiness
# - Optionally runs a Tekton PipelineRun and tails logs

NAMESPACE=${NAMESPACE:-llm-d}
HOST_HEADER=${HOST_HEADER:-llm-d.demo.local}
GATEWAY_URL=${GATEWAY_URL:-http://llm-d-gateway-istio.${NAMESPACE}.svc.cluster.local}
PROM_URL_DEFAULT=http://thanos-querier.openshift-monitoring.svc.cluster.local:9091
PROM_URL=${PROM_URL:-$PROM_URL_DEFAULT}
RUN_PIPELINE=${RUN_PIPELINE:-true}
WARMUP_COUNT=${WARMUP_COUNT:-6}
REQUESTS=${REQUESTS:-60}
SLEEP_SECONDS=${SLEEP_SECONDS:-0.3}
MODEL_ID=${MODEL_ID:-meta-llama/Llama-3.2-3B-Instruct}

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT_DIR"

ns() {
  oc get ns "$NAMESPACE" >/dev/null 2>&1 || oc create ns "$NAMESPACE"
}

ensure_secret() {
  # Requires HF_TOKEN env var to be set in the shell
  if ! oc -n "$NAMESPACE" get secret llm-d-hf-token >/dev/null 2>&1; then
    if [ -z "${HF_TOKEN:-}" ]; then
      echo "ERROR: HF_TOKEN not set. Export HF_TOKEN with your token and re-run." >&2
      exit 1
    fi
    oc -n "$NAMESPACE" create secret generic llm-d-hf-token --from-literal=HF_TOKEN="$HF_TOKEN"
  fi
}

apply_assets() {
  # Core runtime (decode svc/deploy)
  oc -n "$NAMESPACE" apply -f assets/llm-d/decode-service.yaml
  oc -n "$NAMESPACE" apply -f assets/llm-d/decode-deployment.yaml
  # EPP stack
  oc -n "$NAMESPACE" apply -f assets/llm-d/epp.yaml
  # InferencePool/InferenceModel (pool-backed routing is required)
  oc -n "$NAMESPACE" apply -f assets/inference-crs.yaml
  # EnvoyFilter ext-proc
  oc -n "$NAMESPACE" apply -f assets/envoyfilter-epp.yaml
  # HTTPRoute to decode Service
  oc -n "$NAMESPACE" apply -f assets/llm-d/httproute.yaml
  # Tekton pipeline
  oc -n "$NAMESPACE" apply -f assets/cache-aware/tekton/cache-hit-pipeline.yaml
}

wait_ready() {
  echo "Waiting for decode deployment to be Ready..."
  oc -n "$NAMESPACE" rollout status deploy/ms-llm-d-modelservice-decode --timeout=600s
  echo "Waiting for EPP deployment to be Ready..."
  oc -n "$NAMESPACE" rollout status deploy/ms-llm-d-modelservice-epp --timeout=300s
}

run_pipeline() {
  ts=$(date +%s)
  cat <<EOF | oc create -f -
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: cache-hit-test-${ts}
  namespace: ${NAMESPACE}
spec:
  pipelineRef:
    name: cache-hit-pipeline
  params:
  - name: warmup-count
    value: "${WARMUP_COUNT}"
  - name: requests
    value: "${REQUESTS}"
  - name: sleep-seconds
    value: "${SLEEP_SECONDS}"
  - name: gateway-url
    value: "${GATEWAY_URL}"
  - name: host
    value: "${HOST_HEADER}"
  - name: prometheus-url
    value: "${PROM_URL}"
  workspaces:
  - name: output
    emptyDir: {}
EOF
  echo "Streaming logs..."
  tkn -n "$NAMESPACE" pr logs --last -f
}

main() {
  ns
  ensure_secret
  apply_assets
  wait_ready
  if [ "${RUN_PIPELINE}" = "true" ]; then
    run_pipeline
  else
    echo "Deploy complete. To run the pipeline later, ensure tkn is installed and run:"
    echo "  RUN_PIPELINE=true ./deploy.sh"
  fi
}

main "$@"

