#!/usr/bin/env python3

import requests
import json
import time
import subprocess

def get_pod_metrics():
    """Get cache metrics from all decode pods"""
    result = subprocess.run([
        "kubectl", "get", "pods", "-n", "llm-d", "-l", "llm-d.ai/model=llama-3-2-1b", 
        "-l", "llm-d.ai/role=decode", "-o", "name"
    ], capture_output=True, text=True)
    
    pods = [pod.split('/')[-1] for pod in result.stdout.strip().split('\n') if pod]
    metrics = {}
    
    for pod in pods:
        try:
            result = subprocess.run([
                "kubectl", "exec", "-n", "llm-d", pod, "--", 
                "curl", "-s", "localhost:8001/metrics"
            ], capture_output=True, text=True, timeout=10)
            
            queries = 0
            hits = 0
            for line in result.stdout.split('\n'):
                if 'gpu_prefix_cache_queries_total' in line and 'meta-llama/Llama-3.2-1B' in line:
                    queries = float(line.split()[-1])
                elif 'gpu_prefix_cache_hits_total' in line and 'meta-llama/Llama-3.2-1B' in line:
                    hits = float(line.split()[-1])
            
            metrics[pod] = {'queries': queries, 'hits': hits}
        except Exception as e:
            print(f"Error getting metrics from {pod}: {e}")
            metrics[pod] = {'queries': 0, 'hits': 0}
    
    return metrics

def test_cache_aware_routing():
    gateway_url = "https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com"
    
    print("=== Testing Cache-Aware Routing Through Gateway ===")
    print(f"Gateway URL: {gateway_url}")
    
    # Get initial metrics
    print("\n1. Getting initial metrics from all decode pods...")
    initial_metrics = get_pod_metrics()
    
    for pod, metrics in initial_metrics.items():
        print(f"   {pod}: Queries={metrics['queries']}, Hits={metrics['hits']}")
    
    # Test 1: Send identical requests (should hit cache if routed to same pod)
    print("\n2. Sending 10 identical requests through gateway...")
    identical_prompt = "What is the capital of France? Please answer with just the city name."
    
    responses = []
    for i in range(10):
        payload = {
            "model": "meta-llama/Llama-3.2-1B",
            "prompt": identical_prompt,
            "max_tokens": 10,
            "temperature": 0.0  # Deterministic
        }
        
        try:
            response = requests.post(
                f"{gateway_url}/v1/completions",
                json=payload,
                timeout=30,
                verify=False  # Skip SSL verification for demo
            )
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['text'].strip()
                responses.append(content)
                print(f"   Request {i+1}: {content}")
            else:
                print(f"   Request {i+1} failed: {response.status_code} - {response.text}")
                
        except Exception as e:
            print(f"   Request {i+1} error: {e}")
        
        time.sleep(0.5)  # Small delay between requests
    
    # Wait a moment for metrics to update
    time.sleep(2)
    
    # Get final metrics
    print("\n3. Getting final metrics from all decode pods...")
    final_metrics = get_pod_metrics()
    
    print("\n=== CACHE-AWARE ROUTING ANALYSIS ===")
    total_new_queries = 0
    total_new_hits = 0
    pod_activity = {}
    
    for pod in initial_metrics.keys():
        initial = initial_metrics[pod]
        final = final_metrics.get(pod, {'queries': 0, 'hits': 0})
        
        new_queries = final['queries'] - initial['queries']
        new_hits = final['hits'] - initial['hits']
        
        total_new_queries += new_queries
        total_new_hits += new_hits
        
        pod_activity[pod] = {
            'new_queries': new_queries,
            'new_hits': new_hits
        }
        
        if new_queries > 0:
            hit_rate = (new_hits / new_queries) * 100
            print(f"   {pod}: +{new_queries} queries, +{new_hits} hits ({hit_rate:.1f}% hit rate)")
        else:
            print(f"   {pod}: No new activity")
    
    # Analyze routing behavior
    active_pods = [pod for pod, activity in pod_activity.items() if activity['new_queries'] > 0]
    
    print(f"\n4. Routing Analysis:")
    print(f"   Total new queries: {total_new_queries}")
    print(f"   Total new hits: {total_new_hits}")
    print(f"   Active pods: {len(active_pods)} out of {len(initial_metrics)}")
    
    if len(active_pods) == 1:
        print("   ✅ EXCELLENT: All requests routed to single pod (optimal for caching)")
    elif len(active_pods) == 2:
        print("   ⚠️  MODERATE: Requests split between 2 pods (some cache benefit)")
    else:
        print("   ❌ POOR: Requests distributed across multiple pods (minimal cache benefit)")
    
    # Check for cache hits
    if total_new_hits > 0:
        overall_hit_rate = (total_new_hits / total_new_queries) * 100
        print(f"   Overall cache hit rate: {overall_hit_rate:.1f}%")
        print("   ✅ PREFIX CACHING IS WORKING!")
    else:
        print("   ❌ No cache hits detected (prefix caching may not be working)")
    
    # Test 2: Send requests with different prefixes
    print("\n5. Testing with different prefixes (should spread across pods)...")
    different_prompts = [
        "What is the capital of Germany?",
        "What is the capital of Italy?", 
        "What is the capital of Spain?",
        "What is the capital of Brazil?",
        "What is the capital of Japan?"
    ]
    
    initial_metrics_2 = get_pod_metrics()
    
    for i, prompt in enumerate(different_prompts):
        payload = {
            "model": "meta-llama/Llama-3.2-1B",
            "prompt": prompt,
            "max_tokens": 10,
            "temperature": 0.0
        }
        
        try:
            response = requests.post(
                f"{gateway_url}/v1/completions",
                json=payload,
                timeout=30,
                verify=False
            )
            
            if response.status_code == 200:
                result = response.json()
                content = result['choices'][0]['text'].strip()
                print(f"   Different prompt {i+1}: {content}")
            else:
                print(f"   Different prompt {i+1} failed: {response.status_code}")
                
        except Exception as e:
            print(f"   Different prompt {i+1} error: {e}")
        
        time.sleep(0.5)
    
    time.sleep(2)
    final_metrics_2 = get_pod_metrics()
    
    print("\n6. Distribution analysis for different prefixes:")
    active_pods_2 = 0
    for pod in initial_metrics_2.keys():
        initial = initial_metrics_2[pod]
        final = final_metrics_2.get(pod, {'queries': 0, 'hits': 0})
        new_queries = final['queries'] - initial['queries']
        
        if new_queries > 0:
            active_pods_2 += 1
            print(f"   {pod}: +{new_queries} queries")
    
    print(f"   Active pods for different prefixes: {active_pods_2}")
    if active_pods_2 > 1:
        print("   ✅ GOOD: Different prefixes spread across multiple pods")
    else:
        print("   ⚠️  All requests went to same pod (may indicate session affinity)")

if __name__ == "__main__":
    test_cache_aware_routing()
