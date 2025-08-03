#!/bin/bash

echo "=== KV-Cache Hit Rate Improvement Test ==="
echo "Testing identical requests to force cache hits"
echo ""

# Get all decode pods
PODS=($(kubectl get pods -n llm-d -l 'llm-d.ai/role=decode' --no-headers | grep Running | awk '{print $1}'))

echo "Found ${#PODS[@]} decode pods:"
for pod in "${PODS[@]}"; do
    echo "  - $pod"
done
echo ""

# Function to get cache metrics for a pod
get_cache_metrics() {
    local pod=$1
    echo "=== $pod ==="
    kubectl exec $pod -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep -E "(gpu_prefix_cache_queries_total|gpu_prefix_cache_hits_total)" | grep -v "#"
    echo ""
}

# Get baseline metrics
echo "=== BASELINE CACHE METRICS ==="
for pod in "${PODS[@]}"; do
    get_cache_metrics $pod
done

# Send 15 identical requests with temperature=0.0
echo "=== SENDING 15 IDENTICAL REQUESTS ==="
IDENTICAL_PROMPT="What is the capital of France?"
ROUTE_URL="https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions"

for i in {1..15}; do
    echo "Request $i..."
    RESPONSE=$(curl -s -k -X POST "$ROUTE_URL" \
        -H "Content-Type: application/json" \
        -d "{
          \"model\": \"meta-llama/Llama-3.2-1B\",
          \"prompt\": \"$IDENTICAL_PROMPT\",
          \"max_tokens\": 10,
          \"temperature\": 0.0
        }")
    echo "  Response: $(echo $RESPONSE | jq -r '.choices[0].text // .error // "No response"' | head -1 | tr -d '\n')"
    sleep 0.5
done

echo ""
echo "=== FINAL CACHE METRICS AFTER IDENTICAL REQUESTS ==="
for pod in "${PODS[@]}"; do
    get_cache_metrics $pod
done

echo ""
echo "=== CACHE HIT RATE ANALYSIS ==="
echo "Look for:"
echo "1. Which pods received the requests (queries_total increased)"
echo "2. Whether cache hits increased (hits_total > 0)" 
echo "3. Cache hit rate = hits_total / queries_total"
echo ""
echo "Expected: With temperature=0.0 and identical prompts, we should see cache hits!"
