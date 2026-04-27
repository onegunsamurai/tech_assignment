variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "lb_controller_role_arn" {
  type        = string
  description = "IRSA role ARN that backs the AWS LB Controller service account."
}

variable "external_secrets_role_arn" {
  type        = string
  description = "IRSA role ARN that backs the External Secrets Operator service account."
}

variable "tags" {
  type    = map(string)
  default = {}
}
