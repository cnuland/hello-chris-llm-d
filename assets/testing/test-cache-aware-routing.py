#!/usr/bin/env python3
"""
LLM-D Cache-Aware Routing Test Script

This script tests and demonstrates the cache-aware routing functionality
of the LLM-D distributed inference system.

Requirements:
- Python 3.x with requests library
- Access to LLM-D backend route or gateway
- kubectl access to check metrics

Usage:
    python3 test-cache-aware-routing.py
"""

import requests
import json
import time
import threading
from datetime import datetime

# Configuration - Update these URLs for your deployment
BACKEND_URL = "https://llm-d-backend-route-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/api/v1/completions"
GATEWAY_URL = "https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com/v1/completions"

# Test configuration
TEST_PROMPTS = [
    "What is artificial intelligence?",
    "What is artificial intelligence? Please explain in detail.",
    "What is machine learning?", 
    "What is artificial intelligence?",  # Repeat to test cache
    "What is artificial intelligence? Can you tell me more?",
    "What is machine learning? How does it work?",
    "What is artificial intelligence?",  # Another repeat
    "What is deep learning?",
    "What is artificial intelligence? Why is it important?",
]

def make_request(prompt, request_id, endpoint_url=BACKEND_URL):
    """Make an inference request and return response details"""
    payload = {
        "model": "meta-llama/Llama-3.2-1B",
        "prompt": prompt,
        "max_tokens": 30,
        "temperature": 0.1,
        "stream": False
    }
    
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    
    start_time = time.time()
    
    try:
        response = requests.post(endpoint_url, 
                               json=payload, 
                               headers=headers, 
                               timeout=30,
                               verify=False)
        
        end_time = time.time()
        latency = (end_time - start_time) * 1000
        
        if response.status_code == 200:
            response_data = response.json()
            response_text = response_data.get("choices", [{}])[0].get("text", "")
            usage = response_data.get("usage", {})
            
            return {
                "request_id": request_id,
                "prompt": prompt,
                "status": "success",
                "latency_ms": round(latency, 2),
                "response_text": response_text[:100] + "..." if len(response_text) > 100 else response_text,
                "prompt_tokens": usage.get("prompt_tokens", 0),
                "completion_tokens": usage.get("completion_tokens", 0),
                "total_tokens": usage.get("total_tokens", 0),
                "timestamp": datetime.now().isoformat()
            }
        else:
            return {
                "request_id": request_id,
                "prompt": prompt,
                "status": "error", 
                "error": f"HTTP {response.status_code}: {response.text}",
                "latency_ms": round(latency, 2),
                "timestamp": datetime.now().isoformat()
            }
            
    except Exception as e:
        end_time = time.time()
        latency = (end_time - start_time) * 1000
        return {
            "request_id": request_id,
            "prompt": prompt,
            "status": "error",
            "error": str(e),
            "latency_ms": round(latency, 2),
            "timestamp": datetime.now().isoformat()
        }

def test_cache_aware_routing():
    """Test cache-aware routing with varied prompts"""
    print("Testing Cache-Aware Routing in LLM-D")
    print("====================================")
    print(f"Backend URL: {BACKEND_URL}")
    print(f"Total test prompts: {len(TEST_PROMPTS)}")
    print()
    
    results = []
    
    for i, prompt in enumerate(TEST_PROMPTS, 1):
        print(f"Request {i}/{len(TEST_PROMPTS)}: {prompt[:50]}{'...' if len(prompt) > 50 else ''}")
        
        result = make_request(prompt, i)
        results.append(result)
        
        print(f"  Status: {result['status']}")
        print(f"  Latency: {result['latency_ms']}ms")
        
        if result['status'] == 'error':
            print(f"  Error: {result['error']}")
        else:
            print(f"  Response: {result['response_text']}")
        
        print()
        time.sleep(1)  # Brief pause between requests
    
    return results

def test_cache_hits(num_requests=10):
    """Test for cache hits with identical repeated requests"""
    print("\\nTesting Cache Hits with Identical Requests")
    print("==========================================")
    
    test_prompt = "What is artificial intelligence?"
    results = []
    
    for i in range(1, num_requests + 1):
        print(f"Request {i}/{num_requests}: {test_prompt}")
        
        result = make_request(test_prompt, f"cache-{i}")
        results.append(result)
        
        print(f"  Latency: {result['latency_ms']}ms")
        time.sleep(0.5)
    
    return results

def analyze_results(results, test_type="Cache-Aware Routing"):
    """Analyze results for cache behavior patterns"""
    print(f"\\n{test_type} Analysis:")
    print("=" * (len(test_type) + 10))
    
    successful_requests = [r for r in results if r['status'] == 'success']
    failed_requests = [r for r in results if r['status'] != 'success']
    
    print(f"Successful requests: {len(successful_requests)}")
    print(f"Failed requests: {len(failed_requests)}")
    
    if successful_requests:
        latencies = [r['latency_ms'] for r in successful_requests]
        avg_latency = sum(latencies) / len(latencies)
        
        print(f"Average latency: {avg_latency:.2f}ms")
        print(f"Min latency: {min(latencies):.2f}ms")
        print(f"Max latency: {max(latencies):.2f}ms")
        
        # Look for cache warming patterns
        if len(latencies) >= 4:
            first_half = latencies[:len(latencies)//2]
            second_half = latencies[len(latencies)//2:]
            
            first_avg = sum(first_half) / len(first_half)
            second_avg = sum(second_half) / len(second_half)
            improvement = ((first_avg - second_avg) / first_avg * 100)
            
            print(f"First half avg: {first_avg:.1f}ms")
            print(f"Second half avg: {second_avg:.1f}ms")
            
            if improvement > 5:
                print(f"** Cache warming detected: {improvement:.1f}% improvement! **")
            else:
                print(f"Performance change: {improvement:.1f}%")
        
        # Group by similar prompts
        ai_prompts = [r for r in successful_requests if "artificial intelligence" in r['prompt'].lower()]
        if len(ai_prompts) > 1:
            print("\\nArtificial Intelligence prompts:")
            for result in ai_prompts:
                print(f"  {result['request_id']:>8}: {result['latency_ms']:6.1f}ms - {result['prompt']}")
    
    return {
        "successful": len(successful_requests),
        "failed": len(failed_requests),
        "avg_latency": avg_latency if successful_requests else 0,
        "min_latency": min(latencies) if successful_requests else 0,
        "max_latency": max(latencies) if successful_requests else 0
    }

def main():
    print("LLM-D Cache-Aware Routing Test Suite")
    print("===================================")
    
    # Test 1: Cache-aware routing with varied prompts
    routing_results = test_cache_aware_routing()
    routing_analysis = analyze_results(routing_results, "Cache-Aware Routing")
    
    print("\\n" + "="*60 + "\\n")
    
    # Test 2: Cache hits with identical requests
    cache_results = test_cache_hits()
    cache_analysis = analyze_results(cache_results, "Cache Hit")
    
    # Save results
    all_results = {
        "routing_test": {
            "results": routing_results,
            "analysis": routing_analysis
        },
        "cache_test": {
            "results": cache_results,
            "analysis": cache_analysis
        },
        "timestamp": datetime.now().isoformat(),
        "configuration": {
            "backend_url": BACKEND_URL,
            "gateway_url": GATEWAY_URL
        }
    }
    
    with open('cache_routing_test_results.json', 'w') as f:
        json.dump(all_results, f, indent=2)
    
    print(f"\\nResults saved to cache_routing_test_results.json")
    
    # Provide next steps
    print("\\nNext Steps for Demo:")
    print("===================")
    print("1. Check Grafana dashboard for KV Cache Hit Rate metrics")
    print("2. Monitor pod distribution:")
    print("   kubectl get pods -n llm-d | grep decode")
    print("3. Check cache metrics on decode pods:")
    print("   kubectl exec <decode-pod> -n llm-d -c vllm -- curl -s localhost:8001/metrics | grep gpu_prefix_cache")
    print("4. View EPP logs for routing decisions:")
    print("   kubectl logs <epp-pod> -n llm-d --tail=50")
    
    return all_results

if __name__ == "__main__":
    try:
        results = main()
        print("\\n✅ Cache-aware routing test completed successfully!")
    except KeyboardInterrupt:
        print("\\n❌ Test interrupted by user")
    except Exception as e:
        print(f"\\n❌ Test failed with error: {e}")
