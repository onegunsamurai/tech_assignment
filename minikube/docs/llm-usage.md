# LLM usage — minikube path

The assignment asks contributors to **document clearly where and how they
used the LLM in their solution, and share the prompts**. This file does
that for the minikube path specifically.

## Tooling

- **Model**: Claude Opus 4.7 (1M context).
- **Harness**: Claude Code (CLI), with the `Explore`, `Plan`, and
  `AskUserQuestion` agent / tool primitives.
- **Mode**: started in plan mode; switched to auto mode for execution.

## How the LLM was used

I used the LLM in three distinct phases:

1. **Codebase exploration.** Two `Explore` subagents ran in parallel —
   one on `api/` + `operator/`, one on `charts/` + `infra/` + `argocd/`
   + scripts/docs — to summarize what the cloud path already does. This
   prevented duplicating logic that already exists (CRDs, reconcile loop,
   API handlers) and surfaced the exact files I needed to override
   (e.g. `charts/pet-api/values.yaml:18-28`, `api/Dockerfile:8`).

2. **Design decisions.** I deliberately used the LLM to argue the
   trade-offs out loud before committing — chart values overrides vs.
   kustomize overlay vs. hand-written manifests; ingress addon vs.
   NodePort vs. port-forward — and presented the choices to the user
   via `AskUserQuestion` rather than picking silently.

3. **Generating boilerplate that has a single right answer.** The bash
   scripts (`up.sh`, `down.sh`, `install.sh`, `test.sh`) follow a
   well-trodden pattern: `set -euo pipefail`, `source common.sh`,
   colored logging, idempotency. Letting the LLM draft them and then
   reviewing kept the focus on the genuinely-novel parts (image build
   context for the API, REST `id` ↔ CR UID mapping in the smoke test).

## Prompts (verbatim)

### Phase 1 — Exploration

> Explore `/Users/crewmaty/tech_assignment/api/` and
> `/Users/crewmaty/tech_assignment/operator/` directories thoroughly.
>
> Context: This is a Cloud Infrastructure Engineer assignment that requires
> a Kubernetes-native solution managing pets (dogs/cats) via a REST API,
> with declarative + event-driven CRDs, immutable attributes, and dynamic
> state retrievable via `kubectl get`. Another Claude instance built a
> cloud-based solution. I now need to build a SEPARATE minikube version
> in a new folder without disturbing the existing cloud solution.
>
> For each directory, report: language/framework; high-level architecture
> (what the API does, what the operator does, how they talk); CRD
> definitions (kinds, immutable vs status fields, reconciliation loop);
> build tooling (Dockerfile / Makefile / images); how the in-cluster pet
> store works given the no-external-DB constraint; any deployment
> manifests / Helm charts and what they expect (registry, ingress,
> namespaces).
>
> Also peek at `/charts/`, `/infra/`, `/argocd/`, `/manifests/`,
> `/scripts/`, `/docs/` — short summary of each (one or two lines each).
> Be thorough — I need a clear picture of what already exists so my
> minikube version can reuse compatible pieces (like the API container
> image and CRDs) and only diverge where minikube requires it. Aim for
> ~600 words.

> Explore the cloud-deployment side of `/Users/crewmaty/tech_assignment`.
>
> Specifically look at: `/charts/`, `/infra/`, `/argocd/`, `/manifests/`,
> `/scripts/`, `/docs/`, `/.github/`, `/.gitignore`.
>
> Context: This is a Kubernetes assignment for managing pets via CRDs and
> a REST API. Another Claude already built a cloud solution; I'm being
> asked to build a separate minikube-friendly version in a new directory
> that won't conflict with the cloud setup.
>
> For each directory, report: file listing (one-line description per
> file); what cloud provider / infra assumptions are baked in (AWS? GKE?
> ALB? cert-manager? external-dns? cloud LBs?); what images/registries
> are referenced; Helm chart values that would need to change for local
> minikube usage (LoadBalancer → NodePort/ClusterIP, image pull policy,
> resource requests sized for laptop); anything in scripts/ that already
> does local-dev — flag it loudly so I don't reinvent; anything in docs/
> that documents architecture decisions, ADRs, or assumptions.
> Be thorough but concise. ~500 words.

### Phase 2 — Design clarification

The two `AskUserQuestion` prompts the LLM presented to the user:

1. *How should the minikube path consume the existing Helm charts under
   `/charts`?* (values overrides on existing charts / kustomize overlay /
   plain manifests)
2. *How should the REST API be reachable from the host machine for the
   kubectl/curl assignment checks?* (ingress addon + nginx / NodePort /
   port-forward / both ingress and port-forward documented)

User picked the recommended option for both.

### Phase 3 — Implementation

The implementation prompts were embedded in the plan file at
`/Users/crewmaty/.claude/plans/shiny-wandering-toucan.md`. The plan
specified the folder layout, the values override structure, the seven
smoke-test assertions, and the verification steps. Auto-mode then drove
the file writes one at a time.

## What the LLM did well

- Caught the API Dockerfile build-context quirk (`api/Dockerfile:8` copies
  `operator/` because the api module has a `replace` directive). The
  `build-images.sh` script uses the repo root as the API build context
  for that reason — easy to miss without reading the Dockerfile carefully.
- Spotted that the ingress template iterates `hosts` as **a flat list of
  strings** (`charts/pet-api/templates/ingress.yaml:14-25`), not the
  structured `[{host, paths: []}]` form, so the override file uses
  `hosts: ["pets.local"]`.
- Noticed that `pet-operator`'s default values omit `image.pullPolicy`
  even though the deployment template references `.Values.image.pullPolicy`
  — without the override, the operator pod would render with empty pull
  policy. The override sets it explicitly.
- Mapped REST response `id` to CR UID (`api/internal/handlers/api.go:75`)
  and adjusted the smoke test to look up new pets by a unique `breed`
  string rather than CR name (which the API never exposes).

## What needed correction

- Initial `test.sh` draft searched the REST response for `metadata.name`
  ("smoketest-buddy") — the API doesn't expose CR names. Caught on
  re-reading the `internal/handlers/api.go` source.
- Initial values override shaped `ingress.hosts` as objects with nested
  `paths`. Caught when re-reading the chart's ingress template.
- Initial `build-images.sh` used `minikube image build`, which fails with
  the docker driver because the build runs *inside* the minikube container
  and cannot access `/Users`. Caught at first run; switched to `docker
  build` on the host followed by `minikube image load`.
- Initial `build-images.sh` masked image-build failures with a `grep ||
  warn` line that bypassed `set -e`, so a broken build looked successful
  and the helm install ran on top of missing images. Tightened to a hard
  `die` if the post-load verification doesn't see both tags.

Each of these was caught in the same execution loop without re-prompting
the user.
