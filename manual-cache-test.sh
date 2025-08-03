#!/bin/bash

# Manual KV-Cache Routing Experiment
# This tests cache-aware routing followed by random prompts to verify normal load balancing

GATEWAY_URL="https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com"
SESSION_ID="experiment-$(date +%s)"

echo "=== KV-Cache Routing Experiment ==="
echo "Testing cache-aware routing followed by random prompts"
echo "Session ID: $SESSION_ID"
echo

# Function to get pod metrics
get_pod_metrics() {
    local pod=$1
    echo "Pod: $pod"
    oc exec $pod -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep "vllm:prefix_cache_queries_total\|vllm:prefix_cache_hits_total" | grep -o '[0-9.]*$' | paste - - | awk '{printf "  Queries: %.0f, Hits: %.0f, Hit Rate: %.1f%%\n", $1, $2, ($2/$1)*100}'
}

# Get initial metrics for all pods
echo "=== INITIAL METRICS ==="
for pod in $(oc get pods -n llm-d -l llm-d.ai/role=decode --no-headers | awk '{print $1}'); do
    get_pod_metrics $pod
done
echo

# Phase 1: Cache-aware routing test with repeated prompts
echo "=== PHASE 1: CACHE-AWARE ROUTING TEST ==="
echo "Sending 10 identical requests with session affinity..."
CACHE_PROMPT="In the quantum realm of parallel dimensions, where consciousness transcends the boundaries of space and time, what profound philosophical implications emerge when we consider the interconnectedness of all existence across multiple realities?"

for i in {1..10}; do
    echo "  Request $i (cache-optimized)..."
    curl -s -X POST "$GATEWAY_URL/v1/completions" \
        -H "Content-Type: application/json" \
        -H "X-Session-ID: $SESSION_ID" \
        -d "{
            \"model\": \"meta-llama/Llama-3.2-1B\",
            \"prompt\": \"$CACHE_PROMPT Answer:\",
            \"max_tokens\": 50,
            \"temperature\": 0
        }" | jq -r '.choices[0].text' | head -c 50
    echo "..."
    sleep 1
done
echo

# Check metrics after cache test
echo "=== METRICS AFTER CACHE TEST ==="
for pod in $(oc get pods -n llm-d -l llm-d.ai/role=decode --no-headers | awk '{print $1}'); do
    get_pod_metrics $pod
done
echo

# Phase 2: Random prompts test
echo "=== PHASE 2: RANDOM PROMPTS TEST ==="
echo "Sending 5 different requests without session headers..."

RANDOM_PROMPTS=(
    "What is the capital of France?"
    "Explain quantum mechanics in simple terms."
    "Write a haiku about technology."
    "What are the benefits of renewable energy?"
    "Describe the process of photosynthesis."
)

for i in {0..4}; do
    echo "  Random request $((i+1))..."
    curl -s -X POST "$GATEWAY_URL/v1/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"meta-llama/Llama-3.2-1B\",
            \"prompt\": \"${RANDOM_PROMPTS[$i]} Answer:\",
            \"max_tokens\": 30,
            \"temperature\": 0.7
        }" | jq -r '.choices[0].text' | head -c 50
    echo "..."
    sleep 1
done
echo

# Final metrics check
echo "=== FINAL METRICS ==="
for pod in $(oc get pods -n llm-d -l llm-d.ai/role=decode --no-headers | awk '{print $1}'); do
    get_pod_metrics $pod
done

echo
echo "=== EXPERIMENT COMPLETE ==="
echo "Expected behavior:"
echo "1. Cache test should show high hit rate on one pod (session affinity)"
echo "2. Random prompts should distribute across multiple pods (normal load balancing)"
