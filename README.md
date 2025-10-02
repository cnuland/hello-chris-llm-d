# LLM-D: GPU-Accelerated Cache-Aware LLM Inference

**Production-ready distributed LLM inference with intelligent KV-cache-aware routing, GPU acceleration, and 90%+ cache hit rates.**

🎯 **Proven Results**: 92.5% cache hit rate, 77% TTFT improvement, GPU-accelerated inference

⚡ **Key Features**:

- **Cache-Aware Routing**: EPP (External Processing Pod) with intelligent request scheduling
- **GPU Acceleration**: NVIDIA A100 support with vLLM v0.10.0 optimization
- **Istio Integration**: Gateway API + service mesh for production traffic management
- **Out-of-Box Experience**: Automated installation with proper dependency ordering

---

## NVIDIA GPU Operator Setup (for GPU-accelerated inference)

To run LLM-D with GPU acceleration, you'll need to install and configure the NVIDIA GPU Operator on your OpenShift/Kubernetes cluster. This section provides step-by-step instructions based on a successful deployment.

### Prerequisites

- OpenShift 4.16+ or Kubernetes cluster with GPU nodes (tested with p4d.24xlarge instances)
- Cluster admin privileges
- GPU nodes should be labeled appropriately (e.g., `node.kubernetes.io/instance-type=p4d.24xlarge`)

### 1. Install NVIDIA GPU Operator

Install the NVIDIA GPU Operator from OperatorHub:

```bash
# Create the nvidia-gpu-operator namespace
oc create namespace nvidia-gpu-operator

# Install the operator (via OperatorHub or manually)
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator
  namespace: nvidia-gpu-operator
spec:
  channel: stable
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF
```

### 2. Label GPU Nodes (Required for RHCOS)

On RHEL CoreOS (RHCOS), Node Feature Discovery (NFD) may not automatically detect all required labels. Manually add the necessary labels:

```bash
# Get your GPU node names
oc get nodes -l node.kubernetes.io/instance-type | grep -E "(g4dn|g5|p3|p4)"

# For each GPU node, add the required NFD labels
for node in $(oc get nodes -o name -l node.kubernetes.io/instance-type | grep -E "(g4dn|g5|p3|p4)"); do
  # Add NVIDIA PCI device label
  oc label $node feature.node.kubernetes.io/pci-10de.present=true
  
  # Add kernel version label (check your kernel version first)
  KERNEL_VERSION=$(oc debug $node -- chroot /host uname -r | tail -1)
  oc label $node feature.node.kubernetes.io/kernel-version.full=$KERNEL_VERSION
  
  # Add RHCOS version label (for RHCOS nodes)
  OSTREE_VERSION=$(oc debug $node -- chroot /host cat /etc/os-release | grep OSTREE_VERSION | cut -d'=' -f2 | tr -d '"' | tail -1)
  oc label $node feature.node.kubernetes.io/system-os_release.OSTREE_VERSION=$OSTREE_VERSION
done
```

### 3. Create GPU Cluster Policy

Create a cluster policy optimized for RHCOS:

```bash
oc apply -f - <<EOF
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: gpu-cluster-policy
spec:
  operator:
    defaultRuntime: crio
    runtimeClass: nvidia
  driver:
    enabled: true
    rdma:
      enabled: false
    useOpenKernelModules: false
  toolkit:
    enabled: true
  devicePlugin:
    enabled: true
  dcgm:
    enabled: true
  dcgmExporter:
    enabled: true
  gfd:
    enabled: true
  nodeStatusExporter:
    enabled: true
  daemonsets:
    tolerations:
    - key: nvidia.com/gpu
      operator: Exists
      effect: NoSchedule
    updateStrategy: RollingUpdate
EOF
```

### 4. Verify Installation

Monitor the installation progress:

```bash
# Check cluster policy status
oc describe clusterpolicy gpu-cluster-policy

# Watch all GPU operator pods
oc get pods -n nvidia-gpu-operator -w

# Verify GPU resources are advertised
oc describe nodes -l node.kubernetes.io/instance-type | grep nvidia.com/gpu

# Expected output should show: nvidia.com/gpu: <number_of_gpus>
```

Successful deployment should show:

- `nvidia-driver-daemonset-*` pods: `2/2 Running`
- `nvidia-device-plugin-daemonset-*` pods: `1/1 Running`
- `gpu-feature-discovery-*` pods: `1/1 Running`
- `nvidia-container-toolkit-daemonset-*` pods: `1/1 Running`
- GPU resources advertised on nodes (e.g., `nvidia.com/gpu: 8`)

### 5. Test GPU Access

Validate GPU access with a test pod:

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
  namespace: default
spec:
  containers:
  - name: gpu-test
    image: nvidia/cuda:12.4-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
  restartPolicy: Never
EOF

# Check the output
oc logs gpu-test

# Clean up
oc delete pod gpu-test
```

### Troubleshooting

**Driver compilation issues:**

- RHCOS doesn't include kernel headers by default
- The OpenShift Driver Toolkit (DTK) automatically handles driver compilation
- Wait for `nvidia-driver-daemonset` pods to show `2/2 Running`

**Missing NFD labels:**

- Manually add the required labels as shown in step 2
- Check `oc logs` of the GPU operator for specific missing labels

**Image pull issues:**

- Ensure cluster has internet access to pull NVIDIA container images
- Check for any corporate proxy/firewall restrictions

### Expected Resources Per Node

For p4d.24xlarge instances:

- **GPUs**: 8x NVIDIA A100-SXM4-40GB (40GB memory each)
- **GPU Memory**: 320GB total per node
- **CUDA Compute Capability**: 8.0
- **NVLink**: High-speed inter-GPU communication

## 🚀 Out-of-Box Installation Guide

**CRITICAL**: Follow this exact order for guaranteed success. Do NOT skip steps.

### ⚠️ Prerequisites (MANDATORY)

**1. Cluster Requirements:**

- OpenShift 4.16+ or Kubernetes 1.28+
- GPU nodes with NVIDIA GPU Operator installed (see section above)
- Cluster admin privileges

**2. Required Tools:**

```bash
# Verify these tools are installed:
kubectl version --client # Optional
helm version 
oc version  # For OpenShift
tkn version  # Tekton CLI (for testing)
```

**3. Environment Setup:**

```bash
# Required: Set your Hugging Face token for model access
export HF_TOKEN="hf_your_actual_token_here"

# Optional: Set custom namespace (default: llm-d)
export NS=llm-d
```

---

### 📋 Installation Order (DO NOT CHANGE)

#### Step 1: Install Istio 1.27.0+ (REQUIRED)

**Why This Version**: Istio 1.27.0+ includes Gateway API Inference Extension support, which is required for EPP cache-aware routing. Older versions (including OpenShift Service Mesh) will NOT work.

```bash
# Add anyuid SCC permissions for OpenShift
oc create ns istio-system
oc adm policy add-scc-to-user anyuid -z istio-ingressgateway-service-account -n istio-system
oc adm policy add-scc-to-user anyuid -z istiod -n istio-system

# Download and install Istio 1.27.0
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.27.0 TARGET_ARCH=x86_64 sh -
PATH=$PATH:istio-1.27.0/bin

# Install istioctl (optional)
# sudo mv istio-1.27.0/bin/istioctl /usr/local/bin/

# Install Istio with Gateway API support
istioctl install --set values.pilot.env.EXTERNAL_ISTIOD=false -y

```

**Verify Istio Installation:**

```bash
# Should show istio control plane pods running
oc get pods -n istio-system
```

#### Step 2: Install Gateway API CRDs

```bash
# Install standard Gateway API CRDs
oc apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Install Gateway API Inference Extension CRDs
oc apply -f https://github.com/kubernetes-sigs/gateway-api-inference-extension/releases/latest/download/manifests.yaml
```

**Verify Gateway API:**

```bash
# Should show gateway, httproute, and inference CRDs
oc get crd | grep -E "(gateway|inference)"

# Should show "istio" GatewayClass available
oc get gatewayclass
```

#### Step 3: Install LLM-D Infrastructure

```bash
# Install base infrastructure (Gateway, HTTPRoute)
make infra NS=llm-d GATEWAY_CLASS=istio

# Verify gateway is programmed
oc get gateway -n llm-d
# Should show: PROGRAMMED=True
```

#### Step 4: Install LLM-D Components

```bash
# Install EPP, decode services, and complete stack
make llm-d NS=llm-d

# Wait for all components to be ready (~5-10 minutes for GPU model loading)
make status NS=llm-d
```

#### Step 5: Validate Installation

```bash
# Run end-to-end cache-aware routing test
make test NS=llm-d

# Expected results:
# ✅ Cache Hit Rate: 90%+ 
# ✅ TTFT improvement: 70%+ for cached requests
# ✅ Gateway routing: HTTP 200 responses
```

---

### 🎯 Quick Start (TL;DR)

```bash
# Set required environment
export HF_TOKEN="hf_your_actual_token_here"
export NS=llm-d

# Complete installation (10-15 minutes)
make install-all NS=$NS

# Run validation test
make test NS=$NS
```

---

### 🔧 Make Commands Reference

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `make install-all` | Complete installation (all steps) | First-time setup |
| `make infra` | Infrastructure only | Gateway/routing setup |
| `make llm-d` | LLM-D components only | After infra is ready |
| `make test` | Run cache-hit validation | Verify deployment |
| `make status` | Check component status | Troubleshooting |
| `make clean` | Remove all components | Fresh restart |

**Environment Variables:**

- `NS`: Namespace (default: llm-d)
- `HF_TOKEN`: Hugging Face token (required)
- `GATEWAY_CLASS`: Gateway class (default: istio)

---

### ⚠️ DO NOT Use These (Deprecated/Incompatible)

- ❌ **OpenShift Service Mesh**: Based on older Istio, lacks Gateway API Inference Extension
- ❌ **LLM-D Operator**: Outdated and not maintained
- ❌ **Manual Kubernetes Manifests**: Configuration loading issues, use official Helm charts
- ❌ **kGateway**: This demo is optimized for Istio integration

---

### 🏆 Expected Results

After successful installation, you should see:

**Performance Metrics:**

- **Cache Hit Rate**: 90-95%
- **TTFT Improvement**: 70-80% for cached requests  
- **Response Times**: ~220ms TTFT for cache hits vs ~970ms for misses
- **Throughput**: Optimized based on EPP intelligent routing

**Infrastructure Status:**

```bash
oc get pods -n llm-d
# Should show all pods Running:
# - llm-d-gaie-epp-*: 1/1 Running (EPP)
# - ms-llm-d-modelservice-decode-*: 3/3 Running (GPU inference)
# - llm-d-infra-inference-gateway-*: 1/1 Running (Istio gateway)
```

## Architecture (overview)

High-level flow

1) Client → Istio Gateway → Envoy External Processing (EPP)
2) EPP scores endpoints for KV-cache reuse and health → returns routing decision (header hint)
3) Gateway forwards to decode Service/pod honoring EPP’s decision
4) vLLM pods execute inference with prefix cache enabled (TTFT improves after warm-up)
5) Prometheus aggregates metrics; Tekton prints hit-rate and timings

Key components

- EPP (External Processor): cache-aware scoring and decisioning
- Istio Gateway/Envoy: ext_proc integration; EPP uses InferencePool for endpoint discovery and scoring
- vLLM pods: prefix cache enabled, block_size=16, no chunked prefill
- Observability: Prometheus (or Thanos) used by the Tekton Task to aggregate pod metrics

Why it works

- EPP-driven routing concentrates session traffic onto warm pods for maximal KV cache reuse
- Prefix caching reduces TTFT and total latency significantly for repeated prompts
- All policy is centralized in EPP; the data plane remains simple

For a deeper technical outline (design rationale, metrics, demo flow), see the blog posts in blog/ (do not modify them here).

## Monitoring

What’s deployed (llm-d-monitoring)

- Prometheus: v2.45.0, 7d retention, jobs include:
  - kubernetes-pods (llm-d), vllm-instances (port mapping 8000→8000), llm-d-scheduler, gateway-api inference extension (EPP), Envoy/gateway
- Grafana: latest, anonymous viewer enabled, admin user seeded for demo
- Dashboards: LLM Performance Dashboard provisioned from monitoring/grafana-dashboard-llm-performance.json

Key panels (examples)

- TTFT: histogram_quantile over vllm:time_to_first_token_seconds_bucket
- Inter-token latency: vllm:time_per_output_token_seconds_bucket
- Cache hit rates: sum(vllm:gpu_prefix_cache_hits_total) / sum(vllm:gpu_prefix_cache_queries_total)
- Request queue: vllm:num_requests_running vs vllm:num_requests_waiting
- Throughput: rate(vllm:request_success_total[5m])

Files of record

- Prometheus
  - monitoring/prometheus.yaml (SA/RBAC/Deployment/Service)
  - monitoring/prometheus-config.yaml (scrape configs + alert rules)
- Grafana
  - monitoring/grafana.yaml (SA/Deployment)
  - monitoring/grafana-config.yaml (grafana.ini)
  - monitoring/grafana-datasources.yaml (Prometheus datasource)
  - monitoring/grafana-dashboards-config.yaml (provisioning)
  - monitoring/grafana-dashboard-llm-performance.json (dashboard)
  - monitoring/grafana-service.yaml (Service + OpenShift Route)

## Repository Layout (selected)

- deploy.sh: single command installer and validator for the Istio + EPP demo
- assets/llm-d: decode Service/Deployment, EPP stack, HTTPRoute
- assets/cache-aware/tekton: Tekton cache-hit pipeline definition
- monitoring/: optional monitoring assets (Grafana dashboards, configs)
- llm-d-infra/: upstream infrastructure (optional), not required for this demo path

## Notes and expectations

- Metrics and routes: some names/hosts are environment-specific; update to your cluster
- Secrets/tokens: this repo does not include real secrets. Configure any required tokens (e.g., HF) as Kubernetes Secrets in your cluster
- GPU requirement: for real model inference, deploy onto GPU nodes with NVIDIA GPU Operator installed (see "NVIDIA GPU Operator Setup" section above); otherwise, deploy the stack and test the control-plane paths only

## Links

- Blog: see blog/ for architectural deep dives and demo details
- Troubleshooting: monitoring/README.md for monitoring-specific steps
- Advanced architecture details: assets/cache-aware/docs/ARCHITECTURE.md
- Metrics details: assets/cache-aware/docs/METRICS.md
