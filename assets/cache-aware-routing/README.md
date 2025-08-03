# LLM-D Cache-Aware Routing Demo

This directory contains configurations and scripts to demonstrate **LLM-D's key differentiating feature**: **Cache-Aware Routing**. This feature routes requests to pods that already have the relevant KV-cache data, dramatically improving performance and resource efficiency.

## Current Setup Analysis

### **Current Scaling:**
- **3 Decode pods** currently running (perfect for cache demo!)
  - Multiple `llama-3-2-1b-decode-*` pods across GPU nodes
- **2 Prefill pods** for optimal throughput
- **1 EPP (Entry Point Pool)** managing intelligent routing
- **Additional GPUs available** for scaling

### **Current Cache Configuration:**
✅ `ENABLE_KVCACHE_AWARE_SCORER: "true"` - **ENABLED** (Key Feature!)
✅ `ENABLE_PREFIX_AWARE_SCORER: "true"` - Enabled  
✅ `PREFIX_AWARE_SCORER_WEIGHT: "2"` - Good weight
✅ `PREFILL_ENABLE_KVCACHE_AWARE_SCORER: "true"` - Prefill cache-aware routing enabled

## Step 1: Enable Cache-Aware Routing

```bash
# Apply the EPP configuration to enable KV-cache aware routing
oc patch deployment llama-3-2-1b-epp -n llm-d --patch-file assets/cache-aware-routing/epp-cache-enabled-patch.yaml

# Verify the configuration
oc get deployment llama-3-2-1b-epp -n llm-d -o yaml | grep -A 5 -B 5 "KVCACHE_AWARE"

# Wait for EPP to restart
oc rollout status deployment/llama-3-2-1b-epp -n llm-d
```

## Step 2: Scale to 3 Decode Pods (Optional)

```bash
# Scale to 3 decode pods for better cache distribution demonstration
oc apply -f assets/cache-aware-routing/scale-decode-pods.yaml

# Monitor the scaling
oc get pods -n llm-d -l llm-d.ai/inferenceServing=true -w

# Verify all 3 pods are running
oc get pods -n llm-d | grep decode
```

## Step 3: Run Cache-Aware Routing Demo

```bash
# Run the comprehensive demo script
./assets/cache-aware-routing/cache-demo-script.sh
```

### What the Demo Shows:

1. **Cache Population Phase:**
   - Sends requests with different prompt prefixes to different pods
   - Each pod builds cache for specific topics (AI, ML, Cloud)

2. **Cache Hit Phase:**
   - Sends similar requests that should route to pods with relevant cache
   - Measures latency improvements from cache hits

3. **Cache Miss Phase:**
   - Sends completely different requests (new topics)
   - Shows routing to least loaded pods when no cache match exists

## Step 4: Monitor Cache-Aware Routing

### **Real-time Monitoring:**

```bash
# Watch EPP routing decisions
oc logs -n llm-d deployment/llama-3-2-1b-epp -f | grep -E "(cache|routing|score)"

# Monitor vLLM cache metrics on each pod
oc exec -n llm-d llama-3-2-1b-decode-67c74fdb5b-dbh7p -c vllm -- curl -s localhost:8001/metrics | grep cache

# Check cache hit rates in Prometheus
# Look for: vllm:cache_hit_rate, vllm:prefix_cache_hit_rate
```

### **Grafana Dashboard Metrics:**
- **Cache Hit Rate per Pod**
- **Request Routing Distribution**
- **Latency by Cache Status (Hit vs Miss)**
- **EPP Scoring Decisions**

## How Cache-Aware Routing Works

### **Routing Algorithm:**
1. **KV-Cache Scorer (Weight: 5)** - **HIGHEST PRIORITY**
   - Checks which pods have relevant cached computations
   - Routes to pod with best cache match
   
2. **Prefix Scorer (Weight: 3)**
   - Analyzes prompt prefixes for similar patterns
   - Routes to pods that processed similar prefixes

3. **Session Scorer (Weight: 2)**
   - Maintains conversation continuity
   - Routes follow-up requests to same pod

4. **Load Scorer (Weight: 1)** - **FALLBACK**
   - Only used when cache doesn't provide advantage
   - Routes to least loaded pod

### **Cache Types:**
- **KV-Cache**: Stores key-value attention computations
- **Prefix Cache**: Caches common prompt beginnings  
- **Session Cache**: Maintains conversation state

## Expected Demo Results

### **Performance Improvements:**
- **Cache Hits**: ~30-50% latency reduction
- **Cache Misses**: Normal latency (baseline)
- **Routing Overhead**: <5ms additional latency

### **Routing Behavior:**
- **Similar prompts** → Same pod (cache hit)
- **Different topics** → Different pods (load balancing)
- **Follow-up questions** → Same pod (session affinity)

## Customer Demo Script

### **Demo Flow:**
1. **Show Current Scaling**: 2-3 decode pods across different nodes
2. **Explain Routing Algorithm**: Cache > Prefix > Session > Load
3. **Run Live Demo**: Execute the cache demo script
4. **Show Metrics**: Display cache hit rates and latency improvements
5. **Scale Demo**: Show how it works with more pods

### **Key Talking Points:**
- **Resource Efficiency**: Avoid recomputing cached data
- **Latency Optimization**: Route to pods with relevant cache
- **Intelligent Load Balancing**: Beyond simple round-robin
- **Session Continuity**: Conversations stay on same pod
- **Automatic Cache Management**: No manual configuration needed

## Troubleshooting

### **If Cache Hits Are Low:**
```bash
# Check if KV-cache aware scoring is enabled
oc get deployment llama-3-2-1b-epp -n llm-d -o yaml | grep KVCACHE_AWARE

# Verify Redis connection for cache indexing
oc get pods -n llm-d | grep redis
oc logs -n llm-d deployment/llm-d-operator-redis-master

# Check vLLM cache configuration
oc exec -n llm-d <decode-pod-name> -c vllm -- env | grep CACHE
```

### **If Routing Seems Random:**
```bash
# Check EPP logs for scoring details
oc logs -n llm-d deployment/llama-3-2-1b-epp | grep -i score

# Verify inference pool configuration
oc get inferencepool -n llm-d -o yaml
```

## Advanced Scaling Demo

With **22 available GPUs**, you could demonstrate:
- **6-8 decode pods** for massive scale
- **Multi-model cache sharing**
- **Cross-model prefix cache benefits**
- **Geographic cache distribution** (if multi-zone)

This cache-aware routing capability is what sets LLM-D apart from traditional load balancers and makes it ideal for production LLM workloads!
