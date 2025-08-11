# LLM-D: Kubernetes-Native Distributed LLM Inference Platform

A concise, production-oriented demo of distributed LLM inference featuring cache-aware routing, prefill/decode disaggregation, and first-class observability.


## Getting Started

Quickstart (three commands)
- Prerequisites
  - An Istio Gateway named llm-d-gateway in namespace llm-d (community Istio is fine)
  - oc and tkn CLIs installed and logged into your cluster
  - Optional (first run if models need auth): export HF_TOKEN=… in your terminal so your cluster can fetch gated models

Run these from the repo root:
1) chmod +x scripts/make-demo.sh
2) NS=llm-d ./scripts/make-demo.sh
3) tkn pipelinerun logs -n llm-d --last -f --all

What the script does
- Ensures namespace llm-d and applies all LLM-D assets (gateway, HTTPRoute, decode Service/Deployment, EPP, DestinationRules, ModelService)
- Applies Tekton assets (RBAC, cache-pod-restart and cache-hit pipelines)
- Restarts decode pods for clean metrics
- Launches the ramp PipelineRun
- Prints how to stream the logs if tkn is installed

Configuration (env vars)
- NS: target namespace (default llm-d) used by scripts/make-demo.sh
- HOST_HEADER: default llm-d.demo.local
- GATEWAY_URL: default http://llm-d-gateway-istio.$NS.svc.cluster.local
- PROM_URL: default http://thanos-querier.openshift-monitoring.svc.cluster.local:9091 (OpenShift). Override for other platforms
- WARMUP_COUNT, REQUESTS, SLEEP_SECONDS: can be adjusted by editing assets/cache-aware/tekton/cache-ramp-pipelinerun.yaml

What this deploys
- Pool-backed routing with Istio Gateway:
  - HTTPRoute -> Service (ms-llm-d-modelservice-decode:8000)
  - EnvoyFilter envoy.filters.http.ext_proc -> EPP gRPC (ms-llm-d-modelservice-epp:9002)
  - EPP consults InferencePool llm-d for endpoint discovery/selection
- vLLM tuned for prefix cache: enable_prefix_caching, block_size=16, no chunked prefill
- Tekton cache-hit pipeline with Prometheus aggregation (falling back to pod IPs/Service if needed) and a stickiness summary filtered to the active Test-ID and Session-ID

Validate
- Pods:
  oc -n llm-d get pods
- Stream pipeline logs:
  tkn pipelinerun logs -n llm-d --last -f --all
- Look for lines in the output like:
  - Delta Hit Rate (measured traffic): 9x.x%
  - Averages over N requests: TTFT=… ms, TPOT=… ms, TOTAL=… ms
  - MULTI-SESSION STICKINESS SUMMARY: Session … Stickiness % 100.0

Uninstall
- Use oc delete with the same manifests (see deploy.sh apply_assets function for the list).


## Architecture (overview)

High-level flow
1) Client → Istio Gateway → Envoy External Processing (EPP)
2) EPP scores endpoints for KV-cache reuse and health → returns routing decision (header hint)
3) Gateway forwards to decode Service/pod honoring EPP’s decision
4) vLLM pods execute inference with prefix cache enabled (TTFT improves after warm-up)
5) Prometheus aggregates metrics; Tekton prints hit-rate and timings

Key components
- EPP (External Processor): cache-aware scoring and decisioning
- Istio Gateway/Envoy: ext_proc integration; EPP uses InferencePool for endpoint discovery and scoring
- vLLM pods: prefix cache enabled, block_size=16, no chunked prefill
- Observability: Prometheus (or Thanos) used by the Tekton Task to aggregate pod metrics

Why it works
- EPP-driven routing concentrates session traffic onto warm pods for maximal KV cache reuse
- Prefix caching reduces TTFT and total latency significantly for repeated prompts
- All policy is centralized in EPP; the data plane remains simple

For a deeper technical outline (design rationale, metrics, demo flow), see the blog posts in blog/ (do not modify them here).


## Monitoring

What’s deployed (llm-d-monitoring)
- Prometheus: v2.45.0, 7d retention, jobs include:
  - kubernetes-pods (llm-d), vllm-instances (port mapping 8000→8000), llm-d-scheduler, gateway-api inference extension (EPP), Envoy/gateway
- Grafana: latest, anonymous viewer enabled, admin user seeded for demo
- Dashboards: LLM Performance Dashboard provisioned from monitoring/grafana-dashboard-llm-performance.json

Key panels (examples)
- TTFT: histogram_quantile over vllm:time_to_first_token_seconds_bucket
- Inter-token latency: vllm:time_per_output_token_seconds_bucket
- Cache hit rates: sum(vllm:gpu_prefix_cache_hits_total) / sum(vllm:gpu_prefix_cache_queries_total)
- Request queue: vllm:num_requests_running vs vllm:num_requests_waiting
- Throughput: rate(vllm:request_success_total[5m])

Files of record
- Prometheus
  - monitoring/prometheus.yaml (SA/RBAC/Deployment/Service)
  - monitoring/prometheus-config.yaml (scrape configs + alert rules)
- Grafana
  - monitoring/grafana.yaml (SA/Deployment)
  - monitoring/grafana-config.yaml (grafana.ini)
  - monitoring/grafana-datasources.yaml (Prometheus datasource)
  - monitoring/grafana-dashboards-config.yaml (provisioning)
  - monitoring/grafana-dashboard-llm-performance.json (dashboard)
  - monitoring/grafana-service.yaml (Service + OpenShift Route)


## Repository Layout (selected)
- deploy.sh: single command installer and validator for the Istio + EPP demo
- assets/llm-d: decode Service/Deployment, EPP stack, HTTPRoute
- assets/cache-aware/tekton: Tekton cache-hit pipeline definition
- monitoring/: optional monitoring assets (Grafana dashboards, configs)
- llm-d-infra/: upstream infrastructure (optional), not required for this demo path


## Notes and expectations
- Metrics and routes: some names/hosts are environment-specific; update to your cluster
- Secrets/tokens: this repo does not include real secrets. Configure any required tokens (e.g., HF) as Kubernetes Secrets in your cluster
- GPU requirement: for real model inference, deploy onto GPU nodes; otherwise, deploy the stack and test the control-plane paths only


## Links
- Blog: see blog/ for architectural deep dives and demo details
- Troubleshooting: monitoring/README.md for monitoring-specific steps
- Advanced architecture details: assets/cache-aware/docs/ARCHITECTURE.md
- Metrics details: assets/cache-aware/docs/METRICS.md

