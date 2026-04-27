terraform {
  source = "../../../../modules//github-oidc"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  github_repo     = "onegunsamurai/tech_assignment"
  branch          = "main"
  create_provider = false
}
