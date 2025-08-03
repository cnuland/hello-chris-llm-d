# Troubleshooting and FAQs

## Common Issues

### Low Cache Hit Rate
- **Problem**: Cache hit rate falls below 80%.
- **Solution**:
  - Verify cache configuration parameters are correctly set.
  - Ensure session affinity is configured and functioning.
  - Monitor request patterns for anomalies or anti-patterns.
  - Check for cache evictions and memory limits.

### Session Stickiness Problems
- **Problem**: Requests are not targeting the same pod consistently.
- **Solution**:
  - Verify `ClientIP` session affinity is set on the primary service.
  - Ensure client IPs are persistently routed.
  - Confirm HTTPRoute configuration is correct and pointing to the cache-aware service.

### Request Latency Issues
- **Problem**: Increased latency for cached or uncached requests.
- **Solution**:
  - Check vLLM and routing logs for any errors or timeouts.
  - Verify pod resource allocations and that they are not being throttled.
  - Ensure full health of all involved services and nodes.

### Deployment Failures
- **Problem**: Pods fail to start or crash frequently.
- **Solution**:
  - Check pod logs for detailed error messages.
  - Validate Kubernetes manifests for correct syntax and field usage.
  - Ensure all referenced images are available and accessible.

## Performance Optimizations

### Cache Optimization
- Use block size of 16 tokens for balanced cache efficiency.
- Disable chunked prefill to increase cache predictability.

### Resource Allocations
- Maintain GPU memory utilization around 90% for optimal inference speed.
- Verify node selectors and GPU availability to avoid scheduling issues.

## FAQ

### How is session affinity ensured?
Session affinity is ensured using the `ClientIP` method configured on Kubernetes services, with a 2-hour timeout set to maintain routing consistency.

### What if I need more control over request routing?
Consider customizing the routing proxy or implementing additional sidecars that provide enhanced routing capabilities.

### What are the key metrics for monitoring?
- Cache hit rates
- Request latency and throughput
- GPU memory utilization

## Contact and Support
- For further assistance, please contact the project maintainer [email@example.com].
