terraform {
  source = "../../../../modules//argocd"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks"
  mock_outputs = {
    cluster_name                       = "pet-mgmt-dev"
    cluster_endpoint                   = "https://example.eks.amazonaws.com"
    cluster_certificate_authority_data = "Cg=="
  }
}

dependency "addons" {
  config_path = "../eks-addons"
  mock_outputs = {
    cluster_secret_store_name = "aws-secretsmanager"
  }
}

dependency "secrets" {
  config_path = "../secrets"
  mock_outputs = {
    secret_arns = {
      "argocd-admin-password" = "arn:aws:secretsmanager:eu-central-1:000000000000:secret:dev/argocd-admin-password-AAAAAA"
    }
  }
}

# We need the plain-text admin password to bcrypt before passing to Helm.
# Reading from Secrets Manager keeps the secret out of state files.
generate "data_admin_password" {
  path      = "_data_admin_password.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
data "aws_secretsmanager_secret_version" "argocd_admin" {
  secret_id = "${dependency.secrets.outputs.secret_arns["argocd-admin-password"]}"
}
EOF
}

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
  argocd_admin_password = "REPLACE_WITH_SECRETSMANAGER_VALUE"
  git_repo_url          = get_env("GIT_REPO_URL", "https://github.com/example/tech_assignment.git")
  git_target_revision   = "main"
  app_of_apps_path      = "argocd"
  ingress_enabled       = true
}

# After the data source above is generated, override the literal
# argocd_admin_password with the Secrets Manager value via a TF_VAR env
# var emitted by the GHA pipeline. Locally, run:
#   export TF_VAR_argocd_admin_password=$(aws secretsmanager get-secret-value \
#     --secret-id dev/argocd-admin-password --query SecretString --output text)
