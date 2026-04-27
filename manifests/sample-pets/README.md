# Sample pet manifests

Each file declares one pet. Drop a new YAML in this directory and the
ArgoCD `sample-pets` Application picks it up on the next sync. To prove
event-driven behavior locally:

```bash
kubectl apply -f manifests/sample-pets/ginger.yaml
kubectl get cat ginger -n pet-system -w
```

`spec` is immutable (CEL rule on the CRD). To "modify" a pet, delete it
and re-apply.
