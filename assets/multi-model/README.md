# Multi-Model Load Balancing Demo Setup

This directory contains configurations to deploy a second model (Llama-3.2-3B) alongside the existing Llama-3.2-1B model to demonstrate LLM-D's multi-model load balancing and gateway routing capabilities.

## GPU Resource Requirements

- **Llama-3.2-1B**: 1 GPU (already deployed)
- **Llama-3.2-3B**: 2 GPUs (new deployment)
- **Total Required**: 3 GPUs out of 24 available ✅

## Deployment

```bash
# Deploy the 3B model
oc apply -k assets/multi-model/

# Wait for the model to be ready
oc get pods -n llm-d -w | grep llama-3-2-3b

# Check deployment status
oc get modelservice -n llm-d
oc get httproute -n llm-d
```

## Demo Scenarios

### 1. **Path-Based Model Routing**
- **1B Model**: `https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/1b/chat/completions`
- **3B Model**: `https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/3b/chat/completions`

### 2. **A/B Traffic Splitting (70/30)**
- **Endpoint**: `https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/ab-test/chat/completions`
- **Traffic Distribution**: 70% → 1B model, 30% → 3B model

### 3. **Load Test Both Models**
```bash
# Test 1B model
curl -X POST "https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/1b/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model": "llama-3-2-1b", "messages": [{"role": "user", "content": "Hello from 1B model!"}]}'

# Test 3B model  
curl -X POST "https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/3b/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{"model": "llama-3-2-3b", "messages": [{"role": "user", "content": "Hello from 3B model!"}]}'

# Test A/B split
for i in {1..10}; do
  curl -X POST "https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/ab-test/chat/completions" \
    -H "Content-Type: application/json" \
    -d '{"model": "auto", "messages": [{"role": "user", "content": "Test A/B routing #'$i'"}]}'
done
```

## Monitoring & Observability

### Gateway Metrics to Highlight:
- **Request distribution** across models
- **Response latencies** comparison (1B vs 3B)
- **GPU utilization** per model
- **Cache hit rates** per model
- **Traffic splitting** effectiveness

### Grafana Dashboards:
1. **Gateway Traffic Distribution**
2. **Multi-Model Performance Comparison** 
3. **Resource Utilization by Model**
4. **A/B Test Traffic Analysis**

## Demo Key Points

1. **Intelligent Routing**: Requests automatically routed to appropriate model based on path
2. **Performance Trade-offs**: 1B model = faster, 3B model = higher quality
3. **Resource Efficiency**: Different GPU allocations per model size
4. **A/B Testing**: Live traffic splitting for model comparison
5. **Unified Gateway**: Single endpoint managing multiple models
6. **Independent Scaling**: Each model can scale independently
7. **Cache Sharing**: Prefix cache benefits across models when applicable

## Expected Results

- **1B Model**: ~50-100ms latency, high throughput
- **3B Model**: ~100-200ms latency, better quality responses  
- **Gateway**: Sub-10ms routing overhead
- **A/B Split**: Verifiable 70/30 traffic distribution in metrics
