# LLM-D Metrics Collection & Monitoring Guide

This document provides comprehensive information about metrics collection, monitoring setup, and troubleshooting for the LLM-D distributed inference framework.

## 📊 Overview

**STATUS**: ✅ **METRICS COLLECTION WORKING SUCCESSFULLY**

The LLM-D deployment includes a complete observability stack with Prometheus metrics collection and Grafana visualization. After recent debugging and configuration fixes, metrics are now being collected properly from all vLLM components.

### Recent Resolution
- **✅ Service Port Mapping**: Fixed decode pod port conflicts (routing proxy:8000, vLLM:8001)
- **✅ ServiceMonitor Configuration**: Proper targeting of services with `llmd.ai/gather-metrics=true`
- **✅ vLLM Metrics**: Successfully collecting from both prefill and decode pods
- **✅ Prefix Cache Metrics**: Cache hit rate monitoring working with `vllm:gpu_prefix_cache_*` metrics
- **✅ Load Testing Integration**: Validated metrics collection with traffic generation

## Monitoring Infrastructure

### Components
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Namespace**: `llm-d-monitoring`

### Access URLs
- **Grafana Dashboard**: `https://grafana-route-llm-d-monitoring.apps.rhoai-cluster.qhxt.p1.openshiftapps.com`
- **Credentials**: admin/admin

## Metrics Collection Architecture

### 1. Prometheus Scraping Configuration

Prometheus is configured with the following scraping jobs:

| Job Name | Target | Port | Purpose |
|----------|--------|------|---------|
| `vllm-instances` | vLLM inference pods | 8000 | Core vLLM engine metrics |
| `gateway-api-inference-extension` | Gateway extension services | 9090 | LLM-D specific inference metrics |
| `llm-d-scheduler` | Scheduler service | metrics | Scheduling and queuing metrics |
| `kubernetes-pods` | Annotated pods | various | Pod-level metrics with prometheus annotations |
| `llm-d-components` | All llm-d pods | various | General component metrics |

### 2. Service Discovery

Prometheus uses Kubernetes service discovery with label-based filtering:
- **vLLM Services**: Labels `llm-d.ai/model` and `llm-d.ai/role`
- **Gateway Extension**: Services matching `*-epp-service` pattern
- **Annotations**: Pods with `prometheus.io/scrape: true`

## Available Metrics

### Core vLLM Engine Metrics

#### System State Gauges
| Metric Name | Type | Description | Unit |
|-------------|------|-------------|------|
| `vllm:num_requests_running` | Gauge | Requests currently running on GPU | count |
| `vllm:num_requests_waiting` | Gauge | Requests waiting to be processed | count |
| `vllm:gpu_cache_usage_perc` | Gauge | GPU KV-cache usage percentage | percent |

#### Latency Metrics (Histograms)
| Metric Name | Type | Description | Unit |
|-------------|------|-------------|------|
| `vllm:time_to_first_token_seconds` | Histogram | Time to generate first token | seconds |
| `vllm:time_per_output_token_seconds` | Histogram | Time per output token generation | seconds |
| `vllm:e2e_request_latency_seconds` | Histogram | End-to-end request latency | seconds |
| `vllm:request_queue_time_seconds` | Histogram | Time spent in WAITING phase | seconds |
| `vllm:request_inference_time_seconds` | Histogram | Time spent in RUNNING phase | seconds |
| `vllm:request_prefill_time_seconds` | Histogram | Time spent in PREFILL phase | seconds |
| `vllm:request_decode_time_seconds` | Histogram | Time spent in DECODE phase | seconds |

#### Throughput Counters
| Metric Name | Type | Description | Unit |
|-------------|------|-------------|------|
| `vllm:prompt_tokens_total` | Counter | Total prefill tokens processed | tokens |
| `vllm:generation_tokens_total` | Counter | Total generation tokens processed | tokens |
| `vllm:request_success_total` | Counter | Successfully processed requests | count |
| `vllm:num_preemptions_total` | Counter | Total preemptions from engine | count |

#### Cache Metrics
| Metric Name | Type | Description | Unit |
|-------------|------|-------------|------|
| `vllm:gpu_prefix_cache_hits_total` | Counter | GPU prefix cache hits | count |
| `vllm:gpu_prefix_cache_queries_total` | Counter | GPU prefix cache queries | count |

### Gateway API Inference Extension Metrics

These metrics are exposed by the Gateway API Inference Extension component but may require active traffic to appear:

| Subsystem | Metric Examples | Description |
|-----------|-----------------|-------------|
| `inference_model` | `inference_model_request_total` | Model-level request metrics |
| `inference_pool` | `inference_pool_average_kv_cache_utilization` | Pool-level resource metrics |
| `inference_extension` | `inference_extension_scheduler_e2e_duration_seconds` | Scheduling performance |

## Grafana Dashboard

### Dashboard Overview
**Name**: LLM Performance Dashboard  
**UID**: `llm-performance`  
**Refresh**: 5 seconds  
**Tags**: llm, vllm, performance, inference

### Dashboard Panels

#### 1. Time to First Token (TTFT)
- **Type**: Time series
- **Metrics**: P50, P95, P99 percentiles
- **Query**: `histogram_quantile(0.xx, rate(vllm:time_to_first_token_seconds_bucket[5m]))`
- **Purpose**: Critical latency metric for user experience

#### 2. Inter-Token Latency
- **Type**: Time series  
- **Metrics**: P50, P95 percentiles
- **Query**: `histogram_quantile(0.xx, rate(vllm:time_per_output_token_seconds_bucket[5m]))`
- **Purpose**: Generation speed and consistency

#### 3. GPU Cache Utilization
- **Type**: Gauge
- **Metric**: `vllm:gpu_cache_usage_perc`
- **Thresholds**: Green (0-70%), Yellow (70-90%), Red (90%+)
- **Purpose**: Memory utilization monitoring

#### 4. KV Cache Hit Rate
- **Type**: Gauge
- **Metric**: `rate(vllm:gpu_prefix_cache_hits_total[5m]) / rate(vllm:gpu_prefix_cache_queries_total[5m])`
- **Thresholds**: Red (0-30%), Yellow (30-60%), Green (60%+)
- **Purpose**: Cache efficiency monitoring

#### 5. Request Queue Status
- **Type**: Time series
- **Metrics**: `vllm:num_requests_running`, `vllm:num_requests_waiting`
- **Purpose**: System load and queuing analysis

#### 6. Request Throughput
- **Type**: Time series
- **Metrics**: Success rate, Total request rate
- **Query**: `rate(vllm:request_success_total[5m])`, `rate(vllm:e2e_request_latency_seconds_count[5m])`
- **Purpose**: System performance and capacity

#### 7. Token Processing Rate
- **Type**: Time series
- **Metrics**: Prompt tokens/sec, Generated tokens/sec
- **Query**: `rate(vllm:prompt_tokens_total[5m])`, `rate(vllm:generation_tokens_total[5m])`
- **Purpose**: Throughput analysis

#### 8. End-to-End Request Latency
- **Type**: Time series
- **Metrics**: P50, P95, P99, Average
- **Query**: `histogram_quantile(0.xx, rate(vllm:e2e_request_latency_seconds_bucket[5m]))`
- **Purpose**: Complete request performance analysis

### Template Variables
- **Model**: Dynamic selection based on available models
- **Query**: `label_values(vllm:num_requests_running, model_name)`

## Alerting Rules

### Configured Alerts

| Alert Name | Condition | Severity | Purpose |
|------------|-----------|----------|---------|
| `HighInferenceLatency` | P95 latency > 10s | Warning | Performance degradation |
| `LowCacheHitRate` | Cache hit rate < 30% | Warning | Efficiency monitoring |
| `GPUMemoryHigh` | GPU memory > 90% | Critical | Resource exhaustion |
| `InferenceQueueLengthHigh` | Queue length > 20 | Warning | System overload |
| `SchedulerUnhealthy` | Scheduler down | Critical | System availability |

## Data Collection Status

### Currently Collecting ✅
- **vLLM Engine Metrics**: Comprehensive latency, throughput, and resource metrics
- **System State**: Queue status, GPU utilization, cache usage
- **Request Lifecycle**: TTFT, inter-token latency, end-to-end timing
- **Cache Performance**: Hit rates, utilization percentages
- **Throughput**: Token processing rates, request success rates

### Partially Available ⚠️
- **Gateway API Extension**: Configured but may require active traffic
- **Scheduler Metrics**: Endpoint configured but health varies
- **Envoy Gateway**: Configured but endpoints may be down

### Not Currently Implemented ❌
- **KV Cache Manager**: No direct Prometheus metrics (metrics available via Gateway Extension)
- **Routing Sidecar**: No Prometheus metrics implementation

## 🏗️ Current Architecture & Port Configuration

### Service Port Mapping (FIXED)

#### Prefill Service
- **Service Port**: `vllm` → 8000 
- **Target**: vLLM container port 8000
- **Metrics URL**: `http://pod-ip:8000/metrics`
- **Status**: ✅ Working

#### Decode Service  
- **Service Port**: `vllm-proxy` → 8000 (routing proxy)
- **Service Port**: `vllm` → 8001 (vLLM direct)
- **Target**: vLLM container port 8001
- **Metrics URL**: `http://pod-ip:8001/metrics` OR `http://pod-ip:8000/metrics` (proxied)
- **Status**: ✅ Working (both endpoints)

#### EPP Service
- **Service Port**: `metrics` → 9090
- **Target**: EPP container port 9090  
- **Metrics URL**: `http://pod-ip:9090/metrics`
- **Status**: ⚠️ 401 Unauthorized (auth issue, non-critical for vLLM metrics)

### Current Prometheus Targets

**Working Targets** ✅:
```
Job: vllm-instances
- http://10.128.6.245:8000/metrics (decode pod)
- http://10.130.6.188:8000/metrics (decode pod)
Health: UP
```

**Issue Targets** ⚠️:
```
Job: gateway-api-inference-extension  
- http://10.128.4.146:9090/metrics (EPP)
Health: DOWN (401 Unauthorized)
```

## 🔍 Debugging  26 Troubleshooting

### Quick Health Check

Run the comprehensive debug script:

```bash
./debug-metrics.sh
```

This script will:
- ✅ Check pod status and readiness
- ✅ Test metrics endpoints directly
- ✅ Verify service configurations
- ✅ Check ServiceMonitor setup
- ✅ Validate Prometheus target discovery

### Manual Verification Steps

#### 1. Check Pod Status
```bash
kubectl get pods -n llm-d -l llm-d.ai/inferenceServing=true

# Expected output:
# NAME                                     READY   STATUS    RESTARTS   AGE
# llama-3-2-1b-decode-67c74fdb5b-dbh7p     2/2     Running   0          10m
# llama-3-2-1b-prefill-b66bcc88-5zkt7      1/1     Running   0          10m
```

#### 2. Test Metrics Endpoints
```bash
# Get pod names
PREFILL_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=prefill -o jsonpath='{.items[0].metadata.name}')
DECODE_POD=$(kubectl get pods -n llm-d -l llm-d.ai/role=decode -o jsonpath='{.items[0].metadata.name}')

# Test prefill metrics
kubectl exec -n llm-d $PREFILL_POD -c vllm -- curl -s http://localhost:8000/metrics | head -5

# Test decode metrics (direct vLLM)
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | head -5

# Test decode metrics (via proxy)  
kubectl exec -n llm-d $DECODE_POD -c routing-proxy -- curl -s http://localhost:8000/metrics | head -5
```

#### 3. Check Prometheus Targets
```bash
# Port-forward to Prometheus (correct namespace!)
kubectl port-forward -n llm-d-monitoring svc/prometheus 9090:9090  26

# Check active targets
curl -s 'http://localhost:9090/api/v1/targets' | jq -r '.data.activeTargets[] | select(.labels.job == "vllm-instances") | {health: .health, scrapeUrl: .scrapeUrl}'
```

#### 4. Validate Metrics Collection
```bash
# Test cache queries (should be  3e 0 after load testing)
curl -s 'http://localhost:9090/api/v1/query?query=vllm:gpu_prefix_cache_queries_total' | jq '.data.result[].value[1]'

# Test cache hit rate calculation
curl -s 'http://localhost:9090/api/v1/query?query=rate(vllm:gpu_prefix_cache_hits_total[5m])%20/%20rate(vllm:gpu_prefix_cache_queries_total[5m])' | jq '.data.result'

# Test request rate
curl -s 'http://localhost:9090/api/v1/query?query=rate(vllm:request_success_total[5m])' | jq '.data.result[].value[1]'
```

### Load Testing for Metrics Validation

#### Generate Test Traffic
```bash
# Apply load test job
kubectl apply -f assets/load-testing/prefix-cache-test-job.yaml

# Monitor job progress
kubectl logs -f job/prefix-cache-test -n llm-d

# Verify metrics after test
kubectl exec -n llm-d $DECODE_POD -c vllm -- curl -s http://localhost:8001/metrics | grep prefix_cache_queries_total
```

#### Expected Results After Load Testing
```bash
# Cache queries should be  3e 0
vllm:gpu_prefix_cache_queries_total{...} 60

# Cache hits may be 0 initially (normal)
vllm:gpu_prefix_cache_hits_total{...} 0

# Request success should be  3e 0
vllm:request_success_total{...} 60
```

### Common Issues  26 Solutions

#### Issue: No Metrics in Grafana
**Symptoms**: Dashboards show "No data" or empty graphs

**Diagnosis**:
```bash
# Check if Prometheus is running in correct namespace
kubectl get pods -n llm-d-monitoring -l app=prometheus

# Check if targets are being scraped
kubectl port-forward -n llm-d-monitoring svc/prometheus 9090:9090
# Visit http://localhost:9090/targets
```

**Solution**: Ensure ServiceMonitors are correctly configured and services have required labels

#### Issue: Prefill Metrics Missing
**Symptoms**: Only decode pod metrics visible, no prefill data

**Diagnosis**: 
```bash
# Check if prefill service exists and has correct labels
kubectl get service llama-3-2-1b-service-prefill -n llm-d --show-labels

# Check if prefill pod is ready
kubectl get pods -n llm-d -l llm-d.ai/role=prefill
```

**Solution**: This is a known timing issue with service discovery. Prefill metrics should appear automatically.

#### Issue: Cache Hit Rate Always 0%
**Symptoms**: `vllm:gpu_prefix_cache_hits_total` remains 0 despite queries

**Diagnosis**:
```bash
# Check if prefix caching is enabled
kubectl exec -n llm-d $DECODE_POD -c vllm -- ps aux | grep vllm
# Look for --enable-prefix-caching flag

# Check cache-related logs
kubectl logs -n llm-d $DECODE_POD -c vllm | grep -i cache
```

**Solution**: 
1. ✅ Prefix caching is enabled in current deployment
2. Cache hits require repeated requests with shared prefixes
3. Run multiple load tests to build up cache

#### Issue: EPP Metrics 401 Unauthorized
**Symptoms**: EPP metrics endpoint returns authentication error

**Status**: Known issue, non-critical for vLLM metrics

**Workaround**: Focus on vLLM metrics; EPP auth can be resolved separately

### Troubleshooting Commands

```bash
# Overall system status
kubectl get pods,svc,servicemonitors,podmonitors -n llm-d

# Check ServiceMonitor configuration
kubectl describe servicemonitor llm-d-operator-modelservice-monitor -n llm-d

# Check service labels (critical for discovery)
kubectl get svc -n llm-d -l llmd.ai/gather-metrics=true --show-labels

# Monitor resource usage
kubectl top pods -n llm-d

# Check Prometheus config reload
kubectl logs -n llm-d-monitoring deployment/prometheus
```

## Future Enhancements

### Planned Improvements
- **Energy Consumption Metrics**: GPU power usage tracking
- **Model-Specific Dashboards**: Per-model performance analysis  
- **Custom Alerts**: Business-specific SLA monitoring
- **Integration Metrics**: Gateway API Extension comprehensive coverage
- **Multi-Cluster Support**: Federated monitoring setup

### Metric Expansion
- **Routing Sidecar Metrics**: Request routing latency and success rates
- **KV Cache Manager**: Direct metrics implementation
- **Resource Utilization**: CPU, memory, network metrics per component
- **Business Metrics**: Cost per token, accuracy measurements

---

**Last Updated**: `date`  
**Version**: 1.0  
**Maintained By**: LLM-D Operations Team
