# LLM-D: Kubernetes-Native Distributed LLM Inference Platform

A concise, production-oriented demo of distributed LLM inference featuring cache-aware routing, prefill/decode disaggregation, and first-class observability.


## Getting Started

Prerequisites and setup
- A Kubernetes cluster (v1.27+) or OpenShift. GPU nodes recommended for real inference
- kubectl (or oc) configured for your cluster/context
- A gateway implementation (Istio or kGateway) for external access and Envoy External Processing (EPP)
- Recommended: install the base infrastructure with llm-d-infra before deploying this repo’s demo components

Install the base infrastructure first (recommended)
- This repository deploys llm-d-infra under llm-d-infra/. Use its quickstart to prepare namespaces, gateway, and optional monitoring.
- Example:
  - cd llm-d-infra/quickstart
  - ./install-deps.sh   # installs helm/helmfile, kustomize, yq, etc.
  - export HF_TOKEN="your-hf-token"   # if you plan to pull gated models
  - ./llmd-infra-installer.sh --gateway istio   # or --gateway kgateway
  - For details and additional options, see llm-d-infra/quickstart/README.md

Deploy the demo components (dry-run by default)
- After the infrastructure is installed, run from the repo root:
  - Preview what will be applied:
    scripts/deploy.sh --monitoring
  - Apply core plus monitoring:
    scripts/deploy.sh --apply --monitoring

What gets installed
- Core llm-d components via Kustomize at assets/llm-d
- Envoy external processor filter at assets/epp-external-processor.yaml
- Monitoring in llm-d-monitoring namespace:
  - Prometheus (v2.45.0) with scrape jobs for vLLM, EPP, gateway and k8s
  - Grafana with provisioned Prometheus datasource and the LLM Performance dashboard

Validate
- Core status (adjust namespace/model names as needed):
  kubectl get pods -n llm-d
- Grafana route URL:
  kubectl -n llm-d-monitoring get route grafana-secure -o jsonpath='{.spec.host}'
  # Login: admin / admin (demo)
- Prometheus service:
  kubectl -n llm-d-monitoring get svc prometheus

Uninstall (manual example)
- Use kubectl delete with the same manifests you applied, or roll back using your Git history. If desired, I can add a cleanup script on request.


## Architecture (overview)

High-level flow
1) Client → Gateway (TLS) → Envoy external processing (EPP)
2) EPP evaluates cache affinity, load, and policy → issues routing decision
3) HTTPRoute forwards to the backend service based on EPP decision
4) Cache-aware service + session affinity target decode pods
5) Decode pods (routing proxy + vLLM) execute inference with prefix cache
6) Prometheus scrapes metrics; Grafana visualizes TTFT, cache, throughput, etc.

Key components
- EPP (External Processor): request inspection, scoring (cache-aware + load), decision
- Gateway/Envoy: external processing integration point (EnvoyFilter)
- Cache-aware service: Kubernetes Service with session affinity for locality
- vLLM pods: routing proxy on 8000, vLLM metrics on 8001, prefix cache enabled
- Observability: Prometheus scrape jobs and pre-provisioned Grafana dashboard

Why it works
- Session affinity concentrates repeat traffic to warm pods
- Prefix caching improves latency and GPU efficiency
- External processing keeps routing policy out of the data-plane configs and under control

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
- assets/llm-d: primary Kustomize for core deployment
- assets/monitoring: ServiceMonitor/PodMonitor examples for cluster monitoring operators
- monitoring/: exact manifests synced with live llm-d-monitoring namespace
- scripts/deploy.sh: minimal deployer, dry-run by default, supports --monitoring
- guidellm/: Tekton/benchmarking assets (optional)


## Notes and expectations
- Metrics and routes: some names/hosts are environment-specific; update to your cluster
- Secrets/tokens: this repo does not include real secrets. Configure any required tokens (e.g., HF) as Kubernetes Secrets in your cluster
- GPU requirement: for real model inference, deploy onto GPU nodes; otherwise, deploy the stack and test the control-plane paths only


## Links
- Blog: see blog/ for architectural deep dives and demo details
- Troubleshooting: monitoring/README.md for monitoring-specific steps
- Advanced architecture details: assets/cache-aware/docs/ARCHITECTURE.md
- Metrics details: assets/cache-aware/docs/METRICS.md

