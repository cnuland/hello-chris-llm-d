#!/bin/bash

# Get the frontend pod name
FRONTEND_POD=$(kubectl get pods -n llm-d -l app=llm-d-frontend -o jsonpath='{.items[0].metadata.name}')

echo "Updating frontend pod: $FRONTEND_POD"

# Create a temporary index.html with the correct backend URL
cat > /tmp/index.html << 'EOF'
<!doctype html><html lang="en"><head><meta charset="utf-8"/><link rel="icon" href="/favicon.ico"/><meta name="viewport" content="width=device-width,initial-scale=1"/><meta name="theme-color" content="#2563eb"/><meta name="description" content="LLM-D Distributed Inference Demo - Kubernetes-native high-performance LLM inference"/><link rel="apple-touch-icon" href="/logo192.png"/><link rel="manifest" href="/manifest.json"/><title>LLM-D Distributed Inference Demo</title><script>window.BACKEND_URL='https://llm-d-backend-route-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com'</script><script defer="defer" src="/static/js/main.72b4f7f8.js"></script><link href="/static/css/main.ed859c29.css" rel="stylesheet"></head><body><noscript>You need to enable JavaScript to run this app.</noscript><div id="root"></div></body></html>
EOF

# Copy the updated index.html to the frontend pod
kubectl cp /tmp/index.html llm-d/$FRONTEND_POD:/usr/share/nginx/html/index.html

echo "Frontend updated successfully!"

# Clean up
rm /tmp/index.html
