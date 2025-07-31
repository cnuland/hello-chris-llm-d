# GuideLLM Pipeline Deployment

This directory contains all the assets needed to deploy GuideLLM benchmarking capabilities for LLM endpoints. For integration with the main LLM-D demo and performance benchmarks, see the [main README](../README.md#performance-benchmarks).

## Directory Structure

```
guidellm/
├── README.md                           # This file
├── pipeline/                           # Tekton Pipeline resources
│   ├── tekton-task.yaml               # GuideLLM Tekton Task
│   ├── tekton-pipeline.yaml           # GuideLLM Tekton Pipeline
│   └── pipelinerun-template.yaml      # Working PipelineRun template
├── utils/                             # Utility resources
│   ├── pvc.yaml                       # Persistent Volume Claim for output
│   ├── guidellm-job.yaml              # Basic Kubernetes Job for running GuideLLM
│   ├── guidellm-job-advanced.yaml     # Advanced Job with better config and auth
│   ├── taskrun-template.yaml          # TaskRun template with dynamic naming
│   ├── taskrun-text-prompts.yaml      # TaskRun for text-based prompts
│   └── serviceaccount.yaml            # Service Account for pipeline
├── archive/                           # Archived/deprecated files
│   └── ...                            # Old TaskRun iterations
├── configs/                           # Configuration resources
│   ├── config.yaml                    # GuideLLM ConfigMap
│   └── env-config.yaml                # Environment ConfigMap
└── kustomization.yaml                 # Kustomize configuration
```

## Prerequisites

1. **Tekton Pipelines**: Ensure Tekton is installed in your cluster
2. **Target LLM Service**: A running LLM service endpoint to benchmark
3. **Storage**: Persistent storage for benchmark results

## Deployment Options

### Option 1: Deploy All Resources

```bash
kubectl apply -k guidellm/
```

### Option 2: Deploy Individual Components

1. **Deploy base resources:**
   ```bash
   kubectl apply -f guidellm/utils/pvc.yaml
   kubectl apply -f guidellm/utils/serviceaccount.yaml
   kubectl apply -f guidellm/configs/
   ```

2. **Deploy Tekton Pipeline:**
   ```bash
   kubectl apply -f guidellm/pipeline/tekton-task.yaml
   kubectl apply -f guidellm/pipeline/tekton-pipeline.yaml
   ```

3. **Run benchmark via Pipeline:**
   ```bash
   kubectl create -f guidellm/pipeline/pipelinerun-template.yaml
   ```

### Option 3: Run as Kubernetes Job

**Basic Job (for simple testing):**
```bash
kubectl apply -f guidellm/utils/guidellm-job.yaml
```

**Advanced Job (with better configuration and HuggingFace auth):**
```bash
kubectl apply -f guidellm/utils/guidellm-job-advanced.yaml
```

### Option 4: Run TaskRuns Directly

**Template with dynamic naming:**
```bash
envsubst < guidellm/utils/taskrun-template.yaml | kubectl apply -f -
```

**Text-based prompts testing:**
```bash
envsubst < guidellm/utils/taskrun-text-prompts.yaml | kubectl apply -f -
```

## Configuration

### Environment Variables

The following environment variables can be customized in the job or pipeline:

- `TARGET`: LLM endpoint URL (default: internal service)
- `MODEL_NAME`: Model identifier
- `PROCESSOR`: Processor/model path (can be empty for synthetic data)
- `DATA_CONFIG`: Data configuration (e.g., `synthetic:count=10`)
- `RATE_TYPE`: Rate type (`synchronous`, `poisson`, etc.)
- `MAX_SECONDS`: Maximum benchmark duration
- `OUTPUT_FILENAME`: Output file name

### Example Pipeline Run

```bash
# Using tkn CLI
tkn pipeline start guidellm-benchmark-pipeline \
  --param target=http://llama-3-2-1b-decode-service.llm-d.svc.cluster.local:8000 \
  --param model=meta-llama/Llama-3.2-1B \
  --param processor="" \
  --param data="synthetic:count=10" \
  --param rate-type=synchronous \
  --workspace name=shared-workspace,claimName=guidellm-output-pvc
```

## Monitoring Results

### Pipeline Runs
```bash
# List pipeline runs
kubectl get pipelineruns -n llm-d

# View logs
kubectl logs <pipelinerun-pod> -n llm-d
```

### Job Results
```bash
# List jobs
kubectl get jobs -n llm-d

# View logs
kubectl logs job/run-guidellm -n llm-d
```

### Accessing Output
```bash
# Mount PVC to see results
kubectl exec -it <pod-with-pvc> -n llm-d -- ls /output
```

## Troubleshooting

### Common Issues

1. **Processor/Tokenizer Errors**: Set `processor` parameter to empty string `""` when using synthetic data
2. **SSL Certificate Issues**: Use internal service endpoints instead of external HTTPS
3. **Permission Errors**: Ensure proper ServiceAccount permissions for Tekton

### Working Configuration

Based on our testing, this configuration works reliably:
- Target: `http://llama-3-2-1b-decode-service.llm-d.svc.cluster.local:8000`
- Model: `meta-llama/Llama-3.2-1B`
- Processor: `""` (empty)
- Data: `synthetic:count=10`
- Rate Type: `synchronous`

## Integration with LLM-D

This GuideLLM setup is designed to work with the LLM-D vLLM deployment:
- Uses internal ClusterIP service for reliable connectivity
- Configured for the Llama-3.2-1B model
- Generates metrics that integrate with the monitoring stack

## Resources

- [GuideLLM Pipeline Repository](https://github.com/rh-aiservices-bu/guidellm-pipeline)
- [GuideLLM Documentation](https://github.com/NeuML/guidellm)
- [Tekton Documentation](https://tekton.dev/docs/)
