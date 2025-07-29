#!/usr/bin/env python3
"""
llm-d Demo Backend
Main FastAPI application for metrics collection and visualization
"""

import asyncio
import json
import logging
import os
import time
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass, asdict
from contextlib import asynccontextmanager

import aiohttp
import pandas as pd
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from prometheus_client import CollectorRegistry, Gauge, Counter, Histogram, generate_latest
from prometheus_client.parser import text_string_to_metric_families
import uvicorn

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Configuration
PROMETHEUS_URL = os.getenv("PROMETHEUS_URL", "http://prometheus.llm-d-demo.svc.cluster.local:9090")
LLM_D_SCHEDULER_URL = os.getenv("LLM_D_SCHEDULER_URL", "http://llm-d-scheduler.llm-d-demo.svc.cluster.local:8080")
VLLM_DISCOVERY_INTERVAL = int(os.getenv("VLLM_DISCOVERY_INTERVAL", "30"))
METRICS_COLLECTION_INTERVAL = int(os.getenv("METRICS_COLLECTION_INTERVAL", "5"))

@dataclass
class VLLMInstance:
    """Represents a vLLM instance"""
    name: str
    url: str
    variant: str  # standard, prefill, decode
    status: str
    gpu_memory_used: float
    gpu_memory_total: float
    queue_length: int
    cache_hit_rate: float
    tokens_per_second: float
    active_requests: int
    last_updated: datetime

@dataclass
class RequestMetrics:
    """Metrics for a single request"""
    request_id: str
    model: str
    timestamp: datetime
    ttft: float  # Time to First Token
    tbt: float   # Time Between Tokens
    total_latency: float
    input_tokens: int
    output_tokens: int
    cache_hit: bool
    instance: str
    variant: str

@dataclass
class SchedulerMetrics:
    """llm-d scheduler metrics"""
    routing_decisions: int
    cache_aware_routes: int
    load_balanced_routes: int
    failed_routes: int
    avg_routing_time_ms: float
    instances_discovered: int
    healthy_instances: int

class MetricsCollector:
    """Collects and manages metrics from various sources"""
    
    def __init__(self):
        self.vllm_instances: Dict[str, VLLMInstance] = {}
        self.recent_requests: List[RequestMetrics] = []
        self.scheduler_metrics = SchedulerMetrics(0, 0, 0, 0, 0.0, 0, 0)
        self.websocket_connections: List[WebSocket] = []
        
    async def discover_vllm_instances(self) -> Dict[str, VLLMInstance]:
        """Discover vLLM instances from Kubernetes API or scheduler"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{LLM_D_SCHEDULER_URL}/api/v1/instances") as response:
                    if response.status == 200:
                        data = await response.json()
                        instances = {}
                        for instance_data in data.get("instances", []):
                            instance = VLLMInstance(
                                name=instance_data["name"],
                                url=instance_data["url"],
                                variant=instance_data.get("variant", "standard"),
                                status=instance_data.get("status", "unknown"),
                                gpu_memory_used=0.0,
                                gpu_memory_total=0.0,
                                queue_length=0,
                                cache_hit_rate=0.0,
                                tokens_per_second=0.0,
                                active_requests=0,
                                last_updated=datetime.utcnow()
                            )
                            instances[instance.name] = instance
                        return instances
        except Exception as e:
            logger.error(f"Failed to discover vLLM instances: {e}")
        return self.vllm_instances

    async def collect_vllm_metrics(self, instance: VLLMInstance) -> VLLMInstance:
        """Collect metrics from a single vLLM instance"""
        try:
            async with aiohttp.ClientSession() as session:
                # Get health status
                async with session.get(f"{instance.url}/health", timeout=5) as response:
                    instance.status = "healthy" if response.status == 200 else "unhealthy"
                
                # Get metrics
                async with session.get(f"{instance.url}/metrics", timeout=5) as response:
                    if response.status == 200:
                        metrics_text = await response.text()
                        
                        # Parse Prometheus metrics
                        for family in text_string_to_metric_families(metrics_text):
                            for sample in family.samples:
                                metric_name = sample.name
                                value = sample.value
                                labels = sample.labels
                                
                                if metric_name == "vllm:gpu_memory_usage_bytes":
                                    instance.gpu_memory_used = value / (1024**3)  # Convert to GB
                                elif metric_name == "vllm:gpu_memory_total_bytes":
                                    instance.gpu_memory_total = value / (1024**3)  # Convert to GB
                                elif metric_name == "vllm:num_requests_running":
                                    instance.active_requests = int(value)
                                elif metric_name == "vllm:queue_length":
                                    instance.queue_length = int(value)
                                elif metric_name == "vllm:cache_hit_rate":
                                    instance.cache_hit_rate = value
                                elif metric_name == "vllm:avg_tokens_per_sec":
                                    instance.tokens_per_second = value
                
                instance.last_updated = datetime.utcnow()
                                
        except Exception as e:
            logger.error(f"Failed to collect metrics from {instance.name}: {e}")
            instance.status = "error"
            
        return instance

    async def collect_scheduler_metrics(self) -> SchedulerMetrics:
        """Collect metrics from llm-d scheduler"""
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{LLM_D_SCHEDULER_URL}/metrics") as response:
                    if response.status == 200:
                        metrics_text = await response.text()
                        
                        # Parse scheduler-specific metrics
                        routing_decisions = 0
                        cache_aware_routes = 0
                        load_balanced_routes = 0
                        failed_routes = 0
                        avg_routing_time = 0.0
                        instances_discovered = 0
                        healthy_instances = 0
                        
                        for family in text_string_to_metric_families(metrics_text):
                            for sample in family.samples:
                                metric_name = sample.name
                                value = sample.value
                                
                                if metric_name == "llmd_routing_decisions_total":
                                    routing_decisions = int(value)
                                elif metric_name == "llmd_cache_aware_routes_total":
                                    cache_aware_routes = int(value)
                                elif metric_name == "llmd_load_balanced_routes_total":
                                    load_balanced_routes = int(value)
                                elif metric_name == "llmd_failed_routes_total":
                                    failed_routes = int(value)
                                elif metric_name == "llmd_avg_routing_time_ms":
                                    avg_routing_time = value
                                elif metric_name == "llmd_instances_discovered":
                                    instances_discovered = int(value)
                                elif metric_name == "llmd_healthy_instances":
                                    healthy_instances = int(value)
                        
                        return SchedulerMetrics(
                            routing_decisions=routing_decisions,
                            cache_aware_routes=cache_aware_routes,
                            load_balanced_routes=load_balanced_routes,
                            failed_routes=failed_routes,
                            avg_routing_time_ms=avg_routing_time,
                            instances_discovered=instances_discovered,
                            healthy_instances=healthy_instances
                        )
        except Exception as e:
            logger.error(f"Failed to collect scheduler metrics: {e}")
        
        return self.scheduler_metrics

    async def query_prometheus(self, query: str, time_range: str = "5m") -> Dict[str, Any]:
        """Query Prometheus for historical metrics"""
        try:
            params = {
                'query': query,
                'time': int(time.time()),
                'step': '15s'
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{PROMETHEUS_URL}/api/v1/query", params=params) as response:
                    if response.status == 200:
                        return await response.json()
        except Exception as e:
            logger.error(f"Failed to query Prometheus: {e}")
        
        return {}

    async def broadcast_metrics(self):
        """Broadcast current metrics to all WebSocket connections"""
        if not self.websocket_connections:
            return
            
        metrics_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "vllm_instances": [asdict(instance) for instance in self.vllm_instances.values()],
            "scheduler_metrics": asdict(self.scheduler_metrics),
            "recent_requests": [asdict(req) for req in self.recent_requests[-50:]],  # Last 50 requests
            "summary": {
                "total_instances": len(self.vllm_instances),
                "healthy_instances": len([i for i in self.vllm_instances.values() if i.status == "healthy"]),
                "total_active_requests": sum(i.active_requests for i in self.vllm_instances.values()),
                "avg_cache_hit_rate": sum(i.cache_hit_rate for i in self.vllm_instances.values()) / max(len(self.vllm_instances), 1),
                "total_tokens_per_second": sum(i.tokens_per_second for i in self.vllm_instances.values())
            }
        }
        
        # Convert datetime objects to ISO strings for JSON serialization
        def serialize_datetime(obj):
            if isinstance(obj, datetime):
                return obj.isoformat()
            return obj
        
        message = json.dumps(metrics_data, default=serialize_datetime)
        
        # Send to all connected clients
        disconnected = []
        for ws in self.websocket_connections:
            try:
                await ws.send_text(message)
            except WebSocketDisconnect:
                disconnected.append(ws)
            except Exception as e:
                logger.error(f"Error sending WebSocket message: {e}")
                disconnected.append(ws)
        
        # Remove disconnected clients
        for ws in disconnected:
            self.websocket_connections.remove(ws)

# Global metrics collector instance
metrics_collector = MetricsCollector()

async def metrics_collection_task():
    """Background task for continuous metrics collection"""
    while True:
        try:
            # Discover vLLM instances
            instances = await metrics_collector.discover_vllm_instances()
            
            # Collect metrics from each instance
            for instance_name, instance in instances.items():
                updated_instance = await metrics_collector.collect_vllm_metrics(instance)
                metrics_collector.vllm_instances[instance_name] = updated_instance
            
            # Collect scheduler metrics
            metrics_collector.scheduler_metrics = await metrics_collector.collect_scheduler_metrics()
            
            # Broadcast to WebSocket clients
            await metrics_collector.broadcast_metrics()
            
            logger.info(f"Collected metrics from {len(instances)} instances")
            
        except Exception as e:
            logger.error(f"Error in metrics collection task: {e}")
        
        await asyncio.sleep(METRICS_COLLECTION_INTERVAL)

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Start background tasks
    task = asyncio.create_task(metrics_collection_task())
    yield
    # Clean up
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass

# FastAPI app
app = FastAPI(
    title="llm-d Demo Backend",
    description="Backend API for llm-d demonstration and metrics collection",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# API Models
class InferenceRequest(BaseModel):
    model: str
    prompt: str
    max_tokens: int = 100
    temperature: float = 0.7
    priority: str = "standard"  # interactive, standard, batch

class InferenceResponse(BaseModel):
    request_id: str
    response: str
    metrics: RequestMetrics

# API Endpoints
@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@app.get("/api/v1/metrics/instances")
async def get_instances():
    """Get current vLLM instance metrics"""
    return {
        "instances": [asdict(instance) for instance in metrics_collector.vllm_instances.values()],
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/metrics/scheduler")
async def get_scheduler_metrics():
    """Get llm-d scheduler metrics"""
    return {
        "metrics": asdict(metrics_collector.scheduler_metrics),
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/metrics/requests")
async def get_recent_requests(limit: int = 100):
    """Get recent request metrics"""
    return {
        "requests": [asdict(req) for req in metrics_collector.recent_requests[-limit:]],
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/api/v1/metrics/prometheus")
async def query_prometheus_metrics(query: str, time_range: str = "5m"):
    """Query Prometheus metrics"""
    result = await metrics_collector.query_prometheus(query, time_range)
    return result

@app.post("/api/v1/inference")
async def submit_inference_request(request: InferenceRequest):
    """Submit an inference request through llm-d scheduler"""
    try:
        request_id = f"req_{int(time.time() * 1000)}"
        
        # Route through llm-d scheduler
        payload = {
            "model": request.model,
            "messages": [{"role": "user", "content": request.prompt}],
            "max_tokens": request.max_tokens,
            "temperature": request.temperature,
            "stream": False,
            "metadata": {
                "request_id": request_id,
                "priority": request.priority,
                "demo_source": "llm-d-backend"
            }
        }
        
        start_time = time.time()
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{LLM_D_SCHEDULER_URL}/v1/chat/completions",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status == 200:
                    result = await response.json()
                    
                    end_time = time.time()
                    total_latency = end_time - start_time
                    
                    # Extract response text
                    response_text = result.get("choices", [{}])[0].get("message", {}).get("content", "")
                    
                    # Create metrics record
                    request_metrics = RequestMetrics(
                        request_id=request_id,
                        model=request.model,
                        timestamp=datetime.utcnow(),
                        ttft=result.get("metrics", {}).get("ttft", 0.0),
                        tbt=result.get("metrics", {}).get("tbt", 0.0),
                        total_latency=total_latency,
                        input_tokens=result.get("usage", {}).get("prompt_tokens", 0),
                        output_tokens=result.get("usage", {}).get("completion_tokens", 0),
                        cache_hit=result.get("metrics", {}).get("cache_hit", False),
                        instance=result.get("metrics", {}).get("instance", "unknown"),
                        variant=result.get("metrics", {}).get("variant", "standard")
                    )
                    
                    # Store request metrics
                    metrics_collector.recent_requests.append(request_metrics)
                    
                    # Keep only last 1000 requests
                    if len(metrics_collector.recent_requests) > 1000:
                        metrics_collector.recent_requests = metrics_collector.recent_requests[-1000:]
                    
                    return InferenceResponse(
                        request_id=request_id,
                        response=response_text,
                        metrics=request_metrics
                    )
                else:
                    raise HTTPException(status_code=response.status, detail=f"Inference request failed: {await response.text()}")
                    
    except Exception as e:
        logger.error(f"Inference request failed: {e}")
        raise HTTPException(status_code=500, detail=f"Inference request failed: {str(e)}")

@app.websocket("/ws/metrics")
async def websocket_metrics(websocket: WebSocket):
    """WebSocket endpoint for real-time metrics streaming"""
    await websocket.accept()
    metrics_collector.websocket_connections.append(websocket)
    
    try:
        while True:
            # Keep connection alive
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in metrics_collector.websocket_connections:
            metrics_collector.websocket_connections.remove(websocket)

@app.get("/api/v1/demo/scenarios")
async def get_demo_scenarios():
    """Get available demo scenarios"""
    scenarios = {
        "cache_aware_routing": {
            "name": "Cache-Aware Routing",
            "description": "Demonstrate intelligent routing based on prefix cache hits",
            "enabled": True,
            "config": {
                "cache_weight": 0.7,
                "load_weight": 0.3
            }
        },
        "disaggregated_serving": {
            "name": "Prefill/Decode Disaggregation",
            "description": "Show separation of prefill and decode phases",
            "enabled": True,
            "config": {
                "prefill_instances": 2,
                "decode_instances": 4
            }
        },
        "multi_tenant_qos": {
            "name": "Multi-Tenant QoS",
            "description": "Demonstrate different service levels",
            "enabled": True,
            "config": {
                "priority_levels": ["interactive", "standard", "batch"]
            }
        },
        "auto_scaling": {
            "name": "Auto-scaling",
            "description": "Show traffic-aware scaling",
            "enabled": True,
            "config": {
                "min_instances": 2,
                "max_instances": 10,
                "target_utilization": 0.7
            }
        }
    }
    return scenarios

@app.post("/api/v1/demo/scenarios/{scenario_name}/trigger")
async def trigger_demo_scenario(scenario_name: str, config: Dict[str, Any] = None):
    """Trigger a specific demo scenario"""
    try:
        payload = {
            "scenario": scenario_name,
            "config": config or {}
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{LLM_D_SCHEDULER_URL}/api/v1/demo/trigger",
                json=payload
            ) as response:
                if response.status == 200:
                    result = await response.json()
                    return {"status": "triggered", "scenario": scenario_name, "result": result}
                else:
                    raise HTTPException(status_code=response.status, detail=f"Failed to trigger scenario: {await response.text()}")
                    
    except Exception as e:
        logger.error(f"Failed to trigger scenario {scenario_name}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to trigger scenario: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        log_level="info",
        reload=False
    ) 