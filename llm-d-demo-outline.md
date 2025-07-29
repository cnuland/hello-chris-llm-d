# llm-d Demo: Kubernetes-Native Distributed LLM Inference

## Demo Overview

This demo showcases llm-d, a Kubernetes-native high-performance distributed LLM inference framework that leverages the latest distributed inference optimizations like KV-cache aware routing and disaggregated serving, integrated with the Kubernetes operational tooling through Inference Gateway (IGW).

## Demo Architecture

```
Frontend (React/Gradio) → Envoy Gateway → llm-d Inference Scheduler → vLLM Model Servers
                                     ↓
                              Monitoring & Observability
                              (Prometheus, Grafana, Jaeger)
```

## Key Features to Demonstrate

### 1. Distributed Inference Architecture
- **Prefill/Decode Disaggregation**: Show how llm-d separates compute-bound prefill and memory-bound decode phases
- **KV-Cache Aware Routing**: Demonstrate intelligent routing based on cached computations
- **Multi-Tenant Performance**: Show concurrent workloads with different QoS requirements

### 2. Advanced Load Balancing
- **Prefix-Cache Aware Scheduling**: Route requests to instances with relevant cached data
- **Load-Aware Balancing**: Dynamic routing based on real-time GPU utilization
- **Request Shape Optimization**: Handle varying input/output token patterns efficiently

### 3. Kubernetes Integration
- **Gateway API Extensions**: Leverage Inference Gateway for intelligent routing
- **Auto-scaling**: Demonstrate traffic and hardware-aware scaling
- **Resource Management**: Show GPU memory optimization and allocation

## Demo Components

### A. Frontend Application (Enhanced from existing demo)
**Base**: Use frontend from `rh-aiservices-bu/rhai-agentic-demo`
**Enhancements**:
- **Multi-Model Interface**: Support for multiple model endpoints
- **Request Tracing Visualization**: Show request flow through the system
- **Performance Metrics Dashboard**: Real-time latency, throughput, and cache hit rates
- **Workload Type Selector**: RAG, Code Completion, Chat, Batch Processing modes
- **QoS Priority Controls**: Interactive vs. Batch request prioritization

### B. llm-d Inference Scheduler Visualization
**Real-time Dashboard showing**:
- **Request Routing Decisions**: Visual flow of requests to optimal instances
- **Cache Hit/Miss Ratios**: KV-cache utilization across instances
- **GPU Memory Utilization**: Per-instance memory usage and availability
- **Prefill vs. Decode Load**: Separate workload visualization
- **Response Time Distribution**: Latency patterns across different request types

### C. Envoy Gateway Features Demonstration

#### 1. Traffic Management Visualization
```yaml
# Gateway Configuration Display
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: llm-inference-gateway
spec:
  gatewayClassName: envoy-gateway
  listeners:
  - name: inference-http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
```

**Visual Elements**:
- **Route Mapping**: Show HTTP routes to different model endpoints
- **Load Balancing Strategies**: Round-robin vs. llm-d intelligent routing comparison
- **Rate Limiting**: Demonstrate per-user/tenant request limits
- **Circuit Breaker**: Show failure handling and fallback mechanisms

#### 2. Security Features
**Visualizations**:
- **Authentication Flow**: JWT token validation and user identification
- **Authorization Policies**: RBAC for different model access levels
- **TLS Termination**: Secure connection handling
- **Request/Response Filtering**: Security header injection and validation

#### 3. Observability Integration
**Metrics Collection**:
- **Request Tracing**: Jaeger integration showing distributed traces
- **Prometheus Metrics**: Custom inference-specific metrics
- **Grafana Dashboards**: Real-time performance visualization
- **Alert Manager**: Threshold-based alerting for SLA violations

### D. Model Server Pool Management
**Deployment Configurations**:
- **Standard vLLM Instances**: Baseline performance comparison
- **Disaggregated Prefill/Decode**: Specialized instance types
- **Cache-Optimized Instances**: High memory configurations for prefix caching
- **Heterogeneous Hardware**: Different GPU types (H100, A100, L4)

## Demo Scenarios

### Scenario 1: Cache-Aware Routing Performance
**Setup**: 
- Deploy 4 vLLM instances with llm-d scheduler
- Configure prefix caching for common prompts
- Compare with standard Kubernetes Service routing

**Demonstration**:
1. **Cold Start**: Show initial request latency without cache
2. **Cache Population**: Demonstrate progressive cache building
3. **Cache Hits**: Show dramatic latency reduction for cached prefixes
4. **Performance Comparison**: Side-by-side metrics vs. round-robin routing

**Metrics to Highlight**:
- Time to First Token (TTFT): Up to 3x improvement
- Cache Hit Ratio: Progressive improvement over time
- Overall Throughput: Sustained higher QPS under SLO constraints

### Scenario 2: Prefill/Decode Disaggregation
**Setup**:
- Configure separate prefill and decode instance pools
- Deploy workloads with different input/output patterns (RAG vs. Reasoning)

**Demonstration**:
1. **Workload Characteristics**: Show different request patterns
2. **Resource Utilization**: GPU compute vs. memory bandwidth usage
3. **Specialized Scheduling**: Route prefill-heavy vs. decode-heavy requests
4. **Performance Gains**: Demonstrate improved throughput per GPU

**Visual Elements**:
- **Request Flow Diagram**: Prefill → KV Transfer → Decode phases
- **Resource Utilization Charts**: Specialized instance efficiency
- **Latency Breakdown**: Phase-specific timing analysis

### Scenario 3: Multi-Tenant QoS Management
**Setup**:
- Configure different service tiers (Interactive, Standard, Batch)
- Deploy mixed workload types with varying latency requirements

**Demonstration**:
1. **Priority Routing**: Show high-priority requests bypassing queues
2. **Resource Isolation**: Guarantee resources for critical workloads
3. **Fair Sharing**: Demonstrate balanced resource allocation
4. **SLA Compliance**: Track and visualize SLA adherence

**Metrics Dashboard**:
- **Per-Tenant Latency**: P95/P99 latency by service tier
- **Queue Depths**: Priority-based queue management
- **Resource Allocation**: CPU/GPU/Memory usage by tenant
- **SLA Violations**: Real-time compliance monitoring

### Scenario 4: Auto-scaling and Resource Optimization
**Setup**:
- Configure HPA based on custom inference metrics
- Deploy variable traffic patterns

**Demonstration**:
1. **Traffic Surge Handling**: Show automatic scale-up
2. **Smart Scaling**: Scale prefill vs. decode instances independently
3. **Cost Optimization**: Scale down during low traffic
4. **Hardware Heterogeneity**: Show different GPU types being utilized

## Visualization Components

### 1. Real-time Performance Dashboard
**Panels**:
- **System Overview**: Cluster health, active instances, total throughput
- **Request Flow**: Live visualization of request routing decisions
- **Cache Performance**: Hit ratios, cache size, eviction rates
- **Resource Utilization**: GPU memory, compute, network bandwidth
- **Latency Heatmaps**: Response time distribution across instances

### 2. Envoy Gateway Control Plane
**Interface Elements**:
- **Route Configuration**: Visual route table with traffic percentages
- **Security Policies**: Active authentication and authorization rules
- **Rate Limiting**: Current limits and usage per client
- **Health Checks**: Instance health status and circuit breaker states

### 3. llm-d Scheduler Insights
**Visualizations**:
- **Scoring Algorithm**: Show how instances are ranked for requests
- **Cache Topology**: Visual representation of shared cache relationships
- **Load Prediction**: ML-based load forecasting and instance planning
- **Optimization Recommendations**: Suggested configuration improvements

### 4. Cost and Efficiency Analytics
**Metrics**:
- **Cost per Token**: Real-time cost analysis across different configurations
- **GPU Utilization**: Efficiency metrics and optimization opportunities
- **Energy Consumption**: Power usage and carbon footprint tracking
- **ROI Analysis**: Performance gains vs. infrastructure costs

## Technical Implementation Details

### Frontend Enhancements
```javascript
// Real-time metrics integration
const metricsWebSocket = new WebSocket('ws://gateway/metrics');
const tracingIntegration = new Jaeger({
  serviceName: 'llm-d-demo-frontend'
});

// Multi-model request handling
const modelEndpoints = {
  'llama-3.1-8b': '/v1/chat/completions',
  'llama-3.1-70b': '/v1/chat/completions',
  'code-llama': '/v1/code/completions'
};
```

### Monitoring Stack Configuration
```yaml
# Prometheus ServiceMonitor for llm-d metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: llm-d-metrics
spec:
  selector:
    matchLabels:
      app: llm-d-scheduler
  endpoints:
  - port: metrics
    interval: 5s
    path: /metrics
```

### Custom Grafana Dashboards
- **llm-d Overview**: System-wide performance metrics
- **Cache Analytics**: Prefix cache performance and optimization
- **Gateway Health**: Envoy proxy metrics and routing decisions
- **Model Performance**: Per-model latency and throughput analysis
- **Cost Tracking**: Resource utilization and cost attribution

## Demo Flow

### Phase 1: System Setup (5 minutes)
1. **Environment Overview**: Show Kubernetes cluster with llm-d components
2. **Component Introduction**: Explain Envoy Gateway, llm-d scheduler, vLLM instances
3. **Dashboard Walkthrough**: Introduce monitoring and visualization interfaces

### Phase 2: Basic Functionality (10 minutes)
1. **Simple Request**: Send a basic chat completion request
2. **Request Tracing**: Follow the request through the system
3. **Performance Baseline**: Establish standard routing performance metrics

### Phase 3: Advanced Features (15 minutes)
1. **Cache-Aware Routing**: Demonstrate intelligent cache utilization
2. **Disaggregated Serving**: Show prefill/decode separation benefits
3. **Multi-Tenant QoS**: Display different service levels in action
4. **Auto-scaling**: Trigger scaling events and show response

### Phase 4: Comparison and Analysis (10 minutes)
1. **Before/After Metrics**: Compare llm-d vs. standard Kubernetes routing
2. **Cost-Benefit Analysis**: Show efficiency gains and cost savings
3. **Scaling Scenarios**: Demonstrate enterprise-scale capabilities

## Success Metrics

### Performance Improvements
- **Latency Reduction**: 50-300% improvement in P95 TTFT
- **Throughput Increase**: 2-5x higher sustained QPS
- **Cache Efficiency**: 60-90% cache hit rates for typical workloads
- **Resource Utilization**: 80%+ GPU memory efficiency

### Operational Benefits
- **Deployment Simplicity**: One-command deployment vs. custom solutions
- **Monitoring Integration**: Built-in observability vs. custom tooling
- **Cost Optimization**: Automatic scaling vs. manual resource management
- **Multi-tenancy**: Native support vs. application-level isolation

## Conclusion

This demo showcases how llm-d transforms LLM serving on Kubernetes from basic round-robin distribution to an intelligent, performance-optimized system that automatically handles the unique challenges of inference workloads while providing enterprise-grade observability and operational simplicity.

## Next Steps

1. **Implementation**: Build the demo using the outlined architecture
2. **Performance Testing**: Validate metrics under realistic load conditions
3. **Documentation**: Create deployment guides and troubleshooting resources
4. **Community Feedback**: Gather input from early adopters and contributors 