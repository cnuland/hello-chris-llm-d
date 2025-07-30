#!/bin/bash

# Test script for GuideLLM deployment
set -e

NAMESPACE=${NAMESPACE:-llm-d}

echo "🔍 Testing GuideLLM deployment in namespace: $NAMESPACE"

# Check if Tekton resources exist
echo "📋 Checking Tekton Pipeline resources..."
kubectl get pipeline guidellm-benchmark-pipeline -n $NAMESPACE >/dev/null 2>&1 && echo "✅ Pipeline found" || echo "❌ Pipeline not found"
kubectl get task guidellm-benchmark -n $NAMESPACE >/dev/null 2>&1 && echo "✅ Task found" || echo "❌ Task not found"

# Check PVC
echo "💾 Checking Persistent Volume Claim..."
kubectl get pvc guidellm-output-pvc -n $NAMESPACE >/dev/null 2>&1 && echo "✅ PVC found" || echo "❌ PVC not found"

# Check ConfigMaps
echo "⚙️  Checking ConfigMaps..."
kubectl get configmap guidellm-env -n $NAMESPACE >/dev/null 2>&1 && echo "✅ Environment ConfigMap found" || echo "❌ Environment ConfigMap not found"

# Check ServiceAccount
echo "👤 Checking ServiceAccount..."
kubectl get serviceaccount pipeline -n $NAMESPACE >/dev/null 2>&1 && echo "✅ ServiceAccount found" || echo "❌ ServiceAccount not found"

# Test pipeline run (dry run)
echo "🧪 Testing pipeline run creation (dry run)..."
kubectl create --dry-run=client -f pipeline/pipelinerun-template.yaml >/dev/null 2>&1 && echo "✅ PipelineRun template valid" || echo "❌ PipelineRun template invalid"

# Test job creation (dry run)
echo "🚀 Testing job creation (dry run)..."
kubectl create --dry-run=client -f utils/guidellm-job.yaml >/dev/null 2>&1 && echo "✅ Job template valid" || echo "❌ Job template invalid"

echo "🎉 GuideLLM deployment test completed!"
echo ""
echo "To run a benchmark:"
echo "  kubectl create -f guidellm/pipeline/pipelinerun-template.yaml"
echo "  # or"
echo "  kubectl apply -f guidellm/utils/guidellm-job.yaml"
