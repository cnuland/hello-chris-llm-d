#!/bin/bash

# Cache hit test script for LLM-D
ROUTE_URL="https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions"

echo "=== Cache Hit Rate Test ==="
echo "Sending 10 identical requests to test cache-aware routing..."
echo "Route: $ROUTE_URL"
echo ""

# First, get baseline metrics
echo "Getting baseline cache metrics..."
PODS=($(kubectl get pods -n llm-d -l 'llm-d.ai/role=decode' --no-headers | grep Running | awk '{print $1}'))
for i in "${!PODS[@]}"; do
  echo "Pod ${PODS[$i]} metrics:"
  kubectl exec ${PODS[$i]} -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep "gpu_prefix_cache" | head -5
  echo ""
done

echo "Starting identical request test..."

# Send 10 identical requests
IDENTICAL_PROMPT="What is the capital of France? Please explain why Paris is important."

for i in {1..10}; do
  echo "Request $i..."
  RESPONSE=$(curl -s -k -X POST "$ROUTE_URL" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"meta-llama/Llama-3.2-1B\",
      \"prompt\": \"$IDENTICAL_PROMPT\",
      \"max_tokens\": 50,
      \"temperature\": 0.1
    }")
  echo "Response: $(echo $RESPONSE | jq -r '.choices[0].text // .error // "No response"' | head -1)"
  sleep 1
done

echo ""
echo "Test complete. Checking cache metrics after test..."

# Check final metrics
for i in "${!PODS[@]}"; do
  echo "Pod ${PODS[$i]} final metrics:"
  kubectl exec ${PODS[$i]} -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep "gpu_prefix_cache" | head -5
  echo ""
done

echo "=== Cache Hit Rate Analysis ==="
echo "Check the difference between initial and final cache hit numbers."
echo "A working cache-aware routing should show most hits concentrated on one pod."
