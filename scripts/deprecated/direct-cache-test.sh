#!/bin/bash

echo "=== Direct Pod Cache Hit Rate Test ==="
echo "Testing cache-aware routing by sending identical requests to multiple decode pods"
echo ""

# Get decode pods
PODS=($(kubectl get pods -n llm-d -l 'llm-d.ai/role=decode' --no-headers | grep Running | awk '{print $1}'))

echo "Found ${#PODS[@]} decode pods:"
for pod in "${PODS[@]}"; do
    echo "  - $pod"
done
echo ""

# Get baseline metrics for all pods
echo "=== BASELINE CACHE METRICS ==="
for i in "${!PODS[@]}"; do
    echo "Pod ${PODS[$i]} baseline:"
    kubectl exec ${PODS[$i]} -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep -E "(gpu_prefix_cache_queries_total|gpu_prefix_cache_hits_total)" | head -4
    echo ""
done

# Test cache with repeated identical requests to the first pod
echo "=== TESTING CACHE HITS (Sending 5 identical requests to ${PODS[0]}) ==="
IDENTICAL_PROMPT="What is the capital of France?"

for i in {1..5}; do
    echo "Request $i to ${PODS[0]}..."
    kubectl port-forward -n llm-d ${PODS[0]} 8001:8001 &
    PORT_FORWARD_PID=$!
    sleep 2
    
    RESPONSE=$(curl -s -X POST "http://localhost:8001/v1/completions" \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"meta-llama/Llama-3.2-1B\",
          \"prompt\": \"$IDENTICAL_PROMPT\",
          \"max_tokens\": 20,
          \"temperature\": 0.0
        }")
    
    kill $PORT_FORWARD_PID
    wait $PORT_FORWARD_PID 2>/dev/null
    
    echo "  Response: $(echo $RESPONSE | jq -r '.choices[0].text // .error // "No response"' | head -1 | tr -d '\n')"
    sleep 1
done

echo ""
echo "=== FINAL CACHE METRICS AFTER IDENTICAL REQUESTS ==="
for i in "${!PODS[@]}"; do
    echo "Pod ${PODS[$i]} final:"
    kubectl exec ${PODS[$i]} -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep -E "(gpu_prefix_cache_queries_total|gpu_prefix_cache_hits_total)" | head -4
    echo ""
done

echo "=== CACHE HIT RATE ANALYSIS ==="
echo "If prefix caching is working correctly:"
echo "  - The first pod should show increased cache queries AND cache hits"
echo "  - Hit rate should improve after the first identical request"
echo "  - Other pods should show no change (if cache-aware routing works)"
