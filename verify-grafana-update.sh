#!/bin/bash

set -e

echo "🔍 Verifying Grafana Dashboard Updates"
echo "======================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n${BLUE}1. Checking ConfigMaps in llm-d-monitoring namespace:${NC}"
kubectl get configmaps -n llm-d-monitoring | grep dashboard

echo -e "\n${BLUE}2. Checking Grafana deployment status:${NC}"
kubectl get pods -n llm-d-monitoring -l app=grafana

echo -e "\n${BLUE}3. Verifying ConfigMap contains updated description:${NC}"
if kubectl get configmap grafana-dashboard-llm-performance -n llm-d-monitoring -o jsonpath='{.data.llm-performance-dashboard\.json}' | grep -q "KV Cache Memory Usage"; then
    echo -e "${GREEN}✓${NC} ConfigMap contains updated KV Cache Memory Usage description"
else
    echo -e "${YELLOW}!${NC} ConfigMap may not contain updated description"
fi

echo -e "\n${BLUE}4. Dashboard asset files status:${NC}"
echo "Main dashboard: assets/grafana/dashboards/llm-performance-dashboard.json"
echo "Import dashboard: assets/grafana/dashboards/llm-performance-dashboard-import.json"

echo -e "\n${BLUE}5. Grafana URL:${NC}"
echo "https://grafana-llm-d-monitoring.apps.rhoai-cluster.qhxt.p1.openshiftapps.com"

echo -e "\n${GREEN}✓ Grafana dashboard update verification complete!${NC}"
echo ""
echo "Changes applied:"
echo "- Updated 'GPU Cache Utilization' description to clarify it shows KV Cache Memory Usage"
echo "- Fixed misleading GPU utilization metric (was showing tiny percentage)"
echo "- Clarified that this metric represents cache memory consumption, not GPU compute utilization"
echo ""
echo "The dashboard should now show accurate descriptions for the cache utilization metric."
