# LLM-D Monitoring Stack

This directory contains example monitoring configuration you can adapt for your cluster. It is not required for the 0.2.0 demo and versions may differ from your environment.

## 📊 **What's Deployed**
- **Grafana Dashboard Stack** (optional)
- **LLM-D Performance Dashboard**: Cache hit rate and stickiness examples
- **Real-time Metrics**: TTFT, cache hit rates, per-pod performance tracking
- **Automatic Provisioning**: Example dashboards and datasources
- **Automatic Provisioning**: Dashboards and datasources auto-configured

### **Prometheus Monitoring**
- **Prometheus**: Metrics collection (version flexible)
- **Comprehensive Scraping**: vLLM instances, EPP pods, Kubernetes components
- **Alerting Rules**: Example performance and availability alerts
- **Retention**: Configure to your environment needs

## 🚀 **Quick Deployment**

### **Deploy Complete Stack**
```bash
# Deploy Grafana and Prometheus (optional)
kubectl create namespace llm-d-monitoring || true
kubectl apply -f monitoring/grafana.yaml
kubectl apply -f monitoring/grafana-service.yaml
kubectl apply -f monitoring/prometheus.yaml
kubectl apply -f monitoring/grafana-datasources.yaml
kubectl apply -f monitoring/grafana-dashboards-config.yaml
kubectl apply -f monitoring/grafana-config.yaml
kubectl apply -f monitoring/prometheus-config.yaml
kubectl create configmap grafana-dashboard-llm-performance --from-file=monitoring/grafana-dashboard-llm-performance.json -n  llm-d-monitoring --dry-run=client -o yaml | oc replace -f -
```

### **Access Dashboards**
```bash
# Get Grafana URL
kubectl get route grafana-secure -n llm-d-monitoring
# Default login (if configured): admin / admin

# Get Prometheus URL (if needed)
kubectl port-forward svc/prometheus 9090:9090 -n llm-d-monitoring
```

## 📈 **Dashboard Features**

### **Time to First Token (TTFT)**
- **P50, P95, P99 percentiles** - Complete latency distribution
- **Real-time tracking** - 5-second refresh intervals  
- **Threshold indicators** - Green/Yellow/Red status alerts
- **Performance baselines** - Track improvements over time

### **KV Cache Performance**
- **Overall Hit Rate Gauge** - System-wide cache efficiency (target: >60%)
- **Per-Pod Breakdown** - Individual decode pod performance
- **Traffic Distribution** - Session affinity visualization
- **Cache Effectiveness** - Red/Yellow/Green threshold indicators

### **System Health Monitoring**
- **Request Queue Status** - Running vs waiting requests
- **GPU Memory Utilization** - Resource usage tracking  
- **Throughput Metrics** - Success rates and token processing
- **Pod-Level Metrics** - Individual instance performance

## 🔧 **Configuration Details**

### **Grafana Configuration**
```yaml
# Key Components:
- ServiceAccount: grafana
- Config: Anonymous viewer access, admin/admin credentials
- Datasource: Prometheus at http://prometheus:9090
- Dashboard: LLM-D Performance with 9 panels
- Route: TLS-enabled external access
```

### **Prometheus Configuration**  
```yaml
# Scrape Jobs:
- vllm-instances: Port 8000 metrics from decode/prefill pods
- gateway-api-inference-extension: EPP metrics on port 9090
- kubernetes-pods: General pod discovery in llm-d namespace
- llm-d-scheduler: Scheduler health and performance
```

### **Network Access**
- **Grafana**: External route with TLS termination
- **Prometheus**: Internal service, port-forward for access
- **Metrics Collection**: Automatic service discovery across llm-d namespace

## 🎯 **Key Metrics Tracked**

### **Performance Metrics**
| Metric | Description | Target |
|--------|-------------|---------|
| `vllm:time_to_first_token_seconds` | TTFT latency distribution | <500ms P95 |
| `vllm:gpu_prefix_cache_hits_total` | Cache hit count | >60% hit rate |
| `vllm:num_requests_running` | Active request load | Monitor capacity |
| `vllm:e2e_request_latency_seconds` | Complete request timing | <5s P95 |

### **Cache-Aware Routing Metrics**
- **Cache Hit Rate**: `sum(vllm:gpu_prefix_cache_hits_total) / sum(vllm:gpu_prefix_cache_queries_total)`
- **Per-Pod Efficiency**: Individual pod cache performance
- **Session Stickiness**: Traffic concentration analysis
- **Routing Effectiveness**: EPP decision quality tracking

### **Alert Rules**
```yaml
- HighInferenceLatency: P95 > 10 seconds
- LowCacheHitRate: <30% cache efficiency  
- GPUMemoryHigh: >90% memory utilization
- InferenceQueueLengthHigh: >20 queued requests
- SchedulerUnhealthy: EPP/scheduler down
```

## 🔍 **Troubleshooting**

### **Dashboard Not Loading**
```bash
# Check Grafana pod status
kubectl get pods -n llm-d-monitoring -l app=grafana

# Check configmaps
kubectl get configmaps -n llm-d-monitoring

# Restart Grafana if needed
kubectl rollout restart deployment/grafana -n llm-d-monitoring
```

### **Missing Metrics**
```bash
# Verify Prometheus targets
kubectl port-forward svc/prometheus 9090:9090 -n llm-d-monitoring
# Visit http://localhost:9090/targets

# Check vLLM pod metrics endpoints
kubectl get pods -n llm-d -l llm-d.ai/role=decode
kubectl exec <pod-name> -n llm-d -c vllm -- curl localhost:8001/metrics
```

### **Cache Hit Rate Issues**
```bash
# Verify EPP is running
kubectl get pods -n llm-d -l llm-d.ai/epp

# Check EPP logs for routing decisions
kubectl logs -f <epp-pod> -n llm-d

# Verify Redis connectivity (if using cache-aware routing)
kubectl exec <epp-pod> -n llm-d -- nc -zv llm-d-operator-redis-master 6379
```

## 📚 **Production Usage**

### **Performance Analysis**
- Monitor cache hit rates during traffic patterns
- Identify optimal session stickiness configurations  
- Track TTFT improvements from routing optimizations
- Analyze per-pod load distribution

### **Capacity Planning**
- GPU memory utilization trends
- Request queue depth patterns
- Throughput scaling characteristics
- Cache efficiency at different loads

### **Operational Health**
- Alert on performance degradation
- Monitor component availability  
- Track resource utilization trends
- Validate SLA compliance

---

## ✅ **Cluster Synchronization Status**

This monitoring configuration is **synchronized with the live cluster** and includes:

- ✅ **Exact dashboard JSON** from the deployed ConfigMap
- ✅ **Complete Prometheus scrape config** with all job definitions
- ✅ **Production RBAC permissions** for metrics collection
- ✅ **OpenShift route configuration** for external access
- ✅ **Resource specifications** matching deployed containers

**Last Synchronized**: August 7, 2025 - Cluster: `rhoai-cluster.qhxt.p1.openshiftapps.com`
