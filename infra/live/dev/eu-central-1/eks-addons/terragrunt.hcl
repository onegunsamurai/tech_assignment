terraform {
  source = "../../../../modules//eks-addons"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id = "vpc-00000000000000000"
  }
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name                       = "pet-mgmt-dev"
    cluster_endpoint                   = "https://example.eks.amazonaws.com"
    cluster_certificate_authority_data = "Cg=="
    lb_controller_role_arn             = "arn:aws:iam::000000000000:role/dev-eks-lb-controller"
    external_secrets_role_arn          = "arn:aws:iam::000000000000:role/dev-eks-external-secrets"
  }
}

# Provider config that points helm/kubernetes at the EKS cluster the
# previous module just provisioned. Stored at the live level (not the
# module) so the providers can be parameterized by dependency outputs.
generate "provider_kube" {
  path      = "_provider_kube.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_eks_cluster_auth" "this" {
  name = "${dependency.eks.outputs.cluster_name}"
}

provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate_authority_data}")
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
EOF
}

inputs = {
  cluster_name              = dependency.eks.outputs.cluster_name
  vpc_id                    = dependency.vpc.outputs.vpc_id
  lb_controller_role_arn    = dependency.eks.outputs.lb_controller_role_arn
  external_secrets_role_arn = dependency.eks.outputs.external_secrets_role_arn
}
