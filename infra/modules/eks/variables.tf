variable "env" {
  type        = string
  description = "Deployment environment (dev/int/prod)."
}

variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "account_id" {
  type        = string
  description = "AWS account id, used for IAM admin role principal."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes minor version. Bumped from the reference module's 1.22 to a current LTS."
  default     = "1.30"
}

variable "vpc_id" {
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "deployer_arn" {
  type        = string
  description = "Role ARN that the CI pipeline assumes — added to system:masters via aws_auth."
}

variable "endpoint_public_access" {
  type        = bool
  default     = true
  description = "Set to false in production."
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_capacity_type" {
  type        = string
  default     = "SPOT"
  description = "ON_DEMAND or SPOT. Dev runs SPOT to keep cost low."
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_disk_size" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
