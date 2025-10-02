# Deploy demo from OpenShift Web Terminal

## Prerequisites - Get a cluster

- OpenShift 4.14+
  - role: `cluster-admin` - for all [demo](demos) or [cluster](clusters) configs
  - role: `self-provisioner` - for namespaced components

[Red Hat Demo Platform](https://demo.redhat.com) Options (Tested)

NOTE: The node sizes below are the **recommended minimum** to select for provisioning

- <a href="https://demo.redhat.com/catalog?item=babylon-catalog-prod/sandboxes-gpte.sandbox-ocp.prod&utm_source=webapp&utm_medium=share-link" target="_blank">AWS with OpenShift Open Environment</a>
  - 1 x Control Plane - `m6a.2xlarge`
  - 0 x Workers - `m6a.2xlarge`
- <a href="https://demo.redhat.com/catalog?item=babylon-catalog-prod/sandboxes-gpte.ocp4-single-node.prod&utm_source=webapp&utm_medium=share-link" target="_blank">One Node OpenShift</a>
  - 1 x Control Plane - `m6a.2xlarge`
- <a href="https://catalog.demo.redhat.com/catalog?item=babylon-catalog-prod/openshift-cnv.ocp4-cnv-gitops.prod&utm_source=webapp&utm_medium=share-link" target="_blank">OpenShift GitOps Blank Environment</a>
  - 1 x Control Plane - `16 cores`, `64Gi`

## Getting Started

### Install the [OpenShift Web Terminal](https://docs.openshift.com/container-platform/4.12/web_console/web_terminal/installing-web-terminal.html)

The following icon should appear in the top right of the OpenShift web console after you have installed the operator. Clicking this icon launches the web terminal.

![Web Terminal](docs/images/web-terminal.png "Web Terminal")

NOTE: Reload the page in your browser if you do not see the icon after installing the operator.

## Setup the enhanced web terminal

```sh
# apply the enhanced web terminal
oc apply -k https://github.com/redhat-na-ssa/demo-ocp-llm-d/assets/ocp-web-terminal

# delete old web terminal
$(wtoctl | grep 'oc delete')
```

Check cli utils

```sh
bin_check kubectl
bin_check helm
bin_check oc
bin_check tkn
```

Install / configure operators

```sh
# setup operators
oc apply -k ~/demo_ops/components/operators/nfd/operator/overlays/stable/
oc apply -k ~/demo_ops/components/operators/gpu-operator-certified/operator/overlays/stable/
oc apply -k ~/demo_ops/components/operators/openshift-pipelines/operator/overlays/pipelines-1.20/
```

```sh
# setup instances
apply_firmly ~/demo_ops/components/operators/nfd/instance/overlays/default/
apply_firmly ~/demo_ops/components/operators/gpu-operator-certified/instance/overlays/default/
```

Create GPU MachineSet

```sh
# setup machineset
ocp_aws_machineset_create_gpu p5-4xlarge
ocp_aws_machineset_create_gpu p4d.24xlarge
```

Resume Instructions

Resume at [Out-of-Box Installation Guide](../../README.md#out-of-box-installation-guide)
