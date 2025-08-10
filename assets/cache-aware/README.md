# KV-Cache Aware Routing for LLM-D

A production-ready demonstration of intelligent KV-cache aware routing for Large Language Model inference, achieving 90%+ cache hit rates on Llama 3.2 3B Instruct through optimized vLLM configuration and session affinity.

## Overview

This demo shows how to implement high-performance LLM inference with:

- vLLM v0.10.0 with optimized prefix caching (block_size=16, enable_prefix_caching=True)
- Session affinity for consistent cache utilization
- Intelligent routing through gateway + EPP
- Automated testing via Tekton pipelines
- Monitoring with Prometheus metrics and Grafana

## What this repo reproduces (as in the blog)

- Upstream Istio gateway in front of LLM-D
- Model: meta-llama/Llama-3.2-3B-Instruct
- Namespace: llm-d
- Pipelines: restart decode pods, then run cache ramp test with tiny warm-up to capture ramp-up delta

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
kubectl apply -n llm-d -f assets/cache-aware/tekton/cache-pod-restart-pipeline.yaml
kubectl apply -n llm-d -f assets/cache-aware/tekton/cache-hit-pipeline.yaml
```

### Run the demo (restart -> ramp)

```bash
# 1) Restart decode pods to clear metrics/cache
kubectl create -n llm-d -f assets/cache-aware/tekton/cache-pod-restart-pipelinerun.yaml

# Wait for PipelineRun to succeed
PR_RESTART=$(kubectl get pr -n llm-d -o name | grep cache-pod-restart-run | tail -1 | cut -d/ -f2)
watch -n 5 kubectl get pr $PR_RESTART -n llm-d

# 2) Start the ramp run (tiny warm-up, larger measured loop)
kubectl create -n llm-d -f assets/cache-aware/tekton/cache-ramp-pipelinerun.yaml
PR_RAMP=$(kubectl get pr -n llm-d -o name | grep cache-ramp-run | tail -1 | cut -d/ -f2)

# 3) Tail logs and observe ramp-up (expect ~98% hit rate, excellent stickiness)
kubectl get tr -n llm-d -l tekton.dev/pipelineRun=$PR_RAMP
TR=$(kubectl get tr -n llm-d -l tekton.dev/pipelineRun=$PR_RAMP -o jsonpath='{.items[0].metadata.name}')
POD=$(kubectl get pod -n llm-d -l tekton.dev/taskRun=$TR -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD -n llm-d -c step-run-cache-hit-test -f
```

Defaults in the pipeline point to the in-cluster Istio gateway service and host:
- Gateway URL: http://llm-d-gateway-istio.llm-d.svc.cluster.local
- Host header: llm-d.demo.local

## Manual API usage

Use the internal service URL and provide the Host header to match the HTTPRoute.

```bash
GW=http://llm-d-gateway-istio.llm-d.svc.cluster.local
HOST=llm-d.demo.local
curl -sk -H "Host: $HOST" -H "Content-Type: application/json" \
  -X POST "$GW/v1/chat/completions" -d '{
    "model": "meta-llama/Llama-3.2-3B-Instruct",
    "messages": [{"role": "user", "content": "Write a story about AI"}],
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

- vLLM Image: ghcr.io/llm-d/llm-d:v0.2.0 (vLLM v0.10.0)
- Prefix cache metrics used: vllm:prefix_cache_queries_total, vllm:prefix_cache_hits_total
- Session Affinity: ClientIP (2h)

## Expected results

- After restart + tiny warm-up, ramp run should show:
  - Aggregate delta hit rate ~95–99% over measured loop
  - Overall pod hit rate ~98%
  - Session stickiness: EXCELLENT (all traffic to one pod)

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
