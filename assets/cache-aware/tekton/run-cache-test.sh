#!/bin/bash

echo "=== Tekton Cache Hit Test Pipeline ==="
echo "This pipeline will restart LLM-D pods and test cache hit rates"
echo ""

# Check if Tekton is available
if ! kubectl get pipelines.tekton.dev >/dev/null 2>&1; then
    echo "❌ Tekton Pipelines not found. Please install OpenShift Pipelines operator first."
    exit 1
fi

# Deploy the Task and Pipeline if they don't exist
echo "🚀 Deploying Tekton Task and Pipeline..."

# Apply the Task and Pipeline
kubectl apply -f cache-hit-pipeline.yaml

echo "✅ Task and Pipeline deployed"
echo ""

# Start the Task directly for simplicity
echo "🏃 Starting cache-hit-test Task..."
tkn task start cache-hit-test -n llm-d --param host=llm-d.demo.local --showlog

echo ""
echo "📊 Monitor with:"
echo "   tkn taskrun list -n llm-d"
echo ""
echo "📋 View logs with:"
echo "   tkn pipelinerun logs $PIPELINE_RUN -f"
echo ""
echo "🌐 Or view in OpenShift Console:"
echo "   Pipelines -> PipelineRuns -> $PIPELINE_RUN"
