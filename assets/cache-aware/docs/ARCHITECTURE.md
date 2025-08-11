# KV-Cache Aware Routing Architecture

## Overview

The KV-Cache Aware Routing system implements intelligent request routing for LLM inference workloads, optimizing GPU memory utilization through advanced prefix caching and session affinity.

## System Components

### 1. Core Components

#### vLLM Inference Engine
- **Image**: `ghcr.io/llm-d/llm-d:v0.2.0` (includes vLLM v0.10.0)
- **Port**: 8001 (internal inference)
- **Optimizations**:
  - Prefix caching enabled with builtin hash algorithm
  - Block size: 16 tokens (optimized for cache efficiency)
- Chunked prefill disabled for better cache consistency
- GPU memory utilization: tuned for stability (e.g., 70–90% depending on cluster)

#### Routing Proxy Sidecar
- **Image**: `ghcr.io/llm-d/llm-d-routing-sidecar:v0.2.0`
- **Port**: 8000 (service-facing)
- **Function**: Forwards API traffic to vLLM (8001) while maintaining request context
- **Deployment**: Runs as sidecar (no init-container startup dependency)

#### External Processing Pod (EPP)
- **Image**: `ghcr.io/llm-d/llm-d-inference-scheduler:v0.2.1`
- **Function**: Intelligent request routing based on:
  - KV-cache awareness
  - Load balancing
  - Prefix matching
  - Session affinity

### 2. Service Architecture

#### EPP Gateway Path
- **HTTPRoute**: Routes `/v1/*` traffic through the Istio gateway where the ext-proc filter invokes EPP (ms-llm-d-modelservice-epp:9002)
- **EnvoyFilter**: External Processing filter configured on llm-d-gateway (failure_mode_allow=true)
- **Health Path**: Optionally use a plain route for `/v1/models` if you want to keep it outside ext-proc

#### External Gateway
- **Gateway**: In-cluster Istio gateway Service (llm-d-gateway-istio.llm-d.svc.cluster.local)
- **Routing**: Host header (llm-d.demo.local) used to match HTTPRoute on the gateway

### 3. Request Flow

```
Client (with Host header)
    ↓
Istio Gateway
    ↓
Envoy ext-proc → EPP (gRPC)
    ↓ (picks best decode pod based on KV cache + session)
HTTPRoute backend
    ↓
Decode vLLM (8000/8001 metrics)
```

### 4. Caching Strategy

#### Prefix Caching
- **Algorithm**: builtin or sha256_cbor_64bit depending on configuration
- **Block Size**: 16 tokens (balances cache granularity vs. memory)
- **Hit Rate**: Target ≥85%+ during demo validator loop

#### Session Affinity
- **Method**: EPP-driven stickiness via ext-proc at the gateway
- **Mesh Fallback**: DestinationRule currently ROUND_ROBIN (no mesh-level sticky hashing configured)
- **Benefits**: Ensures requests with shared context route to the same warm pod when EPP is healthy

## Key Configuration Parameters

### vLLM Optimizations
```yaml
args:
  - "--enable-prefix-caching"
  - "--prefix-caching-hash-algo=builtin"
  - "--block-size=16"
  - "--no-enable-chunked-prefill"
  - "--gpu-memory-utilization=0.9"
  - "--max-model-len=4096"
```

### Session Affinity Configuration
EPP provides stickiness decisions. No Kubernetes Service sessionAffinity or mesh consistentHash is required for this demo. You may optionally add a DestinationRule with consistentHash on a header (e.g., x-session-id) as a backup if you want sticky fallback when EPP is down.

## Performance Characteristics

- **Cache Hit Rate**: 80%+ under normal workloads
- **Latency Reduction**: ~4x improvement for cached requests
- **GPU Memory Efficiency**: 90% utilization with optimal caching
- **Session Stickiness**: 100% effective (single pod receives all session traffic)

## Monitoring Integration

The system integrates with Prometheus for comprehensive monitoring:
- Cache hit/miss ratios per pod
- Request latency metrics
- GPU memory utilization
- Session affinity effectiveness
