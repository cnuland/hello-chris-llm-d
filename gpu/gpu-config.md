# NVIDIA GPU Configuration in OpenShift

This document outlines the steps taken to configure NVIDIA GPUs in an OpenShift cluster using the NVIDIA GPU Operator and Node Feature Discovery (NFD).

## Hardware Configuration

The cluster includes nodes with the following GPU configuration:
- GPU Model: NVIDIA A100-SXM4-40GB
- Number of GPUs per node: 8
- Node Role: gpu,worker

## Prerequisites

1. OpenShift 4.19 cluster
2. Access to Red Hat Operator Hub
3. Cluster-admin privileges

## Installation and Deployment

### Install the OpenShift Cluster

1. Deploy the OpenShift cluster using the Installer Provisioned Infrastructure (IPI) method:
```bash
openshift-install create cluster --dir=./install_dir --log-level=info
```

2. Stand up the bastion host and configure network settings as required.

### Deploy the Demo Application

1. Once the cluster is ready, deploy a sample GPU-enabled workload to validate the setup:
```bash
oc new-project gpu-demo
```

2. Deploy the demo application:
```bash
cat <<EOF | oc apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: gpu-pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: nvidia/cuda-sample:pi
        resources:
          limits:
            nvidia.com/gpu: 1
        command: ["/bin/sh", "-c"]
        args: ["/samples/pi"]
      restartPolicy: Never
  backoffLimit: 4
EOF
```

Verify that the job runs successfully by checking logs:
```bash
oc logs job/gpu-pi
```

### 1. Install Node Feature Discovery Operator

1. Create the NFD namespace:
```bash
oc create namespace openshift-nfd
```

2. Install the NFD operator by applying the subscription:
```bash
oc apply -f nfd-operator-sub.yaml
```

3. Create the NodeFeatureDiscovery instance:
```bash
oc apply -f nfd-cr.yaml
```

The NFD operator will detect PCI devices and apply appropriate labels to nodes.

### 2. Install NVIDIA GPU Operator

1. Create the NVIDIA GPU operator namespace:
```bash
oc create namespace nvidia-gpu-operator
```

2. Install the NVIDIA GPU operator by applying the subscription:
```bash
oc apply -f gpu-operator-sub.yaml
```

3. Create the ClusterPolicy:
```bash
oc apply -f gpu-cluster-policy.yaml
```

## Configuration Steps

### 1. Node Feature Discovery Setup

Initially, NFD was configured to detect PCI devices for NVIDIA GPUs. The operator looks for:
- PCI Device Class 0300 (VGA compatible controller)
- PCI Device Class 0302 (3D controller)
- NVIDIA Vendor ID (10de)

This resulted in labels like:
```
feature.node.kubernetes.io/pci-0302_10de.present=true
```

### 2. NVIDIA GPU Operator Configuration

The GPU operator was configured with a ClusterPolicy resource with the following key settings:

1. Policy name was set to `cluster-policy` (exact name is required)
2. OpenShift Driver Toolkit mode enabled:
   ```yaml
   driver:
     use_ocp_driver_toolkit: true
     driver_toolkit_image: "driver-toolkit"
   ```

### 3. Driver Installation

The NVIDIA driver (version 570.148.08) was successfully installed using the OpenShift Driver Toolkit approach, which:
- Compiled the driver against the host kernel (5.14.0-570.26.1.el9_6.x86_64)
- Created necessary device nodes and character devices
- Loaded required kernel modules:
  - nvidia
  - nvidia-uvm
  - nvidia-modeset

### 4. Component Deployment

The following components were deployed and validated:

1. NVIDIA Device Plugin
   - Registers GPUs with Kubernetes
   - Enables GPU resource scheduling

2. NVIDIA Container Toolkit
   - Enables container access to GPUs
   - Configures container runtime

3. DCGM Exporter
   - Provides GPU metrics
   - Enables monitoring integration

4. GPU Feature Discovery
   - Adds detailed GPU labels to nodes
   - Enables workload targeting specific GPU features

5. Node Status Exporter
   - Reports GPU health and status
   - Monitors driver and device status

6. NVIDIA MIG Manager
   - Manages GPU partitioning
   - Handles Multi-Instance GPU configurations

## Verification

The setup was verified through multiple validation steps:

1. Node GPU Resource Registration:
   - Confirmed 8 GPUs registered on the node
   - Resource shows as: `nvidia.com/gpu: 8`

2. Node Labels:
   ```
   nvidia.com/gpu=true
   nvidia.com/gpu.present=true
   nvidia.com/gpu.deploy.driver=true
   nvidia.com/gpu.deploy.container-toolkit=true
   nvidia.com/gpu.deploy.device-plugin=true
   nvidia.com/gpu.deploy.dcgm=true
   nvidia.com/gpu.deploy.dcgm-exporter=true
   nvidia.com/gpu.deploy.gpu-feature-discovery=true
   nvidia.com/gpu.deploy.node-status-exporter=true
   ```

3. NVIDIA System Management Interface (nvidia-smi):
   - Shows all 8 GPUs properly detected
   - Reports correct GPU model and memory configuration
   - Shows proper driver version and CUDA compatibility

## Current Status

All components are running successfully:
- NVIDIA driver is loaded and functional
- GPU devices are properly registered with Kubernetes
- All operator components are running and healthy
- Validation tests (CUDA and device plugin) completed successfully

The cluster is now ready for GPU workloads with proper scheduling, monitoring, and management capabilities in place.

## Troubleshooting Notes

Key areas that required attention during setup:
1. ClusterPolicy name must be exactly `cluster-policy`
2. NFD must be configured to detect both VGA (0300) and 3D controller (0302) PCI classes
3. Proper labeling of GPU nodes is crucial for component deployment
4. SELinux compatibility is maintained through proper security context configuration
