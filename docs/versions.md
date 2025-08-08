# Versions

This proof-of-concept standardizes on the following component versions:

- vLLM wrapper image: ghcr.io/llm-d/llm-d:v0.2.0
- Routing proxy sidecar: ghcr.io/llm-d/llm-d-routing-sidecar:v0.2.0
- External Processing Pod (EPP): ghcr.io/llm-d/llm-d-inference-scheduler:v0.2.1

Notes:
- EPP is standardized to v0.2.1 for this POC. Upstream examples may vary.
- Monitoring stack is provided separately under monitoring/ and matches the cluster-aligned configuration.

