#!/bin/bash
# LLM-D Demo Setup Verification Script
#
# This script verifies that all components of the LLM-D demo are properly configured
# and running, with cache-aware routing enabled.

set -e

echo "🔍 LLM-D Demo Setup Verification"
echo "================================="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        return 1
    fi
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if kubectl is available and connected
echo "1. Checking kubectl access..."
kubectl cluster-info > /dev/null 2>&1
check_status "kubectl connected to cluster"

# Check namespace exists
echo "2. Checking namespace..."
kubectl get namespace llm-d > /dev/null 2>&1
check_status "llm-d namespace exists"

# Check pods are running
echo "3. Checking pod status..."
DECODE_PODS=$(kubectl get pods -n llm-d -l app=llama-3-2-1b --no-headers 2>/dev/null | grep decode | grep Running | wc -l)
PREFILL_PODS=$(kubectl get pods -n llm-d -l app=llama-3-2-1b --no-headers 2>/dev/null | grep prefill | grep Running | wc -l)
EPP_PODS=$(kubectl get pods -n llm-d --no-headers 2>/dev/null | grep epp | grep Running | wc -l)

echo "   - Decode pods running: $DECODE_PODS"
echo "   - Prefill pods running: $PREFILL_PODS" 
echo "   - EPP pods running: $EPP_PODS"

if [ "$DECODE_PODS" -ge 1 ] && [ "$PREFILL_PODS" -ge 1 ] && [ "$EPP_PODS" -ge 1 ]; then
    check_status "All required pods are running"
else
    echo -e "${RED}❌ Required pods not running (need: decode≥1, prefill≥1, epp≥1)${NC}"
fi

# Check services exist
echo "4. Checking services..."
kubectl get svc llama-3-2-1b-epp-service -n llm-d > /dev/null 2>&1
check_status "EPP service exists"

kubectl get svc llama-3-2-1b-service-decode -n llm-d > /dev/null 2>&1
check_status "Decode service exists"

kubectl get svc llama-3-2-1b-service-prefill -n llm-d > /dev/null 2>&1
check_status "Prefill service exists"

# Check routes exist
echo "5. Checking routes..."
oc get route llm-d-backend-route -n llm-d > /dev/null 2>&1
check_status "Backend route exists"

oc get route llm-d-inference-gateway -n llm-d > /dev/null 2>&1
check_status "Gateway route exists"

# Check HTTPRoute configuration
echo "6. Checking HTTPRoute configuration..."
HTTPROUTE_BACKEND=$(kubectl get httproute llama-3-2-1b-http-route -n llm-d -o jsonpath='{.spec.rules[0].backendRefs[0].name}' 2>/dev/null)
if [ "$HTTPROUTE_BACKEND" = "llama-3-2-1b-epp-service" ]; then
    check_status "HTTPRoute properly configured to EPP service"
else
    echo -e "${RED}❌ HTTPRoute backend not configured properly (found: $HTTPROUTE_BACKEND)${NC}"
fi

# Check cache-aware routing configuration
echo "7. Checking cache-aware routing configuration..."
EPP_POD=$(kubectl get pods -n llm-d --no-headers | grep epp | grep Running | head -1 | awk '{print $1}')
if [ -n "$EPP_POD" ]; then
    KVCACHE_ENABLED=$(kubectl get deployment -n llm-d -o yaml | grep -A 1 "ENABLE_KVCACHE_AWARE_SCORER" | grep "true" | wc -l)
    if [ "$KVCACHE_ENABLED" -ge 1 ]; then
        check_status "Cache-aware routing enabled in EPP"
    else
        echo -e "${RED}❌ Cache-aware routing not enabled${NC}"
    fi
else
    echo -e "${RED}❌ No EPP pod found${NC}"
fi

# Check prefix caching in decode pods
echo "8. Checking prefix caching in decode pods..."
DECODE_POD=$(kubectl get pods -n llm-d --no-headers | grep decode | grep Running | head -1 | awk '{print $1}')
if [ -n "$DECODE_POD" ]; then
    PREFIX_CACHE=$(kubectl get deployment -n llm-d -o yaml | grep -A 1 "enable-prefix-caching" | wc -l)
    if [ "$PREFIX_CACHE" -ge 1 ]; then
        check_status "Prefix caching enabled in decode pods"
    else
        warning "Prefix caching may not be enabled"
    fi
else
    echo -e "${RED}❌ No decode pod found${NC}"
fi

# Check monitoring setup
echo "9. Checking monitoring setup..."
kubectl get namespace llm-d-monitoring > /dev/null 2>&1
if [ $? -eq 0 ]; then
    check_status "Monitoring namespace exists"
    
    kubectl get pods -n llm-d-monitoring --no-headers | grep grafana | grep Running > /dev/null 2>&1
    check_status "Grafana running"
    
    kubectl get pods -n llm-d-monitoring --no-headers | grep prometheus | grep Running > /dev/null 2>&1
    check_status "Prometheus running"
else
    warning "Monitoring namespace not found - Grafana dashboard may not be available"
fi

# Test basic connectivity
echo "10. Testing basic connectivity..."
BACKEND_URL=$(oc get route llm-d-backend-route -n llm-d -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$BACKEND_URL" ]; then
    echo "    Backend URL: https://$BACKEND_URL"
    curl -k -f "https://$BACKEND_URL/api/health" > /dev/null 2>&1
    check_status "Backend health check passed"
else
    warning "Could not determine backend URL"
fi

echo
echo "📊 Demo URLs:"
echo "============="
if [ -n "$BACKEND_URL" ]; then
    echo "Backend API: https://$BACKEND_URL"
fi

FRONTEND_URL=$(oc get route llm-d-frontend-route -n llm-d -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$FRONTEND_URL" ]; then
    echo "Frontend UI: https://$FRONTEND_URL"
fi

GATEWAY_URL=$(oc get route llm-d-inference-gateway -n llm-d -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$GATEWAY_URL" ]; then
    echo "Gateway API: https://$GATEWAY_URL"
fi

GRAFANA_URL=$(oc get route -n llm-d-monitoring --no-headers 2>/dev/null | grep grafana | awk '{print $2}')
if [ -n "$GRAFANA_URL" ]; then
    echo "Grafana Dashboard: https://$GRAFANA_URL (admin/admin)"
fi

echo
echo "🧪 Testing Commands:"
echo "==================="
echo "Test cache-aware routing:"
echo "  python3 assets/testing/test-cache-aware-routing.py"
echo
echo "Check cache metrics:"
echo "  kubectl exec \$DECODE_POD -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep gpu_prefix_cache"
echo
echo "Monitor EPP logs:"
echo "  kubectl logs \$EPP_POD -n llm-d --tail=50 -f"
echo
echo "Run GuideLLM benchmark:"
echo "  kubectl apply -f assets/load-testing/guidellm-job.yaml"

echo
echo "✅ Demo verification complete!"
