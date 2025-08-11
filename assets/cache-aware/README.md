# KV-Cache Aware Routing for LLM-D

A production-ready demonstration of intelligent KV-cache aware routing for Large Language Model inference, validated on Llama 3.2 3B Instruct through optimized vLLM configuration and EPP-driven stickiness (Envoy External Processing).

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
- Stickiness: EPP on-path; mesh fallback is ROUND_ROBIN (no mesh-level sticky hashing configured)

## Quick Start

### Prerequisites

- OpenShift cluster with GPU nodes
- Upstream Istio installed and functional
- LLM-D infra installed (helm chart) with Istio gateway type, and llm-d namespace created
- ModelService applied for meta-llama/Llama-3.2-3B-Instruct and pods Ready
- Tekton Pipelines installed

### Install the Tekton assets

```bash
# From the repo root
kubectl apply -n llm-d -f assets/cache-aware/tekton/cache-hit-pipeline.yaml
```

### Run the validator task

```bash
# Start the validator Task directly (recommended)
tkn task start cache-hit-test -n llm-d --param host=llm-d.demo.local --showlog
```

Defaults point to the in-cluster Istio gateway service and host:
- Gateway URL: http://llm-d-gateway-istio.llm-d.svc.cluster.local
- Host header: llm-d.demo.local
- Ext-proc: enabled on llm-d-gateway; failure_mode_allow=true (bypass if EPP unavailable)

## Manual API usage

Use the internal service URL and provide the Host header to match the HTTPRoute.

```bash
GW=http://llm-d-gateway-istio.llm-d.svc.cluster.local
HOST=llm-d.demo.local
curl -sk -H "Host: $HOST" -H "Content-Type: application/json" \
  -X POST "$GW/v1/completions" -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "prompt": "Write a story about AI",
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
- Stickiness: EPP-driven via Envoy ext-proc; mesh fallback is ROUND_ROBIN
- EPP in path via Envoy ext-proc filtering (assets/envoyfilter-epp.yaml)

## Expected results

- After restart + tiny warm-up, ramp run should show:
  - Aggregate delta hit rate ~95–99% over measured loop
  - Overall pod hit rate ~98%
- Session stickiness: EXCELLENT (all traffic to one pod) when EPP is healthy; ROUND_ROBIN fallback otherwise

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

---

This demo has been validated on an OpenShift cluster using upstream Istio and LLM-D infra with meta-llama/Llama-3.2-3B-Instruct.
