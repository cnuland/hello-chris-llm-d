#!/usr/bin/env bash
set -euo pipefail

# Smoke test for LLM-D gateway via Host header
# Usage: ./smoke-test.sh [namespace] [host]
# Defaults: namespace=llm-d, host=llm-d.demo.local

NS=${1:-llm-d}
HOST=${2:-llm-d.demo.local}

LB=$(kubectl -n "$NS" get svc llm-d-gateway-istio -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [ -z "$LB" ]; then
  echo "No external LB found; trying in-cluster service"
  INCLUSTER_URL="http://llm-d-gateway-istio.${NS}.svc.cluster.local"
  echo "GET /v1/models"
  kubectl -n "$NS" run tmp-curl --rm -i --restart=Never --image=curlimages/curl:8.7.1 -- \
    sh -lc "curl -sS -m 15 -H 'Host: ${HOST}' ${INCLUSTER_URL}/v1/models | jq . | head -c 2000" || true
  echo
  echo "POST /v1/chat/completions"
  kubectl -n "$NS" run tmp-curl --rm -i --restart=Never --image=curlimages/curl:8.7.1 -- \
    sh -lc "curl -sS -m 25 -H 'Host: ${HOST}' -H 'Content-Type: application/json' \
      -d '{\"model\":\"meta-llama/Llama-3.2-3B-Instruct\",\"messages\":[{\"role\":\"user\",\"content\":\"Say hello from LLM-D\"}],\"max_tokens\":16}' \
      ${INCLUSTER_URL}/v1/chat/completions | jq . | head -c 2000" || true
  exit 0
fi

URL="http://${LB}"
echo "Using LB: ${URL} Host: ${HOST}"

echo "GET /v1/models"
curl -sS -m 15 -H "Host: ${HOST}" "$URL/v1/models" | jq . | head -c 2000 || true

echo

echo "POST /v1/chat/completions"
curl -sS -m 25 -H "Host: ${HOST}" -H "Content-Type: application/json" \
  -d '{"model":"meta-llama/Llama-3.2-3B-Instruct","messages":[{"role":"user","content":"Say hello from LLM-D"}],"max_tokens":16}' \
  "$URL/v1/chat/completions" | jq . | head -c 2000 || true

