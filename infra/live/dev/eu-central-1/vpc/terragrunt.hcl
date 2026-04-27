terraform {
  source = "../../../../modules//vpc"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  name            = "pet-mgmt-dev"
  cidr            = "10.40.0.0/16"
  azs             = ["eu-central-1a", "eu-central-1b"]
  private_subnets = ["10.40.10.0/24", "10.40.11.0/24"]
  public_subnets  = ["10.40.20.0/24", "10.40.21.0/24"]
}
