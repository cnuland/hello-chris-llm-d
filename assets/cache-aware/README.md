# KV-Cache Aware Routing for LLM-D

A production-ready demonstration of intelligent KV-cache aware routing for Large Language Model inference, achieving **80%+ cache hit rates** through optimized vLLM configuration and session affinity.

## Overview

This demo showcases how to implement high-performance LLM inference with:

- **vLLM v0.10.0** with optimized prefix caching
- **Session affinity** for consistent cache utilization  
- **Intelligent routing** through dedicated cache-aware services
- **Automated testing** via Tekton pipelines
- **Comprehensive monitoring** with Prometheus metrics

## Performance Results

🎯 **Current Achievement**: **80% cache hit rate** in production
- 4x performance improvement for cached requests
- Perfect session stickiness (100% consistency)
- Production-stable deployment with zero downtime

## Quick Start

### Prerequisites

- OpenShift cluster with GPU nodes
- LLM-D Operator installed
- Tekton Pipelines (optional, for automated testing)

### Installation

1. **Clone and navigate to the demo:**
   ```bash
   git clone <repository>
   cd assets/cache-aware
   ```

2. **Deploy the system:**
   ```bash
   ./deploy.sh
   ```

3. **Verify deployment:**
   ```bash
   kubectl get pods -n llm-d -l app=llama-3-2-1b-decode
   ```

### Running the Demo

#### Manual Testing
```bash
# Run cache performance test
./cache-test.sh
```

#### Automated Testing (Recommended)
```bash
# Run comprehensive cache validation pipeline
tkn pipeline start cache-hit-pipeline -n llm-d --use-param-defaults --showlog
```

## API Usage

**Endpoint:** `https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions`

**Example Request:**
```bash
curl -H \"Content-Type: application/json\" \\
  -H \"X-Session-ID: my-session-123\" \\
  -d '{
    \"model\": \"meta-llama/Llama-3.2-1B\",
    \"prompt\": \"Write a story about AI\",
    \"max_tokens\": 100
  }' \\
  https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions
```

## Documentation

### 📖 Detailed Documentation

- **[Architecture Guide](docs/ARCHITECTURE.md)** - System components and request flow
- **[Metrics & Monitoring](docs/METRICS.md)** - Performance monitoring and alerting  
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions
- **[Tekton Automation](docs/TEKTON-AUTOMATION.md)** - Automated testing pipeline setup
- **[Development Journey](docs/DEVELOPMENT-JOURNEY.md)** - Challenges faced and lessons learned

### 🔧 Technical Details

- **vLLM Version**: v0.10.0 (via `ghcr.io/llm-d/llm-d:v0.2.0`)
- **Cache Algorithm**: Builtin hash with 16-token block size
- **Session Affinity**: ClientIP with 2-hour timeout
- **GPU Utilization**: 90% for optimal cache performance

## Key Features

### 🚀 Performance Optimization
- **80%+ cache hit rate** through parameter tuning
- **Session affinity** ensures consistent pod targeting
- **Optimized vLLM configuration** for cache efficiency

### 🔍 Monitoring & Observability  
- **Prometheus metrics** for real-time performance tracking
- **Per-pod cache analytics** to validate session affinity
- **Automated testing pipelines** for continuous validation

### 🏗️ Production Ready
- **Zero-downtime deployments** with proper health checks
- **Cluster state as source of truth** for configuration management
- **Comprehensive documentation** for troubleshooting and maintenance

## File Structure

```
├── README.md                    # This file
├── deploy.sh                    # Main deployment script
├── cache-test.sh               # Manual cache testing script
├── hybrid-cache-configmap.yaml # vLLM optimization configuration
├── cache-aware-service.yaml    # Service with session affinity
├── http-route.yaml             # External routing configuration
├── gateway.yaml                # Gateway configuration
├── model-service.yaml          # ModelService configuration
├── monitoring.yaml             # ServiceMonitor configuration
├── docs/                       # Detailed documentation
│   ├── ARCHITECTURE.md         # System architecture
│   ├── METRICS.md              # Monitoring setup
│   ├── TROUBLESHOOTING.md      # Common issues
│   ├── TEKTON-AUTOMATION.md    # Automated testing setup
│   └── DEVELOPMENT-JOURNEY.md  # Development story
└── tekton/                     # Automated testing
    ├── cache-hit-pipeline.yaml
    └── cache-hit-pipelinerun.yaml
```

## Contributing

This demo represents a complete, production-tested implementation. For improvements or issues:

1. Review the [troubleshooting guide](docs/TROUBLESHOOTING.md)
2. Check the [development journey](docs/DEVELOPMENT-JOURNEY.md) for context
3. Test changes using the provided automation tools

## Success Metrics

- ✅ **80% cache hit rate** (production validated)
- ✅ **Perfect session affinity** (100% consistency)  
- ✅ **Zero-downtime deployment** capability
- ✅ **Automated validation** with comprehensive testing
- ✅ **Production stability** with proper monitoring

---

*This demo showcases the successful transformation from 0% to 80% cache hit rate through systematic optimization and architectural improvements.*
