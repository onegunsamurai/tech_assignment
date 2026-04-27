# Root terragrunt config for dev/eu-central-1. Mirrors the shape of
# /Users/crewmaty/sdm-tpc-infra/infra/environments/prod/eu-central-1/terragrunt.hcl
# but trimmed down to what this assignment actually exercises.

locals {
  app_name   = "pet-mgmt"
  env        = basename(dirname(dirname(get_terragrunt_dir())))  # "dev"
  aws_region = basename(dirname(get_terragrunt_dir()))           # "eu-central-1"
  account_id = get_aws_account_id()

  default_tags = {
    Application = local.app_name
    Environment = local.env
    Region      = local.aws_region
    Provisioner = "Terraform"
    Repo        = "tech_assignment"
  }

  # The state bucket name is bound by the 63-char S3 limit.
  state_bucket = "${local.app_name}-${local.env}-${local.aws_region}-${local.account_id}-tfstate"
  lock_table   = "${local.app_name}-${local.env}-${local.aws_region}-tflock"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = local.state_bucket
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = local.lock_table
  }
}

# Single AWS provider config; per-module terragrunt.hcl can layer
# additional providers (kubernetes, helm) on top.
generate "provider_aws" {
  path      = "_provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  default_tags { tags = ${jsonencode(local.default_tags)} }
}
EOF
}

inputs = {
  env        = local.env
  aws_region = local.aws_region
  account_id = local.account_id
  tags       = local.default_tags
}
