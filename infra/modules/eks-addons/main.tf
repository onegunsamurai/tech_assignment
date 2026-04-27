# EKS add-ons that the pet-system depends on.
#
# Why three Helm charts and not one umbrella? Each upstream chart releases
# on its own cadence; pinning their versions independently is easier than
# managing a vendored umbrella. Pattern matches the way add-ons are bolted
# onto the cluster in /Users/crewmaty/infra/modules/services/main.tf.

# ---- AWS Load Balancer Controller ------------------------------------------
resource "helm_release" "aws_lb_controller" {
  name             = "aws-load-balancer-controller"
  namespace        = "kube-system"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = "1.8.1"
  create_namespace = false

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.aws_region
    vpcId       = var.vpc_id

    serviceAccount = {
      create      = true
      name        = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.lb_controller_role_arn
      }
    }

    # Modest defaults; the controller is rarely a bottleneck.
    resources = {
      requests = { cpu = "50m", memory = "64Mi" }
      limits   = { cpu = "200m", memory = "256Mi" }
    }
  })]
}

# ---- cert-manager ----------------------------------------------------------
# The AWS LB Controller no longer needs cert-manager (1.5+ ships its own
# webhook certs). Kept here because future ingress TLS via ACM-PCA or
# Let's Encrypt would land on cert-manager.
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.15.3"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true
    resources = {
      requests = { cpu = "20m", memory = "32Mi" }
      limits   = { cpu = "100m", memory = "128Mi" }
    }
  })]
}

# ---- External Secrets Operator ---------------------------------------------
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.10.4"
  create_namespace = true

  values = [yamlencode({
    installCRDs = true

    serviceAccount = {
      create      = true
      name        = "external-secrets"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.external_secrets_role_arn
      }
    }
  })]
}

# ClusterSecretStore that points at AWS Secrets Manager. Once this exists
# any namespace can declare an ExternalSecret referencing it.
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata   = { name = "aws-secretsmanager" }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.external_secrets]
}
