# Assumptions and explicit non-goals

These shaped the design and limit the scope of the implementation.

## Scope

- Only one environment (`dev`) is materialized in `infra/live`. The
  Terragrunt layout is structured so adding `int` / `prod` is a
  copy-paste of the `dev` directory plus a per-env values overlay.
- One AWS region (`eu-central-1`). Multi-region / DR is out of scope.
- No real domain name. The ALB exposes the pet-api over HTTP on its
  generated `*.elb.amazonaws.com` hostname. To add TLS, drop a Route53
  hosted zone + ACM cert into a new module and switch the
  `alb.ingress.kubernetes.io/listen-ports` annotation.

## Security trade-offs taken for the demo

- ArgoCD `server.insecure = true` (HTTP behind the ALB). For production,
  terminate TLS at the ALB and flip this to `false`.
- The pet-api has no authentication. Internal cluster traffic and the
  ALB itself are the boundary. For production, add OIDC at the ALB or
  authentication middleware on chi.
- The `apply` IAM role is `AdministratorAccess`. Production should
  scope it down to just S3+DynamoDB (state) + EKS + IAM + ECR + Secrets
  Manager + EC2 (VPC).
- Plan IAM role is `ReadOnlyAccess` — cheap and broad. Could be tighter
  but the tradeoff is maintenance.

## Operational trade-offs

- One NAT gateway, not one per AZ — saves ≈€30/month at the cost of
  AZ-level fault tolerance for egress. The cluster API and the workload
  itself remain multi-AZ.
- SPOT-only node group. Survives interruption (the operator and API are
  both stateless), but for production you'd want a small ON_DEMAND group
  for control-plane-adjacent pods.
- No PodDisruptionBudgets (single-AZ workload anyway). Add them when
  multi-replica HA matters.

## "Modify existing pets" interpretation

The OpenAPI spec says pets are immutable after creation (no PUT/PATCH).
The assignment says "modify existing pets" should also be possible
declaratively. We resolved this contradiction in favor of the spec:
identity (`color`, `gender`, `breed`) is immutable and enforced by CEL;
*observed* state changes over time, driven by the operator. To change
identity, the user deletes and re-creates the CR. This is documented in
`manifests/sample-pets/README.md`.

## Limits of the state simulator

The operator's mutator (`operator/internal/state/mutator.go`) generates
*plausible* state transitions, not real ones. There is no underlying
sensor or feed. This was the stated assignment: dynamic state should
"change over time", and the mutator achieves that with a small,
deterministic-given-RNG, well-tested function.

## Things deliberately NOT scaffolded

- envtest / integration tests against a real apiserver. Unit tests
  cover the mutator and HTTP handlers; envtest would require a
  controller-runtime test setup that adds a non-trivial chunk of CI time.
- Validating webhooks. CEL on the CRD covers immutability; nothing else
  needs admission-time logic for this scope.
- Autoscaling of the API (HPA). At 50m CPU req per replica × 2 replicas
  the workload is already modest.
- Karpenter or cluster-autoscaler. The EKS managed node group's
  built-in scaling (min/max/desired) is sufficient for the demo.
