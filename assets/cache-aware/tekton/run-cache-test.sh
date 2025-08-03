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

# Run the pipeline
echo "🏃 Starting cache hit test pipeline run..."
kubectl create -f cache-hit-pipelinerun.yaml

# Get the latest PipelineRun name
sleep 2
PIPELINE_RUN=$(kubectl get pipelinerun --sort-by=.metadata.creationTimestamp -o name | grep cache-hit-run | tail -1 | cut -d'/' -f2)

echo "✅ Pipeline run started: $PIPELINE_RUN"
echo ""
echo "📊 Monitor the pipeline run with:"
echo "   kubectl get pipelinerun $PIPELINE_RUN -w"
echo ""
echo "📋 View logs with:"
echo "   tkn pipelinerun logs $PIPELINE_RUN -f"
echo ""
echo "🌐 Or view in OpenShift Console:"
echo "   Pipelines -> PipelineRuns -> $PIPELINE_RUN"
