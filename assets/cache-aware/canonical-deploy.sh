#!/usr/bin/env bash
set -euo pipefail

# Resolve repo root from this script location
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

NAMESPACE=${NAMESPACE:-llm-d}
HOST=${HOST:-llm-d.demo.local}
GATEWAY_URL=${GATEWAY_URL:-http://llm-d-gateway-istio.$NAMESPACE.svc.cluster.local}

echo "=== KV-Cache-Aware Routing Demo Install (assets/) ==="

# Ensure namespace exists
if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "Creating namespace $NAMESPACE..."
  kubectl create namespace "$NAMESPACE"
fi

echo "Applying core manifests from $REPO_ROOT/assets ..."
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/llm-d/decode-service.yaml"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/llm-d/modelservice.yaml"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/llm-d/gateway.yaml"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/llm-d/httproute.yaml"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/envoyfilter-epp.yaml"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/inference-crs.yaml"
kubectl apply -n "$NAMESPACE" -f "$REPO_ROOT/assets/cache-aware/tekton/cache-hit-pipeline.yaml"

echo "Waiting for decode pods to be ready..."
kubectl wait --for=condition=ready pod -l 'llm-d.ai/role=decode' -n "$NAMESPACE" --timeout=600s

echo "Validating /v1/models via gateway..."
HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" -H "Host: $HOST" "$GATEWAY_URL/v1/models" || true)
echo "/v1/models -> $HTTP_CODE"

if ! command -v tkn >/dev/null 2>&1; then
  echo "tkn not found; install Tekton CLI to run the validator."
  exit 0
fi

echo "Starting Tekton validator task..."
tkn task start cache-hit-test -n "$NAMESPACE" --param host="$HOST" --showlog

