# Metrics and Monitoring

## Overview

The KV-Cache Aware Routing system provides comprehensive metrics through Prometheus integration, enabling real-time monitoring of cache performance, request patterns, and system health.

## Metrics Collection

### ServiceMonitor Configuration

The system uses the existing `vllm-metrics` ServiceMonitor for metrics collection:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vllm-metrics
  namespace: llm-d
spec:
  selector:
    matchLabels:
      llmd.ai/gather-metrics: "true"
  endpoints:
  - port: vllm
    path: /metrics
    interval: 30s
```

### Key Metrics

#### Cache Performance Metrics
- **`vllm:cache_config_info`**: Cache configuration details
- **`vllm:cache_usage_percent`**: Current cache utilization percentage
- **`vllm:num_requests_running`**: Active requests being processed
- **`vllm:num_requests_waiting`**: Queued requests waiting for processing

#### KV-Cache Specific Metrics
- **Cache Queries**: Total number of cache lookup operations
- **Cache Hits**: Number of successful cache retrievals
- **Cache Hit Rate**: Calculated as `hits/queries * 100`

#### Request Metrics
- **Request Latency**: Time taken to process requests
- **Throughput**: Requests processed per second
- **Token Generation Rate**: Tokens generated per second

## Accessing Metrics

### Direct Pod Access
```bash
# Access metrics from a specific pod
kubectl exec -it <pod-name> -n llm-d -c vllm -- curl localhost:8001/metrics

# Example for cache metrics
kubectl exec -it llama-3-2-1b-decode-67cb95968f-289qk -n llm-d -c vllm -- \
  curl -s localhost:8001/metrics | grep -E "(cache|hit|query)"
```

### Via Prometheus Query

Access metrics through Prometheus UI or API:
```promql
# Cache hit rate calculation
(sum(rate(vllm_cache_hits_total[5m])) / sum(rate(vllm_cache_queries_total[5m]))) * 100

# Per-pod cache hit rate
(rate(vllm_cache_hits_total[5m]) / rate(vllm_cache_queries_total[5m])) * 100
```

## Cache Performance Monitoring

### Real-time Monitoring Script

The system includes automated cache performance testing via Tekton pipelines:

```bash
# Run cache performance test
tkn pipeline start cache-hit-pipeline -n llm-d --use-param-defaults --showlog
```

### Manual Cache Testing

For manual cache testing:

```bash
# Run the cache test script
./cache-test.sh
```

This script:
1. Restarts pods for fresh metrics
2. Sends identical requests to test caching
3. Measures cache hit rates
4. Reports per-pod performance

## Metrics Analysis

### Expected Performance Baselines

#### Production Targets
- **Cache Hit Rate**: 80%+ (current achievement)
- **Request Latency**: <500ms for cached responses
- **GPU Memory Utilization**: 85-95%
- **Session Stickiness**: 100% (all session requests to same pod)

#### Warning Thresholds
- Cache hit rate < 70%
- High cache eviction rates
- Uneven traffic distribution across pods
- Memory utilization > 95%

### Troubleshooting with Metrics

#### Low Cache Hit Rate
1. Check cache configuration parameters
2. Verify session affinity is working
3. Analyze request patterns for cache-unfriendly workloads
4. Monitor cache eviction metrics

#### Poor Session Affinity
1. Verify service configuration
2. Check client IP persistence
3. Monitor request distribution across pods
4. Validate HTTPRoute configuration

## Alerting Setup

### Recommended Prometheus Rules

```yaml
groups:
- name: kv-cache-alerts
  rules:
  - alert: LowCacheHitRate
    expr: (sum(rate(vllm_cache_hits_total[10m])) / sum(rate(vllm_cache_queries_total[10m]))) * 100 < 70
    for: 5m
    annotations:
      summary: "KV-Cache hit rate below threshold"
      description: "Cache hit rate is {{ $value }}%, below 70% threshold"

  - alert: HighCacheEviction
    expr: rate(vllm_cache_evictions_total[5m]) > 10
    for: 2m
    annotations:
      summary: "High cache eviction rate detected"
      description: "Cache eviction rate is {{ $value }} evictions/sec"
```

## Dashboard Integration

### Grafana Dashboard Queries

Key queries for Grafana dashboards:

```promql
# Cache Hit Rate
(sum(rate(vllm_cache_hits_total[5m])) / sum(rate(vllm_cache_queries_total[5m]))) * 100

# Request Throughput
sum(rate(vllm_requests_total[5m]))

# Average Response Time
avg(vllm_request_duration_seconds)

# GPU Memory Usage
avg(vllm_gpu_memory_usage_percent)

# Per-Pod Traffic Distribution
sum(rate(vllm_requests_total[5m])) by (pod)
```

## Testing and Validation

### Automated Testing

The Tekton pipeline provides automated validation:
- Restarts pods for clean metrics
- Sends test workloads
- Measures performance
- Reports detailed results

### Manual Validation Commands

```bash
# Check current cache metrics
kubectl exec -it $(kubectl get pods -n llm-d -l app=llama-3-2-1b-decode -o jsonpath='{.items[0].metadata.name}') -n llm-d -c vllm -- \
  curl -s localhost:8001/metrics | grep -E "(cache|hit)"

# Test session affinity
for i in {1..5}; do
  curl -H "X-Session-ID: test-123" \
    https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions \
    -d '{"model":"meta-llama/Llama-3.2-1B","prompt":"Hello","max_tokens":5}'
done
```
