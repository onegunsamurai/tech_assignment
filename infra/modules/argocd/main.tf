# ArgoCD bootstrap. Two phases:
#  1. helm_release installs argo-cd (its CRDs + server + controller + repo
#     server) into the argocd namespace, with the admin password we hand it.
#  2. kubernetes_manifest creates the root App-of-Apps Application — once
#     ArgoCD reconciles that, it discovers the rest of the platform from
#     git (pet-system, sample-pets) and the rest is GitOps.
#
# We pass the bcrypted admin password directly via Helm values; this
# matches the upstream chart's `configs.secret.argocdServerAdminPassword`
# field.

resource "bcrypt_hash" "admin" {
  cleartext = var.argocd_admin_password
}

resource "helm_release" "argocd" {
  name             = "argo-cd"
  namespace        = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  create_namespace = true

  values = [yamlencode({
    global = {
      domain = "argocd.local"
    }

    configs = {
      secret = {
        argocdServerAdminPassword = bcrypt_hash.admin.id
      }
      params = {
        # Behind an ALB without TLS for the dev demo. The ALB itself is
        # the auth boundary; production should set this to false and
        # terminate TLS at the ALB.
        "server.insecure" = true
      }
    }

    server = {
      ingress = {
        enabled          = var.ingress_enabled
        ingressClassName = "alb"
        annotations = {
          "alb.ingress.kubernetes.io/scheme"      = "internet-facing"
          "alb.ingress.kubernetes.io/target-type" = "ip"
          "alb.ingress.kubernetes.io/listen-ports" = "[{\"HTTP\":80}]"
        }
      }
      resources = {
        requests = { cpu = "100m", memory = "128Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
    }

    controller = {
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "1Gi" }
      }
    }

    repoServer = {
      resources = {
        requests = { cpu = "50m", memory = "128Mi" }
        limits   = { cpu = "200m", memory = "256Mi" }
      }
    }
  })]
}

# Root App-of-Apps. Points at this repo's argocd/ directory, which itself
# declares the pet-system and sample-pets Applications.
resource "kubernetes_manifest" "app_of_apps" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "app-of-apps"
      namespace = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_target_revision
        path           = var.app_of_apps_path
        directory = {
          recurse = true
          include = "applications/*.yaml"
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }
      syncPolicy = {
        automated = { prune = true, selfHeal = true }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
