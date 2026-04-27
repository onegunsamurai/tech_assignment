variable "env" {
  type = string
}

variable "github_repo" {
  type        = string
  description = "GitHub repo in 'org/name' form. The trust policy restricts the role to this repo."
}

variable "branch" {
  type    = string
  default = "main"
}

variable "create_provider" {
  type        = bool
  default     = true
  description = "Set to false if the OIDC provider already exists in the account (it is account-scoped, not region- or env-scoped)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
