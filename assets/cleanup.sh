#!/usr/bin/env bash
set -euo pipefail

# Cleanup llm-d demo resources
# Usage: ./cleanup.sh [namespace]
# Default namespace: llm-d

NS=${1:-llm-d}

# Delete the kustomized resources
kubectl delete -k assets/llm-d --ignore-not-found=true || true

# Optionally clean up LB service if lingering
kubectl -n "$NS" delete svc llm-d-gateway-istio --ignore-not-found=true || true

# Delete EPP resources explicitly in case they were created separately
kubectl -n "$NS" delete deploy ms-llm-d-modelservice-epp --ignore-not-found=true || true
kubectl -n "$NS" delete svc ms-llm-d-modelservice-epp --ignore-not-found=true || true

# Delete decode service/deployment if still present
kubectl -n "$NS" delete deploy ms-llm-d-modelservice-decode --ignore-not-found=true || true
kubectl -n "$NS" delete svc ms-llm-d-modelservice-decode --ignore-not-found=true || true

# Delete gateway and routes if left behind
kubectl -n "$NS" delete gateway llm-d-gateway --ignore-not-found=true || true
kubectl -n "$NS" delete httproute ms-llm-d-epp-route --ignore-not-found=true || true

# Delete EnvoyFilter
kubectl -n "$NS" delete envoyfilter epp-ext-proc --ignore-not-found=true || true

# Keep the namespace and HF secret by default. Uncomment to remove everything:
# kubectl delete namespace "$NS" --ignore-not-found=true || true

