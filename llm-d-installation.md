# Installing llm-d on OpenShift ROSA with GPU Support

This document outlines the process of installing llm-d on an OpenShift ROSA cluster with GPU support, including challenges encountered and their solutions.

## Prerequisites

### 1. Infrastructure Requirements
- OpenShift ROSA cluster running version 4.19.4
- GPU nodes using AWS p4d.24xlarge instances (8x NVIDIA A100 Tensor Core GPUs)
- HuggingFace account with access to meta-llama/Llama-3.2-3B-Instruct model

### 2. Required Operators
- NVIDIA GPU Operator
- Node Feature Discovery (NFD) Operator
- Red Hat OpenShift AI Operator

## Installation Process

### 1. GPU Infrastructure Setup

First, we created a GPU-enabled machine pool in ROSA:
```bash
rosa create machinepool --cluster rhoai-cluster \
  --name gpu-pool \
  --instance-type p4d.24xlarge \
  --replicas 3 \
  --labels node-role.kubernetes.io/gpu=true \
  --taints nvidia.com/gpu=true:NoSchedule
```

### 2. Operator Installation

We installed the required operators in the following order:

1. Node Feature Discovery (NFD) Operator:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: openshift-operators
spec:
  channel: "stable"
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

2. NVIDIA GPU Operator:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: "v23.6"
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
```

3. Red Hat OpenShift AI Operator:
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: openshift-operators
spec:
  channel: stable
  name: rhods-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
```

### 3. llm-d Installation

1. Cloned the llm-d-deployer repository:
```bash
git clone https://github.com/llm-d/llm-d-deployer.git
cd llm-d-deployer/quickstart
```

2. Created HuggingFace token secret:
```bash
export HF_TOKEN=<your-token>
oc create secret generic hf-token --from-literal=token=$HF_TOKEN
```

3. Created custom values file (values-openshift.yaml) for OpenShift-specific configuration:
```yaml
gateway:
  enabled: false  # Disable external gateway

ingress:
  enabled: false  # Disable Kubernetes ingress

modelservice:
  routing:
    type: openshift  # Use OpenShift routing
  prefill:
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
  decode:
    tolerations:
      - key: nvidia.com/gpu
        operator: Exists
        effect: NoSchedule
```

4. Installed llm-d using the installer script:
```bash
./llmd-installer.sh -i -n llm-d -f values-openshift.yaml
```

## Challenges and Solutions

### 1. Operator Installation Order
**Challenge**: Initially faced operator conflicts when installing all operators simultaneously.
**Solution**: Installed operators in sequence and in separate namespaces to avoid conflicts.

### 2. GPU Operator Requirements
**Challenge**: GPU Operator failed to install in openshift-operators namespace.
**Solution**: Created dedicated nvidia-gpu-operator namespace and proper OperatorGroup.

### 3. Service Mesh Dependencies
**Challenge**: Initial installation failed due to Istio/Service Mesh requirements.
**Solution**: Customized values.yaml to disable gateway and ingress components, allowing for OpenShift native routing.

### 4. HuggingFace Token Management
**Challenge**: Secure management of HuggingFace token.
**Solution**: Created Kubernetes secret and configured llm-d to use it for model access.

## Current Status

Successfully deployed:
- llm-d model service controller
- Redis instance for caching
- Required CRDs and configurations
- GPU node pool with p4d.24xlarge instances

## Next Steps

1. Create a ModelService instance to deploy the Llama model
2. Set up OpenShift route for service access
3. Configure and test the deployment

## Additional Resources

- [llm-d Documentation](https://llm-d.ai/)
- [OpenShift ROSA Documentation](https://docs.openshift.com/rosa/welcome/index.html)
- [NVIDIA GPU Operator Documentation](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
