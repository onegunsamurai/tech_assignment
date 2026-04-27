terraform {
  source = "../../../../modules//ecr"
}

include "root" {
  path = find_in_parent_folders()
}

inputs = {
  repositories = ["pet-api", "pet-operator"]
}
