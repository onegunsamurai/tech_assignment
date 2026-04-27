# GitHub OIDC provider + two IAM roles: one for "plan" (PR), one for
# "apply" (post-merge). Following the principle of least privilege, the
# plan role is intentionally weaker than apply.
#
# Trust policy mirrors the pattern used in
# /Users/crewmaty/sdm-tpc-infra/.github/workflows — the role is scoped to a
# single repo and a small allowlist of refs.

# GitHub's well-known OIDC config. Thumbprint per AWS docs.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

locals {
  provider_arn = var.create_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Plan runs on PRs only — restrict to pull_request events.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Apply runs only when a push to the protected branch happens.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:ref:refs/heads/${var.branch}"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.env}-gha-terragrunt-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_plan.json
  tags               = var.tags
}

resource "aws_iam_role" "apply" {
  name               = "${var.env}-gha-terragrunt-apply"
  assume_role_policy = data.aws_iam_policy_document.trust_apply.json
  tags               = var.tags
}

# Plan role: read-only across the account so terraform plan can examine
# any current state without being able to mutate it.
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Apply role: full control over the resources this stack manages. In a
# stricter prod setup, replace with a tightly-scoped policy. For the dev
# demo we use AdministratorAccess for clarity.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# The plan role needs DynamoDB write access on the lock table — terraform
# acquires a state lock even on read-only operations, and ReadOnlyAccess
# does not grant PutItem/DeleteItem. AdministratorAccess on the apply role
# already covers this, so only the plan role gets an inline policy.
data "aws_iam_policy_document" "plan_state_backend" {
  statement {
    sid    = "TFLockTable"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:DescribeTable",
    ]
    resources = [var.lock_table_arn]
  }

  statement {
    sid    = "TFStateBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "plan_state_backend" {
  name   = "${var.env}-gha-plan-tf-backend"
  role   = aws_iam_role.plan.name
  policy = data.aws_iam_policy_document.plan_state_backend.json
}
