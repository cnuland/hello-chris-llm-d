#!/bin/bash

# Check if user is logged into OpenShift
if ! oc whoami &>/dev/null; then
    echo "Error: Not logged into OpenShift. Please login first using 'oc login'"
    exit 1
fi

# Check if user has cluster-admin rights
if ! oc auth can-i '*' '*' --all-namespaces >/dev/null 2>&1; then
    echo "Error: User does not have cluster-admin privileges"
    exit 1
fi

# Check if HF_TOKEN is set
if [ -z "${HF_TOKEN}" ]; then
    echo "Error: HF_TOKEN environment variable not set"
    echo "Please set your Hugging Face token: export HF_TOKEN=your_token_here"
    exit 1
fi

# Check for GPU nodes
if ! oc get nodes -l node-role.kubernetes.io/gpu=true | grep -q "gpu"; then
    echo "Warning: No nodes found with label node-role.kubernetes.io/gpu=true"
    echo "LLM-D pods will remain in Pending state without GPU nodes"
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Create values file for OpenShift
VALUES_FILE="$(dirname "$0")/openshift-values.yaml"
cat << EOF > "$VALUES_FILE"
global:
  security:
    allowInsecureImages: true

modelservice:
  enabled: true

sampleApplication:
  enabled: true
  model:
    modelArtifactURI: hf://meta-llama/Llama-3.2-3B-Instruct
    modelName: "meta-llama/Llama-3.2-3B-Instruct"
  resources:
    limits:
      nvidia.com/gpu: "1"
    requests:
      nvidia.com/gpu: "1"

gateway:
  enabled: true  # Enable Envoy Gateway

ingress:
  enabled: false  # Disable default ingress since we're using OpenShift Routes
EOF

# Install NVIDIA GPU Operator
echo "Installing NVIDIA GPU Operator..."
oc new-project nvidia-gpu-operator 2>/dev/null || true
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator
  namespace: nvidia-gpu-operator
spec:
  targetNamespaces:
  - nvidia-gpu-operator
EOF

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: nvidia-gpu-operator
spec:
  channel: "v23.6"
  installPlanApproval: Automatic
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Waiting for GPU operator to be ready..."
sleep 30

# Apply NVIDIA cluster policy
echo "Applying NVIDIA cluster policy..."
# Get absolute paths early
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
oc apply -f "${ROOT_DIR}/k8s/gpu/nvidia-cluster-policy.yaml"

# Wait for GPU operator pods to be ready
echo "Waiting for GPU operator components to be ready..."
oc wait --for=condition=ready pod -l app=nvidia-driver-daemonset -n nvidia-gpu-operator --timeout=300s || true
oc wait --for=condition=ready pod -l app=nvidia-container-toolkit-daemonset -n nvidia-gpu-operator --timeout=300s || true
oc wait --for=condition=ready pod -l app=nvidia-device-plugin-daemonset -n nvidia-gpu-operator --timeout=300s || true

# Run the installer with OpenShift configuration
echo "Installing LLM-D on OpenShift..."

# Get absolute paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
QUICKSTART_DIR="$ROOT_DIR/llm-d-deployer/quickstart"

# Change to quickstart directory
cd "$QUICKSTART_DIR" || {
    echo "Error: Could not find quickstart directory at $QUICKSTART_DIR"
    exit 1
}

# Run the installer
./llmd-installer.sh --skip-infra --gateway kgateway --values-file "$VALUES_FILE"

# Check installation status
if [ $? -eq 0 ]; then
    echo "Installation completed. Checking pod status..."
    oc get pods -n llm-d
    echo
    echo "To verify the installation, run: ./test-request.sh"
else
    echo "Installation failed. Please check the error messages above."
    exit 1
fi
