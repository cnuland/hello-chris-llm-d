#!/bin/bash

# LLM-D Cache-Aware Routing Demo Script
# This script demonstrates how LLM-D routes requests based on KV-cache location

GATEWAY_URL="https://llm-d-inference-gateway-llm-d.apps.rhoai-cluster.qhxt.p1.openshiftapps.com"

echo "🚀 LLM-D Cache-Aware Routing Demo"
echo "=================================="
echo ""

# Define common prompt prefixes that should create cache hits
PROMPT_1="Write a detailed analysis of artificial intelligence and its impact on"
PROMPT_2="Explain the fundamentals of machine learning and how it relates to"
PROMPT_3="Create a comprehensive guide about cloud computing and its"

echo "📊 Step 1: Sending requests with common prefixes to build cache"
echo "--------------------------------------------------------------"

# Send initial requests to populate cache on different pods
echo "🎯 Request 1: Building cache with AI prompt..."
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-demo-1" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_1 society and the economy\"}],
    \"max_tokens\": 50
  }" | jq -r '.choices[0].message.content' | head -2

echo ""
echo "🎯 Request 2: Building cache with ML prompt..."
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-demo-2" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_2 deep learning and neural networks\"}],
    \"max_tokens\": 50
  }" | jq -r '.choices[0].message.content' | head -2

echo ""
echo "🎯 Request 3: Building cache with Cloud prompt..."
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-demo-3" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_3 advantages for modern businesses\"}],
    \"max_tokens\": 50
  }" | jq -r '.choices[0].message.content' | head -2

echo ""
echo "⏱️  Waiting 10 seconds for cache to populate..."
sleep 10

echo ""
echo "🔄 Step 2: Sending similar requests - should hit cache and route to same pods"
echo "--------------------------------------------------------------------------"

# These requests should hit cache and be routed to the pods with relevant cache
echo "🎯 Cache Hit Test 1: AI topic (should route to pod with AI cache)..."
TIME1=$(date +%s%N)
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-hit-1" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_1 healthcare and education\"}],
    \"max_tokens\": 30
  }" | jq -r '.choices[0].message.content' | head -1
TIME1_END=$(date +%s%N)
LATENCY1=$(( (TIME1_END - TIME1) / 1000000 ))
echo "⚡ Latency: ${LATENCY1}ms"

echo ""
echo "🎯 Cache Hit Test 2: ML topic (should route to pod with ML cache)..."
TIME2=$(date +%s%N)
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-hit-2" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_2 computer vision applications\"}],
    \"max_tokens\": 30
  }" | jq -r '.choices[0].message.content' | head -1
TIME2_END=$(date +%s%N)
LATENCY2=$(( (TIME2_END - TIME2) / 1000000 ))
echo "⚡ Latency: ${LATENCY2}ms"

echo ""
echo "🎯 Cache Hit Test 3: Cloud topic (should route to pod with Cloud cache)..."
TIME3=$(date +%s%N)
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-hit-3" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"$PROMPT_3 scalability and cost efficiency\"}],
    \"max_tokens\": 30
  }" | jq -r '.choices[0].message.content' | head -1
TIME3_END=$(date +%s%N)
LATENCY3=$(( (TIME3_END - TIME3) / 1000000 ))
echo "⚡ Latency: ${LATENCY3}ms"

echo ""
echo "🆚 Step 3: Cache Miss Test - New topic should route differently"
echo "---------------------------------------------------------------"

TIME4=$(date +%s%N)
curl -s -X POST "$GATEWAY_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: cache-miss-1" \
  -d "{
    \"model\": \"llama-3-2-1b\",
    \"messages\": [{\"role\": \"user\", \"content\": \"Describe the history of space exploration and its milestones\"}],
    \"max_tokens\": 30
  }" | jq -r '.choices[0].message.content' | head -1
TIME4_END=$(date +%s%N)
LATENCY4=$(( (TIME4_END - TIME4) / 1000000 ))
echo "⚡ Latency (Cache Miss): ${LATENCY4}ms"

echo ""
echo "📈 Performance Analysis"
echo "======================"
echo "Cache Hit Latencies:"
echo "  AI Topic:    ${LATENCY1}ms"
echo "  ML Topic:    ${LATENCY2}ms"
echo "  Cloud Topic: ${LATENCY3}ms"
echo "Cache Miss Latency:"
echo "  Space Topic: ${LATENCY4}ms"

echo ""
echo "🔍 To observe cache-aware routing in action:"
echo "1. Check EPP logs: oc logs -n llm-d deployment/llama-3-2-1b-epp -f"
echo "2. Monitor Grafana cache hit rate dashboard"
echo "3. Check vLLM metrics on each decode pod"
echo "4. Look for 'cache_hit' vs 'cache_miss' in pod logs"

echo ""
echo "✅ Demo completed! The lower latencies for similar prompts indicate successful cache hits."
