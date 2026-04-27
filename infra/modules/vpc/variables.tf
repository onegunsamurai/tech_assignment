variable "env" {
  type        = string
  description = "Deployment environment (dev/int/prod)."
}

variable "aws_region" {
  type        = string
  description = "AWS region."
}

variable "name" {
  type        = string
  description = "VPC name. The community module appends env-specific tags."
}

variable "cidr" {
  type        = string
  description = "Primary VPC CIDR. /16 is plenty for this workload."
  default     = "10.40.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to use. Two is enough for a dev EKS cluster."
}

variable "private_subnets" {
  type        = list(string)
  description = "Private subnets, one per AZ. EKS nodes and pods live here."
}

variable "public_subnets" {
  type        = list(string)
  description = "Public subnets, one per AZ. Hosts the ALB and NAT gateway."
}

variable "tags" {
  type    = map(string)
  default = {}
}
