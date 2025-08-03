#!/bin/bash
# LLM-D Cache Diagnosis Script
#
# This script helps diagnose why prefix cache hits are 0

set -e

echo "🔍 LLM-D Cache Issue Diagnosis"
echo "=============================="
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get decode pods
DECODE_PODS=$(kubectl get pods -n llm-d --no-headers | grep decode | grep Running | awk '{print $1}')

if [ -z "$DECODE_PODS" ]; then
    echo -e "${RED}❌ No running decode pods found${NC}"
    exit 1
fi

echo "📊 Current Cache Metrics:"
echo "========================"

for pod in $DECODE_PODS; do
    echo
    echo -e "${YELLOW}Pod: $pod${NC}"
    
    # Get cache metrics
    kubectl exec $pod -n llm-d -c vllm -- curl -s localhost:8001/metrics | \
        grep -E "(gpu_prefix_cache_|cache_config_info)" | \
        grep -E "(queries_total|hits_total|enable_prefix_caching)" || echo "  No cache metrics found"
done

echo
echo "🔧 Configuration Analysis:"
echo "=========================="

# Check deployment configuration
FIRST_POD=$(echo $DECODE_PODS | head -1 | awk '{print $1}')
echo
echo -e "${YELLOW}vLLM Arguments:${NC}"
kubectl get deployment llama-3-2-1b-decode -n llm-d -o yaml | \
    grep -A 20 "args:" | head -15

echo
echo -e "${YELLOW}Environment Variables:${NC}"
kubectl get deployment llama-3-2-1b-decode -n llm-d -o yaml | \
    grep -A 10 "env:" | head -10

echo
echo "🧪 Test Recommendations:"
echo "========================"
echo "1. 🔧 Remove KV Transfer Config (likely cause):"
echo "   kubectl patch deployment llama-3-2-1b-decode -n llm-d --patch-file=assets/fixes/decode-deployment-fix.yaml"
echo
echo "2. 🐛 Enable Debug Logging:"
echo "   kubectl patch deployment llama-3-2-1b-decode -n llm-d --patch-file=assets/fixes/enable-debug-logging.yaml"
echo
echo "3. 🧪 Test Single Pod Direct:"
echo "   kubectl port-forward $FIRST_POD -n llm-d 18001:8001 &"
echo "   # Then send identical requests to http://localhost:18001/v1/completions"
echo
echo "4. 📊 Monitor Cache Metrics:"
echo "   watch 'kubectl exec $FIRST_POD -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep gpu_prefix_cache'"

echo
echo "💡 Key Insight:"
echo "=============="
echo -e "${YELLOW}The KV transfer config (NixlConnector) is likely interfering with local prefix caching.${NC}"
echo -e "${YELLOW}Consider using EITHER distributed KV transfer OR local prefix caching, not both.${NC}"
