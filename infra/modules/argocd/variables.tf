variable "argocd_chart_version" {
  type    = string
  default = "7.6.12"
}

variable "argocd_admin_password" {
  type        = string
  description = "Plain-text initial admin password. Stored in AWS Secrets Manager by the caller; bcrypted before being passed to the chart."
  sensitive   = true
}

variable "git_repo_url" {
  type        = string
  description = "HTTPS URL of the git repo holding ArgoCD app manifests. Public repos do not need credentials."
}

variable "app_of_apps_path" {
  type        = string
  default     = "argocd"
  description = "Directory inside the git repo that contains the App-of-Apps root."
}

variable "git_target_revision" {
  type    = string
  default = "main"
}

variable "ingress_enabled" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
