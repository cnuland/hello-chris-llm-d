#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="llm-d"
FRONTEND_IMAGE="llm-d-frontend:latest"
BACKEND_IMAGE="llm-d-backend:latest"

echo -e "${BLUE}🚀 Starting LLM-D Demo Deployment${NC}"

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if Podman is available
if ! command -v podman &> /dev/null; then
    print_error "Podman is not installed or not in PATH"
    exit 1
fi

print_status "Checking prerequisites"

# Create namespace if it doesn't exist
if ! kubectl get namespace $NAMESPACE &> /dev/null; then
    print_status "Creating namespace: $NAMESPACE"
    kubectl create namespace $NAMESPACE
else
    print_status "Namespace $NAMESPACE already exists"
fi

# Note: For remote clusters, images need to be pushed to a registry
# For now, we'll build locally and you may need to push to a registry
print_status "Building frontend image with Podman"
cd frontend
podman build -t $FRONTEND_IMAGE .
cd ..

print_status "Building backend image with Podman"
cd backend
podman build -t $BACKEND_IMAGE .
cd ..

print_warning "Images built locally. For remote clusters, you may need to:"
print_warning "1. Tag images for your registry: podman tag <image> <registry>/<image>"
print_warning "2. Push images: podman push <registry>/<image>"
print_warning "3. Update deployment.yaml files with registry URLs"

# Apply Kubernetes manifests
print_status "Deploying frontend components"
kubectl apply -f assets/frontend/

print_status "Deploying backend components"
kubectl apply -f assets/backend/

print_status "Deploying ingress"
kubectl apply -f assets/ingress.yaml

print_status "Deploying network policy"
kubectl apply -f assets/networkpolicy.yaml

# Wait for deployments to be ready
print_status "Waiting for deployments to be ready..."

kubectl wait --for=condition=available --timeout=300s deployment/llm-d-frontend -n $NAMESPACE
kubectl wait --for=condition=available --timeout=300s deployment/llm-d-backend -n $NAMESPACE

print_status "All deployments are ready!"

# Display status
echo -e "\n${BLUE}📊 Deployment Status:${NC}"
kubectl get pods -n $NAMESPACE -o wide
echo ""
kubectl get services -n $NAMESPACE
echo ""
kubectl get ingress -n $NAMESPACE

# Instructions for accessing the application
echo -e "\n${GREEN}🎉 Deployment Complete!${NC}"
echo -e "\n${YELLOW}To access the application:${NC}"
echo "1. Add the following to your /etc/hosts file:"
echo "   127.0.0.1 llm-d.local"
echo ""
echo "2. If using minikube, run:"
echo "   minikube tunnel"
echo ""
echo "3. Access the application at:"
echo "   http://llm-d.local"
echo ""
echo -e "${BLUE}API endpoints will be available at:${NC}"
echo "   http://llm-d.local/api/v1/completions"
echo "   http://llm-d.local/api/status"
echo "   http://llm-d.local/api/health"

# Show logs command
echo -e "\n${BLUE}To view logs:${NC}"
echo "Frontend: kubectl logs -f deployment/llm-d-frontend -n $NAMESPACE"
echo "Backend:  kubectl logs -f deployment/llm-d-backend -n $NAMESPACE"

echo -e "\n${GREEN}Deployment script completed successfully!${NC}"
