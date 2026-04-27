output "namespace" {
  value = "argocd"
}

output "release_name" {
  value = helm_release.argocd.name
}
