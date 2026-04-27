# LLM usage in this assignment

The assignment requires that I "document clearly where and how you used
the LLM in your solution, and share the prompts." This file captures
that record.

## Tool

Claude Code (Anthropic) running on Claude Opus 4.7. The harness has a
plan-mode workflow that I leaned on heavily: before writing any code,
the model researched the existing private repos in my home directory
(`/Users/crewmaty/sdm-tpc-infra`, `/Users/crewmaty/infra`,
`/Users/crewmaty/sdm-tpc-aos-cluster-state`) to mirror their
conventions, then proposed a plan, took my decisions, and executed.

## How I used it (verbatim categories)

### 1. Codebase reconnaissance (research, not code)

Three parallel `Explore` sub-agents inspected:
- the EKS Terraform module template under `~/infra` (so the new EKS
  module mirrors the existing IRSA + LB controller wiring);
- the Terragrunt + GHA OIDC pattern under `~/sdm-tpc-infra`;
- the ArgoCD ApplicationSet + Helm + ESO patterns under
  `~/sdm-tpc-aos-cluster-state`.

This kept the new code consistent with the conventions I already use
elsewhere — without me having to grep manually.

### 2. Architecture planning

A planning round produced the file
`/Users/crewmaty/.claude/plans/assignment-description-you-are-nested-valley.md`
(the approved plan committed alongside this docs/ tree). Four
clarifying questions were asked before the plan was written:

1. Where the pet REST API lives (in-cluster stub backed by CRDs);
2. How many environments to scaffold (dev only);
3. How ArgoCD is bootstrapped (Terraform `helm_release` + App-of-Apps);
4. Ingress strategy (AWS LB Controller / ALB).

### 3. Code generation

Every file in this repo was authored by Claude. I supplied:
- the assignment description;
- the OpenAPI spec;
- the pointers to `~/infra` and `~/sdm-tpc-infra` for templates;
- the four design decisions in §2;
- two follow-ups during execution: "use Helm + ArgoCD" and "Secrets
  Manager via Terraform".

### 4. Verification

The model generated unit tests alongside the code:
- `operator/internal/state/mutator_test.go` — Markov transitions,
  invariants (sleeping dog can't bark, hiding cat can't meow), and a
  reachability check across 5000 seeded iterations.
- `api/internal/handlers/api_test.go` — empty-list returns `[]` not
  `null`, validation cases, happy paths, 404 mapping, error envelope
  shape.

A `charts-lint` workflow runs `helm lint` + `helm template` +
`kubeval` on every PR; a `go-test` workflow runs `go vet` + `go test
-race` on every PR; both are wired up in `.github/workflows/`.

## Prompts used (as they were issued)

These are the user prompts in chronological order. Tool results and
internal reasoning are omitted — the prompts alone are what the
assignment asked for.

> 1. _(initial)_ The full assignment description (above) plus:
>    "few notes from myself (use terragrunt and terraform) for refferences
>    use sdm-tpc-infra repo that you can find in my home directory.
>    also the same thing as for the CI/CD pipelines for infrastructure
>    deployment. While you plan I will create an AWS role for you etc.
>    You will have to provide what input would you need to let pipes
>    work."

> 2. "for the eks module development search for (infra) repo there would
>    be templates for eks module you can use."

> 3. "Make sure to configure secrets manager deployment, also via
>    terraform. Application should be deploymed using helm charts and
>    argocd"

> 4. _(via AskUserQuestion in plan mode)_ Decisions on API hosting,
>    environments, ArgoCD bootstrap, ingress — all four "Recommended"
>    options were chosen.

## What I did NOT delegate

- I read every file the model produced before approving the plan.
- I made the architectural call (CRDs as source of truth, two binaries
  sharing one Go module via `replace`, mutator as a pure function) —
  the model proposed it and I evaluated the trade-offs.
- The OpenAPI spec was vendored verbatim, not regenerated.

## Reproducibility

The plan file (`.claude/plans/...`) and this file together let a
reviewer reconstruct the entire decision chain: input → research →
options → choices → output.
