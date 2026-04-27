# Pet Management on minikube

A laptop-friendly path for the Pet Management assignment. Brings the same
API + operator + CRDs that the cloud (EKS) path uses up on minikube, with
overrides only where the local environment requires them.

> **Where does the implementation live?**
> The Go API lives in [`/api`](../api), the operator in
> [`/operator`](../operator), the Helm charts in [`/charts`](../charts).
> This `minikube/` folder contains *only* the values overrides and scripts
> needed to run the same artifacts on a single-node cluster — no template
> duplication.

---

## Prerequisites

| Tool      | Version | Install (macOS) |
|-----------|---------|------------------|
| minikube  | ≥ 1.32  | `brew install minikube` |
| kubectl   | ≥ 1.25  | `brew install kubectl`  |
| helm      | ≥ 3.10  | `brew install helm`     |
| docker    | running | Docker Desktop          |

Roughly 2 vCPU and 2 GiB free for the minikube VM.

## Quickstart

```bash
# from the repo root
bash minikube/scripts/up.sh
```

That script is idempotent and does six things:

1. starts minikube (if it isn't already running)
2. enables the `ingress` addon (nginx)
3. builds `pet-api:local` and `pet-operator:local` directly into minikube's
   container runtime via `minikube image build` — no registry needed
4. `helm upgrade --install pet-system charts/pet-system` with the
   minikube override at [`values/minikube-values.yaml`](values/minikube-values.yaml)
5. applies the sample pets (`rex`, `ginger`) into the `pet-system` namespace
6. best-effort adds `pets.local` to `/etc/hosts` (sudo prompt — declinable)

Cold start takes ~3–5 minutes on a recent Mac; subsequent runs are ~30 s.

## Verifying it works

```bash
# CRDs serve immutable + dynamic fields directly
kubectl get cats,dogs -n pet-system
kubectl get cat ginger -n pet-system -o yaml

# state changes every ~15 s (operator reconcile loop)
watch -n2 kubectl get cat ginger -n pet-system

# REST API via ingress
curl http://pets.local/cats
curl http://pets.local/dogs
# (or, if you skipped the /etc/hosts step:)
curl --resolve pets.local:80:$(minikube ip) http://pets.local/cats

# automated smoke test (asserts 7 invariants from the assignment)
bash minikube/scripts/test.sh
```

## Declarative pet management

Pets are Kubernetes Custom Resources. Defining a new one is `kubectl apply`:

```yaml
# new-pet.yaml
apiVersion: pets.example.com/v1alpha1
kind: Dog
metadata:
  name: buddy
  namespace: pet-system
spec:
  color: brown
  gender: male
  breed: labrador
  initialState:
    isBarking: false
    isHungry: true
    isSleeping: false
```

```bash
kubectl apply -f new-pet.yaml
kubectl get dog buddy -n pet-system -w
```

The operator picks the resource up via its informer (event-driven) and
populates `.status.state` within the next reconcile (≤ 15 s on this path).

Immutable spec fields are enforced by a CEL rule on the CRD — `kubectl
patch dog buddy --type=merge -p '{"spec":{"color":"black"}}'` is rejected
by the API server.

## Tearing down

```bash
bash minikube/scripts/down.sh                  # remove release + CRDs, keep cluster
bash minikube/scripts/down.sh --delete-cluster # also `minikube delete`
```

## Layout

```
minikube/
├── README.md                     # this file
├── values/minikube-values.yaml   # subchart overrides for charts/pet-system
├── manifests/sample-pets/        # symlink → ../../manifests/sample-pets
├── scripts/
│   ├── up.sh                     # bootstrap: cluster + images + helm + samples
│   ├── build-images.sh           # minikube image build (api + operator)
│   ├── install.sh                # helm dep update + helm upgrade --install
│   ├── test.sh                   # smoke test (7 assertions)
│   ├── down.sh                   # uninstall release + CRDs
│   ├── _etc_hosts.sh             # add pets.local → minikube ip
│   └── common.sh                 # shared helpers (sourced)
└── docs/
    ├── architecture.md           # diagram, request flow, footprint, deltas
    └── llm-usage.md              # which LLM prompts shaped this work
```

## Further reading

- [`docs/architecture.md`](docs/architecture.md) — diagram, request /
  reconcile flow, resource footprint, conscious deltas vs. the cloud path.
- [`docs/llm-usage.md`](docs/llm-usage.md) — exact prompts used and how the
  LLM was integrated into the workflow.
