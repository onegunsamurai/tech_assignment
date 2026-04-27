terraform {
  source = "../../../../modules//github-oidc"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  github_repo      = "onegunsamurai/tech_assignment"
  branch           = "main"
  create_provider  = false
  lock_table_arn   = "arn:aws:dynamodb:eu-central-1:418295698645:table/pet-mgmt-dev-eu-central-1-tflock"
  state_bucket_arn = "arn:aws:s3:::pet-mgmt-dev-eu-central-1-418295698645-tfstate"
}
