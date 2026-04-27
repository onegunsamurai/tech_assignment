# Architecture — minikube path

## Component diagram

```
                         ┌──────────────────────────────────────────────┐
                         │                  minikube                     │
                         │                                              │
  curl http://pets.local │   ┌──────────────┐                           │
  ───────────────────────┼──▶│ ingress-nginx │                           │
                         │   └──────┬───────┘                           │
                         │          │                                   │
                         │          ▼                                   │
                         │   ┌──────────────┐  watch + write status    │
                         │   │   pet-api    │     (REST handlers)       │
                         │   │  (1 replica) │◀──────────────┐           │
                         │   └──────┬───────┘                │          │
                         │          │ list/get/create/delete │          │
                         │          ▼                        │          │
                         │   ┌────────────────────────────────────┐    │
                         │   │       kube-apiserver  (etcd)       │    │
                         │   │   Cat / Dog CRs + .status data     │    │
                         │   └─────────▲──────────────────┬──────┘    │
                         │             │                  │           │
                         │   patch .status                │ informer  │
                         │             │                  ▼           │
                         │   ┌──────────────┐    events on Cat/Dog   │
                         │   │ pet-operator │                         │
                         │   │ (1 replica)  │ requeue every 15 s      │
                         │   └──────────────┘                         │
                         └──────────────────────────────────────────────┘
```

Two pods, no database, no external storage. State is split:

- **Immutable identity** — `Cat.spec` / `Dog.spec` (`color`, `gender`,
  `breed`). Locked by a CEL `self == oldSelf` rule on the CRD.
- **Dynamic state** — `.status.state` booleans
  (`isMeowing/isPurring/isHiding` for cats; `isBarking/isHungry/isSleeping`
  for dogs). Owned by the operator via the `status` subresource.

Both live in etcd (already part of the kube control plane). The CRD's
`additionalPrinterColumns` surface the booleans on `kubectl get`, satisfying
the assignment's _"`kubectl get cat ginger` should return those
attributes"_ requirement.

## Request flow — `POST /dogs`

```
client ──▶ ingress-nginx ──▶ pet-api ──▶ kube-apiserver
                              │              │
                              │      validates spec (CRD schema + CEL),
                              │      assigns UID, persists Dog CR
                              │              │
                              ◀── 201 Created ◀── stored Dog CR
                              │
                              ◀── pet-api maps CR → API response shape
                                  ({ id: <CR UID>, color, gender, breed,
                                     state: <CRD .status.state> })
```

Within ≤ 15 s the operator's informer fires, the reconciler initializes
`.status.state` (from `spec.initialState` or neutral defaults) and starts
advancing it on every requeue.

## Reconcile flow

`pet-operator` runs two reconcilers (`CatReconciler`, `DogReconciler`).
Each reconcile pass:

1. Fetch the CR.
2. If `.status.state == nil`, seed from `.spec.initialState` (or default).
3. Otherwise call the Markov mutator (`internal/state/mutator.go`) — biased
   transitions, e.g. a sleeping dog stays asleep with 85% probability.
4. Patch the `status` subresource with the new state, advance
   `lastTransitionTime` and `observedGeneration`.
5. Requeue after the configured interval (`--reconcile-interval=15s` on
   this path; cloud uses 30 s).

Reconciles are also event-driven: the controller-runtime informer triggers
on every CR create/update/delete, so a freshly applied CR gets a status
within the time it takes to set up the informer cache (typically << 1 s).

## Resource footprint

| Pod          | Replicas | CPU req / lim | Memory req / lim |
|--------------|----------|---------------|------------------|
| pet-api      | 1        | 50m / 200m    | 64Mi / 128Mi     |
| pet-operator | 1        | 50m / 200m    | 64Mi / 128Mi     |
| **total**    | **2**    | **100m / 400m** | **128Mi / 256Mi** |

Container images are distroless static (~15 MB each). No sidecars, no DB,
no persistent volumes. The minikube ingress addon adds its own controller
(~50m / 90Mi).

## Conscious deltas vs. the cloud (EKS) path

| Concern             | Cloud (EKS)                              | minikube path                  |
|---------------------|------------------------------------------|--------------------------------|
| Image distribution  | ECR via `images-build.yml` GitHub Action | `docker build` on the host → `minikube image load` |
| Image pull policy   | `IfNotPresent` (cloud usually pulls)     | `IfNotPresent` (must use local image) |
| Service exposure    | ALB ingress, target-type `ip`            | nginx ingress addon, host `pets.local` |
| Replicas            | api 2, operator 1 with leader election   | api 1, operator 1, leader election off |
| Service-account IAM | IRSA annotation on each SA               | empty annotations              |
| Reconcile interval  | 30 s                                     | 15 s (faster reviewer feedback) |
| Add-ons             | aws-load-balancer-controller, cert-manager, external-secrets | none |
| Bootstrap           | Terraform + ArgoCD app-of-apps           | one shell script               |

None of these changes touch the chart templates — every override lives in
[`values/minikube-values.yaml`](../values/minikube-values.yaml).

## Assumptions

1. **Single-node cluster.** Anti-affinity, multi-replica spread, and
   leader election are turned off because they buy nothing on one node.
2. **Reviewer has Docker Desktop.** `up.sh` defaults to the docker
   driver. Other drivers (podman, hyperkit, qemu) work with
   `MINIKUBE_DRIVER=...` but aren't tested.
3. **Reviewer can grant sudo to edit `/etc/hosts`.** If not, every
   `curl` example documents the `--resolve` fallback.
4. **The cloud path is the source of truth for templates.** Any future
   chart change there flows to minikube without edits as long as the
   override keys still apply. If the override drifts, `helm template`
   in CI catches it (see `verify` step in this folder's docs).
5. **API maps CR UID → response `id`.** Confirmed at
   `api/internal/handlers/api.go:75` (dog) and `:89` (cat). The smoke
   test relies on this and matches new pets by their unique `breed`
   string rather than CR name.
