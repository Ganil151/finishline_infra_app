#============================================================
#          ***  Kubernetes Provider Configuration  ***
#============================================================
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  exec {
    # PROFESSOR'S MANDATE: Using v1 (stable) for 2026-compliant DevOps
    # v1beta1 is deprecated and can cause issues during CRD discovery
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

#============================================================
#          ***  Helm Provider Configuration  ***
#============================================================
provider "helm" {
  kubernetes = {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

    exec = {
      # PROFESSOR'S MANDATE: Using v1 (stable) for consistent authentication
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

#============================================================
#          ***  Time Provider Configuration  ***
#============================================================
provider "time" {}

#============================================================
#          ***  Kubectl Provider Configuration  ***
#============================================================
provider "kubectl" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--region",
      var.aws_region
    ]
  }
  load_config_file = false
}
