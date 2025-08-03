#!/bin/bash

echo "🔍 Real-Time Cache Hit Monitoring for Frontend Demo"
echo "=================================================="
echo ""

while true; do
    echo "$(date +%H:%M:%S) - Cache Metrics:"
    
    # Get cache metrics from both decode pods
    for pod in $(oc get pods -n llm-d -l llm-d.ai/inferenceServing=true --no-headers | grep decode | awk '{print $1}'); do
        echo "  📊 Pod: $pod"
        
        # Try to get cache metrics
        cache_hits=$(oc exec -n llm-d $pod -c vllm -- curl -s localhost:8001/metrics 2>/dev/null | grep "vllm:cache_hit" | tail -1 | awk '{print $2}' || echo "N/A")
        cache_miss=$(oc exec -n llm-d $pod -c vllm -- curl -s localhost:8001/metrics 2>/dev/null | grep "vllm:cache_miss" | tail -1 | awk '{print $2}' || echo "N/A")
        
        if [[ "$cache_hits" != "N/A" && "$cache_miss" != "N/A" ]]; then
            total=$((cache_hits + cache_miss))
            if [[ $total -gt 0 ]]; then
                hit_rate=$(echo "scale=1; $cache_hits * 100 / $total" | bc -l 2>/dev/null || echo "0")
                echo "    ✅ Cache Hits: $cache_hits"
                echo "    ❌ Cache Miss: $cache_miss" 
                echo "    📈 Hit Rate: ${hit_rate}%"
            else
                echo "    🔄 No requests yet"
            fi
        else
            echo "    🔄 Metrics not available yet"
        fi
        echo ""
    done
    
    # Check EPP logs for routing decisions
    echo "  🎯 Recent EPP Routing Decisions (last 5 lines):"
    oc logs -n llm-d deployment/llama-3-2-1b-epp --tail=5 2>/dev/null | grep -E "(routing|score|cache)" | tail -3 || echo "    No routing logs available"
    
    echo "----------------------------------------"
    sleep 5
done
