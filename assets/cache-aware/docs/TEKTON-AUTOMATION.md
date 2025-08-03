# Tekton Cache Hit Testing Pipeline

This directory contains a Tekton Pipeline for automated testing of the LLM-D KV-cache performance. The pipeline restarts LLM pods to ensure fresh metrics and then runs comprehensive cache hit rate validation.

## Files

- `cache-hit-pipeline.yaml` - Main Task and Pipeline definitions
- `cache-hit-pipelinerun.yaml` - PipelineRun template with auto-generated names
- `run-cache-test.sh` - Deployment and execution script
- `README.md` - This documentation

## Features

### Pipeline Capabilities
- **Fresh Pod Testing**: Automatically deletes and waits for LLM pods to restart
- **Clean Metrics**: Tests against pods with zero baseline cache metrics
- **Comprehensive Validation**: Tests both direct pod access and gateway routing
- **Auto-generated Names**: Uses `generateName` to allow unlimited reruns
- **Production Ready**: Validates 90% cache hit rate target

### Two-Step Process
1. **Pod Restart Step**: Deletes optimized vLLM v0.10.0 pods and waits for recreation
2. **Cache Test Step**: Runs 20 identical requests and validates cache performance

## Prerequisites

- OpenShift Pipelines (Tekton) operator installed
- LLM-D deployed with optimized vLLM v0.10.0 configuration
- kubectl access to the cluster
- `tkn` CLI (optional, for log viewing)

## Usage

### Quick Start
```bash
# Deploy and run the pipeline
cd tekton/
./run-cache-test.sh
```

### Manual Deployment
```bash
# Deploy Task and Pipeline
kubectl apply -f cache-hit-pipeline.yaml

# Run a test (creates new PipelineRun each time)
kubectl create -f cache-hit-pipelinerun.yaml
```

### Custom Parameters
You can customize the pipeline by editing `cache-hit-pipelinerun.yaml`:

```yaml
spec:
  params:
    - name: namespace
      value: "your-namespace"  # Default: llm-d
    - name: gateway-url
      value: "your-gateway-url"  # Your specific gateway URL
```

## Monitoring

### Pipeline Status
```bash
# List all pipeline runs
kubectl get pipelinerun

# Watch a specific run
kubectl get pipelinerun cache-hit-run-xyz123 -w

# Get detailed status
kubectl describe pipelinerun cache-hit-run-xyz123
```

### Viewing Logs
```bash
# Using tkn CLI (recommended)
tkn pipelinerun logs cache-hit-run-xyz123 -f

# Using kubectl
kubectl logs -l tekton.dev/pipelineRun=cache-hit-run-xyz123
```

### OpenShift Console
Navigate to: **Pipelines → PipelineRuns** and select your run for a visual interface.

## Pipeline Steps

### Step 1: Restart LLM Pods
- Identifies optimized vLLM v0.10.0 pods
- Deletes all running LLM decode pods
- Waits for pod recreation and readiness
- Allows additional time for vLLM initialization

### Step 2: Cache Hit Testing
- Verifies optimized configuration parameters
- Captures baseline metrics (should be 0 for fresh pods)
- Runs 20 identical cache test requests
- Calculates cache hit rate and validates against targets
- Tests gateway routing functionality
- Reports comprehensive results

## Expected Results

### Success Criteria
- **Cache Hit Rate**: ≥90% (excellent), ≥75% (very good)
- **Configuration**: Verified optimized vLLM parameters
- **Gateway**: Successful routing through production gateway
- **Fresh Metrics**: Clean baseline from restarted pods

### Sample Output
```
🎉 Cache Hit Rate: 90.0%
🏆 EXCELLENT: Target 90%+ achieved!

=== CACHE-AWARE ROUTING STATUS ===
✅ vLLM v0.10.0 optimized configuration active
✅ Session Affinity: 2-hour ClientIP stickiness
✅ Cache Hit Rate: 90.0%
✅ Production gateway routing functional

🎯 Production KV-Cache System Validation Complete!
```

## Troubleshooting

### Pipeline Fails to Start
- Verify OpenShift Pipelines operator is installed
- Check RBAC permissions for pipeline service account
- Ensure Task and Pipeline are properly deployed

### Pod Restart Issues
- Check if optimized pods exist with correct image tag
- Verify deployment has sufficient replicas configured
- Ensure namespace parameter matches your deployment

### Cache Test Failures
- Verify vLLM configuration includes optimized parameters
- Check network connectivity between pipeline pod and LLM pods
- Confirm gateway URL is accessible and correct

### Low Cache Hit Rates
- Ensure pods were properly restarted with fresh metrics
- Verify session affinity is configured (2-hour ClientIP)
- Check for competing traffic during test execution

## Integration with CI/CD

This pipeline can be integrated into your CI/CD workflows:

```bash
# In your CI/CD script
kubectl create -f tekton/cache-hit-pipelinerun.yaml
PIPELINE_RUN=$(kubectl get pipelinerun -l tekton.dev/pipeline=cache-hit-pipeline --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# Wait for completion
kubectl wait --for=condition=Succeeded pipelinerun/$PIPELINE_RUN --timeout=10m

# Check results
kubectl get pipelinerun/$PIPELINE_RUN -o jsonpath='{.status.conditions[0].status}'
```

## Customization

### Different Test Patterns
Modify the cache test section in `cache-hit-pipeline.yaml` to test different prompt patterns or request volumes.

### Additional Metrics
Add steps to collect additional vLLM or Istio metrics during the test execution.

### Multi-Model Testing
Extend the pipeline to test cache performance across different model deployments.

This pipeline provides automated, repeatable validation of your KV-cache optimization with fresh pod metrics and comprehensive reporting.
