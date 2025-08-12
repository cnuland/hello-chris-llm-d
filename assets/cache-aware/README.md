# KV-Cache Aware Routing for LLM-D

A production-ready demonstration of intelligent KV-cache aware routing for Large Language Model inference, validated on Llama 3.2 3B Instruct through optimized vLLM configuration and EPP-driven stickiness (Envoy External Processing) with mesh-level fallback stickiness enabled via Istio consistent hashing.

## Overview

This demo shows how to implement high-performance LLM inference with:

- vLLM v0.10.0 with optimized prefix caching (block_size=16, enable_prefix_caching=True)
- EPP-driven stickiness (ext-proc at the Istio gateway)
- Intelligent routing through gateway + EPP
- Automated testing via Tekton pipelines
- Monitoring with Prometheus metrics and Grafana

## What this repo reproduces (as in the blog)

- Upstream Istio gateway in front of LLM-D
- Model: meta-llama/Llama-3.2-3B-Instruct
- Namespace: llm-d
- Pipelines: restart decode pods, then run cache ramp test with tiny warm-up to capture ramp-up delta
- Stickiness: EPP on-path; mesh fallback stickiness ENABLED via DestinationRule consistentHash(x-session-id) and session header normalization

## Quick Start

### Prerequisites

- Cluster with GPU nodes (recommended for model execution)
- Istio installed and functional
- LLM-D infra installed via Helm (MANDATED): make infra NS=llm-d GATEWAY_CLASS=istio
- ModelService and serving pods running (can be applied from this repo or your operator)
- Tekton Pipelines installed
- The Makefile assets target will apply EnvoyFilters and patch the Helm DestinationRule for out-of-the-box stickiness

### Install the Tekton assets

```bash
# From the repo root
make assets NS=llm-d   # applies EnvoyFilters, DRs, HTTPRoute, decode/EPP
make tekton NS=llm-d   # applies pipeline and triggers a run
```

### Run the validator task (manual)

```bash
# Start the validator Task directly (optional)
tkn task start cache-hit-test -n llm-d --showlog
```

Defaults point to the in-cluster Istio gateway service and host:
- Gateway URL: http://llm-d-infra-inference-gateway-istio.llm-d.svc.cluster.local
- Host header: llm-d-infra-inference-gateway.localhost (optional; HTTPRoute also matches the service DNS)
- Ext-proc: enabled on the infra gateway; failure_mode_allow=true (bypass if EPP unavailable)

## Manual API usage

Use the internal service URL. Host header is optional.

```bash
GW=http://llm-d-infra-inference-gateway-istio.llm-d.svc.cluster.local
curl -sk -H "Content-Type: application/json" \
  -X POST "$GW/v1/chat/completions" -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "messages": [{"role":"user","content":"Write a story about AI"}],
    "max_tokens": 50,
    "temperature": 0.0
  }'
```

## Documentation

- Architecture: docs/ARCHITECTURE.md
- Metrics & Monitoring: docs/METRICS.md
- Troubleshooting: docs/TROUBLESHOOTING.md
- Tekton Automation: docs/TEKTON-AUTOMATION.md
- Development Journey: docs/DEVELOPMENT-JOURNEY.md

## Technical details

- Model: meta-llama/Llama-3.2-3B-Instruct
- vLLM Image: ghcr.io/llm-d/llm-d:v0.2.0 (vLLM v0.10.0)
- Prefix cache metrics used: prefix_cache_queries_total, prefix_cache_hits_total
- Stickiness:
  - Primary: EPP-driven via Envoy ext-proc (assets/envoyfilter-epp.yaml)
  - Fallback: Istio DestinationRule consistentHash on x-session-id (assets/llm-d/destinationrule-decode.yaml) with session header normalization (assets/gateway-session-header-normalize.yaml)
- EPP in path via Envoy ext-proc filtering (assets/envoyfilter-epp.yaml)

## Expected results

- After restart + tiny warm-up, ramp run should show:
  - Aggregate delta hit rate ~95–99% over measured loop
  - Overall pod hit rate ~98%
- Session stickiness: EXCELLENT (all traffic to one pod) when EPP is healthy; and High (near 100%) under mesh fallback consistent hashing using x-session-id

## File Structure

```
├── README.md
├── cache-demo-script.sh         # Manual cache testing script (updated)
├── hybrid-cache-configmap.yaml  # vLLM optimization configuration
├── tekton/
│   ├── cache-hit-pipeline.yaml
│   ├── cache-hit-pipelinerun.yaml
│   ├── cache-pod-restart-pipeline.yaml
│   ├── cache-pod-restart-pipelinerun.yaml
│   └── cache-ramp-pipelinerun.yaml
```

## Istio-specific changes in this repo (summary)

- Envoy ext-proc at the infra gateway (assets/envoyfilter-epp.yaml)
- Session header normalization (assets/gateway-session-header-normalize.yaml) to ensure x-session-id is always present (header or Cookie fallback)
- DestinationRule consistentHash(x-session-id) safety net (assets/llm-d/destinationrule-decode.yaml) and Helm DR patch baked into Makefile/scripts
- HTTPRoute includes gateway service DNS hostname so Host header is optional

---

This demo has been validated on an OpenShift cluster using upstream Istio and LLM-D infra with meta-llama/Llama-3.2-3B-Instruct.
