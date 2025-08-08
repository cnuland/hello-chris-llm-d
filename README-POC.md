# LLM-D POC Deployment

This repository provides a single, canonical deployment path for the LLM-D proof of concept.

## Deploy

1. Prerequisites:
   - GPU-enabled cluster
   - LLM-D Operator installed
   - Hugging Face token secret `llm-d-hf-token` in namespace `llm-d`

2. Deploy core LLM-D resources:

```bash
kubectl apply -k assets/llm-d
kubectl apply -f assets/epp-external-processor.yaml   # EnvoyFilter for EPP
```

3. Optional: Deploy monitoring stack

```bash
kubectl apply -f monitoring/prometheus.yaml
kubectl apply -f monitoring/grafana.yaml
```

## Structure

- assets/llm-d/
  - gateway.yaml
  - httproute.yaml
  - modelservice.yaml
  - kustomization.yaml
- assets/epp-external-processor.yaml (single EnvoyFilter)
- monitoring/ (cluster-aligned Prometheus + Grafana)
- app/ (frontend and backend examples)
- blog/ (KV-cache-aware routing write-up)
- docs/
  - versions.md (component versions)

## Versions

See docs/versions.md for canonical versions (v0.2.0 across components).

## Notes

- Legacy, duplicate, and experimental manifests have been removed or archived.
- This POC uses inline ModelService configuration (no ConfigMap presets).

