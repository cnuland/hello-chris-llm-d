#!/bin/bash

set -e

echo "🔍 LLM-D Metrics Debug Script"
echo "==============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if a command succeeded
check_command() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
        return 1
    fi
}

# Function to test metrics endpoint
test_metrics() {
    local pod_name=$1
    local container=$2
    local port=$3
    local description=$4
    
    echo -e "\n${BLUE}Testing:${NC} $description"
    echo "Pod: $pod_name, Container: $container, Port: $port"
    
    if kubectl exec -n llm-d "$pod_name" ${container:+-c $container} -- curl -s --max-time 5 "http://localhost:$port/metrics" | head -5 >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Metrics accessible on port $port"
        # Get a sample of actual metrics
        echo "Sample metrics:"
        kubectl exec -n llm-d "$pod_name" ${container:+-c $container} -- curl -s --max-time 5 "http://localhost:$port/metrics" | grep -E "(prefix_cache|vllm)" | head -3 || echo "  No prefix_cache metrics found"
    else
        echo -e "${RED}✗${NC} Metrics NOT accessible on port $port"
    fi
}

echo -e "\n${YELLOW}1. Checking Pod Status${NC}"
kubectl get pods -n llm-d -l llm-d.ai/inferenceServing=true
check_command "Pod listing"

echo -e "\n${YELLOW}2. Checking Services${NC}"
kubectl get services -n llm-d --show-labels | grep gather-metrics || echo "No services with gather-metrics label found"

echo -e "\n${YELLOW}3. Getting Pod Names${NC}"
PREFILL_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=prefill -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
DECODE_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=decode -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
EPP_POD=$(kubectl get pods -n llm-d -l app.kubernetes.io/gateway=llm-d-operator-inference-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

echo "Prefill Pod: ${PREFILL_POD:-NOT FOUND}"
echo "Decode Pod: ${DECODE_POD:-NOT FOUND}"
echo "EPP Pod: ${EPP_POD:-NOT FOUND}"

echo -e "\n${YELLOW}4. Testing Metrics Endpoints${NC}"

if [ -n "$PREFILL_POD" ]; then
    test_metrics "$PREFILL_POD" "vllm" "8000" "Prefill vLLM metrics"
else
    echo -e "${RED}✗${NC} No prefill pod found"
fi

if [ -n "$DECODE_POD" ]; then
    test_metrics "$DECODE_POD" "vllm" "8001" "Decode vLLM metrics (direct)"
    test_metrics "$DECODE_POD" "routing-proxy" "8000" "Decode routing proxy metrics"
else
    echo -e "${RED}✗${NC} No decode pod found"
fi

if [ -n "$EPP_POD" ]; then
    test_metrics "$EPP_POD" "" "9090" "EPP metrics"
else
    echo -e "${RED}✗${NC} No EPP pod found"
fi

echo -e "\n${YELLOW}5. Checking ServiceMonitors${NC}"
kubectl get servicemonitors -n llm-d
check_command "ServiceMonitor listing"

echo -e "\n${YELLOW}6. Checking PodMonitors${NC}"
kubectl get podmonitors -n llm-d
check_command "PodMonitor listing"

echo -e "\n${YELLOW}7. Checking Prometheus Targets (if accessible)${NC}"

# Try to access Prometheus
if kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus >/dev/null 2>&1; then
    echo "Prometheus found in monitoring namespace"
    # Try port-forward in background briefly
    kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 >/dev/null 2>&1 &
    PF_PID=$!
    sleep 3
    
    if curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job | contains("llm-d")) | "\(.labels.job): \(.health)"' 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Prometheus targets accessible"
    else
        echo -e "${YELLOW}!${NC} Could not access Prometheus targets API"
    fi
    
    kill $PF_PID 2>/dev/null || true
else
    echo -e "${YELLOW}!${NC} Prometheus not found in monitoring namespace"
fi

echo -e "\n${YELLOW}8. Service Label Check${NC}"
echo "Services with gather-metrics label:"
kubectl get svc -n llm-d -l llmd.ai/gather-metrics=true -o name 2>/dev/null || echo "None found"

echo -e "\n${YELLOW}9. Pod Label Check${NC}"
echo "Pods with inferenceServing label:"
kubectl get pods -n llm-d -l llm-d.ai/inferenceServing=true -o name 2>/dev/null || echo "None found"

echo -e "\n${BLUE}Summary:${NC}"
echo "- Apply updated monitoring configs: kubectl apply -k assets/monitoring/"
echo "- Check Prometheus targets at: http://localhost:9090/targets (after port-forward)"
echo "- Look for 'llm-d' jobs in Prometheus targets"
echo "- Verify Grafana dashboard queries match available metrics"

echo -e "\n${GREEN}Debug script completed!${NC}"
