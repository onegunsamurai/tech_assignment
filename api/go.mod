module github.com/example/tech_assignment/api

go 1.22

// Reuse the operator's typed CR API rather than re-declaring the schema.
// In the monorepo a `replace` directive points the import at the local
// operator module so both binaries always share one source of truth.
replace github.com/example/tech_assignment/operator => ../operator

require (
	github.com/example/tech_assignment/operator v0.0.0
	github.com/go-chi/chi/v5 v5.0.12
	github.com/google/uuid v1.6.0
	k8s.io/apimachinery v0.30.3
	sigs.k8s.io/controller-runtime v0.18.4
)
