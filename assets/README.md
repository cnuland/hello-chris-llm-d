# LLM-D Architecture Deployment Assets

> Current demo state (v0.2.0)
> - Model: meta-llama/Llama-3.2-3B-Instruct
> - Stickiness: EPP-driven via Envoy ext-proc on llm-d-gateway (failure_mode_allow=true); mesh fallback is ROUND_ROBIN
> - Gateway: http://llm-d-gateway-istio.llm-d.svc.cluster.local with Host: llm-d.demo.local

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

### 2. **Decode Pods**
- **Purpose**: Handle token generation phase
- **Features**:
  - ✅ Proper vLLM prefix caching (`--enable-prefix-caching`)
  - ✅ GPU scheduling and resource management

### 3. (Optional) Prefill Pods
- Not required for this 0.2.0 demo flow. If enabled in your environment, ensure KV transfer compatibility accordingly.

## 🔧 Key Improvements

### Fixed Prefix Caching
- **Before**: Broken LMCache configuration causing 0% hit rate
- **After**: Proper vLLM prefix caching with `sha256` hash algorithm

### P/D Disaggregation
- **Before**: `PD_ENABLED=false` (monolithic mode)
- **After**: `PD_ENABLED=true` with proper threshold configuration

### KV Eventing (optional)
- If you enable cross-pod KV transfer or external indexers, ensure consistent hashing configuration and ports across components.

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

MANDATED: Install llm-d-infra via Helm first
- This repo now assumes the gateway and core infra are provisioned by the upstream Helm chart.
- Run: make infra NS=llm-d GATEWAY_CLASS=istio (HF_TOKEN in env if needed)

Then apply model/pipeline layers as needed from this repo. Do not manually create gateway resources here; they are managed by the chart.

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
# Decode pod metrics
POD=$(kubectl get pods -n llm-d -l app=ms-llm-d-modelservice-decode -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n llm-d $POD -c vllm -- curl -s http://localhost:8001/metrics | grep prefix_cache
```

### Expected Results
With P/D disaggregation working:
- **Prefill pods**: Should see `prefix_cache_queries_total > 0`
- **Decode pods**: Should see `prefix_cache_hits_total > 0` (from KV transfer)

## 🔍 Verification

### Check EPP Configuration
```bash
kubectl get deploy -n llm-d ms-llm-d-modelservice-epp
kubectl logs -n llm-d deploy/ms-llm-d-modelservice-epp -c epp -f --tail=100
```

### Verify ext-proc is attached
```bash
kubectl get envoyfilter -n llm-d epp-ext-proc -o yaml | grep -E '(workloadSelector|cluster_name|failure_mode_allow)'
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
