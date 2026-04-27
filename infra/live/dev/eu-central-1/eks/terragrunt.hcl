terraform {
  source = "../../../../modules//eks"
}

include "root" {
  path = find_in_parent_folders()
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    vpc_id          = "vpc-00000000000000000"
    private_subnets = ["subnet-aaaaaaaaaaaaaaaaa", "subnet-bbbbbbbbbbbbbbbbb"]
  }
}

dependency "github_oidc" {
  config_path = "../github-oidc"
  mock_outputs = {
    apply_role_arn = "arn:aws:iam::000000000000:role/dev-gha-terragrunt-apply"
  }
}

inputs = {
  cluster_name    = "pet-mgmt-dev"
  vpc_id          = dependency.vpc.outputs.vpc_id
  private_subnets = dependency.vpc.outputs.private_subnets
  deployer_arn    = dependency.github_oidc.outputs.apply_role_arn
}
