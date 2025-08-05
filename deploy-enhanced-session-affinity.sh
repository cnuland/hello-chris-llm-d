#!/bin/bash

# Script to deploy enhanced session affinity for >90% pod routing stickiness
set -e

echo "🚀 Deploying Enhanced Session Affinity Optimizations"
echo "===================================================="

# Check if logged in
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "❌ Not logged in to cluster. Please login first:"
    echo "   oc login ..."
    exit 1
fi

echo "✅ Cluster access confirmed"

# Deploy enhanced session affinity configurations
echo "📦 Deploying Istio DestinationRule for consistent hash routing..."
kubectl apply -f assets/cache-aware/destination-rule-session-affinity.yaml

echo "📦 Deploying enhanced cache-aware service..."
kubectl apply -f assets/cache-aware/enhanced-cache-aware-service.yaml

# Update HTTPRoute to use enhanced service
echo "📦 Updating HTTPRoute to use enhanced service..."
kubectl patch httproute llama-3-2-1b-http-route -n llm-d --type='merge' -p='{
  "spec": {
    "rules": [{
      "matches": [{
        "path": {
          "type": "PathPrefix",
          "value": "/v1"
        }
      }],
      "backendRefs": [{
        "group": "",
        "kind": "Service", 
        "name": "llama-3-2-1b-cache-aware-service-enhanced",
        "port": 8000,
        "weight": 1
      }]
    }]
  }
}'

# Wait for configurations to propagate
echo "⏳ Waiting for configurations to propagate..."
sleep 10

# Verify the configurations
echo "🔍 Verifying configurations..."
kubectl get destinationrule llama-3-2-1b-session-affinity -n llm-d -o yaml | grep -A 5 "consistentHash"
kubectl get virtualservice llama-3-2-1b-session-routing -n llm-d -o yaml | grep -A 3 "headers"
kubectl get service llama-3-2-1b-cache-aware-service-enhanced -n llm-d -o yaml | grep -A 3 "sessionAffinity"

echo "✅ Enhanced session affinity deployed successfully!"
echo ""
echo "🎯 Key optimizations applied:"
echo "   • Consistent hash routing based on session-id header"
echo "   • Cookie-based fallback for session persistence"
echo "   • Optimized connection pooling and timeouts"
echo "   • Enhanced service with strict session affinity"
echo ""
echo "🧪 Test with session headers:"
echo '   curl -H "session-id: test-session-123" -H "Content-Type: application/json" \\'
echo '        -d '"'"'{"model":"meta-llama/Llama-3.2-1B","prompt":"Hello","max_tokens":10}'"'"' \\'
echo '        https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions'
echo ""
echo "🎉 Ready to test >90% session affinity!"
