# Architecture

## High-level diagram

```
                                  ┌──────────────┐
   kubectl apply ginger.yaml ─►  │ Cat / Dog CR  │
                                  │   (etcd)      │
                                  └─────┬─┬──────┘
                                        │ │ watch (event-driven)
                  ┌─────────────────────┘ └─────────────────┐
                  │                                         │
            ┌─────▼─────────┐                       ┌───────▼────────┐
            │ pet-operator   │                       │ pet-api        │
            │ controller-rt  │                       │ chi + client-go│
            │ patches        │                       │ POST/GET/DEL → │
            │ .status every  │                       │   CR CRUD      │
            │ 30s (mutator)  │                       │ no DB, no cache│
            └────────────────┘                       └────────┬───────┘
                                                              │
                                                       ALB (LB Ctrl)
                                                              │
                                                          internet
```

## Key design choices

### CRDs as source of truth

Requirement: "Pets should be managed entirely within Kubernetes without
external dependencies." The natural fit is to model pets as Custom
Resources. etcd is the database; we add nothing.

### Two binaries, one CR schema

The operator and the REST API both consume the `Cat` / `Dog` types
defined in `operator/api/v1alpha1`. The API module imports the operator
module via a Go `replace` directive so they cannot diverge.

### Why a thin REST API stub instead of just CRDs?

The assignment provides an OpenAPI contract that we have to honor.
Rather than pretend the API doesn't exist, the stub exposes those
endpoints, but stores nothing of its own — every request becomes one or
two `kube-apiserver` calls. No DB is needed because there is no state
the CR doesn't already hold.

The stub maps the OpenAPI `id` field to `metadata.uid` (RFC4122,
immutable, assigned by the apiserver). `metadata.name` carries the
human-readable identity used by `kubectl get cat ginger`.

### Why a separate operator at all?

To satisfy two requirements:

1. *"Dynamic state changes over time."* The operator's reconcile loop
   runs a Markov-style mutator every 30s and patches `.status.state`.
   Without it, state would be static.
2. *"Event-driven."* controller-runtime informers watch etcd; the
   reconcile fires immediately when a CR is created/updated/deleted.
   `RequeueAfter: 30s` adds the time-driven leg on top.

The mutator is a pure function (`internal/state/mutator.go`) so it's
trivially unit-testable; the controllers only orchestrate I/O around it.

### Spec immutability

Two layers:

1. **CEL on the CRD** (`x-kubernetes-validations: rule: self == oldSelf`)
   — rejects spec edits at the apiserver, no admission webhook needed.
2. The operator never writes spec — only `.status` via the status
   subresource. Defense in depth.

### `kubectl get cat ginger` UX

`additionalPrinterColumns` on the CRD surface `Color`, `Breed`, `Gender`,
and the three state booleans. So the column-formatted output makes the
dynamic state visible at a glance without `-o yaml`.

### Event-driven flow, end-to-end

```
1. user: kubectl apply -f cat.yaml
2. apiserver writes Cat CR to etcd
3. controller-runtime informer (operator) fires Reconcile(name)
4. operator seeds .status.state from spec.initialState, RequeueAfter 30s
5. 30s later: Reconcile(name) again → mutator advances state
6. user: kubectl get cat ginger → printer columns show new state
7. user: curl $ALB/cats/$UID → API LISTs CRs, returns observed state
```

### ArgoCD App-of-Apps

```
Terraform helm_release(argo-cd)
  └── creates the argocd namespace + ArgoCD CRDs + controllers
Terraform kubernetes_manifest(app-of-apps)
  └── points at argocd/ in this repo
       └── Application: pet-system  ──► charts/pet-system  (CRDs, op, API)
       └── Application: sample-pets ──► manifests/sample-pets (Cat, Dog)
```

Sync waves enforce ordering: pet-crds (-1) → pet-operator (0) → pet-api
(1) → sample-pets (2). Auto-sync with `prune` and `selfHeal` keeps the
cluster in lockstep with main.

### Secrets handling

External Secrets Operator + AWS Secrets Manager — pattern lifted from
`/Users/crewmaty/infra/modules/services/main.tf`. The infra module
provisions the Secret in AWS; the eks-addons module wires up the
`ClusterSecretStore`; consumers reference the secret via an
`ExternalSecret` (currently only the ArgoCD admin password).

### Why so few resources?

- Two Go binaries, distroless static images, ≈15-20 MB each.
- Operator does almost nothing: list/watch + a Markov step every 30s.
- API is essentially a translator; CRUD is delegated to the apiserver.
- Resource requests intentionally tiny: 50m CPU / 64Mi memory each.
- Single 2-node SPOT node group is enough; cluster autoscaler (or
  Karpenter, when added) can scale 2→4 if traffic grows.

## What is NOT here

See [`assumptions.md`](assumptions.md) for explicit non-goals.
