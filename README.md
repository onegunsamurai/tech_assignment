# Pet Management on Kubernetes

A Kubernetes-native system for managing cats and dogs through the
provided REST API specification — with **no external databases or
persistent file systems**. Pet definitions live in Kubernetes itself
(as `Cat` / `Dog` Custom Resources); a tiny operator drives their
dynamic state on a fixed cadence; a thin REST API stub speaks the
provided OpenAPI contract on top of the same CRs.

| Layer                | Technology                                                  |
| -------------------- | ----------------------------------------------------------- |
| Source of truth      | Kubernetes CRDs (`pets.example.com/v1alpha1`) — etcd         |
| Reconciler           | Go controller built with kubebuilder + controller-runtime    |
| REST API             | Go (chi) backed by client-go, no in-memory state             |
| Cluster bootstrap    | Terraform + Terragrunt (EKS, VPC, ECR, Secrets Manager)      |
| Add-ons              | AWS LB Controller, External Secrets Operator, cert-manager   |
| GitOps               | ArgoCD (App-of-Apps) with Helm chart sync waves              |
| CI/CD                | GitHub Actions with OIDC (no long-lived AWS keys)            |

See [`docs/architecture.md`](docs/architecture.md) for the full picture
and [`docs/llm-usage.md`](docs/llm-usage.md) for how I used the LLM.

---

## Repo layout

```
api/        Pet REST API (Go) — implements the OpenAPI spec, backed by CRDs
operator/   Kubebuilder operator — drives .status.state on a 30s cadence
charts/     Helm charts: pet-crds, pet-operator, pet-api, pet-system (umbrella)
argocd/     App-of-Apps + per-Application manifests
manifests/  Sample Cat/Dog CRs (ginger, rex)
infra/      Terraform modules + Terragrunt live config (dev/eu-central-1)
.github/    CI workflows (infra-plan, infra-apply, images-build, charts-lint, go-test)
docs/       Architecture, assumptions, LLM usage
```

## Quickstart (local kind, no AWS needed)

```bash
# 1. Bring up a kind cluster
kind create cluster --name pet-mgmt

# 2. Install the CRDs and operator (the API needs only kubectl access)
helm install pet-system charts/pet-system --create-namespace -n pet-system

# 3. Apply a sample pet
kubectl apply -f manifests/sample-pets/ginger.yaml -n pet-system

# 4. Watch state evolve every 30s
watch kubectl get cat ginger -n pet-system
```

## Deploying to AWS (EKS, dev)

```bash
# Required environment / variables (provide before running):
#   AWS_PROFILE / AWS_ACCESS_KEY_ID etc. — bootstrap creds for the very
#   first apply. After that the GHA OIDC role takes over.
#   GITHUB_REPO  — e.g. "my-org/tech_assignment"
#   GIT_REPO_URL — e.g. "https://github.com/my-org/tech_assignment.git"

cd infra/live/dev/eu-central-1
terragrunt run-all apply
```

After the apply finishes, ArgoCD comes up at the ALB DNS name printed in
the `argocd` module output. Initial admin password is in AWS Secrets
Manager at `dev/argocd-admin-password`.

## Required CI/CD inputs

Configure the following on the GitHub repo (Settings → Secrets and
variables → Actions):

| Name                          | Type     | Purpose                                                            |
| ----------------------------- | -------- | ------------------------------------------------------------------ |
| `AWS_REGION`                  | variable | AWS region, e.g. `eu-central-1`                                    |
| `AWS_ROLE_TO_ASSUME_PLAN`     | variable | ARN of the IAM role used by `infra-plan` (read-only)                |
| `AWS_ROLE_TO_ASSUME_APPLY`    | variable | ARN of the IAM role used by `infra-apply` and `images-build`       |

Both roles are created by the `github-oidc` Terraform module — bootstrap
that module first (or `terragrunt apply infra/live/dev/eu-central-1/github-oidc`
locally with admin creds) and copy its outputs into the GitHub UI.

## Verification

The end-to-end test plan lives in `.claude/plans/...` (see the approved
plan file). Short version:

```bash
# After ArgoCD is up and pet-system is "Healthy / Synced":
kubectl get cats,dogs -A                             # printer cols show state
kubectl get cat ginger -n pet-system -o yaml | yq .status   # observed state
sleep 60 && kubectl get cat ginger -n pet-system     # state should evolve
curl "$ALB_HOST/cats" | jq .                         # REST API matches CRs
```

## Engineering footprint

- Operator: 50m CPU req / 64Mi mem req
- API:      50m CPU req / 64Mi mem req per replica × 2 replicas
- Total app footprint: < 0.2 vCPU and < 200 MiB at idle
- Single t3.medium SPOT node group (2-4 nodes, autoscaling)
