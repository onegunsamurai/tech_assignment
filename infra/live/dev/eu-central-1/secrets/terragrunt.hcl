terraform {
  source = "../../../../modules//secrets"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  secrets = {
    "argocd-admin-password" = {
      description = "Initial ArgoCD admin password — rotated in Secrets Manager, consumed by the argocd module."
    }
    "github-webhook-token" = {
      description = "Placeholder for the GitHub webhook token used by ArgoCD."
    }
    "pet-api-extra-config" = {
      description = "Placeholder for future pet-api configuration consumed via ESO."
      value       = "{}"
    }
  }
}
