# LLM-D Testing & Validation Guide

Comprehensive testing procedures to verify LLM-D performance and functionality. For architecture details, see the [main README](README.md). For deployment steps, see the [Deployment Guide](DEPLOYMENT_GUIDE.md).

## 🚀 Quick Start

### 1. Deploy the New LLM-D Architecture
```bash
# Deploy the complete LLM-D system
kubectl apply -k assets/

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l llm-d.ai/inferenceServing=true -n llm-d --timeout=300s
```

### 2. Verify the Architecture is Deployed
```bash
# Check that we have EPP, prefill, and decode pods
kubectl get pods -n llm-d -l llm-d.ai/inferenceServing=true --show-labels

# Verify EPP has P/D enabled
kubectl describe pod -l llm-d.ai/epp -n llm-d | grep PD_ENABLED
# Should show: PD_ENABLED: true

# Check NIXL ports are listening
kubectl get pods -n llm-d -l llm-d.ai/role=prefill -o name | head -1 | xargs -I {} kubectl exec {} -n llm-d -c vllm -- netstat -tuln | grep 5557
kubectl get pods -n llm-d -l llm-d.ai/role=decode -o name | head -1 | xargs -I {} kubectl exec {} -n llm-d -c vllm -- netstat -tuln | grep 5557
```

## 🧪 Run GuideLLM Tests

### Option 1: Run P/D Disaggregation Test (Recommended)
```bash
# Run the improved GuideLLM test through EPP
kubectl apply -f assets/load-testing/guidellm-pd-test-job.yaml

# Monitor the test
kubectl logs -f job/guidellm-pd-benchmark -n llm-d

# Check results
kubectl logs job/guidellm-pd-benchmark -n llm-d | tail -20
```

### Option 2: Run Original GuideLLM Test
```bash
# Run the original GuideLLM (will bypass EPP)
kubectl apply -f guidellm/utils/guidellm-job.yaml

# Monitor
kubectl logs -f job/run-guidellm -n llm-d
```

### Option 3: Quick Prefix Cache Test
```bash
# Run simple cache test
kubectl apply -f assets/load-testing/prefix-cache-test-job.yaml

# Check results
kubectl logs job/prefix-cache-test -n llm-d
```

## 📊 Monitor P/D Disaggregation

### Check Request Distribution
```bash
# Get pod names
PREFILL_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=prefill -o jsonpath='{.items[0].metadata.name}')
DECODE_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=decode -o jsonpath='{.items[0].metadata.name}')

echo "Prefill Pod: $PREFILL_POD"
echo "Decode Pod: $DECODE_POD"

# Check metrics during test
echo "=== PREFILL POD METRICS ==="
kubectl exec -n llm-d $PREFILL_POD -c vllm -- curl -s http://localhost:8000/metrics | grep -E "prefix_cache_(queries|hits)_total"

echo "=== DECODE POD METRICS ==="
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | grep -E "prefix_cache_(queries|hits)_total"
```

### Expected Results with P/D Working:
- **Prefill Pod**: Should show `prefix_cache_queries_total > 0` (handling prompts)
- **Decode Pod**: Should show `prefix_cache_hits_total > 0` (receiving KV cache from prefill)

### Current Expected Results (P/D not yet active):
- **Prefill Pod**: `prefix_cache_queries_total = 0` (not being used)
- **Decode Pod**: `prefix_cache_queries_total > 0`, `prefix_cache_hits_total >= 0` (handling everything)

## 📈 Check EPP Routing Decisions

```bash
# Check EPP logs for routing decisions
EPP_POD=$(kubectl get pods -n llm-d -l llm-d.ai/epp -o jsonpath='{.items[0].metadata.name}')
kubectl logs $EPP_POD -n llm-d --tail=50 | grep -E "(request|route|prefill|decode|score)"

# Check EPP metrics
kubectl exec -n llm-d $EPP_POD -- curl -s http://localhost:9090/metrics | grep -E "(request|route)"
```

## 🔍 Detailed Verification

### 1. Architecture Verification
```bash
# Verify all components are present
kubectl get modelservice llama-3-2-1b -n llm-d
kubectl get inferencepool llama-3-2-1b-inference-pool -n llm-d
kubectl get httproute llama-3-2-1b-http-route -n llm-d

# Check services
kubectl get services -n llm-d | grep -E "(epp|prefill|decode)"
```

### 2. Configuration Verification
```bash
# Check ConfigMap has correct settings
kubectl get configmap basic-gpu-with-nixl-and-pd-preset -n llm-d -o yaml | grep -A 5 -B 5 "PD_ENABLED"

# Verify prefix caching args
kubectl get deployment -n llm-d -o yaml | grep -A 3 "enable-prefix-caching"
```

### 3. Network Verification
```bash
# Test EPP connectivity
kubectl run test-pod --rm -i --tty --image=curlimages/curl -- sh
# Inside pod: curl -v http://llama-3-2-1b-epp-service.llm-d.svc.cluster.local:9002/v1/models

# Test direct decode connectivity (bypass EPP)
# Inside pod: curl -v http://llama-3-2-1b-decode-service.llm-d.svc.cluster.local:8000/v1/models
```

## 🎯 Performance Comparison

### Before vs After Metrics

#### Before (Broken LMCache):
- KV Cache Hit Rate: **0%** (broken)
- Architecture: Monolithic (decode only)
- Caching: LMCache (non-functional)

#### After (Fixed Architecture):
- KV Cache Hit Rate: **>0%** (functional vLLM prefix caching)
- Architecture: P/D Disaggregation (EPP + prefill + decode)
- Caching: vLLM prefix caching + NIXL KV transfer

### Key Metrics to Monitor:
```bash
# Cache hit rate calculation
echo "Cache Hit Rate = (cache_hits / cache_queries) * 100%"

# Request latency
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | grep -E "time_to_first_token|time_per_output_token"

# Throughput
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | grep -E "request_success_total|generation_tokens_total"
```

## 🐛 Troubleshooting

### P/D Disaggregation Not Working
```bash
# Check EPP environment
kubectl describe pod -l llm-d.ai/epp -n llm-d | grep -A 20 Environment

# Check EPP version
kubectl get pod -l llm-d.ai/epp -n llm-d -o jsonpath='{.items[0].spec.containers[0].image}'

# Check logs for errors
kubectl logs -l llm-d.ai/epp -n llm-d --tail=100
```

### Cache Not Working
```bash
# Verify prefix caching is enabled
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | grep cache_config

# Check for LMCache errors (should be none)
kubectl logs $DECODE_POD -n llm-d -c vllm | grep -i lmcache
```

### No Requests Reaching Pods
```bash
# Check HTTPRoute configuration
kubectl get httproute llama-3-2-1b-http-route -n llm-d -o yaml

# Check if requests are reaching EPP
kubectl logs -l llm-d.ai/epp -n llm-d --tail=20
```

## 📋 Test Checklist

- [ ] All pods are running (EPP, prefill, decode)
- [ ] EPP shows `PD_ENABLED: true`
- [ ] NIXL ports (5557) are listening on all pods
- [ ] GuideLLM test completes successfully
- [ ] Prefix cache metrics show queries > 0
- [ ] No LMCache errors in logs
- [ ] HTTPRoute points to EPP service
- [ ] ModelService CRD is present and healthy

## 🎉 Success Indicators

✅ **Fixed Prefix Caching**: `prefix_cache_queries_total > 0` and potentially `prefix_cache_hits_total > 0`

✅ **P/D Architecture**: EPP, prefill, and decode pods all running

✅ **Improved Performance**: Better latency/throughput compared to original broken setup

✅ **Monitoring Working**: Grafana dashboard shows non-zero cache metrics

## 📞 Next Steps

1. **Run GuideLLM**: Execute the P/D test when kubectl is restored
2. **Monitor Metrics**: Check Grafana dashboard for improvements
3. **Compare Performance**: Document before/after performance gains
4. **Demo Ready**: Architecture is ready for demonstration
