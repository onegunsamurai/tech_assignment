# AWS Secrets Manager wiring. Pattern lifted from
# /Users/crewmaty/infra/modules/services/main.tf (lines 86–513): one
# aws_secretsmanager_secret per logical credential, plus a *_version with
# either an explicit value or a random_password.
#
# The Kubernetes-side ExternalSecret manifests live in the eks-addons module
# (deployed after External Secrets Operator), keeping IAM and CRDs in
# separate modules so terragrunt can apply them independently.

resource "random_password" "generated" {
  for_each = { for k, v in var.secrets : k => v if v.value == null }

  length           = 32
  special          = true
  override_special = "!@#%^&*()-_=+[]{}"
}

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = "${var.env}/${each.key}"
  description = coalesce(each.value.description, "${each.key} (managed by Terraform)")
  # 7 is the AWS minimum and matches the EKS KMS deletion window above.
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secrets

  secret_id = aws_secretsmanager_secret.this[each.key].id
  secret_string = each.value.value != null ? each.value.value : random_password.generated[each.key].result
}
