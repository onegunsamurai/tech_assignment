terraform {
  source = "../../../../modules//github-oidc"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  github_repo     = get_env("GITHUB_REPO", "example/tech_assignment")
  branch          = "main"
  create_provider = true
}
