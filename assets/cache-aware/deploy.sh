#!/bin/bash

echo "=== Production KV-Cache Optimized Deployment ==="
echo "Deploys 90% cache hit rate configuration with vLLM v0.10.0"
echo ""

NAMESPACE="llm-d"

# Check if namespace exists
if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace $NAMESPACE
fi

echo "=== Step 1: Deploy Cache-Aware ConfigMap ==="
kubectl apply -f hybrid-cache-configmap.yaml
echo "✅ ConfigMap deployed"

echo ""
echo "=== Step 2: Deploy Cache-Aware Service ==="
kubectl apply -f cache-aware-service.yaml
echo "✅ Cache-aware service deployed"

echo ""
echo "=== Step 3: Deploy ModelService ==="
kubectl apply -f model-service.yaml
echo "✅ ModelService deployed"

echo ""
echo "=== Step 4: Deploy Gateway ==="
kubectl apply -f gateway.yaml
echo "✅ Gateway deployed"

echo ""
echo "=== Step 5: Deploy HTTPRoute ==="
kubectl apply -f http-route.yaml
echo "✅ HTTPRoute deployed"

echo ""
echo "=== Step 6: Deploy Monitoring ==="
kubectl apply -f monitoring.yaml
echo "✅ Monitoring deployed"

echo ""
echo "=== Waiting for pods to be ready ==="
echo "Waiting for decode pods..."
kubectl wait --for=condition=ready pod -l llm-d.ai/role=decode -n $NAMESPACE --timeout=300s

echo "Waiting for EPP pod..."
kubectl wait --for=condition=ready pod -l llm-d.ai/epp -n $NAMESPACE --timeout=300s

echo "Waiting for prefill pods..."
kubectl wait --for=condition=ready pod -l llm-d.ai/role=prefill -n $NAMESPACE --timeout=300s

echo ""
echo "=== Deployment Status ==="
kubectl get pods -n $NAMESPACE
echo ""
echo "=== Services ==="
kubectl get services -n $NAMESPACE
echo ""
echo "=== Routes ==="
kubectl get httproute -n $NAMESPACE

echo ""
echo "🎉 Cache-Aware Routing Deployment Complete!"
echo ""
echo "Test the deployment:"
echo "1. Run cache validation: ./cache-test.sh"
echo "2. Check metrics in Grafana dashboard"
echo ""
echo "API Endpoint:"
echo "https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions"
