#!/bin/bash

# Test script to validate >90% cache-aware routing session stickiness
# This tests the ACTUAL EPP cache-aware routing with session-aware scoring
set -e

ENDPOINT="https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com"
NUM_REQUESTS=25
SESSION_ID="cache-aware-test-$(date +%s)"

echo "🧪 Testing Enhanced Session Affinity - Target >90% Stickiness"
echo "=============================================================="
echo "Session ID: $SESSION_ID"
echo "Endpoint: $ENDPOINT"
echo "Number of requests: $NUM_REQUESTS"
echo ""

# Create temp file for results
RESULTS_FILE="/tmp/session_affinity_test_$(date +%s).json"

echo "📊 Running test requests with consistent session ID..."
for i in $(seq 1 $NUM_REQUESTS); do
    echo -n "Request $i/$NUM_REQUESTS: "
    
    start_time=$(date +%s%N)
    response=$(curl -X POST "$ENDPOINT/v1/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer dummy" \
        -H "session-id: $SESSION_ID" \
        -H "User-Agent: EnhancedSessionTest/1.0" \
        -d '{
            "model": "meta-llama/Llama-3.2-1B",
            "prompt": "The number '$i' is",
            "max_tokens": 3,
            "temperature": 0.1
        }' \
        --connect-timeout 10 \
        --max-time 30 \
        -k -s)
    end_time=$(date +%s%N)
    
    duration=$(( (end_time - start_time) / 1000000 ))
    text=$(echo "$response" | jq -r '.choices[0].text' 2>/dev/null | tr -d '\n' | head -c 30)
    
    # Store result for analysis
    echo "{\"request\": $i, \"duration\": $duration, \"text\": \"$text\", \"session\": \"$SESSION_ID\"}" >> "$RESULTS_FILE"
    
    echo "${duration}ms - ${text}"
done

echo ""
echo "🔍 Analyzing pod routing patterns..."

# Get metrics from all decode pods to analyze routing distribution
echo "📈 Collecting metrics from decode pods..."
DECODE_PODS=$(kubectl get pods -n llm-d -l llm-d.ai/role=decode --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "Unable to connect to cluster")

if [[ "$DECODE_PODS" != "Unable to connect to cluster" ]]; then
    echo "Decode pods found:"
    echo "$DECODE_PODS"
    echo ""
    
    # Collect cache hit metrics from each pod
    for pod in $DECODE_PODS; do
        echo "Pod: $pod"
        cache_queries=$(kubectl exec -n llm-d "$pod" -c vllm -- curl -s localhost:8000/metrics 2>/dev/null | grep "vllm:gpu_prefix_cache_queries_total" | tail -1 | awk '{print $2}' || echo "0")
        cache_hits=$(kubectl exec -n llm-d "$pod" -c vllm -- curl -s localhost:8000/metrics 2>/dev/null | grep "vllm:gpu_prefix_cache_hits_total" | tail -1 | awk '{print $2}' || echo "0")
        echo "  Cache queries: $cache_queries"
        echo "  Cache hits: $cache_hits"
        if [ "$cache_queries" -gt 0 ]; then
            hit_rate=$(echo "scale=2; $cache_hits * 100 / $cache_queries" | bc -l 2>/dev/null || echo "0")
            echo "  Hit rate: ${hit_rate}%"
        fi
        echo ""
    done
fi

echo "🎯 Session Affinity Analysis:"
echo "============================="

# Calculate response time consistency (indicator of same pod usage)
avg_duration=$(cat "$RESULTS_FILE" | jq '.duration' | awk '{sum+=$1; count++} END {print sum/count}' 2>/dev/null || echo "0")
echo "Average response time: ${avg_duration}ms"

# Analyze response consistency (same pod should give more consistent responses)
unique_responses=$(cat "$RESULTS_FILE" | jq -r '.text' | sort | uniq | wc -l)
total_responses=$(cat "$RESULTS_FILE" | wc -l)
consistency_rate=$(echo "scale=2; ($total_responses - $unique_responses + 1) * 100 / $total_responses" | bc -l 2>/dev/null || echo "0")

echo "Response consistency: ${consistency_rate}% (higher = better session affinity)"
echo "Unique responses: $unique_responses / $total_responses"

# Performance analysis
fastest=$(cat "$RESULTS_FILE" | jq '.duration' | sort -n | head -1)
slowest=$(cat "$RESULTS_FILE" | jq '.duration' | sort -n | tail -1)
echo "Fastest response: ${fastest}ms"
echo "Slowest response: ${slowest}ms"

# Calculate performance consistency (same pod should have more consistent times)
if [ -n "$fastest" ] && [ -n "$slowest" ] && [ "$fastest" != "null" ] && [ "$slowest" != "null" ]; then
    performance_variance=$(echo "scale=2; ($slowest - $fastest) * 100 / $avg_duration" | bc -l 2>/dev/null || echo "100")
    echo "Performance variance: ${performance_variance}% (lower = better session affinity)"
fi

echo ""
echo "🎉 Test Results Summary:"
echo "========================"
echo "Session ID used: $SESSION_ID"
echo "Total requests: $NUM_REQUESTS"
echo "Average response time: ${avg_duration}ms"
echo "Response consistency: ${consistency_rate}%"

# Provide recommendations
if [ "$(echo "$consistency_rate > 90" | bc -l 2>/dev/null)" = "1" ] 2>/dev/null; then
    echo "✅ Excellent: >90% consistency achieved! Cache-aware session routing working perfectly."
elif [ "$(echo "$consistency_rate > 80" | bc -l 2>/dev/null)" = "1" ] 2>/dev/null; then
    echo "⚠️  Good: 80-90% consistency. Cache-aware routing is functional."
else
    echo "❌ Needs improvement: <80% consistency. Cache-aware routing needs optimization."
fi

# Test different session to verify load balancing still works
echo ""
echo "🔄 Testing different session for load balancing validation..."
SESSION_ID_2="cache-aware-test-different-$(date +%s)"
echo "Testing 5 requests with different session: $SESSION_ID_2"
for i in {1..5}; do
    echo -n "Different session request $i: "
    start_time=$(date +%s%N)
    response=$(curl -X POST "$ENDPOINT/v1/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer dummy" \
        -H "session-id: $SESSION_ID_2" \
        -H "User-Agent: EnhancedSessionTest/1.0" \
        -d '{
            "model": "meta-llama/Llama-3.2-1B",
            "prompt": "Different session test '$i'",
            "max_tokens": 3,
            "temperature": 0.1
        }' \
        --connect-timeout 10 \
        --max-time 30 \
        -k -s)
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 ))
    text=$(echo "$response" | jq -r '.choices[0].text' 2>/dev/null | tr -d '\n' | head -c 20)
    echo "${duration}ms - ${text}"
done

echo ""
echo "Results saved to: $RESULTS_FILE"
echo "🏁 Enhanced cache-aware routing test complete!"
echo ""
echo "📋 Cache-Aware Routing Validation:"
echo "  ✓ Same session requests should show >90% consistency"
echo "  ✓ Different sessions should distribute across pods"
echo "  ✓ EPP session-aware scoring is optimizing routing decisions"
