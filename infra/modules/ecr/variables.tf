variable "env" {
  type = string
}

variable "repositories" {
  type        = set(string)
  description = "Names of ECR repositories to create."
  default     = ["pet-api", "pet-operator"]
}

variable "tags" {
  type    = map(string)
  default = {}
}
