# OpenShift Cluster Installation with GPU Support

This document outlines the process for installing an OpenShift cluster with NVIDIA GPU support.

## Prerequisites

1. OpenShift installer (`openshift-install`) binary
2. OpenShift CLI (`oc`) binary
3. Valid pull secret from Red Hat
4. SSH key for cluster access
5. AWS credentials with appropriate permissions
6. Domain or subdomain configured in Route53

## Installation Configuration

### 1. Create Installation Directory

```bash
mkdir install_dir
cd install_dir
```

### 2. Create install-config.yaml

```bash
cat <<EOF > install-config.yaml
apiVersion: v1
baseDomain: your.domain.com
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform:
    aws:
      type: g5.xlarge  # GPU instance type
      zones:
      - us-east-1a
      - us-east-1b
      - us-east-1c
  replicas: 3
controlPlane:
  architecture: amd64
  hyperthreading: Enabled
  name: master
  platform:
    aws:
      type: m6i.xlarge
      zones:
      - us-east-1a
      - us-east-1b
      - us-east-1c
  replicas: 3
metadata:
  name: cluster-name
networking:
  clusterNetwork:
  - cidr: 10.128.0.0/14
    hostPrefix: 23
  machineNetwork:
  - cidr: 10.0.0.0/16
  networkType: OVNKubernetes
  serviceNetwork:
  - 172.30.0.0/16
platform:
  aws:
    region: us-east-1
pullSecret: '{"auths": ...}'  # Your pull secret here
sshKey: |
  ssh-rsa AAAA...  # Your SSH public key here
EOF
```

### 3. Create Manifests and Apply Custom Configurations

```bash
openshift-install create manifests --dir=./install_dir
```

Add MachineConfig for GPU nodes:

```bash
cat <<EOF > install_dir/openshift/99-gpu-worker.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-gpu-worker
spec:
  config:
    ignition:
      version: 3.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,b3B0aW9ucyBudmlkaWEgTlZyZWcgTlZyZWdfTW9kZVNldCBOVmlkaWFfbW9kZXNldCBOVmlkaWFfdXZtCg==
        mode: 0644
        overwrite: true
        path: /etc/modules-load.d/nvidia.conf
EOF
```

### 4. Create the Cluster

```bash
openshift-install create cluster --dir=./install_dir --log-level=info
```

## Post-Installation Configuration

### 1. Label GPU Nodes

After the cluster is installed, label the GPU nodes:

```bash
# Get the node names
oc get nodes

# Label GPU nodes
oc label node <node-name> node-role.kubernetes.io/gpu=true
```

### 2. Create Machine Sets for GPU Nodes

If you need to scale GPU nodes, create a dedicated MachineSet:

```yaml
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  name: gpu-worker
  namespace: openshift-machine-api
spec:
  replicas: 3
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: <cluster-name>
      machine.openshift.io/cluster-api-machineset: gpu-worker
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: <cluster-name>
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: gpu-worker
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/gpu: ""
      providerSpec:
        value:
          ami:
            id: <ami-id>
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
            - ebs:
                iops: 2000
                volumeSize: 100
                volumeType: io1
          credentialsSecret:
            name: aws-cloud-credentials
          deviceIndex: 0
          iamInstanceProfile:
            id: <instance-profile>
          instanceType: g5.xlarge
          kind: AWSMachineProviderConfig
          placement:
            region: us-east-1
          securityGroups:
            - filters:
                - name: tag:Name
                  values:
                    - <cluster-name>-worker-sg
          subnet:
            filters:
              - name: tag:Name
                values:
                  - <cluster-name>-private-us-east-1a
          tags:
            - name: kubernetes.io/cluster/<cluster-name>
              value: owned
          userDataSecret:
            name: worker-user-data
          terminationGracePeriodSeconds: 300
```

## Verification

1. Check if nodes are properly labeled:
```bash
oc get nodes -l node-role.kubernetes.io/gpu=true
```

2. Verify machine sets:
```bash
oc get machinesets -n openshift-machine-api
```

3. Check node capacity:
```bash
oc describe node <gpu-node-name> | grep nvidia.com/gpu
```

## Next Steps

After the cluster is installed and GPU nodes are properly configured, proceed with:

1. Installing the Node Feature Discovery Operator
2. Installing the NVIDIA GPU Operator
3. Configuring the GPU stack as detailed in gpu-config.md

## Troubleshooting

1. If nodes don't join the cluster:
   - Check security group configurations
   - Verify subnet routing and connectivity
   - Check instance IAM roles and permissions

2. If GPU detection fails:
   - Verify instance type has GPUs attached
   - Check if required kernel modules are loaded
   - Verify driver installation status

3. Common AWS-specific issues:
   - Instance quota limits
   - GPU instance availability in selected zones
   - VPC and subnet configuration issues
