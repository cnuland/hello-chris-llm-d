# LLM-D Deployment Guide

Step-by-step instructions for deploying the LLM-D distributed inference platform. For architecture details and feature overview, see the [main README](README.md).

## 🚀 Deployment Options

### Option 1: Production Cache-Aware Deployment (Recommended)
```bash
# Deploy optimized cache-aware system
kubectl apply -k assets/cache-aware/

# Verify deployment
kubectl get pods -n llm-d -l app=llama-3-2-1b-decode

# Test functionality
./assets/cache-aware/cache-test.sh
```

### Option 2: Standard Asset Deployment
```bash
# Deploy base infrastructure
kubectl apply -k assets/

# Deploy monitoring (optional)
kubectl apply -k assets/monitoring/
```

### Option 3: Custom Component Deployment
```bash
# Deploy specific components
kubectl apply -f assets/cache-aware/model-service.yaml
kubectl apply -f assets/cache-aware/gateway.yaml
```

## 🚀 Final Deployment Steps

### Step 1: Login to Quay.io Registry
```bash
podman login quay.io
# Username: cnuland+ddkuberay
# Password: Q7KGVZ0KK0RQK9UMSTWIMHDJXSB987XG1O243O6PIRSOPWJHN0XAPD6M48DKWZ33
```

### Step 2: Push Images to Registry
```bash
# Run the push script
./push-images.sh

# Or manually:
podman push quay.io/cnuland/llm-interface:frontend
podman push quay.io/cnuland/llm-interface:backend
```

### Step 3: Deploy to Kubernetes
```bash
# Deploy all components
kubectl apply -f assets/

# Check deployment status
kubectl get pods -n llm-d
kubectl get services -n llm-d
kubectl get ingress -n llm-d
```

### Step 4: Access the Application

#### Option A: Via Ingress (Recommended)
1. **Get the ingress URL:**
   ```bash
   kubectl get ingress llm-d-ingress -n llm-d
   ```

2. **Add to /etc/hosts if needed:**
   ```bash
   echo "127.0.0.1 llm-d.local" | sudo tee -a /etc/hosts
   ```

3. **Access at:** `http://llm-d.local`

#### Option B: Via Port Forward (Development)
```bash
# Frontend
kubectl port-forward service/llm-d-frontend-service 8080:80 -n llm-d

# Backend  
kubectl port-forward service/llm-d-backend-service 3001:3001 -n llm-d
```

## 📋 Application Features

### 🎮 Inference Playground
- Interactive LLM testing interface
- Real-time streaming responses
- Configurable parameters (temperature, max tokens)
- Request history and caching hints

### 📊 Performance Metrics
- Real-time performance charts
- Cache hit rate monitoring
- Request throughput metrics
- Pod distribution visualization

### 🖥️ System Status
- Live pod and service monitoring
- Resource utilization tracking
- Health status indicators
- Configuration overview

## 🔧 Architecture

```
[User Browser] 
    ↓
[Ingress Controller]
    ↓
[Frontend Service] → [Frontend Pods (React + nginx)]
    ↓
[Backend Service] → [Backend Pods (Node.js Express)]
    ↓
[LLM Services, EPP, Prometheus in cluster]
```

## 🛠️ Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n llm-d
kubectl describe pod <pod-name> -n llm-d
kubectl logs <pod-name> -n llm-d
```

### Check Service Connectivity
```bash
kubectl get services -n llm-d
kubectl describe service llm-d-frontend-service -n llm-d
```

### Check Ingress
```bash
kubectl get ingress -n llm-d
kubectl describe ingress llm-d-ingress -n llm-d
```

## 🔄 Update Deployment
To update the application:
1. Rebuild images: `./deploy.sh` (build only)
2. Push to registry: `./push-images.sh`
3. Restart deployments: `kubectl rollout restart deployment/llm-d-frontend deployment/llm-d-backend -n llm-d`

## 📡 API Endpoints
Once deployed, the following endpoints will be available:

- **Frontend:** `http://llm-d.local/`
- **API Health:** `http://llm-d.local/api/health`
- **API Status:** `http://llm-d.local/api/status`
- **LLM Completions:** `http://llm-d.local/api/v1/completions`

## 🎉 Success!
Your LLM-D demo application is ready to showcase distributed inference capabilities with a professional web interface!
