#!/usr/bin/env bash
set -euo pipefail

NAMESPACE=${NAMESPACE:-llm-d}
GATEWAY_URL=${GATEWAY_URL:-"http://llm-d-gateway-istio.$NAMESPACE.svc.cluster.local"}
HOST=${HOST:-"llm-d.demo.local"}
MODEL="meta-llama/Llama-3.2-3B-Instruct"

echo "=== KV-Cache Validation Script (canonical) ==="

DECODE_PODS=($(kubectl get pods -n "$NAMESPACE" -l 'llm-d.ai/role=decode' --field-selector=status.phase=Running -o jsonpath='{.items[*].metadata.name}'))
if [ ${#DECODE_PODS[@]} -eq 0 ]; then echo "❌ No decode pods"; exit 1; fi
TEST_POD=${DECODE_PODS[0]}

BASELINE_QUERIES=$(kubectl exec "$TEST_POD" -n "$NAMESPACE" -c vllm -- sh -c "curl -s localhost:8200/metrics || curl -s localhost:8001/metrics" | grep "prefix_cache_queries_total{" | grep -o '[0-9.]*$' | head -1)
BASELINE_HITS=$(kubectl exec "$TEST_POD" -n "$NAMESPACE" -c vllm -- sh -c "curl -s localhost:8200/metrics || curl -s localhost:8001/metrics" | grep "prefix_cache_hits_total{" | grep -o '[0-9.]*$' | head -1)

CACHE_PROMPT="You are an expert AI assistant. Provide detailed information about the cultural significance of the Eiffel Tower in Paris, France."
for i in {1..10}; do
  curl -sk -X POST "$GATEWAY_URL/v1/completions" \
    -H "Host: ${HOST}" -H "Content-Type: application/json" \
    -d "{\"model\": \"$MODEL\", \"prompt\": \"$CACHE_PROMPT\", \"max_tokens\": 20, \"temperature\": 0.0}" >/dev/null || true
  sleep 0.2
done

FINAL_QUERIES=$(kubectl exec "$TEST_POD" -n "$NAMESPACE" -c vllm -- sh -c "curl -s localhost:8200/metrics || curl -s localhost:8001/metrics" | grep "prefix_cache_queries_total{" | grep -o '[0-9.]*$' | head -1)
FINAL_HITS=$(kubectl exec "$TEST_POD" -n "$NAMESPACE" -c vllm -- sh -c "curl -s localhost:8200/metrics || curl -s localhost:8001/metrics" | grep "prefix_cache_hits_total{" | grep -o '[0-9.]*$' | head -1)

NEW_Q=$(echo "(${FINAL_QUERIES:-0} - ${BASELINE_QUERIES:-0})" | bc -l)
NEW_H=$(echo "(${FINAL_HITS:-0} - ${BASELINE_HITS:-0})" | bc -l)

if (( $(echo "$NEW_Q > 0" | bc -l) )); then
  HIT_RATE=$(echo "scale=1; ($NEW_H*100)/$NEW_Q" | bc -l)
  echo "New queries: $NEW_Q | New hits: $NEW_H | Hit rate: ${HIT_RATE}%"
else
  echo "No new queries detected."
fi

echo "Gateway routing test..."
RESP=$(curl -sk -H "Host: ${HOST}" -H "Content-Type: application/json" -X POST "$GATEWAY_URL/v1/completions" -d '{
  "model": "meta-llama/Llama-3.2-3B-Instruct",
  "prompt": "What makes Paris a unique city?",
  "max_tokens": 8,
  "temperature": 0.0
}')
echo "Response: $(echo "$RESP" | jq -r '.choices[0].text // .choices[0].message.content // .error // "No response"' | head -1)"

echo "Done."

