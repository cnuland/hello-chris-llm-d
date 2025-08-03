# Assets Overview for LLM-D Project

This document provides a detailed overview of key assets in the LLM-D project related to inference. The assets include configurations for ModelService, EPP, HTTPRoute, and associated services, gateways, and configurations for KV-cache, vLLM, and Envoy (ISTIO).

## ModelService

The `ModelService` resource manages the lifecycle of AI models within the cluster. It outlines how the models are deployed, required accelerators, replicas, and what models to load. Here's a breakdown:
- **Accelerator Types**: Utilizes GPUs defined by Kubernetes labels (e.g., `nvidia.com/gpu`).
- **Containers**: Defines environment variables and resources for running vLLM, limiting GPU usage, and configuring caching.
- **Model Artifacts**: Specifies the size and URI for retrieving the model.
- **Routing**: Connects the ModelService to a specific Gateway for inference.

## Hybrid Cache ConfigMap

The `Cache-Aware Hybrid ConfigMap` configures GPU-based caching strategies for high cache hit rates in vLLM. Key features include:
- **Routing Proxy**: A sidecar container managing routing and connectivity.
- **Prefix Caching**: Enabling both local prefix caching and minimal KV transfer for efficient querying.
- **Resource Limits**: Configures GPU memory utilization and other limits to optimize performance.

## HTTPRoute

The `HTTPRoute` asset defines how HTTP requests are managed and directed within the network. Specific aspects include:
- **Hostnames**: Configures external access.
- **Backend Services**: Specifies services to handle requests with weights indicating load distribution.
- **Path Matching**: Determines how paths are matched to different services.

## Cache-Aware Service

The `Cache-Aware Service` handles network interactions between the cache layer and decoding services:
- **Ports and Protocols**: Defines the ports used for vLLM interactions.
- **Session Affinity**: Utilizes `ClientIP` session affinity to maintain cache coherency.
- **Target Selection**: Uses labels to identify appropriate decode pods.

## Gateway (Envoy/ISTIO)

The `Gateway` resource manages ingress traffic to ensure it is correctly routed within the cluster using Istio's capabilities:
- **Listener Configuration**: Manages traffic rules and allows routes within the same namespace.
- **Programmed Status**: Ensures resources are validated and routes are correctly assigned.

## EPP (External Processing Pipeline)

The `EPP Deployment` manages additional processing needed for more complex inference tasks:
- **KV-Cache Aware Scorer**: Provides additional scoring methods based on cache hits.
- **Service Integration**: Connects with services required for processing and scoring metrics.
- **Prefill/Decode Disaggregation**: Enables P/D disaggregation with configurable prompt length thresholds.
- **Redis Integration**: Connects to Redis for KV-cache indexing and scoring weights.
- **Multi-Scorer Architecture**: Supports multiple scoring algorithms including load-aware, prefix-aware, and session-aware scorers.

## Envoy Filters

The `Envoy Filters` provide HTTP external processing capabilities needed to handle custom routing logic in the LLM-D inference workload. These configurations enable efficient data processing and traffic handling through Istio.

- **EppExtProcFilter**: Manages external HTTP processing, configuring GRPC communication and processing behaviors such as buffering and header transmission.
  - Integrated with the LLM-D gateway to handle incoming requests.
  - Uses configuration patches to insert processing logic within the Envoy HTTP filter chain.
  - Configured with a 30-second timeout and buffered request body mode.
  - Processes request headers and attributes like `x-request-id` and `x-llm-model`.

- **ClusterFilter**: Ensures logical DNS resolution and balanced traffic handling to services within the LLM-D namespace.
  - Configures protocol options and connection timeouts, ensuring smooth and reliable traffic flow.
  - Uses ROUND_ROBIN load balancing for EPP service communication.
  - Supports HTTP/2 protocol for GRPC communication with the EPP service.

## DestinationRule

The `DestinationRule` plays a vital role in service communication policies, especially when using TLS:
- **Traffic Policy Configuration**: Manages load balancing policies, connection pool settings, and circuit breaker configurations.
- **TLS Configuration**: Handles secure communication between services, with options for insecure skip verification in development environments.
- **Session Affinity**: Can be configured to use consistent hash-based routing for session stickiness.
- **Subset Configuration**: Allows traffic splitting and canary deployments based on pod labels.

## vLLM Configuration Details

The vLLM containers are configured with specific optimization parameters:
- **Prefix Caching**: Enabled with `builtin` hash algorithm for optimal performance.
- **Memory Utilization**: Set to 90% for decode pods and 80% for prefill pods.
- **Block Size**: Configured to 16 for optimized memory allocation.
- **Chunked Prefill**: Disabled to improve cache hit rates.
- **NIXL Side Channel**: Configured on port 5557 for KV-cache communication.
- **Model Length**: Limited to 4096 tokens for efficient processing.

## Routing Proxy (Sidecar)

The routing proxy runs as a sidecar container in decode pods:
- **Port Configuration**: Listens on port 8000 for external traffic, forwards to vLLM on port 8001.
- **Connector Type**: Uses `nixlv2` connector for KV-cache communication.
- **Health Checks**: Configured with TCP-based liveness and readiness probes.
- **Security Context**: Runs with dropped capabilities and no privilege escalation.

These components collectively ensure efficient, high-performance AI inference within your Kubernetes cluster, providing key optimizations for cache, routing, and resource management.
