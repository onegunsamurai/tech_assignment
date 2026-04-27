# EKS module — adapted from /Users/crewmaty/infra/modules/eks/main.tf.
# Differences from the reference:
#   - terraform-aws-modules/eks/aws bumped 18.26.2 → 20.x (API changes)
#   - cluster_version 1.22 → 1.30
#   - cluster creator gets admin via the new access-entries API instead of
#     the deprecated aws_auth ConfigMap

resource "aws_iam_role" "admin_role" {
  name = "admin-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnvironmentAdministratorRole"
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
    }]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AdministratorAccess"]
  tags                = var.tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                          = var.vpc_id
  subnet_ids                      = var.private_subnets
  cluster_endpoint_public_access  = var.endpoint_public_access
  cluster_endpoint_private_access = true

  enable_irsa = true

  # Encrypt Kubernetes secrets at rest with a customer-managed KMS key.
  cluster_encryption_config = {
    resources = ["secrets"]
  }
  kms_key_administrators          = [var.deployer_arn, aws_iam_role.admin_role.arn]
  kms_key_deletion_window_in_days = 7
  enable_kms_key_rotation         = true

  # Bootstrap the official add-ons. CoreDNS and kube-proxy are required;
  # vpc-cni handles pod networking; pod-identity-agent is needed by EKS Pod
  # Identity (cleaner than IRSA for new IAM-bound workloads).
  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    eks-pod-identity-agent = { most_recent = true }
  }

  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    disk_size      = var.node_disk_size
    instance_types = var.node_instance_types
  }

  eks_managed_node_groups = {
    primary = {
      capacity_type  = var.node_capacity_type
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
    }
  }

  # New v20 access-entries API — replaces aws_auth. The deployer role gets
  # cluster-admin so the CI pipeline can apply ArgoCD bootstrap manifests.
  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    deployer = {
      principal_arn = var.deployer_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
    admin_role = {
      principal_arn = aws_iam_role.admin_role.arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }

  tags = var.tags
}

# IRSA role for the AWS Load Balancer Controller. Reused verbatim from
# /Users/crewmaty/infra/modules/eks/main.tf (the v18→v20 EKS module bump
# does not change this submodule's interface).
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                              = "${var.env}-eks-lb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# IRSA role used by External Secrets Operator to read AWS Secrets Manager.
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                  = "${var.env}-eks-external-secrets"
  attach_external_secrets_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets"]
    }
  }

  tags = var.tags
}
