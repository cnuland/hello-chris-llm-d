# Metrics Collection Debug Guide

This guide helps troubleshoot metrics collection issues with the LLM-D architecture. For monitoring setup and configuration details, see the [main README monitoring section](README.md#monitoring-and-observability).

## 🔍 Quick Diagnosis Commands

### 1. Check if Pods are Exposing Metrics
```bash
# Get pod names
PREFILL_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=prefill -o jsonpath='{.items[0].metadata.name}')
DECODE_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=decode -o jsonpath='{.items[0].metadata.name}')
EPP_POD=$(kubectl get pods -n llm-d -l llm-d.ai/epp -o jsonpath='{.items[0].metadata.name}')

echo "Prefill Pod: $PREFILL_POD"
echo "Decode Pod: $DECODE_POD"  
echo "EPP Pod: $EPP_POD"

# Test direct metrics access
echo "=== PREFILL METRICS ==="
kubectl exec -n llm-d $PREFILL_POD -c vllm -- curl -s http://localhost:8000/metrics | head -10

echo "=== DECODE METRICS ==="
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | head -10

echo "=== EPP METRICS ==="
kubectl exec -n llm-d $EPP_POD -- curl -s http://localhost:9090/metrics | head -10
```

### 2. Check Services and Labels
```bash
# Check if services have correct labels
kubectl get services -n llm-d -o wide --show-labels

# Check if pods have correct labels
kubectl get pods -n llm-d --show-labels | grep -E "(prefill|decode|epp)"

# Check specifically for gather-metrics labels
kubectl get services -n llm-d -l llmd.ai/gather-metrics=true
```

### 3. Check ServiceMonitors and PodMonitors
```bash
# List all monitoring resources
kubectl get servicemonitors -n llm-d
kubectl get podmonitors -n llm-d

# Check ServiceMonitor status
kubectl describe servicemonitor llm-d-modelservice-metrics -n llm-d
kubectl describe servicemonitor llm-d-epp-service-metrics -n llm-d

# Check PodMonitor status
kubectl describe podmonitor llm-d-comprehensive-metrics -n llm-d
kubectl describe podmonitor llm-d-epp-comprehensive-metrics -n llm-d
```

### 4. Check Prometheus Targets
```bash
# Port-forward to Prometheus (adjust service name as needed)
kubectl port-forward -n monitoring service/prometheus-operated 9090:9090 &

# Then visit http://localhost:9090/targets in your browser
# Or use curl:
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job | contains("llm-d")) | {job: .labels.job, health: .health, lastError: .lastError}'
```

## 🛠️ Common Issues and Fixes

### Issue 1: Pods Not Found
```bash
# Verify pods are running with correct labels
kubectl get pods -n llm-d -l llm-d.ai/inferenceServing=true

# If no pods found, ModelService might not be deployed
kubectl get modelservice -n llm-d
kubectl describe modelservice llama-3-2-1b -n llm-d
```

### Issue 2: Wrong Ports
```bash
# Check what ports are actually open
kubectl exec -n llm-d $DECODE_POD -c vllm -- netstat -tuln | grep LISTEN
kubectl exec -n llm-d $PREFILL_POD -c vllm -- netstat -tuln | grep LISTEN
kubectl exec -n llm-d $EPP_POD -- netstat -tuln | grep LISTEN
```

### Issue 3: ServiceMonitor Not Matching Services
```bash
# Check service labels vs ServiceMonitor selectors
kubectl get services -n llm-d -o yaml | grep -A 10 -B 10 labels
kubectl get servicemonitor llm-d-modelservice-metrics -n llm-d -o yaml | grep -A 5 selector
```

### Issue 4: Prometheus Not Scraping
```bash
# Check Prometheus logs
kubectl logs -n monitoring deployment/prometheus-operator-prometheus -c prometheus

# Check if ServiceMonitor is being recognized
kubectl get servicemonitor -n llm-d -o yaml
```

## 🔧 Manual Metrics Test

### Test Individual Endpoints
```bash
# Port-forward to each pod and test metrics
kubectl port-forward -n llm-d $PREFILL_POD 8000:8000 &
curl http://localhost:8000/metrics | grep prefix_cache

kubectl port-forward -n llm-d $DECODE_POD 8001:8001 &  
curl http://localhost:8001/metrics | grep prefix_cache

kubectl port-forward -n llm-d $EPP_POD 9090:9090 &
curl http://localhost:9090/metrics | head -20
```

### Test Through Services
```bash
# Port-forward to services
kubectl port-forward -n llm-d service/llama-3-2-1b-epp-service 9002:9002 &
curl http://localhost:9002/metrics

# Check headless services
kubectl get services -n llm-d | grep headless
```

## 📊 Grafana Dashboard Debug

### Check Data Sources
1. Go to Grafana → Configuration → Data Sources
2. Verify Prometheus data source is working
3. Test query: `up{namespace="llm-d"}`

### Check Dashboard Queries
1. Go to your LLM-D dashboard
2. Edit a panel showing 0 data
3. Check the query: 
   - `rate(vllm:gpu_prefix_cache_hits_total[5m]) / rate(vllm:gpu_prefix_cache_queries_total[5m])`
4. Try simpler query first: `vllm:gpu_prefix_cache_queries_total`

### Manual Query Test
```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring service/prometheus-operated 9090:9090 &

# Test queries directly
curl -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=vllm:gpu_prefix_cache_queries_total'

curl -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=up{namespace="llm-d"}'
```

## 🎯 Expected Results

### Healthy Metrics Collection:
- **Services**: Should have `llmd.ai/gather-metrics=true` labels
- **Pods**: Should respond to `/metrics` on ports 8000, 8001, 9090
- **ServiceMonitors**: Should show "Up" status in Prometheus targets
- **Grafana**: Should show non-zero values for cache metrics

### Common Metric Names:
- `vllm:gpu_prefix_cache_queries_total`
- `vllm:gpu_prefix_cache_hits_total`
- `vllm:gpu_cache_usage_perc`
- `vllm:time_to_first_token_seconds`
- `vllm:request_success_total`

## 🚀 Quick Fix Commands

If metrics are still not showing up:

```bash
# 1. Redeploy monitoring
kubectl delete -k assets/monitoring/
kubectl apply -k assets/monitoring/

# 2. Restart Prometheus Operator (if needed)
kubectl rollout restart deployment/prometheus-operator -n monitoring

# 3. Force ServiceMonitor refresh
kubectl annotate servicemonitor llm-d-modelservice-metrics -n llm-d \
  refreshed-at=$(date +%s) --overwrite

# 4. Check if pods are actually processing requests
kubectl apply -f assets/load-testing/prefix-cache-test-job.yaml
```

## 📞 Escalation

If metrics still don't appear after following this guide:

1. **Check cluster monitoring setup**: Ensure Prometheus Operator is installed
2. **Verify RBAC**: ServiceMonitors need proper permissions
3. **Check network policies**: Prometheus needs to reach pod metrics endpoints
4. **Validate ModelService**: Ensure it's creating services with correct labels
