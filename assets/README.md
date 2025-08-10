# LLM-D Architecture Deployment Assets

This directory contains assets for deploying a complete **LLM-D (Large Language Model Disaggregation)** architecture. For comprehensive architecture details and demo scenarios, see the [main README](../README.md).

## 🎯 What's Included

## 🏗️ Architecture Components

### 1. **Entry Point Pool (EPP)**
- **Purpose**: Intelligent request scheduler and router
- **Features**: 
  - ✅ P/D disaggregation enabled (`PD_ENABLED=true`)
  - ✅ KV cache-aware routing (`ENABLE_KVCACHE_AWARE_SCORER=true`)
  - ✅ Load-aware and prefix-aware scoring
  - ✅ Routes requests to appropriate prefill or decode pods

### 2. **Prefill Pods**
- **Purpose**: Handle prompt processing phase
- **Features**:
  - ✅ Proper vLLM prefix caching (`--enable-prefix-caching`)
  - ✅ NIXL KV transfer for sharing cache with decode pods
  - ✅ GPU scheduling and resource management

### 3. **Decode Pods**
- **Purpose**: Handle token generation phase
- **Features**:
  - ✅ Proper vLLM prefix caching (`--enable-prefix-caching`)
  - ✅ NIXL KV transfer for receiving cache from prefill pods
  - ✅ GPU scheduling and resource management

## 🔧 Key Improvements

### Fixed Prefix Caching
- **Before**: Broken LMCache configuration causing 0% hit rate
- **After**: Proper vLLM prefix caching with `sha256` hash algorithm

### P/D Disaggregation
- **Before**: `PD_ENABLED=false` (monolithic mode)
- **After**: `PD_ENABLED=true` with proper threshold configuration

### NIXL KV Transfer
- **Purpose**: Enables cache sharing between prefill and decode pods
- **Configuration**: Both pods listen on port 5557 for KV transfer

## 📁 Directory Structure

```
assets/
├── llm-d/                     # Main LLM-D architecture
│   ├── modelservice.yaml      # ModelService CRD definition
│   ├── configmap-preset.yaml  # Improved ConfigMap with P/D enabled
│   └── kustomization.yaml     # LLM-D components
├── monitoring/                # Prometheus/Grafana monitoring
├── load-testing/              # Load testing jobs
└── kustomization.yaml         # Main deployment configuration
```

## 🚀 Deployment

Prereqs:
- Namespace: llm-d
- Hugging Face token secret:

```
kubectl create namespace llm-d 2>/dev/null || true
kubectl -n llm-d create secret generic llm-d-hf-token \
  --from-literal=HF_TOKEN={{HF_TOKEN}} --dry-run=client -o yaml | kubectl apply -f -
```

Apply all LLM-D gateway, EPP, and decode components at once with Kustomize:

```
kubectl apply -k assets/llm-d
kubectl -n llm-d rollout status deploy/ms-llm-d-modelservice-decode
```

Validate via the gateway (replace <LB> if you prefer direct IP):

```
LB=$(kubectl -n llm-d get svc llm-d-gateway-istio -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -sS -H 'Host: llm-d.demo.local' http://$LB/v1/models | jq .
curl -sS -H 'Host: llm-d.demo.local' http://$LB/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"meta-llama/Llama-3.2-3B-Instruct","messages":[{"role":"user","content":"Say hello from LLM-D"}],"max_tokens":16}' | jq .
```

For Tekton-based cache tests, apply the Tekton assets and run the task afterward.

## 📊 Monitoring

The deployment includes:
- **Grafana Dashboard**: LLM-D Performance Dashboard with KV cache hit rate
- **Prometheus Metrics**: All vLLM and EPP metrics
- **Load Testing**: Jobs to test P/D disaggregation

## 🧪 Testing P/D Disaggregation

### Run Prefix Cache Test
```bash
kubectl apply -f assets/load-testing/prefix-cache-test-job.yaml
```

### Check Metrics
```bash
# Prefill pod metrics
kubectl exec -n llm-d <prefill-pod> -c vllm -- curl -s http://localhost:8000/metrics | grep prefix_cache

# Decode pod metrics  
kubectl exec -n llm-d <decode-pod> -c vllm -- curl -s http://localhost:8001/metrics | grep prefix_cache
```

### Expected Results
With P/D disaggregation working:
- **Prefill pods**: Should see `prefix_cache_queries_total > 0`
- **Decode pods**: Should see `prefix_cache_hits_total > 0` (from KV transfer)

## 🔍 Verification

### Check EPP Configuration
```bash
kubectl describe pod -l llm-d.ai/epp -n llm-d
# Should show: PD_ENABLED: true
```

### Check NIXL Ports
```bash
kubectl exec -n llm-d <pod> -c vllm -- netstat -tuln | grep 5557
# Should show: tcp ... :5557 ... LISTEN
```

### Check Pod Roles
```bash
kubectl get pods -n llm-d -l llm-d.ai/inferenceServing=true --show-labels
# Should show pods with role=prefill and role=decode
```

## 📈 Performance Benefits

1. **Proper Prefix Caching**: Eliminates 0% hit rate issues
2. **P/D Disaggregation**: Optimizes resource utilization
3. **NIXL KV Transfer**: Enables cache sharing across pods
4. **Intelligent Routing**: EPP routes based on load and cache affinity

## 🐛 Troubleshooting

### No Cache Hits
- Ensure requests with shared prefixes hit the same pod
- Check that prefix caching is enabled in metrics
- Verify NIXL KV transfer is working

### P/D Not Working
- Verify `PD_ENABLED=true` in EPP pod
- Check EPP logs for routing decisions
- Ensure prefill and decode pods are both ready

### Pod Discovery Issues
- Check EPP logs for pod reconciliation
- Verify pod labels match EPP selectors
- Ensure InferencePool is properly configured
