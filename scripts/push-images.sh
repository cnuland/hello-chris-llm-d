#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Pushing LLM-D Images to Quay.io${NC}"

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

# Check if images exist locally
if ! podman image exists quay.io/cnuland/llm-interface:frontend; then
    print_error "Frontend image not found. Please run the build first."
    exit 1
fi

if ! podman image exists quay.io/cnuland/llm-interface:backend; then
    print_error "Backend image not found. Please run the build first."
    exit 1
fi

print_status "Images tagged and ready for push"

# Instructions for manual login
echo -e "\n${YELLOW}Please login to Quay.io first:${NC}"
echo "podman login quay.io"
echo "Username: cnuland+ddkuberay"
echo "Password: Q7KGVZ0KK0RQK9UMSTWIMHDJXSB987XG1O243O6PIRSOPWJHN0XAPD6M48DKWZ33"
echo ""
read -p "Press Enter after you've logged in successfully..."

# Push frontend image
print_status "Pushing frontend image..."
if podman push quay.io/cnuland/llm-interface:frontend; then
    print_status "Frontend image pushed successfully"
else
    print_error "Failed to push frontend image"
    exit 1
fi

# Push backend image
print_status "Pushing backend image..."
if podman push quay.io/cnuland/llm-interface:backend; then
    print_status "Backend image pushed successfully"
else
    print_error "Failed to push backend image"
    exit 1
fi

echo -e "\n${GREEN}🎉 All images pushed successfully!${NC}"
echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Deploy to Kubernetes:"
echo "   kubectl apply -f assets/"
echo ""
echo "2. Check deployment status:"
echo "   kubectl get pods -n llm-d"
echo ""
echo "3. Access the application via ingress"
