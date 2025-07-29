#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="llm-d-demo"
DEMO_VERSION="v1.0.0"
WAIT_TIMEOUT="300s"

# Print functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check OpenShift CLI
    if ! command -v oc &> /dev/null; then
        print_error "OpenShift CLI (oc) is not installed"
        exit 1
    fi
    
    # Check if logged into OpenShift
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift cluster. Please login first."
        exit 1
    fi

    # Check for GPU nodes
    if ! oc get nodes -l nvidia.com/gpu=true | grep -q "gpu"; then
        print_warning "No GPU nodes found. The demo requires GPU nodes for inference."
        read -p "Do you want to continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check for Hugging Face token
    if [ -z "${HF_TOKEN:-}" ]; then
        print_error "HF_TOKEN environment variable not set"
        echo "Please set your Hugging Face token: export HF_TOKEN=your_token_here"
        exit 1
    fi

    print_success "Prerequisites check completed"
}

# Deploy base infrastructure
deploy_base() {
    print_status "Deploying base infrastructure..."

# Check and apply CRDs
    print_status "Checking and applying CRDs..."
    oc apply -f ./k8s/crds/gateway-crd.yaml || true
    oc apply -f ./k8s/crds/gatewayparameters-crd.yaml || true
    
    # Wait for CRDs to be established
    print_status "Waiting for CRDs to be established..."
    oc wait --for condition=established --timeout=60s crd/gateways.gateway.networking.k8s.io || true
    oc wait --for condition=established --timeout=60s crd/gatewayparameters.gateway.kgateway.dev || true

    # Create namespace
    oc new-project $NAMESPACE 2/dev/null || true
    
    # Deploy LLM-D using our OpenShift installation script
    print_status "Installing LLM-D with Envoy Gateway..."
    # Save current directory
    CURRENT_DIR=$(pwd)
    cd llm-d-deployer/quickstart
    $CURRENT_DIR/scripts/install-llmd-openshift.sh
    cd $CURRENT_DIR

    print_success "Base infrastructure deployed"
}

# Deploy monitoring stack
deploy_monitoring() {
    print_status "Deploying monitoring stack..."

    # Deploy Prometheus
    print_status "Deploying Prometheus..."
    oc apply -f k8s/monitoring/prometheus.yaml

    # Deploy Grafana
    print_status "Deploying Grafana..."
    oc apply -f k8s/monitoring/grafana.yaml

    # Deploy Jaeger
    print_status "Deploying Jaeger..."
    oc apply -f k8s/monitoring/jaeger.yaml

    # Wait for monitoring components
    oc wait --for=condition=Available deployment/prometheus -n $NAMESPACE --timeout=$WAIT_TIMEOUT
    oc wait --for=condition=Available deployment/grafana -n $NAMESPACE --timeout=$WAIT_TIMEOUT
    oc wait --for=condition=Available deployment/jaeger -n $NAMESPACE --timeout=$WAIT_TIMEOUT

    print_success "Monitoring stack deployed"
}

# Deploy model servers
deploy_model_servers() {
    print_status "Deploying vLLM model servers..."

    # Deploy standard vLLM instances
    print_status "Deploying standard vLLM instances..."
    oc apply -f k8s/vllm-deployments/standard-vllm.yaml

    # Deploy disaggregated instances
    print_status "Deploying disaggregated vLLM instances..."
    oc apply -f k8s/vllm-deployments/disaggregated-vllm.yaml

    # Wait for model servers
    oc wait --for=condition=Available deployment/vllm-standard -n $NAMESPACE --timeout=$WAIT_TIMEOUT
    oc wait --for=condition=Available deployment/vllm-prefill -n $NAMESPACE --timeout=$WAIT_TIMEOUT
    oc wait --for=condition=Available deployment/vllm-decode -n $NAMESPACE --timeout=$WAIT_TIMEOUT

    print_success "Model servers deployed"
}

# Deploy backend API
deploy_backend() {
    print_status "Deploying backend API..."

    # Build and push backend image
    print_status "Building backend image..."
    cd backend
    docker build -t llm-d-demo-backend:$DEMO_VERSION .
    cd ..

    # Deploy backend
    oc apply -f k8s/backend/deployment.yaml

    # Wait for backend deployment
    oc wait --for=condition=Available deployment/llm-d-demo-backend -n $NAMESPACE --timeout=$WAIT_TIMEOUT

    print_success "Backend API deployed"
}

# Deploy frontend
deploy_frontend() {
    print_status "Deploying frontend..."

    # Build frontend
    print_status "Building frontend..."
    cd frontend
    npm install
    npm run build
    cd ..

    # Deploy frontend
    oc apply -f k8s/frontend/deployment.yaml

    # Wait for frontend deployment
    oc wait --for=condition=Available deployment/llm-d-demo-frontend -n $NAMESPACE --timeout=$WAIT_TIMEOUT

    print_success "Frontend deployed"
}

# Configure demo scenarios
configure_scenarios() {
    print_status "Configuring demo scenarios..."

    # Apply scenario configurations
    oc apply -f k8s/demo-scenarios/cache-aware-routing.yaml
    oc apply -f k8s/demo-scenarios/disaggregated-serving.yaml
    oc apply -f k8s/demo-scenarios/multi-tenant-qos.yaml
    oc apply -f k8s/demo-scenarios/auto-scaling.yaml

    print_success "Demo scenarios configured"
}

# Show access information
show_access_info() {
    print_success "Demo deployment completed!"

    # Get route information
    FRONTEND_URL=$(oc get route llm-d-demo-frontend -n $NAMESPACE -o jsonpath='{.spec.host}')
    GRAFANA_URL=$(oc get route grafana -n $NAMESPACE -o jsonpath='{.spec.host}')
    JAEGER_URL=$(oc get route jaeger -n $NAMESPACE -o jsonpath='{.spec.host}')

    echo -e "\nAccess Information:"
    echo "Demo Frontend: https://$FRONTEND_URL"
    echo "Grafana Dashboard: https://$GRAFANA_URL"
    echo "Jaeger Tracing: https://$JAEGER_URL"
    
    echo -e "\nDemo Scenarios:"
    echo "1. Cache-Aware Routing: https://$FRONTEND_URL/demo/cache-routing"
    echo "2. Prefill/Decode Disaggregation: https://$FRONTEND_URL/demo/disaggregation"
    echo "3. Multi-Tenant QoS: https://$FRONTEND_URL/demo/qos"
    echo "4. Auto-scaling: https://$FRONTEND_URL/demo/scaling"

    echo -e "\nUseful Commands:"
    echo "Watch pods: oc get pods -n $NAMESPACE -w"
    echo "View logs: oc logs -f deployment/llm-d-scheduler -n $NAMESPACE"
    echo "Access metrics: oc get --raw /apis/custom.metrics.k8s.io/v1beta1/namespaces/$NAMESPACE/pods/*/inference_qps"

    echo -e "\nCleanup Command:"
    echo "To remove the demo: $0 cleanup"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up demo deployment..."

    # Delete demo namespace
    print_status "Removing demo namespace..."
    oc delete project $NAMESPACE --timeout=$WAIT_TIMEOUT 2>/dev/null || true

    # Remove GPU operator
    print_status "Removing GPU operator..."
    oc delete clusterpolicy cluster-policy --ignore-not-found
    oc delete subscription gpu-operator-certified -n nvidia-gpu-operator --ignore-not-found
    oc delete operatorgroup nvidia-gpu-operator -n nvidia-gpu-operator --ignore-not-found
    oc delete project nvidia-gpu-operator --timeout=$WAIT_TIMEOUT 2>/dev/null || true

    print_success "Demo cleanup completed"
}

# Main deployment function
main() {
    case "${1:-deploy}" in
        "deploy")
            print_status "Starting llm-d demo deployment..."
            check_prerequisites
            deploy_base
            deploy_monitoring
            deploy_model_servers
            deploy_backend
            deploy_frontend
            configure_scenarios
            show_access_info
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            print_status "Checking deployment status..."
            oc get all -n $NAMESPACE
            ;;
        *)
            echo "Usage: $0 {deploy|cleanup|status}"
            echo ""
            echo "Commands:"
            echo "  deploy  - Deploy the complete demo environment"
            echo "  cleanup - Remove all demo resources"
            echo "  status  - Show current deployment status"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
