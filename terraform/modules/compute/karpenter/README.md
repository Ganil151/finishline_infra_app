# Karpenter Module

Deploys Karpenter autoscaler for Kubernetes-native node provisioning on EKS clusters.

## Overview

This module manages:

- **CRDs** - Installs Karpenter Custom Resource Definitions (EC2NodeClass, NodePool, NodeClaim) using `kubectl_manifest`
- **Helm Release** - Installs the Karpenter controller via OCI chart from ECR
- **EC2NodeClass** - Defines EC2 configuration (AMI, subnets, security groups, volumes)
- **NodePool** - Defines node provisioning rules (instance types, capacity, disruption)

## Architecture

### Resource Dependency Chain

```
kubectl_manifest.karpenter_crds (EC2NodeClass CRD)
    └── kubectl_manifest.karpenter_crds_nodepool (NodePool CRD)
        └── kubectl_manifest.karpenter_crds_nodeclaim (NodeClaim CRD)
            └── helm_release.karpenter (Controller)
                └── time_sleep.wait_for_karpenter_crds (60s buffer)
                    └── kubectl_manifest.karpenter_ec2_node_class
                        └── kubectl_manifest.karpenter_node_pool
```

### Why kubectl_manifest?

The module uses `kubectl_manifest` instead of `kubernetes_manifest` for CRDs and Karpenter resources because:

1. **No Plan-Time Validation** - `kubectl_manifest` doesn't validate schema at plan time, avoiding "CRD not found" errors
2. **Deferred Validation** - Resources are validated at apply time when CRDs are actually installed
3. **Cleaner Dependency Management** - Explicit dependency chain ensures proper ordering

## Prerequisites

- EKS cluster deployed (`compute/eks`)
- IAM roles created (`security/iam`) including:
  - `karpenter-controller` role with OIDC trust
  - `karpenter-node` role for EC2 instances
- VPC and security groups with `karpenter.sh/discovery` tags
- Helm provider >= 3.0 (required for `set` argument syntax)
- kubectl provider >= 1.14

## Usage

```hcl
module "karpenter" {
  source = "../compute/karpenter"

  # EKS Cluster Configuration
  cluster_name               = module.eks.cluster_name
  cluster_endpoint           = module.eks.cluster_endpoint
  cluster_ca_certificate     = module.eks.cluster_certificate_authority_data
  aws_region                 = "us-east-1"

  # IAM Configuration (from security/iam)
  karpenter_controller_role_arn    = module.iam.karpenter_controller_role_arn
  karpenter_node_role_name         = module.iam.karpenter_node_role_name
  karpenter_instance_profile_name  = module.iam.karpenter_node_instance_profile_name

  # Networking Configuration (via tags)
  karpenter_subnet_tags = {
    "karpenter.sh/discovery" = "finishline-prod-eks"
  }
  karpenter_security_group_tags = {
    "karpenter.sh/discovery" = "finishline-prod-eks"
  }

  # Karpenter Configuration
  karpenter_instance_types      = ["m5.large", "m5.xlarge", "c5.large"]
  karpenter_max_cpu             = 50
  karpenter_capacity_types      = ["spot", "on-demand"]
  karpenter_ami_family          = "Bottlerocket"
  karpenter_volume_size         = "50Gi"
  karpenter_detailed_monitoring = false

  karpenter_namespace              = "karpenter"
  karpenter_interruption_queue_name = "finishline-prod-eks"

  # Tagging
  project_name   = "finishline"
  environment    = "prod"
  computed_tags  = local.common_tags
}
```

## Resources Created

| Resource                                    | Type         | Description                               |
| ------------------------------------------- | ------------ | ----------------------------------------- |
| `kubectl_manifest.karpenter_crds`           | CRD          | EC2NodeClass CRD                          |
| `kubectl_manifest.karpenter_crds_nodepool`  | CRD          | NodePool CRD                              |
| `kubectl_manifest.karpenter_crds_nodeclaim` | CRD          | NodeClaim CRD                             |
| `helm_release.karpenter`                    | Helm Release | Karpenter controller (OCI chart from ECR) |
| `time_sleep.wait_for_karpenter_crds`        | Time Delay   | 60-second buffer for CRD registration     |
| `kubectl_manifest.karpenter_ec2_node_class` | K8s Resource | EC2NodeClass - EC2 configuration          |
| `kubectl_manifest.karpenter_node_pool`      | K8s Resource | NodePool - provisioning rules             |

## Variables

| Variable                            | Description                                   | Type         | Default     | Required |
| ----------------------------------- | --------------------------------------------- | ------------ | ----------- | -------- |
| `cluster_name`                      | Name of the EKS cluster                       | string       | -           | ✅       |
| `cluster_endpoint`                  | Endpoint URL of the EKS cluster               | string       | -           | ✅       |
| `cluster_ca_certificate`            | Certificate authority data of the EKS cluster | string       | -           | ✅       |
| `aws_region`                        | AWS region                                    | string       | -           | ✅       |
| `karpenter_controller_role_arn`     | IAM role ARN for Karpenter controller (IRSA)  | string       | -           | ✅       |
| `karpenter_node_role_name`          | IAM role name for Karpenter nodes             | string       | -           | ✅       |
| `karpenter_instance_profile_name`   | IAM instance profile name for Karpenter nodes | string       | -           | ✅       |
| `karpenter_subnet_tags`             | Tags to select subnets for Karpenter nodes    | map(string)  | -           | ✅       |
| `karpenter_security_group_tags`     | Tags to select security groups for Karpenter  | map(string)  | -           | ✅       |
| `karpenter_instance_types`          | List of instance types for provisioning       | list(string) | -           | ✅       |
| `karpenter_max_cpu`                 | Maximum CPU cores Karpenter can provision     | number       | -           | ✅       |
| `karpenter_capacity_types`          | Capacity types (spot, on-demand)              | list(string) | -           | ✅       |
| `karpenter_ami_family`              | AMI family (e.g., Bottlerocket, AL2)          | string       | -           | ✅       |
| `karpenter_volume_size`             | Root volume size for Karpenter nodes          | string       | -           | ✅       |
| `karpenter_detailed_monitoring`     | Enable detailed monitoring for nodes          | bool         | -           | ✅       |
| `karpenter_interruption_queue_name` | SQS queue name for interruption handling      | string       | -           | ✅       |
| `karpenter_namespace`               | Kubernetes namespace for Karpenter            | string       | `karpenter` | ❌       |
| `project_name`                      | Project name for tagging                      | string       | -           | ✅       |
| `environment`                       | Environment name                              | string       | -           | ✅       |
| `computed_tags`                     | Map of tags to apply to all resources         | map(string)  | -           | ✅       |

## Outputs

| Output                          | Description                       |
| ------------------------------- | --------------------------------- |
| `karpenter_ec2_node_class_name` | Name of the EC2NodeClass resource |
| `karpenter_node_pool_name`      | Name of the NodePool resource     |

## Helm Chart Configuration

The module installs the Karpenter chart from the AWS ECR public registry:

```
oci://public.ecr.aws/karpenter/karpenter
```

**Chart Version:** 1.0.8

**Configuration Values:**

```yaml
serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: <karpenter-controller-role-arn>
settings:
  clusterName: <cluster-name>
  clusterEndpoint: <cluster-endpoint>
replicas: 1
```

### Helm Provider >= 3.0

This module uses the `set` argument syntax introduced in Helm provider v3.0:

```hcl
set = [
  {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.karpenter_controller_role_arn
  },
  {
    name  = "settings.clusterName"
    value = var.cluster_name
  },
  {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
  },
  {
    name  = "replicas"
    value = "1"
  }
]
```

The `dynamic "set"` block syntax used in Helm provider v2.x is no longer supported.

## CRD Installation Strategy

### Why Separate CRD Installation?

The Karpenter module installs CRDs separately from the Helm chart using `kubectl_manifest` resources. This approach solves the "CRD not found" error that occurs when Terraform validates `kubernetes_manifest` resources at plan time.

**Key Benefits:**

1. **Plan-Time Safety** - CRDs are installed first, avoiding validation errors
2. **Explicit Dependencies** - Clear dependency chain ensures proper ordering
3. **No Schema Validation Issues** - `kubectl_manifest` doesn't validate at plan time

### CRD Resources

The module installs three CRDs:

1. **EC2NodeClass** (`karpenter.k8s.aws/v1`) - EC2 instance configuration
2. **NodePool** (`karpenter.sh/v1`) - Node provisioning rules
3. **NodeClaim** (`karpenter.k8s.aws/v1`) - Individual node claims

## Time Sleep Buffer

After the Helm chart is installed, the module waits 60 seconds before applying the EC2NodeClass and NodePool resources:

```hcl
resource "time_sleep" "wait_for_karpenter_crds" {
  create_duration = "60s"
  depends_on = [helm_release.karpenter]
}
```

This buffer ensures:

- Kubernetes API server has registered the CRDs
- Karpenter controller has started and registered with the API
- Discovery cache has refreshed

## Verification

```bash
# Update kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region us-east-1

# Verify Karpenter controller
kubectl get pods -n karpenter

# Expected output:
# NAME                         READY   STATUS    RESTARTS   AGE
# karpenter-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Verify CRDs
kubectl get crds | grep karpenter

# Expected output:
# ec2nodeclasses.karpenter.k8s.aws          2024-01-01T00:00:00Z
# nodeclaims.karpenter.k8s.aws              2024-01-01T00:00:00Z
# nodepools.karpenter.sh                    2024-01-01T00:00:00Z

# Verify EC2NodeClass and NodePool
kubectl get ec2nodeclass default
kubectl get nodepool default

# Expected output:
# NAME      ZONES        USAGELIMITED   READY   AGE
# default   us-east-1a   true           True    2m

# NAME    TYPE        NODECLASS   MIN   MAX   WEIGHT   READY   AGE
# default   provision   default     -     -     100      True    2m

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter --tail=50
```

## Troubleshooting

### CRD Not Found Error

**Error:**

```
Error: API did not recognize GroupVersionKind from manifest
no matches for kind "EC2NodeClass" in group "karpenter.k8s.aws"
```

**Cause:** CRDs not installed or API server hasn't registered them yet.

**Resolution:**

1. Ensure CRDs are applied first (handled by module dependencies)
2. Wait for the 60-second time_sleep buffer to complete
3. Re-run `terragrunt apply` if the error persists

### Namespace Not Found Error

**Error:**

```
Error: namespaces "karpenter" not found
```

**Resolution:**
The module sets `create_namespace = true` in the Helm release, which creates the namespace automatically. If you still see this error:

1. Manually create the namespace:
   ```bash
   kubectl create namespace karpenter
   ```
2. Re-run `terragrunt apply`

### Helm Provider Version Error

**Error:**

```
Error: Unsupported block type
Blocks of type "set" are not expected here.
```

**Resolution:**
Ensure Helm provider version >= 3.0 is installed:

```bash
terraform init -upgrade
```

Check the provider version in `root.hcl`:

```hcl
helm = {
  source  = "hashicorp/helm"
  version = ">= 2.9.0"
}
```

## Related Documentation

- [Compute Modules README](../README.md)
- [Security Modules - IAM](../../security/iam/README.md)
- [Networking Modules](../../networking/README.md)
- [RUNBOOK - Karpenter Deployment](../../../docs/RUNBOOK.md#step-3-deploy-karpenter)
- [Karpenter Official Documentation](https://karpenter.sh/docs/)
