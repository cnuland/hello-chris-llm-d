# Setup Assets

This directory contains configuration files and values used during initial setup and troubleshooting.

## Files

### `gaie-values.yaml`
Configuration values for the Gateway API Inference Extension (GAIE) EPP deployment. Used with the official LLM-D community Helm chart.

**Usage:**
```bash
# Deploy GAIE EPP with custom values
helm upgrade -i llm-d-gaie gateway-api-inference-extension/gaie -n llm-d -f assets/setup/gaie-values.yaml
```

**Key configurations:**
- EPP image: `ghcr.io/llm-d/llm-d-inference-scheduler:v0.2.1`
- Plugin configuration: `plugins-v2.yaml`
- Service discovery: Labels `llm-d.ai/inferenceServing=true` and `llm-d.ai/role=decode`

### `gpu-cluster-policy-rhcos.yaml`
NVIDIA GPU Operator ClusterPolicy specifically configured for Red Hat CoreOS (RHCOS). This policy includes all necessary drivers and components for GPU acceleration in OpenShift environments.

**Usage:**
```bash
# Apply GPU cluster policy for RHCOS
kubectl apply -f assets/setup/gpu-cluster-policy-rhcos.yaml
```

**Key features:**
- RHCOS-optimized driver configuration
- DCGM and GPU Feature Discovery enabled
- Proper tolerations for GPU nodes
- Container runtime: CRI-O

## Integration with Main Installation

These files are referenced in the main installation process but stored here for organization:

- The main `Makefile` and `README.md` reference these files when needed
- GAIE values are used when deploying the EPP via official community Helm charts
- GPU cluster policy is applied as part of the prerequisite GPU operator setup

## Notes

- These files represent the working configurations discovered through troubleshooting
- They use the official LLM-D community approach (no operator, no Redis dependencies)
- All configurations are optimized for production deployments with high cache hit rates
