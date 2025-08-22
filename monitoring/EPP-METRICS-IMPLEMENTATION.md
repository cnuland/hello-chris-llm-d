# LLM-D EPP Metrics Implementation Guide

## 📊 Current Status & Issues

### EPP Metrics Discovery
- **EPP Service**: `llm-d-gaie-epp.llm-d.svc.cluster.local:9090`
- **Status**: Metrics endpoint is running but has authorization enabled
- **Issue**: Controller-runtime metrics server requires authentication even with `--secureServing=false`

### Available Metrics (Expected)
Based on the EPP implementation and logs, the following metrics should be available:

```prometheus
# EPP Core Metrics (controller-runtime standard metrics)
go_memstats_alloc_bytes
go_memstats_heap_objects
go_goroutines
process_cpu_seconds_total
process_open_fds
process_resident_memory_bytes

# EPP Custom Metrics (LLM-D specific)
epp_requests_total{method="", status=""}
epp_request_duration_seconds_bucket{method="", le=""}
epp_cache_hits_total{backend=""}
epp_cache_requests_total{backend=""}
epp_routing_decisions_total{decision_type=""}
epp_backend_health{backend="", state=""}
epp_pods_discovered{namespace="", label_selector=""}
```

## 🔧 Implementation Solutions

### Solution 1: Fix EPP Authorization (Recommended)

Since the current EPP deployment has authorization issues, we need to either:

**Option A: Create proper RBAC for metrics access**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metrics-reader
rules:
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: epp-metrics-access
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metrics-reader
subjects:
- kind: ServiceAccount
  name: llm-d-gaie-epp
  namespace: llm-d
- kind: ServiceAccount
  name: prometheus
  namespace: llm-d-monitoring
```

**Option B: Deploy EPP without controller-runtime security (Demo)**
Add to the EPP deployment args:
```yaml
- --metrics-bind-address=0.0.0.0:9090
- --health-probe-bind-address=0.0.0.0:8080
- --disable-auth=true  # If supported
```

### Solution 2: ServiceMonitor Configuration

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: llm-d-epp-metrics
  namespace: llm-d-monitoring
spec:
  namespaceSelector:
    matchNames:
    - llm-d
  selector:
    matchLabels:
      app: llm-d-gaie-epp
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
    scheme: http
    # For authorization issues, you might need:
    bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    tlsConfig:
      insecureSkipVerify: true
```

### Solution 3: Manual Prometheus Scrape Configuration

Add to prometheus.yaml:
```yaml
scrape_configs:
- job_name: 'llm-d-epp'
  kubernetes_sd_configs:
  - role: endpoints
    namespaces:
      names:
      - llm-d
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_name]
    action: keep
    regex: llm-d-gaie-epp
  - source_labels: [__meta_kubernetes_endpoint_port_name]
    action: keep
    regex: metrics
  - source_labels: [__meta_kubernetes_namespace]
    target_label: namespace
  - source_labels: [__meta_kubernetes_service_name]
    target_label: service
```

## 🎯 Key Metrics to Monitor

### 1. Request Performance
- **`epp_requests_total`**: Total requests processed by EPP
- **`epp_request_duration_seconds`**: EPP response time histograms
- **Rate**: `rate(epp_requests_total[5m])` - Requests per second

### 2. Cache Intelligence
- **`epp_cache_hits_total`**: Cache-aware routing successes
- **`epp_cache_requests_total`**: Total cache lookup requests
- **Hit Rate**: `(rate(epp_cache_hits_total[5m]) / rate(epp_cache_requests_total[5m])) * 100`

### 3. Routing Decisions
- **`epp_routing_decisions_total{decision_type=""}`**: Breakdown of routing logic
  - `decision_type="cache_hit"` - Routed based on cache
  - `decision_type="load_balance"` - Load-based routing
  - `decision_type="health_check"` - Health-based routing

### 4. Backend Discovery
- **`epp_backend_health`**: Health status of discovered decode pods
- **`epp_pods_discovered`**: Number of pods discovered by label selector

## 📈 Grafana Dashboard Setup

### Panel Suggestions

1. **EPP Request Rate**
   ```promql
   rate(epp_requests_total{job="llm-d-epp-metrics"}[5m])
   ```

2. **EPP Response Time (95th percentile)**
   ```promql
   histogram_quantile(0.95, rate(epp_request_duration_seconds_bucket{job="llm-d-epp-metrics"}[5m])) * 1000
   ```

3. **Cache Hit Rate**
   ```promql
   (rate(epp_cache_hits_total{job="llm-d-epp-metrics"}[5m]) / rate(epp_cache_requests_total{job="llm-d-epp-metrics"}[5m])) * 100
   ```

4. **Routing Decision Breakdown**
   ```promql
   increase(epp_routing_decisions_total{job="llm-d-epp-metrics"}[5m])
   ```

5. **Backend Health Status**
   ```promql
   epp_backend_health{job="llm-d-epp-metrics"}
   ```

## 🔄 Integration with Existing Monitoring

### Update Existing Prometheus Configuration

1. **Add EPP service discovery to existing prometheus.yaml**:
   ```yaml
   - job_name: 'llm-d-epp'
     static_configs:
     - targets: ['llm-d-gaie-epp.llm-d.svc.cluster.local:9090']
     metrics_path: /metrics
     scrape_interval: 30s
   ```

2. **Add EPP metrics to existing dashboard**:
   - Import the `grafana-dashboard-llm-d-epp.json` 
   - Or add EPP panels to existing LLM performance dashboard

### Alerting Rules

```yaml
groups:
- name: llm-d-epp
  rules:
  - alert: EPPHighLatency
    expr: histogram_quantile(0.95, rate(epp_request_duration_seconds_bucket[5m])) > 0.1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "EPP response time is high"
      description: "EPP 95th percentile latency is {{ $value }}s"

  - alert: EPPCacheHitRateLow
    expr: (rate(epp_cache_hits_total[5m]) / rate(epp_cache_requests_total[5m])) < 0.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "EPP cache hit rate is low"
      description: "Cache hit rate is {{ $value | humanizePercentage }}"

  - alert: EPPNoHealthyBackends
    expr: sum(epp_backend_health) == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "No healthy backends discovered by EPP"
```

## 🚀 Quick Start Commands

1. **Apply RBAC for metrics access**:
   ```bash
   kubectl apply -f monitoring/llm-d-servicemonitor.yaml
   ```

2. **Import Grafana dashboard**:
   ```bash
   # Copy the dashboard JSON to your Grafana instance
   # Or use the API:
   curl -X POST -H "Content-Type: application/json" \
     -d @monitoring/grafana-dashboard-llm-d-epp.json \
     http://grafana.llm-d-monitoring.svc.cluster.local:3000/api/dashboards/db
   ```

3. **Verify metrics are being scraped**:
   ```bash
   # Check if Prometheus can access EPP metrics
   kubectl port-forward -n llm-d-monitoring svc/prometheus 9090:9090 &
   curl "http://localhost:9090/api/v1/query?query=up{job='llm-d-epp-metrics'}"
   ```

## 🔍 Troubleshooting

### Common Issues

1. **"Unauthorized" errors**: Apply the RBAC configuration above
2. **No metrics scraped**: Check ServiceMonitor selector matches service labels
3. **Empty dashboards**: Verify metric names match actual EPP implementation

### Debugging Commands

```bash
# Check EPP service labels
kubectl get svc -n llm-d llm-d-gaie-epp -o yaml

# Check ServiceMonitor is created
kubectl get servicemonitor -n llm-d-monitoring

# Check Prometheus targets
kubectl logs -n llm-d-monitoring deployment/prometheus
```

## 🎯 Expected Benefits

With proper EPP metrics monitoring:

- **Cache Performance Visibility**: Track 87.4%+ cache hit rates
- **Routing Intelligence**: Monitor decision-making effectiveness
- **Performance Optimization**: Identify EPP latency bottlenecks
- **Proactive Alerting**: Get notified when cache performance degrades
- **Backend Health**: Monitor decode pod discovery and health

This monitoring setup will provide complete visibility into the cache-aware routing intelligence that makes LLM-D achieve its impressive performance metrics.
