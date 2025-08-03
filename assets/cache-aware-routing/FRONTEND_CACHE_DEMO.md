# Frontend-Based Cache-Aware Routing Demo

This demo uses the LLM-D frontend UI to visually demonstrate cache-aware routing by sending identical and similar requests and observing cache hit rates.

## Demo Setup

### **Frontend URL:**
🌐 **https://llm-d-frontend-route-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com**

### **Grafana Dashboard:**
🔍 **http://localhost:3000** (port-forwarded)
- Login: `admin` / `admin`
- Navigate to "LLM Performance Dashboard"

## Demo Scenarios

### **Scenario 1: Identical Request Repetition (100% Cache Hit Expected)**

1. **Open the Frontend UI** in your browser
2. **Start the monitoring script** in terminal:
   ```bash
   ./assets/cache-aware-routing/monitor-cache-hits.sh
   ```

3. **In the Frontend Playground:**
   - Enter this exact prompt: `"Write a detailed analysis of artificial intelligence"`
   - Set max tokens to 50
   - Click "Send" and wait for response
   - **Repeat the EXACT same request 5-10 times**

4. **Expected Results:**
   - First request: Cache miss (baseline latency ~100-200ms)
   - Subsequent identical requests: Cache hits (reduced latency ~50-100ms)
   - Cache hit rate should approach 90-100%

### **Scenario 2: Similar Prefix Demonstration**

1. **Send these prompts in sequence:**
   ```
   1. "Write a detailed analysis of artificial intelligence in healthcare"
   2. "Write a detailed analysis of artificial intelligence in education"  
   3. "Write a detailed analysis of artificial intelligence in finance"
   ```

2. **Expected Results:**
   - All requests should route to the same pod (prefix cache hit)
   - Latency should be reduced after the first request
   - Prefix cache hit rate should increase

### **Scenario 3: Different Topics (Cache Miss)**

1. **Send completely different prompts:**
   ```
   1. "Explain quantum physics fundamentals"
   2. "Describe the history of space exploration"
   3. "Write about cooking techniques"
   ```

2. **Expected Results:**
   - Each may route to different pods (load balancing)
   - No cache benefit initially
   - Normal latency for each new topic

## Monitoring During Demo

### **Terminal Monitoring:**
Run the monitoring script to see real-time cache metrics:
```bash
./assets/cache-aware-routing/monitor-cache-hits.sh
```

### **What to Look For:**
- **Cache Hits vs Misses**: Numbers increasing
- **Hit Rate Percentage**: Should increase with repeated queries
- **Pod Distribution**: Similar prompts should hit same pods
- **EPP Routing Logs**: Routing decisions in real-time

### **Grafana Metrics:**
- Open **http://localhost:3000**
- Look for:
  - `vllm:cache_hit_rate` - Overall cache efficiency
  - `vllm:prefix_cache_hit_rate` - Prefix-specific cache hits
  - Request latency histograms by cache status

## Demo Script for Presentation

### **Step 1: Show Setup**
```bash
# Show running pods
oc get pods -n llm-d -l llm-d.ai/inferenceServing=true -o wide

# Show we have 2 decode pods on different nodes
echo "We have 2 decode pods running on different nodes for cache distribution"
```

### **Step 2: Start Monitoring**
```bash
# In separate terminal window
./assets/cache-aware-routing/monitor-cache-hits.sh
```

### **Step 3: Demo in Browser**
1. **Open Frontend**: Navigate to the frontend URL
2. **Baseline Test**: Send a unique request, note the latency
3. **Cache Test**: Send the EXACT same request 5 times
4. **Show Results**: Point to reduced latency and cache hit metrics

### **Step 4: Explain What Happened**
- **First Request**: "No cache available, normal processing time"
- **Repeated Requests**: "EPP routes to pod with cached computation, ~50% latency reduction"
- **Multiple Pods**: "Cache is distributed across pods, EPP intelligently routes"

## Expected Performance

### **Cache Hit Improvements:**
- **Latency Reduction**: 30-60% for identical requests
- **Throughput Increase**: More requests handled per second
- **Resource Efficiency**: Less GPU computation needed

### **Routing Intelligence:**
- **Identical prompts** → Same pod (cache hit)
- **Similar prefixes** → Same pod (prefix cache)
- **Different topics** → Load balanced across pods

## Troubleshooting

### **If Cache Hits Are Low:**
```bash
# Check vLLM cache configuration
oc exec -n llm-d <decode-pod-name> -c vllm -- env | grep -i cache

# Check EPP routing logs
oc logs -n llm-d deployment/llama-3-2-1b-epp -f
```

### **If Frontend is Unresponsive:**
```bash
# Check frontend pods
oc get pods -n llm-d | grep frontend

# Check backend connectivity
oc get pods -n llm-d | grep backend
```

## Customer Demo Key Points

1. **Visual Impact**: "Watch the latency drop on repeated requests"
2. **Real-world Relevance**: "This is how chatbots become faster with common questions"
3. **Resource Efficiency**: "Less GPU computation means lower costs"
4. **Intelligent Routing**: "Not just round-robin, but smart cache-aware decisions"
5. **Production Ready**: "This works automatically, no manual tuning needed"

## Advanced Demo Options

### **Scale Test**: 
Scale to 3 decode pods to show more complex routing:
```bash
oc apply -f assets/cache-aware-routing/scale-decode-pods.yaml
```

### **Multi-User Simulation**:
Open multiple browser tabs and send requests simultaneously to show session affinity and load distribution.

### **A/B Testing**:
Use different model endpoints to show traffic splitting capabilities.

This frontend approach makes the cache-aware routing very tangible and visually compelling for customers!
