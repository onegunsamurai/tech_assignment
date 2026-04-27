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

variable "lock_table_arn" {
  type        = string
  description = "ARN of the DynamoDB table backing the terragrunt state lock. The plan role needs PutItem/DeleteItem here even though plan is otherwise read-only."
}

variable "state_bucket_arn" {
  type        = string
  description = "ARN of the S3 bucket holding terraform state. Granted to the plan role for explicit GetObject/ListBucket so it does not depend on the AWS-managed ReadOnlyAccess policy."
}
